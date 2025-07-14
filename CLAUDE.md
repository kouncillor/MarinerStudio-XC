# Mariner Studio XC - Claude Development Context

## Project Overview
Mariner Studio XC is a comprehensive iOS maritime application built with SwiftUI, providing weather data, tidal information, navigation tools, and vessel tracking for maritime professionals and enthusiasts.

## Build & Development Commands

### Build Commands
```bash
# Open project in Xcode
open "Mariner Studio.xcodeproj"

# Build from command line (if needed)
xcodebuild -project "Mariner Studio.xcodeproj" -scheme "Mariner Studio" -configuration Debug build

# Clean build
xcodebuild -project "Mariner Studio.xcodeproj" -scheme "Mariner Studio" clean
```

### Common Development Tasks
```bash
# View project structure
find "Mariner Studio" -name "*.swift" | head -20

# Search for specific functionality
grep -r "authentication" "Mariner Studio" --include="*.swift"
grep -r "SupabaseManager" "Mariner Studio" --include="*.swift"

# Check database files
ls -la "Mariner Studio"/*.db
```

## Project Structure

### Key Directories
- **`Mariner Studio/`** - Main application source code
- **`Mariner Studio/Authentication/`** - User authentication (Supabase)
- **`Mariner Studio/Services/`** - Core services and dependency injection
- **`Mariner Studio/Views/`** - SwiftUI views organized by feature
- **`Mariner Studio/ViewModels/`** - MVVM view models
- **`Mariner Studio/Models/`** - Data models and database schemas
- **`Mariner Studio/Supabase/`** - Cloud database integration
- **`Mariner Studio/RevenueCat/`** - Subscription management
- **`Documentation/`** - Project documentation (root level)

### Critical Files
- **`Mariner_StudioApp.swift`** - App entry point and initialization
- **`ContentView.swift`** - Root view with authentication logic
- **`MainView.swift`** - Main navigation menu
- **`Services/ServiceProvider.swift`** - Dependency injection container
- **`Supabase/SupabaseManager.swift`** - Cloud service management
- **`Authentication/AuthenticationViewModel.swift`** - Auth state management

## Architecture Notes

### Startup Flow
1. App launches → `Mariner_StudioApp.swift:5`
2. Services initialize → `ServiceProvider.swift:48-196`
3. Authentication check → `AuthenticationViewModel.swift:50-78`
4. UI decision → `ContentView.swift:7-24`
5. Main menu display → `MainView.swift:25-154`

### Key Dependencies
- **Supabase**: Authentication and cloud database
- **RevenueCat**: Subscription management
- **SwiftUI**: UI framework
- **CoreLocation**: Location services
- **SQLite**: Local database (SS1.db)

### Service Architecture
- **ServiceProvider**: Dependency injection container
- **DatabaseCore**: SQLite database management
- **LocationService**: GPS and location handling
- **Weather/Tide/Current Services**: Maritime data APIs
- **Sync Services**: Cloud synchronization

## Development Guidelines

### Authentication Flow
- Uses Supabase for user management
- RevenueCat integration for subscriptions
- Session validation on app startup
- Conditional UI rendering based on auth state

### Database Pattern
- Local SQLite database (`SS1.db`) for offline data
- Cloud sync via Supabase for favorites and user data
- Database services follow repository pattern
- Async/await for database operations

### UI Architecture
- SwiftUI with MVVM pattern
- `@StateObject` for view models
- Environment objects for shared state
- Navigation stack for deep linking

## Common Issues & Solutions

### Startup Performance
- Service initialization can take 1-3 seconds
- Database and network operations run async
- Monitor `ServiceProvider` initialization logs

### Authentication Problems
- Check SupabaseManager session validation
- Verify RevenueCat API key configuration
- Test network connectivity to Supabase

### Database Issues
- Check `SS1.db` file permissions
- Monitor DatabaseCore initialization
- Verify table creation in ServiceProvider

## Testing & Debugging

### Debug Mode Features
- Verbose logging enabled in SupabaseManager
- Dev-only sign-out button in MainView
- Debug menu available in development builds

### Key Log Patterns
```
🚀 SUPABASE MANAGER: [operation details]
📦 ServiceProvider: [service status]
🔍 SESSION CHECK: [auth flow]
✅/❌ [SUCCESS/ERROR]: [operation results]
```

### Common Debug Commands
```bash
# Monitor app logs (if using simulator)
xcrun simctl spawn booted log stream --predicate 'process CONTAINS "Mariner"'

# Check database schema
sqlite3 "Mariner Studio/SS1.db" ".schema"
```

## File Navigation Tips

### Finding Specific Functionality
- **Authentication**: `Authentication/` folder
- **Main navigation**: `Views/MainView.swift`
- **Services**: `Services/` folder (organized by domain)
- **Data models**: `Models/` folder
- **Cloud operations**: `Supabase/SupabaseManager.swift`

### Search Patterns
```bash
# Find view models
find "Mariner Studio" -name "*ViewModel.swift"

# Find database services
find "Mariner Studio/Services" -name "*DatabaseService.swift"

# Find authentication code
grep -r "authentication\|auth\|login\|signin" "Mariner Studio" --include="*.swift"
```

## Development Workflow

### Making Changes
1. **Services**: Add to `ServiceProvider.swift` dependency injection
2. **Views**: Follow MVVM pattern with dedicated ViewModels
3. **Database**: Update models and database services
4. **Authentication**: Modify through `AuthenticationViewModel`

### Testing Changes
1. Build and run in Xcode
2. Monitor startup logs for service initialization
3. Test authentication flows (sign-in/sign-out)
4. Verify database operations
5. Check network connectivity features

## Important Notes

### Security Considerations
- Supabase API keys are in source code (review for production)
- RevenueCat API key is configured in AppDelegate
- Database contains maritime navigation data

### Performance Considerations
- App startup involves extensive service initialization
- Database operations should remain async
- Location services can impact battery life
- Network requests should handle offline scenarios

### Maintenance Tasks
- Monitor Supabase operation statistics
- Review service initialization performance
- Update authentication flow as needed
- Maintain database schema migrations

## Debug Logging System

### Real-Time Log Streaming
**Live application logs stream to:** https://logflare.app/sources/public/aRjXAXyUU10ZNVGL

**Usage:** Tell Claude to "check the logs" and provide this URL for real-time debugging assistance.

**How it works:**
- Every `DebugLogger.shared.log()` call streams to Logflare automatically
- No more copy-paste from Xcode console required
- Claude can view logs directly via the URL
- Logs include device name, app version, timestamps, and categories

### Log File Locations (Local Files)
- **iOS Simulator**: App sandbox Documents directory (not project folder)
- **Physical Device**: App sandbox Documents directory  
- **Release Builds**: No logging (disabled)

### Quick Command for Finding Local Logs
**Prompt to give Claude:**
```
"find logs"
```

**What Claude will do:**
1. Search for DebugConsole.log in CoreSimulator directories
2. Show you the exact file path 
3. Display recent log entries
4. No need to remember the obscure simulator paths

### Log Categories
- `APP_INIT` - Application startup
- `AUTH_SESSION` - Authentication flow
- `SUPABASE_OPS` - Database operations  
- `DATABASE_*` - Database core operations
- `LOCATION_*` - Location services
- `SERVICE_*` - Service initialization
- `LOGFLARE_TEST` - Real-time streaming tests

### Manual Log Location (if needed)
```bash
find ~/Library/Developer/CoreSimulator -name "DebugConsole.log" -exec ls -la {} \;
```

---

**Last Updated**: July 6, 2025
**Claude Context Version**: 1.1