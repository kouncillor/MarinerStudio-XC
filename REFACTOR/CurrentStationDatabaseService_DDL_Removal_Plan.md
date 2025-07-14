# CurrentStationDatabaseService DDL Removal Plan

## Overview
Remove all database schema creation and alteration code from CurrentStationDatabaseService since the table is now manually created with the complete schema.

## Current Table Schema (Confirmed)
Based on the database manager screenshot, the TidalCurrentStationFavorites table now has:

| Column | Type | Nullable | Primary |
|--------|------|----------|---------|
| id | INTEGER | ✓ | ✓ |
| user_id | TEXT | ✗ | ✗ |
| station_id | TEXT | ✗ | ✗ |
| current_bin | INTEGER | ✗ | ✗ |
| is_favorite | BOOLEAN | ✗ | ✗ |
| last_modified | DATETIME | ✗ | ✗ |
| device_id | TEXT | ✗ | ✗ |
| station_name | TEXT | ✓ | ✗ |
| latitude | REAL | ✓ | ✗ |
| longitude | REAL | ✓ | ✗ |
| depth | REAL | ✓ | ✗ |
| depth_type | TEXT | ✓ | ✗ |

## Code Changes Required

### 1. Remove `addColumnIfNeeded` Method
**File**: `/Users/timothyrussell/Documents/MarinerStudio-XC/Mariner Studio/Services/Database/CurrentStationDatabaseService.swift`

**Lines to remove**: ~52-75 (entire method)

```swift
// DELETE THIS ENTIRE METHOD:
private func addColumnIfNeeded(db: Connection, tableName: String, columnName: String, columnType: String) async throws {
    // ... entire method implementation
}
```

### 2. Remove `initializeCurrentStationFavoritesTableAsync` Method
**File**: `/Users/timothyrussell/Documents/MarinerStudio-XC/Mariner Studio/Services/Database/CurrentStationDatabaseService.swift`

**Lines to remove**: ~79-171 (entire method)

```swift
// DELETE THIS ENTIRE METHOD:
func initializeCurrentStationFavoritesTableAsync() async throws {
    // ... entire method implementation including:
    // - Table creation: db.run(tidalCurrentStationFavorites.create...)
    // - All addColumnIfNeeded calls (lines 117-124)
    // - Test record insertion and cleanup
}
```

### 3. Remove Table Initialization Call from ServiceProvider
**File**: `/Users/timothyrussell/Documents/MarinerStudio-XC/Mariner Studio/Services/ServiceProvider.swift`

**Line to remove**: Line 122

```swift
// DELETE THIS LINE:
try await self.currentStationService.initializeCurrentStationFavoritesTableAsync()
```

### 4. Update Comments (Optional)
**File**: `/Users/timothyrussell/Documents/MarinerStudio-XC/Mariner Studio/Services/Database/CurrentStationDatabaseService.swift`

Add a comment after line ~31 (in the init method):

```swift
init(databaseCore: DatabaseCore) {
    self.databaseCore = databaseCore
    print("🏗️ CURRENT_DB_SERVICE: Initialized with databaseCore")
    // Note: TidalCurrentStationFavorites table schema is manually managed
    // Table must exist with all required columns before app startup
}
```

## What Remains After Cleanup

The CurrentStationDatabaseService will retain:
- ✅ All column definitions (Expression<T> properties)
- ✅ Table reference (`tidalCurrentStationFavorites`)
- ✅ All data operations (INSERT, UPDATE, SELECT, DELETE)
- ✅ Utility methods (`getDeviceId`, `getCurrentUserId`)
- ✅ All sync-related functionality

## What is Removed

- ❌ Table creation code (`table.create(ifNotExists: true)`)
- ❌ Column migration code (`ALTER TABLE ADD COLUMN`)
- ❌ Schema checking and modification logic
- ❌ Test record insertion during initialization
- ❌ ServiceProvider table initialization call

## Testing After Changes

1. **Verify app startup**: App should start normally without table creation attempts
2. **Test sync functionality**: CurrentStationSyncService should work normally
3. **Check data operations**: INSERT, UPDATE, SELECT operations should work as before
4. **Verify no DDL logging**: No more "Creating table" or "Adding column" log messages

## Benefits

1. **Cleaner code**: Removes ~100 lines of DDL code
2. **Faster startup**: No table creation/migration checks during app launch
3. **Manual control**: Database schema is explicitly controlled outside the app
4. **Reduced complexity**: No conditional schema logic or migration paths

## Risk Mitigation

- Table schema is now fixed and must exist before app launch
- If table is missing, app will fail gracefully with SQLite errors
- No automatic schema migration - any schema changes must be done manually
- Existing data operations are unaffected since column definitions remain the same