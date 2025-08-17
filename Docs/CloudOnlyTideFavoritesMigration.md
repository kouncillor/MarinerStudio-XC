# Cloud-Only Tide Favorites Migration Plan

## Overview
Eliminate local SQLite storage and sync complexity by using Supabase as single source of truth for tide favorites.

## Architecture Change
```
Before: Local DB ↔️ Sync Service ↔️ Supabase Cloud
After:  App → Supabase Cloud (direct)
```

## Benefits
- ✅ Eliminates race conditions and "ghost" favorites
- ✅ Removes ~1000 lines of sync/database code  
- ✅ Simplifies error handling (network-only)
- ✅ Faster development (single operations)
- ✅ Consistent cross-device experience

## Step-by-Step Migration

### Phase 1: Create New Cloud Service
1. ✅ **TideFavoritesCloudService.swift** - New cloud-only service
2. ✅ **TideFavoritesViewModel_CloudOnly.swift** - Simplified ViewModel

### Phase 2: Update ServiceProvider
```swift
// Remove
private var tideStationDatabaseService: TideStationDatabaseService?
private var tideStationSyncService: TideStationSyncService?

// Add  
private var tideFavoritesCloudService: TideFavoritesCloudService?
```

### Phase 3: Update ViewModels

#### TidalHeightStationsViewModel.swift
Replace:
```swift
await tideStationService.toggleTideStationFavorite(...)
```
With:
```swift
await cloudService.toggleFavorite(stationId: station.id, ...)
```

#### TidalHeightPredictionViewModel.swift  
Replace:
```swift
let isFavorite = await tideStationService.isTideStationFavorite(id: stationId)
```
With:
```swift
let result = await cloudService.isFavorite(stationId: stationId)
let isFavorite = try? result.get() ?? false
```

### Phase 4: Update Views

#### TideFavoritesView.swift
Remove:
- Sync button and sync status UI
- Progress indicators for sync operations
- Sync error/success messages

Keep:
- Pull-to-refresh (but calls `loadFavorites()` directly)
- Swipe-to-delete functionality

#### TidalHeightStationsView.swift & TidalHeightPredictionView.swift
- Replace database service calls with cloud service calls
- Add loading states for network operations
- Handle network errors gracefully

### Phase 5: Database Cleanup

#### Remove SQLite Table
```swift
// Remove from DatabaseCore initialization:
try db.run(tideStationFavorites.create(ifNotExists: true) { t in
    t.column(colStationId, primaryKey: true)
    t.column(colIsFavorite)
    t.column(colStationName)
    // ... etc
})
```

### Phase 6: File Cleanup

#### Files to DELETE:
- `Services/Database/TideStationDatabaseService.swift` (645 lines)
- `Services/Sync/TideStationSyncService.swift` (~500 lines)  
- `Models/Sync/TideSyncOperationStats.swift`
- `Documentation/TideStationSupabaseSyncDocumentation.md`

#### Files to RENAME (after testing):
- `TideFavoritesViewModel_CloudOnly.swift` → `TideFavoritesViewModel.swift`
- Remove original `TideFavoritesViewModel.swift`

## Error Handling Strategy

### Network Errors
```swift
// Before: Complex sync error handling
case .syncFailed(let errors):
case .partialSuccess(let stats, let errors):
case .conflictResolution(let conflicts):

// After: Simple network error handling  
case .failure(let error):
    if error is NetworkError {
        showNetworkErrorMessage()
    }
```

### Offline Handling
Since tide data requires internet anyway:
- Show "Internet required" message
- Disable favorite buttons when offline
- Cache last loaded favorites for display (optional)

## Migration Validation

### Test Cases
1. **Add Favorite**: Station appears immediately in favorites list
2. **Remove Favorite**: Station disappears immediately, no reappearing
3. **Toggle Favorite**: Consistent state across all views
4. **Load Favorites**: Fast loading from cloud, sorted by distance
5. **Network Error**: Graceful error handling, retry options
6. **Cross-device**: Changes sync instantly across devices

### Performance Expectations
- **Add/Remove**: ~200-500ms (network call)
- **Load Favorites**: ~300-800ms (network call + sorting)
- **Toggle Status Check**: ~200-400ms (network call)

*Note: These are faster than complex sync operations and more predictable*

## Rollback Plan
Keep existing files as `.backup` until migration is validated:
- `TideFavoritesViewModel.swift.backup`
- `TideStationDatabaseService.swift.backup` 
- `TideStationSyncService.swift.backup`

## Success Metrics
- ✅ Zero "ghost favorite" bug reports
- ✅ Reduced support tickets about sync issues  
- ✅ Faster feature development for favorites
- ✅ Simplified debugging and logs
- ✅ Consistent user experience across devices

---

**Estimated Migration Time**: 4-6 hours
**Lines of Code Removed**: ~1000+
**Complexity Reduction**: Significant (eliminates entire sync system)