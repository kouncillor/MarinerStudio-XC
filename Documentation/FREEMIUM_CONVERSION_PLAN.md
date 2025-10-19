# Freemium Conversion Plan: All Features Daily-Limited

**Date Created:** 2025-10-19
**Status:** Ready for Implementation
**Goal:** Remove all hard premium gates and give free users 1 use per day of every feature

---

## Table of Contents
- [Overview](#overview)
- [Current State](#current-state)
- [Implementation Phases](#implementation-phases)
- [Testing Checklist](#testing-checklist)
- [Files to Modify](#files-to-modify)
- [Benefits](#benefits)

---

## Overview

### Objective
Convert the app from a mixed freemium model (some features free, some premium-only) to a consistent model where **all features are available once per day for free users** and unlimited for subscribers.

### Subscription Model
- **Free Tier:** 1 use per feature per day (resets at midnight)
- **Premium Tier:** Unlimited access to all features for $2.99/month
- **Trial:** 14-day free trial (already configured in StoreKit)

### Value Proposition Change
- **Before:** "Some features locked, some limited"
- **After:** "Use every feature unlimited times with subscription"

---

## Current State

### Features Already with Daily Limits ✅
These features already implement the daily limit pattern:
- Local Weather
- Local Tides
- Local Currents
- Local Nav Units
- Local Buoys

### Features Currently Premium-Only 🔒 → 🕐
Need to convert to daily-limited:

| Category | Feature | File | Lines |
|----------|---------|------|-------|
| **Weather** | Favorites | `WeatherMenuView.swift` | 15-37 |
| **Weather** | Map | `WeatherMenuView.swift` | 78-99 |
| **Weather** | Radar | `WeatherMenuView.swift` | 101-124 |
| **Tides** | Favorites | `TideMenuView.swift` | 14-35 |
| **Currents** | Favorites | `CurrentMenuView.swift` | 14-35 |
| **Nav Units** | Favorites | `NavUnitMenuView.swift` | 14-35 |
| **Buoys** | Favorites | `BuoyMenuView.swift` | 22-44 |
| **Routes** | Entire Menu | `MainView.swift` | 76-94 |

**Total:** 8 features to convert

---

## Implementation Phases

### PHASE 1: Update SimpleSubscription Service
**File:** `Mariner Studio/Services/SimpleSubscription.swift`

#### Step 1.1: Add New UserDefaults Keys
Add after line 20 (after existing usage keys):

```swift
private let weatherFavoritesUsageKey = "weatherFavoritesUsageDate"
private let weatherMapUsageKey = "weatherMapUsageDate"
private let weatherRadarUsageKey = "weatherRadarUsageDate"
private let tideFavoritesUsageKey = "tideFavoritesUsageDate"
private let currentFavoritesUsageKey = "currentFavoritesUsageDate"
private let navUnitFavoritesUsageKey = "navUnitFavoritesUsageDate"
private let buoyFavoritesUsageKey = "buoyFavoritesUsageDate"
private let routesUsageKey = "routesUsageDate"
```

#### Step 1.2: Add Access Check Methods
Add after line 289 (after existing feature access methods):

```swift
// MARK: - Weather Feature Access
func canAccessWeatherFavorites() -> Bool {
    if subscriptionStatus.hasAccess { return true }
    return canUseDailyFeature(key: weatherFavoritesUsageKey)
}

func recordWeatherFavoritesUsage() {
    recordDailyFeatureUsage(key: weatherFavoritesUsageKey)
    DebugLogger.shared.log("⭐ SIMPLE_SUB: Weather favorites usage recorded for today", category: "SUBSCRIPTION")
}

func canAccessWeatherMap() -> Bool {
    if subscriptionStatus.hasAccess { return true }
    return canUseDailyFeature(key: weatherMapUsageKey)
}

func recordWeatherMapUsage() {
    recordDailyFeatureUsage(key: weatherMapUsageKey)
    DebugLogger.shared.log("🗺️ SIMPLE_SUB: Weather map usage recorded for today", category: "SUBSCRIPTION")
}

func canAccessWeatherRadar() -> Bool {
    if subscriptionStatus.hasAccess { return true }
    return canUseDailyFeature(key: weatherRadarUsageKey)
}

func recordWeatherRadarUsage() {
    recordDailyFeatureUsage(key: weatherRadarUsageKey)
    DebugLogger.shared.log("📡 SIMPLE_SUB: Weather radar usage recorded for today", category: "SUBSCRIPTION")
}

// MARK: - Tide Feature Access
func canAccessTideFavorites() -> Bool {
    if subscriptionStatus.hasAccess { return true }
    return canUseDailyFeature(key: tideFavoritesUsageKey)
}

func recordTideFavoritesUsage() {
    recordDailyFeatureUsage(key: tideFavoritesUsageKey)
    DebugLogger.shared.log("⭐ SIMPLE_SUB: Tide favorites usage recorded for today", category: "SUBSCRIPTION")
}

// MARK: - Current Feature Access
func canAccessCurrentFavorites() -> Bool {
    if subscriptionStatus.hasAccess { return true }
    return canUseDailyFeature(key: currentFavoritesUsageKey)
}

func recordCurrentFavoritesUsage() {
    recordDailyFeatureUsage(key: currentFavoritesUsageKey)
    DebugLogger.shared.log("⭐ SIMPLE_SUB: Current favorites usage recorded for today", category: "SUBSCRIPTION")
}

// MARK: - Nav Unit Feature Access
func canAccessNavUnitFavorites() -> Bool {
    if subscriptionStatus.hasAccess { return true }
    return canUseDailyFeature(key: navUnitFavoritesUsageKey)
}

func recordNavUnitFavoritesUsage() {
    recordDailyFeatureUsage(key: navUnitFavoritesUsageKey)
    DebugLogger.shared.log("⭐ SIMPLE_SUB: Nav unit favorites usage recorded for today", category: "SUBSCRIPTION")
}

// MARK: - Buoy Feature Access
func canAccessBuoyFavorites() -> Bool {
    if subscriptionStatus.hasAccess { return true }
    return canUseDailyFeature(key: buoyFavoritesUsageKey)
}

func recordBuoyFavoritesUsage() {
    recordDailyFeatureUsage(key: buoyFavoritesUsageKey)
    DebugLogger.shared.log("⭐ SIMPLE_SUB: Buoy favorites usage recorded for today", category: "SUBSCRIPTION")
}

// MARK: - Routes Feature Access
func canAccessRoutes() -> Bool {
    if subscriptionStatus.hasAccess { return true }
    return canUseDailyFeature(key: routesUsageKey)
}

func recordRoutesUsage() {
    recordDailyFeatureUsage(key: routesUsageKey)
    DebugLogger.shared.log("🗺️ SIMPLE_SUB: Routes usage recorded for today", category: "SUBSCRIPTION")
}
```

#### Step 1.3: Update Debug Reset Function
Add to existing `resetSubscriptionState()` function (around line 352):

```swift
// Clear new feature usage tracking
userDefaults.removeObject(forKey: weatherFavoritesUsageKey)
userDefaults.removeObject(forKey: weatherMapUsageKey)
userDefaults.removeObject(forKey: weatherRadarUsageKey)
userDefaults.removeObject(forKey: tideFavoritesUsageKey)
userDefaults.removeObject(forKey: currentFavoritesUsageKey)
userDefaults.removeObject(forKey: navUnitFavoritesUsageKey)
userDefaults.removeObject(forKey: buoyFavoritesUsageKey)
userDefaults.removeObject(forKey: routesUsageKey)
```

---

### PHASE 2: Update Weather Menu View
**File:** `Mariner Studio/Views/Weather/WeatherMenuView.swift`

#### Step 2.1: Add State Variables
Add after line 7:

```swift
@State private var showWeatherFavoritesView = false
@State private var showWeatherMapView = false
```

#### Step 2.2: Convert Weather Favorites (Lines 14-37)
Replace the existing premium-gated code:

```swift
// Favorites - Daily limited
if subscriptionService.hasAppAccess {
    NavigationLink(destination: WeatherFavoritesView(
        coreDataManager: serviceProvider.coreDataManager
    )) {
        MenuButtonContent(
            iconType: .system("star.fill"),
            title: "FAVORITES",
            color: .yellow
        )
    }
} else if subscriptionService.canAccessWeatherFavorites() {
    Button(action: {
        subscriptionService.recordWeatherFavoritesUsage()
        showWeatherFavoritesView = true
    }) {
        MenuButtonContent(
            iconType: .system("star.fill"),
            title: "FAVORITES",
            color: .yellow,
            isDailyLimited: true
        )
    }
    .buttonStyle(PlainButtonStyle())
} else {
    Button(action: {
        showSubscriptionPrompt = true
    }) {
        MenuButtonContent(
            iconType: .system("star.fill"),
            title: "FAVORITES",
            color: .yellow,
            isUsedToday: true
        )
    }
    .buttonStyle(PlainButtonStyle())
}
```

#### Step 2.3: Convert Weather Map (Lines 78-99)
Apply same pattern using `canAccessWeatherMap()` / `recordWeatherMapUsage()` / `showWeatherMapView`

#### Step 2.4: Convert Weather Radar (Lines 101-124)
Apply same pattern using `canAccessWeatherRadar()` / `recordWeatherRadarUsage()`
Note: Radar opens URL, so no navigation destination needed - just record usage before opening

#### Step 2.5: Add Navigation Destinations
Add after line 138 (after existing `.navigationDestination`):

```swift
.navigationDestination(isPresented: $showWeatherFavoritesView) {
    WeatherFavoritesView(coreDataManager: serviceProvider.coreDataManager)
}
.navigationDestination(isPresented: $showWeatherMapView) {
    WeatherMapView()
}
```

---

### PHASE 3: Update Tide Menu View
**File:** `Mariner Studio/Views/Tides/TideMenuView.swift`

#### Step 3.1: Add State Variable
Add after line 7:

```swift
@State private var showTideFavoritesView = false
```

#### Step 3.2: Convert Tide Favorites (Lines 14-35)
Apply daily-limit pattern using:
- `canAccessTideFavorites()` / `recordTideFavoritesUsage()`
- `showTideFavoritesView` state variable
- Follow same structure as Weather Favorites

#### Step 3.3: Add Navigation Destination
Add after existing `.navigationDestination`:

```swift
.navigationDestination(isPresented: $showTideFavoritesView) {
    TideFavoritesView(coreDataManager: serviceProvider.coreDataManager)
}
```

---

### PHASE 4: Update Current Menu View
**File:** `Mariner Studio/Views/Currents/CurrentMenuView.swift`

#### Step 4.1: Add State Variable
Add after line 7:

```swift
@State private var showCurrentFavoritesView = false
```

#### Step 4.2: Convert Current Favorites (Lines 14-35)
Apply daily-limit pattern using:
- `canAccessCurrentFavorites()` / `recordCurrentFavoritesUsage()`
- `showCurrentFavoritesView` state variable

#### Step 4.3: Add Navigation Destination
Add after existing `.navigationDestination`:

```swift
.navigationDestination(isPresented: $showCurrentFavoritesView) {
    CurrentFavoritesView(coreDataManager: serviceProvider.coreDataManager)
}
```

---

### PHASE 5: Update Nav Unit Menu View
**File:** `Mariner Studio/Views/NavUnit/NavUnitMenuView.swift`

#### Step 5.1: Add State Variable
Add after line 7:

```swift
@State private var showNavUnitFavoritesView = false
```

#### Step 5.2: Convert Nav Unit Favorites (Lines 14-35)
Apply daily-limit pattern using:
- `canAccessNavUnitFavorites()` / `recordNavUnitFavoritesUsage()`
- `showNavUnitFavoritesView` state variable

#### Step 5.3: Add Navigation Destination
Add after existing `.navigationDestination`:

```swift
.navigationDestination(isPresented: $showNavUnitFavoritesView) {
    NavUnitFavoritesView(coreDataManager: CoreDataManager.shared)
}
```

---

### PHASE 6: Update Buoy Menu View
**File:** `Mariner Studio/Views/Buoys/BuoyMenuView.swift`

#### Step 6.1: Add State Variable
Add after line 15:

```swift
@State private var showBuoyFavoritesView = false
```

#### Step 6.2: Convert Buoy Favorites (Lines 22-44)
Apply daily-limit pattern using:
- `canAccessBuoyFavorites()` / `recordBuoyFavoritesUsage()`
- `showBuoyFavoritesView` state variable

#### Step 6.3: Add Navigation Destination
Add after existing `.navigationDestination`:

```swift
.navigationDestination(isPresented: $showBuoyFavoritesView) {
    BuoyFavoritesView(coreDataManager: serviceProvider.coreDataManager)
}
```

---

### PHASE 7: Update Main View (Routes Button)
**File:** `Mariner Studio/Views/MainView.swift`

#### Step 7.1: Add State Variable
Add after line 9:

```swift
@State private var showRoutesView = false
```

#### Step 7.2: Convert Routes Button (Lines 76-94)
Replace existing code:

```swift
// ROUTES - Daily limited feature
if subscriptionService.hasAppAccess {
    NavigationLink(destination: RouteMenuView()) {
        NavigationButtonContent(
            icon: "rsixseven",
            title: "ROUTES"
        )
    }
} else if subscriptionService.canAccessRoutes() {
    Button(action: {
        subscriptionService.recordRoutesUsage()
        showRoutesView = true
    }) {
        NavigationButtonContent(
            icon: "rsixseven",
            title: "ROUTES",
            isDailyLimited: true
        )
    }
    .buttonStyle(PlainButtonStyle())
} else {
    Button(action: {
        showSubscriptionPrompt = true
    }) {
        NavigationButtonContent(
            icon: "rsixseven",
            title: "ROUTES",
            isUsedToday: true
        )
    }
    .buttonStyle(PlainButtonStyle())
}
```

#### Step 7.3: Update NavigationButtonContent (Lines 240-310)
Verify the struct supports:
- `isDailyLimited: Bool` (shows blue border, "1 USE/DAY" badge)
- `isUsedToday: Bool` (shows gray, "USED TODAY" badge)

Remove or deprecate `isPremium: Bool` if it's still being used.

#### Step 7.4: Add Navigation Destination
Add after line 172 (after existing `.sheet` calls):

```swift
.navigationDestination(isPresented: $showRoutesView) {
    RouteMenuView()
}
```

---

### PHASE 8: Update Welcome Screen Messaging
**File:** `Mariner Studio/Views/Subscription/SubscriptionGateView.swift`

#### Step 8.1: Update Subscription Pitch (Line 93)
Change from:
```swift
Text("Get unlimited access for $2.99/month")
```

To:
```swift
Text("Get unlimited daily uses for $2.99/month")
```

#### Step 8.2: Update Feature Descriptions (Lines 80-86)
Add "(1 use/day free)" to each feature:

```swift
WelcomeFeatureRow(icon: "cloud.sun.fill", title: "Live Weather", description: "Real-time conditions (1 use/day free)")
WelcomeFeatureRow(icon: "map.fill", title: "Interactive Map", description: "Professional tools (1 use/day free)")
WelcomeFeatureRow(icon: "arrow.up.arrow.down", title: "Tides", description: "Accurate predictions (1 use/day free)")
WelcomeFeatureRow(icon: "arrow.left.arrow.right", title: "Currents", description: "Currents data (1 use/day free)")
WelcomeFeatureRow(icon: "portfoureight", title: "Docks and Facilities", description: "(1 use/day free)")
WelcomeFeatureRow(icon: "point.bottomleft.forward.to.arrow.triangle.uturn.scurvepath", title: "Route Planning", description: "Plan voyages (1 use/day free)")
```

#### Step 8.3: Update Free Button Text (Line 128)
Change from:
```swift
Text("Continue with Free Version")
```

To:
```swift
Text("Try Free Version (1 use per feature/day)")
```

#### Step 8.4: Update Bottom Disclaimer (Line 142)
Change from:
```swift
Text("Limited features • Upgrade anytime")
```

To:
```swift
Text("1 use per feature daily • Unlimited with subscription")
```

---

### PHASE 9: Update Paywall Messaging
**File:** `Mariner Studio/Views/Subscription/EnhancedPaywallView.swift`

#### Step 9.1: Verify Header Subtitle (Lines 110-112)
Current text is already good:
```swift
return "Daily limit reached. Subscribe for unlimited access to all features."
```

No changes needed unless you want to adjust wording.

---

## Testing Checklist

### Free User Flow
- [ ] Can access Weather Favorites once per day
- [ ] Can access Weather Map once per day
- [ ] Can access Weather Radar once per day
- [ ] Can access Tide Favorites once per day
- [ ] Can access Current Favorites once per day
- [ ] Can access Nav Unit Favorites once per day
- [ ] Can access Buoy Favorites once per day
- [ ] Can access Routes menu once per day
- [ ] After using a feature, it shows "USED TODAY" badge
- [ ] Clicking "USED TODAY" feature shows paywall
- [ ] All features show "1 USE/DAY" badge when available
- [ ] Daily reset works correctly (test by changing device time to next day)

### Subscriber Flow
- [ ] All features show unlimited access (no badges)
- [ ] No usage tracking occurs
- [ ] Can access any feature multiple times without restriction
- [ ] No paywall shown

### First Launch
- [ ] Welcome screen shows updated messaging
- [ ] Feature descriptions mention "(1 use/day free)"
- [ ] "Try Free Version" button shows new text
- [ ] Subscription pitch mentions "unlimited daily uses"

### Paywall
- [ ] Shows when any daily limit is reached
- [ ] Messaging is clear about unlimited access
- [ ] Purchase flow works correctly
- [ ] Restore purchases works

### Debug Tools
- [ ] Testing tools can reset all 13 usage tracking keys
- [ ] Reset clears both old and new feature usage
- [ ] Can test multiple daily cycles easily

---

## Files to Modify

| File | Changes | Lines Affected |
|------|---------|----------------|
| `Services/SimpleSubscription.swift` | Add 8 new features with access tracking | ~150 new lines |
| `Views/Weather/WeatherMenuView.swift` | Convert 3 features to daily-limited | Lines 7, 14-37, 78-99, 101-124, 138+ |
| `Views/Tides/TideMenuView.swift` | Convert 1 feature to daily-limited | Lines 7, 14-35, 92+ |
| `Views/Currents/CurrentMenuView.swift` | Convert 1 feature to daily-limited | Lines 7, 14-35, 92+ |
| `Views/NavUnit/NavUnitMenuView.swift` | Convert 1 feature to daily-limited | Lines 7, 14-35, 92+ |
| `Views/Buoys/BuoyMenuView.swift` | Convert 1 feature to daily-limited | Lines 15, 22-44, 100+ |
| `Views/MainView.swift` | Convert Routes to daily-limited | Lines 9, 76-94, 172+ |
| `Views/Subscription/SubscriptionGateView.swift` | Update welcome messaging | Lines 80-86, 93, 128, 142 |
| `Views/Subscription/EnhancedPaywallView.swift` | Verify paywall messaging | Lines 110-112 (review only) |

**Total Files:** 9 files
**Estimated New/Modified Lines:** 600-800 lines

---

## Benefits of This Change

### User Experience
✅ **More generous freemium model** - Users can try everything
✅ **Clearer value proposition** - "Everything unlimited" is simple
✅ **Better conversion potential** - Users understand value before subscribing
✅ **Reduced frustration** - No hard walls, just daily limits

### Technical
✅ **Consistent UI patterns** - All features use same visual indicators
✅ **Reusable code** - Daily limit pattern is proven and tested
✅ **No breaking changes** - Subscribers remain unaffected
✅ **Easy to track** - Analytics can show which features drive subscriptions

### Business
✅ **Higher engagement** - More users trying more features
✅ **Better data** - Learn which features are most valuable
✅ **Stronger conversion** - Users hit real limits that frustrate them into subscribing
✅ **Competitive advantage** - More generous than "freemium lite" competitors

---

## Subscription Value Proposition

### Before
- "Some features locked behind paywall"
- "Some features have daily limits"
- Confusing which features have which restrictions

### After
- "Use every feature once per day for free"
- "Subscribe for unlimited access to everything"
- Clear, simple, and consistent

---

## Implementation Order

Recommended order to minimize conflicts:

1. ✅ Create this documentation
2. ✅ Git commit current state
3. **Phase 1** - SimpleSubscription service (foundation)
4. **Phase 2** - Weather menu (most complex, 3 features)
5. **Phase 3-6** - Other menu views (1 feature each)
6. **Phase 7** - Main view Routes button
7. **Phase 8** - Welcome screen messaging
8. **Phase 9** - Paywall verification
9. **Testing** - Full test cycle
10. **Documentation** - Create final documentation

---

## Notes

- All code follows existing patterns from Weather/Tide/Current/NavUnit/Buoy LOCAL features
- UI indicators already exist (isDailyLimited, isUsedToday badges)
- Daily reset logic already tested and working
- No database schema changes needed
- No StoreKit configuration changes needed
- Backward compatible with existing subscriptions

---

**Status:** Ready to implement
**Last Updated:** 2025-10-19
