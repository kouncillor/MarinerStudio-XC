# ID Management Approaches Across Sync Services

Each sync service uses a different strategy for tracking the relationship between local and remote records. Here's a detailed breakdown:

## 1. Tidal Height Stations - Station ID Based

```swift
// Uses station ID as natural key
let localFavorites = await databaseService.getAllFavoriteStationIds() // Returns Set<String>
let remoteFavorites = await getRemoteFavorites(userId: session.user.id) // Returns [RemoteTideFavorite]

// Comparison based on station ID
let localOnlyFavorites = localFavorites.subtracting(remoteStationIds)
let remoteOnlyFavorites = remoteFavoriteIds.subtracting(localFavorites)
```

**Strategy**: Uses `stationId` as the natural primary key for matching records
- **Local tracking**: Stores station IDs in local SQLite
- **Remote tracking**: Supabase table has `station_id` column
- **Matching logic**: Direct string comparison of station IDs
- **Pros**: Simple, no additional ID management needed
- **Cons**: Can't distinguish between multiple users favoriting the same station

## 2. Tidal Current Stations - Composite Key Based

```swift
// Uses composite key: stationId + currentBin
let localSet = Set(local.map { "\($0.stationId):\($0.currentBin)" })
let remoteSet = Set(remote.map { "\($0.stationId):\($0.currentBin)" })

// Comparison based on composite string
let key = "\(localRecord.stationId):\(localRecord.currentBin)"
guard let remoteRecord = remoteDict[key] else { continue }
```

**Strategy**: Uses `stationId:currentBin` composite key for matching
- **Local tracking**: Combines station ID and current bin into composite key
- **Remote tracking**: Supabase table has separate `station_id` and `current_bin` columns
- **Matching logic**: String concatenation `"stationId:currentBin"`
- **Pros**: Handles multiple bins per station correctly
- **Cons**: String manipulation for key generation, potential collision risk

## 3. Navigation Units - UUID with Sync Metadata

```swift
// Local stores user_id, device_id, last_modified for sync
guard let userIdString = navUnit.userId,
      let userId = UUID(uuidString: userIdString) else {
    print("⚠️📱🧭 LOCAL_SKIP: Nav unit \(navUnit.navUnitId) missing user_id, skipping...")
    continue
}

// Enhanced local data includes sync metadata
let remoteFavorite = RemoteNavUnitFavorite(
    userId: userId,
    navUnitId: navUnit.navUnitId,
    isFavorite: navUnit.isFavorite,
    deviceId: deviceId,
    // ... other fields
)
```

**Strategy**: Uses nav unit ID with comprehensive sync metadata stored locally
- **Local tracking**: Stores `userId`, `deviceId`, `lastModified` in local SQLite alongside nav unit data
- **Remote tracking**: Supabase has full `RemoteNavUnitFavorite` with UUID primary key
- **Matching logic**: Matches on `navUnitId` but validates sync metadata
- **Pros**: Full sync metadata, supports conflict resolution, user isolation
- **Cons**: More complex local schema, requires sync metadata management

## 4. Weather Favorites - Remote ID Tracking

```swift
// Local records track their remote counterparts via remoteId field
let localRemoteIds = Set(localFavorites.compactMap { $0.remoteId }) // remoteId is String?
let remoteIds = Set(remoteFavorites.compactMap { $0.id?.uuidString })

// Upload creates new record and updates local with remote ID
if let newRemoteRecord = response.value.first,
   let remoteId = newRemoteRecord.id?.uuidString {
    let updateSuccess = await databaseService.updateLocalRecordWithRemoteId(
        localId: localRecord.id,
        remoteId: remoteId
    )
}
```

**Strategy**: Local records maintain a `remoteId` field pointing to Supabase UUID
- **Local tracking**: Each local record has optional `remoteId: String?` field
- **Remote tracking**: Supabase generates UUID primary keys
- **Matching logic**: Local `remoteId` matches remote `id.uuidString`
- **Pros**: Explicit relationship tracking, supports multiple records per location, clean separation
- **Cons**: Requires additional local schema column, two-phase operations (create + update)

## Comparison Summary

| Service          | Primary Key Strategy             | Local Schema Impact     | Conflict Resolution | User Isolation   |
|------------------|----------------------------------|-------------------------|---------------------|------------------|
| Tide Height      | Natural Key (stationId)          | Minimal                 | Basic timestamp     | Via user queries |
| Tidal Current    | Composite (stationId:currentBin) | Minimal                 | Basic timestamp     | Via user queries |
| Navigation Units | Natural + Sync Metadata          | Heavy (sync fields)     | Advanced (Step 0)   | Built-in         |
| Weather          | Remote ID Tracking               | Medium (remoteId field) | Timestamp-based     | Via user queries |

## Evolution of Approaches

Looking at the code timestamps and complexity, there appears to be an evolution in ID management sophistication:

1. **Early approach** (Tide Height): Simple station ID matching
2. **Specialized approach** (Tidal Current): Composite keys for complex relationships
3. **Advanced approach** (Navigation Units): Full sync metadata with conflict prevention
4. **Modern approach** (Weather): Clean remote ID tracking with proper relationship management

The **Weather service** approach with `remoteId` tracking appears to be the most scalable and maintainable for future sync services.