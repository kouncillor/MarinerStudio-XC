# Additional Table Creation Analysis

## Overview
Analysis of remaining table creation code in the codebase to determine if any other tables should be manually managed.

## Tables Still Being Created in Code

### 1. **MapOverlaySettings** (MapOverlayDatabaseService)
**File**: `Services/Database/MapOverlayDatabaseService.swift:39-44`
**Purpose**: UI/View state management - stores map overlay preferences per view
**Schema**:
```sql
CREATE TABLE MapOverlaySettings (
    view_id TEXT PRIMARY KEY,
    is_overlay_enabled BOOLEAN,
    selected_layers TEXT,  -- JSON string of layer IDs
    last_modified DATETIME
);
```
**Sync Status**: ❌ **NOT synced to Supabase** - this is purely local UI state
**Recommendation**: **Keep in code** - this is view-specific UI state, not user data

### 2. **RouteFavorites** (RouteFavoritesDatabaseService)  
**File**: `GPX/RouteFavoritesDatabaseService.swift:47-57`
**Purpose**: Local GPX route storage and favorites
**Schema**:
```sql
CREATE TABLE RouteFavorites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    gpx_data TEXT,
    waypoint_count INTEGER,
    total_distance REAL,
    created_at DATETIME,
    last_accessed_at DATETIME,
    tags TEXT,
    notes TEXT
);
```
**Sync Status**: ❌ **NOT synced to Supabase** - this is purely local route storage
**Recommendation**: **Keep in code** - local-only feature, no sync service exists

### 3. **DatabaseCore Test Table** (DatabaseCore)
**File**: `Services/Database/DatabaseCore.swift:172-180`
**Purpose**: Temporary table for write permission testing
**Schema**: Temporary test table that's immediately dropped
**Sync Status**: ❌ **NOT synced** - purely for testing database permissions
**Recommendation**: **Keep in code** - this is infrastructure testing

## Favorites Sync Services vs. Table Creation

### Four Favorites That Sync to Supabase:
1. ✅ **Tidal Height** (`TideStationFavorites`) - **No table creation in code**
2. ✅ **Tidal Current** (`TidalCurrentStationFavorites`) - **DDL removed** ✅
3. ✅ **Navigation Units** (`NavUnits`) - **No table creation in code**  
4. ✅ **Weather** (`WeatherLocationFavorites`) - **No table creation in code**

### Non-Sync Tables:
1. ❌ **MapOverlaySettings** - UI state only, not synced
2. ❌ **RouteFavorites** - Local-only route storage, not synced

## Investigation Results: RouteFavorites Sync Status

**Evidence confirming RouteFavorites does NOT sync:**
1. No `RouteFavoritesSyncService` exists in `/Services/Sync/` directory
2. No `RemoteRouteFavorite` model exists (only `RemoteEmbeddedRoute` for public routes)
3. No Supabase table references for `user_route_favorites`
4. `RouteFavoritesDatabaseService` contains only local SQLite operations
5. No sync service initialization in `ServiceProvider.swift`

**Note**: `RemoteEmbeddedRoute` exists but is for public community routes, not personal favorites

## Summary

**Investigation Complete**: ✅ **All table creation code analyzed**

**Current State**:
- ✅ **TidalCurrentStationFavorites**: DDL removed, manually managed
- ❌ **MapOverlaySettings**: Keep DDL (UI state, not synced)  
- ❌ **RouteFavorites**: Keep DDL (local-only storage, not synced)
- ❌ **DatabaseCore test table**: Keep DDL (infrastructure testing)

**Final Recommendation**:
Only `TidalCurrentStationFavorites` required DDL removal because it syncs to Supabase. All other table creation code should remain as these are local-only features or infrastructure components.