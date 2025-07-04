import Foundation
#if canImport(SQLite)
import SQLite
#endif

class WeatherDatabaseService {
    // MARK: - Table Definitions
    private let moonPhases = Table("MoonPhase")
    private let weatherLocationFavorites = Table("WeatherLocationFavorites")
    
    // MARK: - Column Definitions - MoonPhase
    private let colDate = Expression<String>("Date")
    private let colPhase = Expression<String>("Phase")
    
    // MARK: - Column Definitions - WeatherLocationsFavorites
    private let colId = Expression<Int64>("id")
    private let colLatitude = Expression<Double>("Latitude")
    private let colLongitude = Expression<Double>("Longitude")
    private let colLocationName = Expression<String>("LocationName")
    private let colIsFavorite = Expression<Bool>("is_favorite")
    private let colCreatedAt = Expression<Date>("CreatedAt")
    
    // MARK: - Sync Metadata Columns
    private let colUserId = Expression<String?>("user_id")
    private let colDeviceId = Expression<String?>("device_id")
    private let colLastModified = Expression<Date?>("last_modified")
    private let colRemoteId = Expression<String?>("remote_id")
    
    // MARK: - Properties
    private let databaseCore: DatabaseCore
    
    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }
    
    // MARK: - Moon Phase Methods
    
    // Get moon phase for a specific date
    func getMoonPhaseForDateAsync(date: String) async throws -> MoonPhase? {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = moonPhases.filter(colDate == date)
            
            if let row = try db.pluck(query) {
                let phase = MoonPhase(
                    date: row[colDate],
                    phase: row[colPhase]
                )
                print("Looking up moon phase for date: \(date)")
                print("Found: \(phase.phase)")
                
                return phase
            }
            
            print("Looking up moon phase for date: \(date)")
            print("Found: no phase")
            
            return nil
        } catch {
            print("Error getting moon phase: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Weather Location Methods
    
    
    // Check if a weather location is marked as favorite
    func isWeatherLocationFavoriteAsync(latitude: Double, longitude: Double) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
            
            if let favorite = try db.pluck(query) {
                return favorite[colIsFavorite]
            }
            return false
        } catch {
            print("Error checking weather location favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    // Toggle favorite status for a weather location
    func toggleWeatherLocationFavoriteAsync(latitude: Double, longitude: Double, locationName: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            let now = Date()
            
            let query = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
            
            if let favorite = try db.pluck(query) {
                let currentValue = favorite[colIsFavorite]
                let newValue = !currentValue
                
                let updatedRow = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
                try db.run(updatedRow.update(
                    colIsFavorite <- newValue,
                    colLocationName <- locationName,
                    colLastModified <- now
                ))
                
                try await databaseCore.flushDatabaseAsync()
                return newValue
            } else {
                try db.run(weatherLocationFavorites.insert(
                    colLatitude <- latitude,
                    colLongitude <- longitude,
                    colLocationName <- locationName,
                    colIsFavorite <- true,
                    colCreatedAt <- now,
                    colLastModified <- now
                ))
                try await databaseCore.flushDatabaseAsync()
                return true
            }
        } catch {
            print("Error toggling weather location favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    // Get all favorite weather locations
    func getFavoriteWeatherLocationsAsync() async throws -> [WeatherLocationFavorite] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = weatherLocationFavorites.filter(colIsFavorite == true).order(colCreatedAt.desc)
            var results: [WeatherLocationFavorite] = []
            
            for row in try db.prepare(query) {
                let favorite = WeatherLocationFavorite(
                    id: row[colId],
                    latitude: row[colLatitude],
                    longitude: row[colLongitude],
                    locationName: row[colLocationName],
                    isFavorite: row[colIsFavorite],
                    createdAt: row[colCreatedAt],
                    userId: row[colUserId],
                    deviceId: row[colDeviceId],
                    lastModified: row[colLastModified],
                    remoteId: row[colRemoteId]
                )
                results.append(favorite)
            }
            
            return results
        } catch {
            print("Error fetching favorite weather locations: \(error.localizedDescription)")
            throw error
        }
    }
    
    
    
    
    // Add this method to WeatherDatabaseService
    func updateWeatherLocationNameAsync(latitude: Double, longitude: Double, newName: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            let now = Date()
            
            let query = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
            
            if let favorite = try db.pluck(query) {
                let updatedRow = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
                try db.run(updatedRow.update(
                    colLocationName <- newName,
                    colLastModified <- now
                ))
                
                try await databaseCore.flushDatabaseAsync()
                return true
            } else {
                return false
            }
        } catch {
            print("Error updating weather location name: \(error.localizedDescription)")
            return false
        }
    }
    
    
    // MARK: - Enhanced Sync Methods
    
    /// Get all weather locations with sync metadata for synchronization (includes both favorites and unfavorited items)
    func getFavoriteWeatherLocationsForSync() async throws -> [WeatherLocationFavorite] {
        do {
            let db = try databaseCore.ensureConnection()
            
            // Get all records that have sync metadata, regardless of favorite status
            let query = weatherLocationFavorites.filter(colLastModified != nil).order(colCreatedAt.desc)
            var results: [WeatherLocationFavorite] = []
            
            for row in try db.prepare(query) {
                let favorite = WeatherLocationFavorite(
                    id: row[colId],
                    latitude: row[colLatitude],
                    longitude: row[colLongitude],
                    locationName: row[colLocationName],
                    isFavorite: row[colIsFavorite],
                    createdAt: row[colCreatedAt],
                    userId: row[colUserId],
                    deviceId: row[colDeviceId],
                    lastModified: row[colLastModified],
                    remoteId: row[colRemoteId]
                )
                results.append(favorite)
            }
            
            return results
        } catch {
            print("Error fetching weather locations for sync: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Set weather location favorite with sync metadata for cloud synchronization
    func setWeatherLocationFavoriteWithSyncData(
        latitude: Double,
        longitude: Double,
        locationName: String,
        isFavorite: Bool,
        userId: String,
        deviceId: String,
        lastModified: Date,
        remoteId: String? = nil
    ) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            var existingRecord: Row? = nil
            
            // First try to find by remote ID if provided
            if let remoteId = remoteId {
                let remoteQuery = weatherLocationFavorites.filter(colRemoteId == remoteId)
                existingRecord = try db.pluck(remoteQuery)
            }
            
            if let existing = existingRecord {
                // Update existing record found by remote ID
                print("🔍💾 setWeatherLocationFavoriteWithSyncData: BEFORE update - existing lastModified: \(existing[colLastModified]?.description ?? "nil")")
                print("🔍💾 setWeatherLocationFavoriteWithSyncData: About to set lastModified to: \(lastModified)")
                
                let updatedRow = weatherLocationFavorites.filter(colId == existing[colId])
                try db.run(updatedRow.update(
                    colLatitude <- latitude,
                    colLongitude <- longitude,
                    colLocationName <- locationName,
                    colIsFavorite <- isFavorite,
                    colUserId <- userId,
                    colDeviceId <- deviceId,
                    colLastModified <- lastModified,
                    colRemoteId <- remoteId
                ))
                
                // Verify the update worked correctly
                if let updatedRecord = try db.pluck(weatherLocationFavorites.filter(colId == existing[colId])) {
                    print("✅💾 setWeatherLocationFavoriteWithSyncData: AFTER update - lastModified is: \(updatedRecord[colLastModified]?.description ?? "nil")")
                    let timeDifference = abs(updatedRecord[colLastModified]?.timeIntervalSince(lastModified) ?? 999.0)
                    if timeDifference < 1.0 {
                        print("✅💾 setWeatherLocationFavoriteWithSyncData: Timestamp preserved correctly (diff: \(timeDifference)s)")
                    } else {
                        print("⚠️💾 setWeatherLocationFavoriteWithSyncData: Timestamp changed unexpectedly (diff: \(timeDifference)s)")
                    }
                }
            } else {
                // Insert new record - always create new entry (no duplicate prevention by coordinates)
                try db.run(weatherLocationFavorites.insert(
                    colLatitude <- latitude,
                    colLongitude <- longitude,
                    colLocationName <- locationName,
                    colIsFavorite <- isFavorite,
                    colCreatedAt <- Date(),
                    colUserId <- userId,
                    colDeviceId <- deviceId,
                    colLastModified <- lastModified,
                    colRemoteId <- remoteId
                ))
            }
            
            try await databaseCore.flushDatabaseAsync()
            return true
        } catch {
            print("Error setting weather location favorite with sync data: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Update an existing local record with its remote ID after upload
    func updateLocalRecordWithRemoteId(localId: Int64, remoteId: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            let updatedRow = weatherLocationFavorites.filter(colId == localId)
            try db.run(updatedRow.update(colRemoteId <- remoteId))
            
            try await databaseCore.flushDatabaseAsync()
            return true
        } catch {
            print("Error updating local record with remote ID: \(error.localizedDescription)")
            return false
        }
    }
    
    
    /// Enhanced toggle method that updates sync metadata - now creates new entries instead of toggling
    func toggleWeatherLocationFavoriteWithSyncData(
        latitude: Double,
        longitude: Double,
        locationName: String,
        userId: String,
        deviceId: String
    ) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            let now = Date()
            
            // Always create a new entry - no more coordinate-based deduplication
            try db.run(weatherLocationFavorites.insert(
                colLatitude <- latitude,
                colLongitude <- longitude,
                colLocationName <- locationName,
                colIsFavorite <- true,
                colCreatedAt <- now,
                colUserId <- userId,
                colDeviceId <- deviceId,
                colLastModified <- now,
                colRemoteId <- nil  // Will be set when synced to remote
            ))
            
            try await databaseCore.flushDatabaseAsync()
            return true
        } catch {
            print("Error creating weather location favorite with sync data: \(error.localizedDescription)")
            return false
        }
    }
}
