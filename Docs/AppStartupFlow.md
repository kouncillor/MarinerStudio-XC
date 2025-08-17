# Mariner Studio XC - Application Startup Flow Documentation

**Generated:** July 6, 2025  
**Version:** 1.0  
**Author:** Application Analysis

## Overview

This document provides a comprehensive breakdown of the Mariner Studio XC iOS application startup sequence, from the moment a user taps the app icon on their home screen until the main menu is fully displayed and functional.

## Table of Contents

1. [Startup Flow Overview](#startup-flow-overview)
2. [Detailed Phase Breakdown](#detailed-phase-breakdown)
3. [File Execution Order](#file-execution-order)
4. [Critical Dependencies](#critical-dependencies)
5. [Performance Considerations](#performance-considerations)
6. [Troubleshooting Common Issues](#troubleshooting-common-issues)

---

## Startup Flow Overview

The application startup follows a well-defined sequence through 7 distinct phases:

1. **System Launch** - iOS initiates app launch
2. **App Initialization** - Core app structure setup
3. **Service Provider Setup** - Comprehensive service initialization  
4. **UI Hierarchy Construction** - SwiftUI view hierarchy creation
5. **Authentication Flow** - User session validation
6. **UI Display Decision** - Conditional view presentation
7. **Main Menu Display** - Final UI presentation

---

## Detailed Phase Breakdown

### Phase 1: System Launch
**Duration:** ~50-100ms  
**Thread:** Main Thread

1. User taps app icon on home screen
2. iOS launches the app process and calls the main entry point
3. System allocates memory and prepares runtime environment

### Phase 2: App Initialization  
**Duration:** ~200-500ms  
**Thread:** Main Thread

**Key Actions:**
- `@main` annotation triggers `Mariner_StudioApp` struct initialization
- `init()` method executes core setup:
  - Initializes `SupabaseManager.shared` singleton
  - Enables verbose logging for Supabase operations
- `AppDelegate` initialization via `@UIApplicationDelegateAdaptor`
- RevenueCat configuration with API key in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
- `ServiceProvider` creation as `@StateObject` (triggers extensive initialization)

**Critical File:** `Mariner Studio/Mariner_StudioApp.swift:5-26`

### Phase 3: Service Provider Setup
**Duration:** ~1-3 seconds  
**Thread:** Main Thread (sync) + Background Threads (async)

**Synchronous Initialization:**
- `DatabaseCore` setup
- `LocationService` configuration (default or injected)
- Database service creation (tide, current, nav unit, vessel, buoy, weather, etc.)
- Weather service initialization
- Navigation service setup  
- GPX and route service preparation
- Recommendation and sync service configuration

**Asynchronous Tasks (Background):**
- Database initialization and table creation
- Location permission requests
- Recommendation service authentication setup

**Critical File:** `Mariner Studio/Services/ServiceProvider.swift:48-196`

### Phase 4: UI Hierarchy Construction
**Duration:** ~100-300ms  
**Thread:** Main Thread

**Key Actions:**
- `WindowGroup` creation with `ContentView`
- `ContentView` initialization triggers `@StateObject` `AuthenticationViewModel` creation
- `AuthenticationViewModel.init()` starts session checking process
- SwiftUI view hierarchy construction begins

**Critical Files:**
- `Mariner Studio/ContentView.swift:4-5`
- `Mariner Studio/Authentication/AuthenticationViewModel.swift:16-24`

### Phase 5: Authentication Flow
**Duration:** ~500ms-2 seconds (network dependent)  
**Thread:** Background Thread

**Process:**
- `AuthenticationViewModel.checkSession()` executes asynchronously
- Calls `SupabaseManager.shared.getSession()` to verify existing session
- **If authenticated:** Sets `isAuthenticated = true` and logs into RevenueCat
- **If not authenticated:** Sets `isAuthenticated = false`

**Critical Files:**
- `Mariner Studio/Authentication/AuthenticationViewModel.swift:50-78`
- `Mariner Studio/Supabase/SupabaseManager.swift:202-222`

### Phase 6: UI Display Decision
**Duration:** ~50-100ms  
**Thread:** Main Thread

**Logic:**
- `ContentView.body` evaluates `authViewModel.isAuthenticated`
- **If `true`:** Shows `MainView()` with RevenueCat paywall modifier
- **If `false`:** Shows `AuthenticationView()` for sign-in/sign-up

**Critical File:** `Mariner Studio/ContentView.swift:7-24`

### Phase 7: Main Menu Display (Authenticated Path)
**Duration:** ~200-500ms  
**Thread:** Main Thread

**UI Construction:**
- `MainView` creates `NavigationStack` with grid layout
- Displays navigation buttons for core features:
  - MAP, WEATHER, TIDES, CURRENTS
  - DOCKS, BUOYS, TUGS, BARGES, ROUTES
- Shows toolbar with sign-out button (dev builds) and home button
- Sets navigation title to "Mariner Studio"

**Critical File:** `Mariner Studio/Views/MainView.swift:25-154`

---

## File Execution Order

The following files are touched during the startup process in this specific order:

| Order | File Path | Line Range | Purpose |
|-------|-----------|------------|---------|
| 1 | `Mariner Studio/Mariner_StudioApp.swift` | 5 | Main app entry point (`@main struct`) |
| 2 | `Mariner Studio/Mariner_StudioApp.swift` | 13-17 | App initialization and SupabaseManager setup |
| 3 | `Mariner Studio/Supabase/SupabaseManager.swift` | 24-43 | SupabaseManager singleton initialization |
| 4 | `Mariner Studio/RevenueCat/AppDelegateAdaptor.swift` | 6-12 | RevenueCat configuration |
| 5 | `Mariner Studio/Services/ServiceProvider.swift` | 48-111 | Service provider initialization (sync portion) |
| 6 | `Mariner Studio/Services/Database/DatabaseCore.swift` | - | Database core initialization |
| 7 | `Mariner Studio/Services/LocationServiceImpl.swift` | - | Location service setup |
| 8 | `Mariner Studio/Services/ServiceProvider.swift` | 114-196 | Async service setup tasks |
| 9 | `Mariner Studio/Mariner_StudioApp.swift` | 19-26 | WindowGroup and ContentView creation |
| 10 | `Mariner Studio/ContentView.swift` | 4-5 | ContentView initialization with AuthenticationViewModel |
| 11 | `Mariner Studio/Authentication/AuthenticationViewModel.swift` | 16-24 | Authentication state setup |
| 12 | `Mariner Studio/Authentication/AuthenticationViewModel.swift` | 50-78 | Session checking via SupabaseManager |
| 13 | `Mariner Studio/Supabase/SupabaseManager.swift` | 202-222 | Session validation |
| 14 | `Mariner Studio/ContentView.swift` | 7-24 | Authentication state evaluation and view selection |
| 15 | `Mariner Studio/Views/MainView.swift` | 6-155 | Main menu construction (if authenticated) |
| 16 | `Mariner Studio/Views/MainView.swift` | 25-154 | Navigation grid with menu buttons display |

**Total Files Involved:** 16 core files + numerous service implementation files

---

## Critical Dependencies

### External Dependencies
- **Supabase SDK**: Authentication and cloud database operations
- **RevenueCat SDK**: Subscription and paywall management
- **SwiftUI Framework**: UI construction and state management
- **CoreLocation Framework**: Location services (via LocationService)

### Internal Dependencies
- **DatabaseCore**: Local SQLite database management
- **ServiceProvider**: Dependency injection container
- **AuthenticationViewModel**: User session state management
- **SupabaseManager**: Centralized cloud service operations

### Network Dependencies
- Supabase authentication server connectivity
- RevenueCat subscription service availability
- Location services (if user permits)

---

## Performance Considerations

### Startup Time Optimization
- **Cold Start:** 2-5 seconds (typical)
- **Warm Start:** 1-2 seconds (app in background)
- **Hot Start:** <1 second (app in memory)

### Bottlenecks
1. **Service Provider Initialization** (~1-3s)
   - Database setup and table creation
   - Multiple service instantiation
   - Network connectivity checks

2. **Authentication Flow** (~0.5-2s)
   - Network-dependent session validation
   - RevenueCat subscription status check

3. **Location Permission** (Variable)
   - User interaction required on first launch
   - System dialog presentation time

### Optimization Strategies
- Services initialize asynchronously where possible
- Database operations occur on background queues
- UI renders immediately while authentication proceeds
- Location requests happen in parallel with other initialization

---

## Troubleshooting Common Issues

### Slow Startup (>5 seconds)
**Potential Causes:**
- Poor network connectivity affecting Supabase authentication
- Database initialization issues
- Service dependency conflicts

**Investigation Steps:**
1. Check console logs for service initialization failures
2. Verify network connectivity
3. Monitor database initialization time
4. Check for service circular dependencies

### Authentication Failures
**Potential Causes:**
- Expired or invalid session tokens
- Supabase server connectivity issues
- RevenueCat API problems

**Investigation Steps:**
1. Verify SupabaseManager session validation logs
2. Check RevenueCat configuration and API key
3. Test authentication flow in isolation
4. Monitor network requests to Supabase

### Missing Main Menu
**Potential Causes:**
- Authentication state not updating properly
- ContentView conditional logic issues
- MainView initialization failures

**Investigation Steps:**
1. Verify `isAuthenticated` state in ContentView
2. Check AuthenticationViewModel state changes
3. Ensure MainView construction completes successfully
4. Review navigation stack initialization

### Service Initialization Failures
**Potential Causes:**
- Database file corruption or permission issues
- Location service permission problems
- Network service configuration errors

**Investigation Steps:**
1. Check ServiceProvider initialization logs
2. Verify database file accessibility
3. Review location permission status
4. Test individual service initialization

---

## Development Notes

### Adding New Services
When adding new services to the startup flow:

1. Add service initialization to `ServiceProvider.init()`
2. Consider whether initialization should be synchronous or asynchronous
3. Update `setupAsyncTasks()` if background initialization is needed
4. Ensure proper error handling and logging
5. Update this documentation

### Modifying Authentication Flow
When changing authentication behavior:

1. Update `AuthenticationViewModel` session checking logic
2. Modify `ContentView` conditional rendering if needed
3. Consider impact on RevenueCat integration
4. Test both authenticated and unauthenticated startup paths
5. Update documentation accordingly

### Performance Monitoring
Key metrics to monitor:
- Total startup time from launch to main menu display
- Service Provider initialization duration
- Authentication flow completion time
- Database initialization performance
- Memory usage during startup

---

**Document Maintenance:**
This document should be updated whenever:
- New services are added to the startup flow
- Authentication logic changes
- Major architectural modifications occur
- Performance optimizations are implemented
- New dependencies are introduced