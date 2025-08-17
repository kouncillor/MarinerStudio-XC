#  <#Title#>

# Authentication System Documentation

## Overview

The Mariner Studio app uses a centralized authentication system built around **SupabaseManager** for database operations and **AuthenticationViewModel** for UI state management. The system provides comprehensive logging, race condition monitoring, and seamless integration with RevenueCat for subscription management.

---

## Architecture Components

### 1. SupabaseManager (Global Singleton)

**Location:** `Supabase/SupabaseManager.swift`

A comprehensive, thread-safe singleton that manages all Supabase operations with extensive logging and monitoring capabilities.

#### Key Features:
- **Global Static Access:** `SupabaseManager.shared`
- **Operation Tracking:** Every operation gets unique ID with timing
- **Race Condition Detection:** Monitors concurrent operations
- **Performance Analytics:** Success rates, timing statistics
- **Thread Safety:** All operations are properly queued

#### Core Methods:
```swift
// Authentication
func signIn(email: String, password: String) async throws -> Session
func signUp(email: String, password: String) async throws -> AuthResponse  
func signOut() async throws
func getSession() async throws -> Session

// Database Operations
func from(_ table: String) -> PostgrestQueryBuilder

// Monitoring
func checkConnectionHealth() async -> Bool
func printStats()
func logCurrentState()
```

#### Initialization:
```swift
// Auto-initializes on first access, or explicitly initialize in App.swift
init() {
    _ = SupabaseManager.shared
    SupabaseManager.shared.enableVerboseLogging()
}
```

### 2. AuthenticationViewModel

**Location:** `Authentication/AuthenticationViewModel.swift`

A MainActor-bound ObservableObject that manages authentication UI state and coordinates between SupabaseManager and RevenueCat.

#### Published Properties:
```swift
@Published var isAuthenticated: Bool = false
@Published var isLoading: Bool = false  
@Published var errorMessage: String?
```

#### Core Methods:
```swift
func checkSession() async          // Check for existing session
func signIn(email: String, password: String) async
func signUp(email: String, password: String) async
func signOut() async
```

#### Network Monitoring:
- Real-time network status monitoring
- WiFi/Cellular detection
- Connection availability tracking

---

## Authentication Flow

### 1. App Startup Sequence

```mermaid
graph TD
    A[App Launch] --> B[SupabaseManager.shared initializes]
    B --> C[AuthenticationViewModel init]
    C --> D[checkSession() called]
    D --> E{Session exists?}
    E -->|Yes| F[User authenticated]
    E -->|No| G[Show login screen]
    F --> H[Login to RevenueCat]
    G --> I[User enters credentials]
    I --> J[signIn() called]
    J --> K[SupabaseManager.shared.signIn()]
    K --> L[Success] --> H
```

### 2. Session Check Process

**When:** App startup, app foreground
**Duration:** 0.008s (cached) to 0.396s (network call)

```swift
func checkSession() async {
    do {
        let session = try await SupabaseManager.shared.getSession()
        // Session valid - user authenticated
        self.isAuthenticated = true
        await logInToRevenueCat(userId: session.user.id.uuidString)
    } catch {
        // No session or expired - user not authenticated  
        self.isAuthenticated = false
    }
}
```

### 3. Sign In Process

**Trigger:** User submits login form
**Duration:** ~0.396s for network authentication

```swift
func signIn(email: String, password: String) async {
    isLoading = true
    do {
        let session = try await SupabaseManager.shared.signIn(email: email, password: password)
        await logInToRevenueCat(userId: session.user.id.uuidString)
        self.isAuthenticated = true
    } catch {
        self.errorMessage = error.localizedDescription
    }
    isLoading = false
}
```

### 4. Sign Up Process

**Trigger:** User submits registration form
**Returns:** AuthResponse with user and session data

```swift
func signUp(email: String, password: String) async {
    isLoading = true
    do {
        let authResponse = try await SupabaseManager.shared.signUp(email: email, password: password)
        await logInToRevenueCat(userId: authResponse.user.id.uuidString)
        self.isAuthenticated = true
    } catch {
        self.errorMessage = error.localizedDescription
    }
    isLoading = false
}
```

### 5. Sign Out Process

**Trigger:** User taps sign out
**Actions:** Clears Supabase session AND RevenueCat session

```swift
func signOut() async {
    do {
        try await SupabaseManager.shared.signOut()
        try await Purchases.shared.logOut()
        self.isAuthenticated = false
    } catch {
        self.errorMessage = error.localizedDescription
    }
}
```

---

## Integration Points

### RevenueCat Integration

Every successful authentication automatically logs the user into RevenueCat:

```swift
private func logInToRevenueCat(userId: String) async {
    do {
        let result = try await Purchases.shared.logIn(userId)
        // User now has subscription access
    } catch {
        self.errorMessage = "Could not connect to subscription service"
    }
}
```

### ContentView Integration

The main app view responds to authentication state:

```swift
struct ContentView: View {
    @StateObject private var authViewModel = AuthenticationViewModel()
    
    var body: some View {
        VStack {
            if authViewModel.isAuthenticated {
                MainView()  // Authenticated user experience
            } else {
                AuthenticationView()  // Login/signup forms
            }
        }
        .environmentObject(authViewModel)
    }
}
```

---

## Logging and Monitoring

### Operation Logging

Every Supabase operation is comprehensively logged:

```
🟢 OPERATION START: signIn_2
🟢 OPERATION: signIn  
🟢 DETAILS: email: user@example.com
🟢 START TIME: 2025-06-20 23:13:31 +0000
🟢 ACTIVE OPERATIONS: 1
🟢 CONCURRENT OPS: ["signIn_2"]

📊 SIGN IN RESULT:
   User ID: 2292E6EC-EE94-4D14-9D86-CCCE9A060FCB
   Email: user@example.com
   Session expires: 2025-06-21 00:13:31 +0000
   Access token length: 843

✅ OPERATION SUCCESS: signIn_2
✅ DURATION: 0.396s
✅ REMAINING ACTIVE: 0
```

### Performance Monitoring

```swift
// Get current performance stats
SupabaseManager.shared.printStats()

// Check active operations (for race condition detection)
let activeOps = SupabaseManager.shared.getCurrentOperations()

// Test connection health
let isHealthy = await SupabaseManager.shared.checkConnectionHealth()
```

### Network Status Monitoring

Real-time network status is monitored and logged:

```
📡 NETWORK STATUS: satisfied
📡 NETWORK EXPENSIVE: false  
📡 NETWORK CONSTRAINED: false
📡 NETWORK INTERFACES: [en0, pdp_ip0]
✅ NETWORK: Connection is available
📡 NETWORK: Using WiFi
```

---

## Error Handling

### Session Errors

```swift
// Common session errors:
// - sessionMissing: No stored session (user needs to login)
// - sessionExpired: Session expired (automatic refresh attempted)  
// - networkError: Connection issues
```

### Authentication Errors

```swift
// Common auth errors:
// - invalidCredentials: Wrong email/password
// - emailNotConfirmed: Account needs email verification
// - networkError: Connection issues
// - rateLimited: Too many attempts
```

### Error Display

Errors are automatically displayed in the UI via `errorMessage`:

```swift
@Published var errorMessage: String?

// Usage in UI:
if let errorMessage = authViewModel.errorMessage {
    Text(errorMessage)
        .foregroundColor(.red)
}
```

---

## Security Considerations

### Session Management
- Sessions automatically expire (typically 60 minutes)
- Refresh tokens handle automatic renewal
- Sessions are securely stored by Supabase client

### Network Security
- All communication uses HTTPS
- JWT tokens for session management
- API keys are embedded (standard for client apps)

### Data Protection
- User passwords never stored locally
- Session tokens encrypted by system keychain
- Comprehensive audit logging for security analysis

---

## Troubleshooting

### Common Issues

**"No active session found"**
- Expected behavior when user hasn't logged in
- Duration: ~0.008s (fast local check)

**"Network connection lost"**  
- Check network connectivity
- Duration: Varies, usually >1s for timeouts

**RevenueCat login warnings**
- "appUserID is the same as cached" - Normal, no action needed
- Indicates user already logged into RevenueCat

### Debugging Tools

```swift
// Enable verbose logging
SupabaseManager.shared.enableVerboseLogging()

// Print performance statistics  
SupabaseManager.shared.printStats()

// Check current state
SupabaseManager.shared.logCurrentState()

// Test connection
let healthy = await SupabaseManager.shared.checkConnectionHealth()
```

### Performance Benchmarks

| Operation | Expected Duration | Notes |
|-----------|------------------|-------|
| Session check (cached) | 0.008s | Local validation |
| Session check (network) | 0.3-0.4s | Network validation |
| Sign in | 0.3-0.5s | Network authentication |
| Sign up | 0.3-0.5s | Account creation |
| Sign out | 0.1-0.3s | Session cleanup |

---

## Best Practices

### For Developers

1. **Always use SupabaseManager.shared** - Never create direct SupabaseClient instances
2. **Monitor the logs** - Rich logging helps debug issues quickly  
3. **Handle async properly** - All auth methods are async/await
4. **Check `isAuthenticated`** - Use published property for UI state
5. **Test offline scenarios** - App should handle network failures gracefully

### For UI Development

1. **Observe `isLoading`** - Show loading states during auth operations
2. **Display `errorMessage`** - Always show user-friendly error messages
3. **Use `@StateObject`** - For AuthenticationViewModel in main view
4. **Use `@EnvironmentObject`** - For child views accessing auth state

### For Testing

1. **Check operation timing** - Use logs to verify performance
2. **Test network conditions** - Verify behavior with poor connectivity
3. **Monitor race conditions** - Check for concurrent operations
4. **Validate session expiry** - Test automatic session renewal
