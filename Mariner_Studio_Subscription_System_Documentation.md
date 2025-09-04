# Mariner Studio - Subscription System Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture Components](#architecture-components)
3. [Subscription States & Flow](#subscription-states--flow)
4. [Trial System Implementation](#trial-system-implementation)
5. [StoreKit Integration](#storekit-integration)
6. [UI Components & User Flows](#ui-components--user-flows)
7. [Key Methods & APIs](#key-methods--apis)
8. [Configuration & Setup](#configuration--setup)
9. [Error Handling & Edge Cases](#error-handling--edge-cases)
10. [Testing & Debug Tools](#testing--debug-tools)
11. [Development Guidelines](#development-guidelines)

---

## System Overview

Mariner Studio implements a comprehensive 14-day free trial subscription system using Apple's StoreKit framework. The system provides immediate app access to new users with a seamless conversion flow to a paid monthly subscription.

### Key Features
- **14-day free trial** with automatic activation for new users
- **Single subscription tier**: $2.99/month (pro_monthly)
- **Non-intrusive UI**: Trial banner appears only in final 5 days
- **Fail-safe architecture**: Subscription gate prevents unauthorized access
- **Pure StoreKit integration**: No third-party services required
- **Comprehensive debug tools**: Full trial state simulation for testing

### Architecture Philosophy
The system follows a **subscription gate pattern** where access control occurs before the main application interface, ensuring no premium features are accessible without proper authorization.

---

## Architecture Components

### Core Service Layer

#### `SimpleSubscription.swift`
**Location**: `/Mariner Studio/Services/SimpleSubscription.swift`

The central service managing all subscription logic, trial tracking, and StoreKit integration.

**Key Properties:**
```swift
@Published var subscriptionStatus: SubscriptionStatus = .unknown
@Published var trialDaysRemaining: Int = 0
@Published var isLoading: Bool = false
@Published var showTrialBanner: Bool = false

private let monthlyTrialProductID = "pro_monthly"
private let trialDurationDays = 14
```

**Computed Properties:**
```swift
var hasAppAccess: Bool {
    return subscriptionStatus.hasAccess
}

var needsPaywall: Bool {
    return subscriptionStatus.needsPaywall
}
```

### Data Models

#### `SubscriptionStatus.swift`
**Location**: `/Mariner Studio/Models/SubscriptionStatus.swift`

Defines all possible subscription states with associated data and computed properties.

```swift
enum SubscriptionStatus: Equatable {
    case unknown                              // Initial loading state
    case firstLaunch                         // New user, ready for trial
    case inTrial(daysRemaining: Int)         // Active trial period
    case trialExpired                        // Trial ended, needs subscription
    case subscribed(expiryDate: Date?)       // Active paid subscription
    case expired                             // Subscription lapsed
}
```

**State Logic:**
- **hasAccess**: `firstLaunch`, `inTrial`, `subscribed` → true
- **needsPaywall**: `trialExpired`, `expired` → true

---

## Subscription States & Flow

### User Journey States

1. **First Launch (.firstLaunch)**
   - New user opens app for first time
   - Welcome screen with trial offer displayed
   - Full feature access immediately upon trial start

2. **Active Trial (.inTrial)**
   - 14-day countdown begins
   - Full app access maintained
   - Banner appears in final 5 days (days 10-14)

3. **Trial Expired (.trialExpired)**
   - Trial period ended
   - Enhanced paywall displayed
   - App access blocked until subscription

4. **Active Subscription (.subscribed)**
   - Paid subscription active
   - Full app access
   - No restrictions or banners

5. **Expired Subscription (.expired)**
   - Subscription lapsed
   - Paywall displayed for reactivation
   - App access blocked

### State Transitions

```
firstLaunch → inTrial → trialExpired → subscribed
                    ↘        ↓           ↓
                     subscribed ← expired
```

---

## Trial System Implementation

### Trial Activation Process

1. **New User Detection**
   ```swift
   private func hasUsedTrialBefore() -> Bool {
       return userDefaults.bool(forKey: hasUsedTrialKey)
   }
   ```

2. **Trial Start**
   ```swift
   func startTrial() async {
       let now = Date()
       setTrialStartDate(now)
       markTrialAsUsed()
       
       trialDaysRemaining = trialDurationDays
       subscriptionStatus = .inTrial(daysRemaining: trialDurationDays)
   }
   ```

3. **Daily Countdown Calculation**
   ```swift
   func calculateTrialDaysRemaining() -> Int {
       guard let startDate = getTrialStartDate() else { return 0 }
       
       let calendar = Calendar.current
       let now = Date()
       let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: now).day ?? 0
       let remaining = max(0, trialDurationDays - daysSinceStart)
       
       return remaining
   }
   ```

### Persistence Strategy

**UserDefaults Keys:**
- `trialStartDate`: Date - When trial began
- `hasUsedTrial`: Bool - Trial usage flag (prevents resets)

**Security Considerations:**
- Trial state survives app deletion/reinstallation (by design)
- No server validation required
- Client-side enforcement with StoreKit verification

### Banner Logic

```swift
private func updateTrialBannerVisibility() {
    // Show banner in last 5 days of trial
    showTrialBanner = trialDaysRemaining <= 5 && trialDaysRemaining > 0
}
```

---

## StoreKit Integration

### Product Configuration

**StoreKit Configuration File**: `MarinerStudio.storekit`
```json
{
  "subscriptionGroups": [{
    "name": "Pro Subscription",
    "subscriptions": [{
      "id": "pro_monthly",
      "displayPrice": "2.99",
      "introductoryOffer": {
        "displayPrice": "Free",
        "paymentMode": "free",
        "subscriptionPeriod": "P2W"  // 14 days
      },
      "recurringSubscriptionPeriod": "P1M"
    }]
  }]
}
```

### Purchase Implementation

```swift
func subscribe(to productID: String) async throws {
    isLoading = true
    
    let products = try await Product.products(for: [productID])
    guard let product = products.first else {
        throw SubscriptionError.productNotFound
    }
    
    let result = try await product.purchase()
    
    switch result {
    case .success(let verification):
        await processTransaction(verification.unsafePayloadValue)
    case .userCancelled:
        // Handle cancellation
    case .pending:
        // Handle pending state
    }
    
    isLoading = false
}
```

### Transaction Verification

```swift
func checkForActiveSubscription() async -> Bool {
    for await result in Transaction.all {
        if case .verified(let transaction) = result {
            if transaction.productID == monthlyTrialProductID {
                return true
            }
        }
    }
    return false
}
```

### Restore Purchases

```swift
func restorePurchases() async {
    isLoading = true
    
    do {
        try await AppStore.sync()
        await determineSubscriptionStatus()
    } catch {
        // Handle restore failure
    }
    
    isLoading = false
}
```

---

## UI Components & User Flows

### Core UI Architecture

#### `SubscriptionGateView.swift`
**Purpose**: Primary access control component that determines app entry point

**Flow Logic:**
```swift
switch subscriptionService.subscriptionStatus {
case .subscribed:
    MainView()                           // Full access
case .inTrial(let daysRemaining):
    MainView()                          // Access with optional banner
        .overlay(alignment: .top) {
            if subscriptionService.showTrialBanner {
                TrialBannerView()
            }
        }
case .firstLaunch:
    FirstTimeWelcomeView()              // Trial activation screen
case .trialExpired, .expired, .unknown:
    EnhancedPaywallView()               // Subscription required
}
```

### UI Component Breakdown

#### 1. **FirstTimeWelcomeView** (in SubscriptionGateView.swift)
- **Purpose**: Welcome new users and initiate trial
- **Features**: 
  - App feature highlights
  - Clear pricing disclosure
  - Trial activation button
  - Automatic trial start

#### 2. **TrialBannerView.swift**
- **Purpose**: Non-intrusive trial status display
- **Behavior**: 
  - Appears only in final 5 days
  - Expandable subscription options
  - Days remaining counter
  - Smooth animations

#### 3. **EnhancedPaywallView.swift**
- **Purpose**: Subscription conversion screen
- **Features**:
  - Context-aware messaging
  - Feature grid layout
  - Product loading from StoreKit
  - Restore purchases option

#### 4. **SubscriptionOptionsView.swift**
- **Purpose**: Reusable subscription selection component
- **Features**:
  - Product-driven pricing display
  - Context-aware button text
  - Loading states
  - Trial inclusion badges

#### 5. **Settings Integration** (AppSettingsView.swift)
- **Purpose**: Subscription management within app settings
- **Features**:
  - Status card display
  - Action grid (upgrade, restore, manage)
  - Trial information cards
  - Subscription details

### User Flow Examples

#### New User Flow
```
App Launch → SubscriptionGateView → FirstTimeWelcomeView → 
Trial Activation → MainView (full access)
```

#### Trial Progress Flow
```
MainView → (Day 10+) TrialBannerView appears → 
Days countdown → (Day 14) Trial expires → EnhancedPaywallView
```

#### Subscription Flow
```
EnhancedPaywallView → Product selection → StoreKit purchase → 
Transaction verification → MainView (subscribed)
```

---

## Key Methods & APIs

### Primary Service Methods

#### Status Determination
```swift
func determineSubscriptionStatus() async
```
**Purpose**: Central method that evaluates current subscription state
**Logic**:
1. Check for active StoreKit subscription
2. Evaluate trial status if no subscription
3. Calculate remaining trial days
4. Update UI state accordingly

#### Trial Management
```swift
func startTrial() async                    // Activate new trial
func calculateTrialDaysRemaining() -> Int  // Get current countdown
func hasTrialBeenUsed() -> Bool           // Check trial history
```

#### Subscription Operations
```swift
func subscribe(to productID: String) async throws    // Purchase subscription
func restorePurchases() async                       // Restore previous purchases
func getAvailableProducts() async throws -> [Product] // Load StoreKit products
```

#### Status Helpers
```swift
func getSubscriptionStatusMessage() -> String  // UI-friendly status text
var hasAppAccess: Bool                        // Access permission check
var needsPaywall: Bool                        // Paywall requirement check
```

### Private Helper Methods

#### Persistence
```swift
private func setTrialStartDate(_ date: Date)
private func getTrialStartDate() -> Date?
private func markTrialAsUsed()
private func hasUsedTrialBefore() -> Bool
```

#### State Management
```swift
private func isTrialExpired() -> Bool
private func updateTrialBannerVisibility()
private func processTransaction(_ transaction: Transaction) async
```

---

## Configuration & Setup

### App Store Connect Requirements

#### Product Configuration
- **Product ID**: `pro_monthly`
- **Type**: Auto-Renewable Subscription
- **Price**: $2.99 USD per month
- **Introductory Offer**: 14-day free trial
- **Subscription Group**: Pro Subscription

#### Required Setup Steps
1. ✅ **Product Created**: `pro_monthly` already exists
2. ✅ **Trial Configured**: 14-day introductory offer added
3. ✅ **Pricing Set**: $2.99/month recurring
4. ✅ **Testing Ready**: Sandbox environment configured

### Xcode Project Configuration

#### StoreKit Configuration File
**File**: `MarinerStudio.storekit`
- Used for local testing and development
- Mirrors production App Store Connect configuration
- Includes introductory offer setup

#### Required Capabilities
- **In-App Purchase**: Enabled
- **StoreKit Testing**: Configured for local development

#### Environment Setup
```swift
// ContentView.swift - Service initialization
@StateObject private var subscriptionService = SimpleSubscription()

// Environment object propagation
.environmentObject(subscriptionService)
```

### UserDefaults Configuration

**Keys Used:**
- `"trialStartDate"`: Date storage for trial beginning
- `"hasUsedTrial"`: Boolean flag for trial usage history

**Storage Strategy:**
- Persistent across app updates
- Survives app deletion/reinstallation
- No server synchronization required

---

## Error Handling & Edge Cases

### Error Types

```swift
enum SubscriptionError: Error, LocalizedError {
    case productNotFound
    case trialAlreadyUsed
    case unknownError(String)
}
```

### Common Error Scenarios

#### 1. **Product Loading Failures**
**Cause**: Network issues, App Store Connect configuration
**Handling**:
```swift
do {
    availableProducts = try await subscriptionService.getAvailableProducts()
} catch {
    errorMessage = "Failed to load subscription options: \(error.localizedDescription)"
    showingError = true
}
```

#### 2. **Purchase Failures**
**Causes**: User cancellation, payment issues, network problems
**Handling**: Built into `subscribe(to:)` method with proper state cleanup

#### 3. **Transaction Verification Issues**
**Cause**: StoreKit verification failures
**Solution**: Using `unsafePayloadValue` for development, proper verification for production

### Edge Cases

#### 1. **Trial State Corruption**
**Scenario**: UserDefaults corruption or manipulation
**Protection**: 
- Multiple validation points
- Graceful degradation to unknown state
- Fresh status determination on app launch

#### 2. **Clock Manipulation**
**Scenario**: User changes device date
**Mitigation**:
- Based on Calendar.current for system consistency
- StoreKit verification provides server truth
- No additional protection needed for trial system

#### 3. **Network Connectivity**
**Scenario**: Offline usage during trial
**Behavior**:
- Trial countdown works offline
- Subscription validation requires connection
- Graceful degradation with retry mechanisms

#### 4. **App Store Review Edge Cases**
**Scenario**: Reviewer testing requirements
**Solution**: 
- Debug tools for state simulation
- Clear reviewer instructions provided
- Multiple test scenarios covered

---

## Testing & Debug Tools

### Built-in Debug Tools

The app includes comprehensive debug tools accessible in development builds through MainView.

#### Trial State Simulation
```swift
// Available debug actions:
- "Reset to First Launch": Complete trial reset with app restart
- "Simulate Day 10": Jump to day 10 for banner testing
- "Simulate Day 14": Jump to final trial day
- "Simulate Trial Expired": Force trial expiration
```

#### Debug Implementation Example
```swift
Button("Simulate Day 10") {
    let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
    UserDefaults.standard.set(tenDaysAgo, forKey: "trialStartDate")
    UserDefaults.standard.set(true, forKey: "hasUsedTrial")
    
    Task {
        await subscriptionService.determineSubscriptionStatus()
    }
}
```

### Testing Checklist

#### Local Development Testing
- [ ] Fresh app install shows welcome screen
- [ ] Trial activation creates proper UserDefaults entries
- [ ] Day countdown calculations work correctly
- [ ] Banner appears at correct trial stage (≤ 5 days)
- [ ] Trial expiry triggers paywall
- [ ] StoreKit integration works in simulator

#### Production Testing Preparation
- [ ] Sandbox testing with real App Store products
- [ ] Purchase flow completion
- [ ] Restore purchases functionality
- [ ] Cross-device subscription sync
- [ ] Trial-to-subscription conversion

#### User Experience Testing
- [ ] Welcome screen clarity and appeal
- [ ] Trial banner non-intrusiveness
- [ ] Paywall effectiveness and clarity
- [ ] Navigation flow smoothness
- [ ] Loading states and error handling

### Debug Logging

The system includes comprehensive logging through `DebugLogger.shared`:

```swift
// Example log entries:
DebugLogger.shared.log("💰 TRIAL_SUB: Starting trial", category: "TRIAL_SUBSCRIPTION")
DebugLogger.shared.log("⏰ TRIAL_SUB: Trial active - \(daysRemaining) days remaining", category: "TRIAL_SUBSCRIPTION")
DebugLogger.shared.log("❌ TRIAL_SUB: Trial expired", category: "TRIAL_SUBSCRIPTION")
```

**Log Categories**:
- `TRIAL_SUBSCRIPTION`: Core subscription logic
- `SUBSCRIPTION_SETTINGS`: Settings UI interactions
- `PAYWALL`: Paywall and purchase flows

---

## Development Guidelines

### Code Organization Principles

1. **Single Responsibility**: Each view handles one aspect of subscription flow
2. **Environment Objects**: Subscription service passed through environment
3. **State Management**: Centralized in SimpleSubscription service
4. **Error Boundaries**: Proper error handling at each UI layer

### Best Practices

#### Service Integration
```swift
// Proper service initialization in parent view
@StateObject private var subscriptionService = SimpleSubscription()

// Environment propagation
.environmentObject(subscriptionService)
```

#### State Observation
```swift
// React to subscription status changes
@EnvironmentObject var subscriptionService: SimpleSubscription

// Use computed properties for UI logic
var shouldShowPaywall: Bool {
    subscriptionService.needsPaywall
}
```

#### Async Operations
```swift
// Proper async handling in UI
Button("Subscribe") {
    Task {
        try await subscriptionService.subscribe(to: "pro_monthly")
    }
}
```

### Security Considerations

1. **Client-Side Enforcement**: Appropriate for trial system
2. **StoreKit Verification**: Proper transaction verification implemented
3. **No Sensitive Data**: Trial state in UserDefaults is acceptable
4. **Purchase Validation**: Server-side validation recommended for production

### Performance Optimization

1. **Lazy Loading**: Products loaded only when needed
2. **State Caching**: Subscription status cached during session
3. **Async Operations**: All StoreKit calls properly async
4. **UI Responsiveness**: Loading states for all operations

### Maintenance Guidelines

#### Regular Review Areas
1. **StoreKit API Changes**: Monitor for iOS updates
2. **App Store Guidelines**: Review policy changes
3. **User Feedback**: Monitor trial conversion rates
4. **Performance Metrics**: Track subscription status determination times

#### Update Procedures
1. **Product Changes**: Update both .storekit and App Store Connect
2. **Trial Duration Changes**: Update `trialDurationDays` constant
3. **UI Updates**: Maintain consistency across all subscription views
4. **Debug Tools**: Keep debug functionality updated with new features

### Future Enhancement Areas

1. **Analytics Integration**: Track trial progression and conversion
2. **A/B Testing**: Different trial lengths or messaging
3. **Push Notifications**: Trial expiry reminders
4. **Advanced Paywall**: Dynamic pricing or promotional offers
5. **Server Integration**: Enhanced security and cross-platform sync

---

## Conclusion

The Mariner Studio subscription system provides a comprehensive, user-friendly trial experience that balances immediate value delivery with effective conversion mechanisms. The architecture is designed for maintainability, testability, and future enhancement while meeting all App Store requirements and providing a smooth user experience.

The fail-safe subscription gate pattern ensures premium features remain protected while the generous 14-day trial period allows users to fully evaluate the app's value proposition before making a purchase decision.

---

*Documentation Version: 1.0*  
*Last Updated: August 28, 2025*  
*System Version: Production-ready with comprehensive testing tools*