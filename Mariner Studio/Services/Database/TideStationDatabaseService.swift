import Foundation
import UIKit
#if canImport(SQLite)
import SQLite
#endif

class TideStationDatabaseService {
    // MARK: - Table Definitions
    private let tideStationFavorites = Table("TideStationFavorites")

    // MARK: - Column Definitions (UPDATED: Made station_name optional for safety)
    private let colStationId = Expression<String>("station_id")
    private let colIsFavorite = Expression<Bool>("is_favorite")
    private let colStationName = Expression<String?>("station_name")  // CHANGED: Now optional
    private let colLatitude = Expression<Double?>("latitude")
    private let colLongitude = Expression<Double?>("longitude")
    private let colLastModified = Expression<Date>("last_modified")
    private let colDeviceId = Expression<String>("device_id")

    // MARK: - Properties
    private let databaseCore: DatabaseCore

    // MARK: - Utility Methods

    private func getDeviceId() async -> String {
        return await UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }

    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }

    // MARK: - Favorite Management Methods

    func isTideStationFavorite(id: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()

            let query = tideStationFavorites.filter(colStationId == id)

            if let favorite = try db.pluck(query) {
                let result = favorite[colIsFavorite]
                return result
            }
            return false
        } catch {
            print("❌ CHECK ERROR: \(error.localizedDescription)")
            return false
        }
    }

    // UPDATED: Enhanced with data validation and safety checks
    func toggleTideStationFavorite(id: String, name: String, latitude: Double?, longitude: Double?) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()

            // SAFETY: Validate and sanitize input data
            let safeStationId = validateStationId(id)
            let safeName = validateStationName(name, fallbackId: safeStationId)
            let safeLatitude = validateLatitude(latitude)
            let safeLongitude = validateLongitude(longitude)

            print("📊 TOGGLE: Processing station \(safeStationId)")
            print("📊 TOGGLE: Name = '\(safeName)'")
            print("📊 TOGGLE: Coordinates = (\(safeLatitude?.description ?? "nil"), \(safeLongitude?.description ?? "nil"))")

            let query = tideStationFavorites.filter(colStationId == safeStationId)

            let currentTime = Date()
            let deviceId = await getDeviceId()

            let result: Bool
            if let existingFavorite = try db.pluck(query) {
                let currentFavoriteStatus = existingFavorite[colIsFavorite]
                let newFavoriteStatus = !currentFavoriteStatus

                print("📊 TOGGLE: Station exists, current status = \(currentFavoriteStatus), new status = \(newFavoriteStatus)")

                // Update existing record with safe values
                let updateQuery = query.update(
                    colIsFavorite <- newFavoriteStatus,
                    colStationName <- safeName,  // Update name with validated value
                    colLatitude <- safeLatitude,
                    colLongitude <- safeLongitude,
                    colLastModified <- currentTime,
                    colDeviceId <- deviceId
                )

                let updateCount = try db.run(updateQuery)
                result = newFavoriteStatus
                print("📊 TOGGLE: Updated \(updateCount) record(s)")
            } else {
                print("📊 TOGGLE: Station doesn't exist, creating new favorite record")

                // Insert new record with safe values
                try db.run(tideStationFavorites.insert(
                    colStationId <- safeStationId,
                    colIsFavorite <- true,
                    colStationName <- safeName,
                    colLatitude <- safeLatitude,
                    colLongitude <- safeLongitude,
                    colLastModified <- currentTime,
                    colDeviceId <- deviceId
                ))

                result = true
                print("📊 TOGGLE: Inserted new favorite record")
            }

            try await databaseCore.flushDatabaseAsync()
            print("📊 TOGGLE: ✅ Database changes flushed to disk")

            // BACKGROUND SYNC: Attempt cloud sync after successful local write
            // This is non-fatal - local operation has already succeeded
            Task.detached(priority: .background) {
                print("☁️ TOGGLE: Starting background sync after local write success")

                // Try the sync operation
                let syncResult = await TideStationSyncService.shared.syncTideStationFavorites()
                switch syncResult {
                case .success(let stats):
                    print("☁️ TOGGLE: ✅ Background sync completed successfully")
                    print("☁️ TOGGLE: Sync stats - uploaded: \(stats.uploaded), downloaded: \(stats.downloaded)")
                case .failure(let error):
                    print("☁️ TOGGLE: ⚠️ Background sync failed (non-fatal): \(error)")
                case .partialSuccess(let stats, let errors):
                    print("☁️ TOGGLE: ⚠️ Background sync partially successful")
                    print("☁️ TOGGLE: Sync stats - uploaded: \(stats.uploaded), downloaded: \(stats.downloaded)")
                    print("☁️ TOGGLE: Errors encountered: \(errors.count)")
                }
            }

            return result
        } catch {
            print("❌ TOGGLE ERROR: \(error.localizedDescription)")
            print("❌ TOGGLE ERROR DETAILS: \(error)")
            return false
        }
    }

    // MARK: - Data Validation Methods (NEW)

    private func validateStationId(_ id: String) -> String {
        let trimmedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedId.isEmpty ? "UNKNOWN_STATION" : trimmedId
    }

    private func validateStationName(_ name: String, fallbackId: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "Station \(fallbackId)"
        }
        return trimmedName
    }

    private func validateLatitude(_ latitude: Double?) -> Double? {
        guard let lat = latitude else { return nil }
        // Valid latitude range: -90 to 90
        if lat >= -90.0 && lat <= 90.0 {
            return lat
        }
        print("⚠️ VALIDATION: Invalid latitude \(lat), setting to nil")
        return nil
    }

    private func validateLongitude(_ longitude: Double?) -> Double? {
        guard let lon = longitude else { return nil }
        // Valid longitude range: -180 to 180
        if lon >= -180.0 && lon <= 180.0 {
            return lon
        }
        print("⚠️ VALIDATION: Invalid longitude \(lon), setting to nil")
        return nil
    }

    // MARK: - Query Methods (UPDATED: Safe data retrieval)

    func getAllFavoriteStationIds() async -> Set<String> {
        do {
            let db = try databaseCore.ensureConnection()

            var favoriteIds = Set<String>()

            for favorite in try db.prepare(tideStationFavorites.filter(colIsFavorite == true)) {
                favoriteIds.insert(favorite[colStationId])
            }

            print("🌊 SYNC SUPPORT: Found \(favoriteIds.count) local favorites")
            return favoriteIds

        } catch {
            print("❌ SYNC SUPPORT ERROR: \(error.localizedDescription)")
            return Set<String>()
        }
    }

    // UPDATED: Safe data retrieval with null handling
    func getAllFavoriteStationsWithDetails() async -> [TidalHeightStation] {
        do {
            let db = try databaseCore.ensureConnection()

            var favoriteStations: [TidalHeightStation] = []

            for favorite in try db.prepare(tideStationFavorites.filter(colIsFavorite == true)) {
                let stationId = favorite[colStationId]

                // SAFETY: Use safe unwrapping with fallbacks
                let stationName = favorite[colStationName] ?? "Station \(stationId)"
                let latitude = favorite[colLatitude]
                let longitude = favorite[colLongitude]

                print("🌊 DETAILED QUERY: Processing station \(stationId)")
                print("🌊 DETAILED QUERY: Name = '\(stationName)'")
                print("🌊 DETAILED QUERY: Coordinates = (\(latitude?.description ?? "nil"), \(longitude?.description ?? "nil"))")

                let station = TidalHeightStation(
                    id: stationId,
                    name: stationName,
                    latitude: latitude,
                    longitude: longitude,
                    state: nil,
                    type: "tidepredictions",
                    referenceId: stationId,
                    timezoneCorrection: nil,
                    timeMeridian: nil,
                    tidePredOffsets: nil,
                    isFavorite: true
                )
                favoriteStations.append(station)
            }

            print("🌊 DETAILED QUERY: Found \(favoriteStations.count) favorite stations with details")
            return favoriteStations.sorted { $0.name < $1.name }

        } catch {
            print("❌ DETAILED QUERY ERROR: \(error.localizedDescription)")
            print("❌ DETAILED QUERY ERROR DETAILS: \(error)")
            return []
        }
    }

    func getAllFavoriteStations() async -> [(stationId: String, isFavorite: Bool)] {
        do {
            let db = try databaseCore.ensureConnection()

            var stations: [(String, Bool)] = []

            for favorite in try db.prepare(tideStationFavorites) {
                stations.append((favorite[colStationId], favorite[colIsFavorite]))
            }

            print("🌊 QUERY: Found \(stations.count) total station records")
            return stations

        } catch {
            print("❌ QUERY ERROR: \(error.localizedDescription)")
            return []
        }
    }

    // NEW: Get favorites with timestamps for conflict resolution
    func getAllFavoriteStationsWithTimestamps() async -> [(stationId: String, isFavorite: Bool, lastModified: Date, deviceId: String, stationName: String?, latitude: Double?, longitude: Double?)] {
        do {
            let db = try databaseCore.ensureConnection()

            var favoriteRecords: [(String, Bool, Date, String, String?, Double?, Double?)] = []

            for record in try db.prepare(tideStationFavorites) {
                let stationId = record[colStationId]
                let isFavorite = record[colIsFavorite]
                let lastModified = record[colLastModified]
                let deviceId = record[colDeviceId]
                let stationName = record[colStationName]
                let latitude = record[colLatitude]
                let longitude = record[colLongitude]

                favoriteRecords.append((stationId, isFavorite, lastModified, deviceId, stationName, latitude, longitude))
            }

            print("🌊 TIMESTAMP QUERY: Found \(favoriteRecords.count) station records with timestamps")
            return favoriteRecords

        } catch {
            print("❌ TIMESTAMP QUERY ERROR: \(error.localizedDescription)")
            return []
        }
    }

    // UPDATED: Enhanced with safety checks
    func setTideStationFavorite(id: String, isFavorite: Bool, name: String? = nil, latitude: Double? = nil, longitude: Double? = nil) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()

            // SAFETY: Validate input data
            let safeStationId = validateStationId(id)
            let safeName = validateStationName(name ?? "", fallbackId: safeStationId)
            let safeLatitude = validateLatitude(latitude)
            let safeLongitude = validateLongitude(longitude)

            print("📊 SET_FAVORITE: Setting station \(safeStationId) to \(isFavorite)")

            let query = tideStationFavorites.filter(colStationId == safeStationId)

            let currentTime = Date()
            let deviceId = await getDeviceId()

            if let existingFavorite = try db.pluck(query) {
                // Update existing record
                let updateQuery = query.update(
                    colIsFavorite <- isFavorite,
                    colStationName <- safeName,
                    colLatitude <- safeLatitude,
                    colLongitude <- safeLongitude,
                    colLastModified <- currentTime,
                    colDeviceId <- deviceId
                )
                let updateCount = try db.run(updateQuery)
                print("📊 SET_FAVORITE: Updated \(updateCount) record(s)")
            } else {
                // Insert new record
                try db.run(tideStationFavorites.insert(
                    colStationId <- safeStationId,
                    colIsFavorite <- isFavorite,
                    colStationName <- safeName,
                    colLatitude <- safeLatitude,
                    colLongitude <- safeLongitude,
                    colLastModified <- currentTime,
                    colDeviceId <- deviceId
                ))
                print("📊 SET_FAVORITE: Inserted new record")
            }

            try await databaseCore.flushDatabaseAsync()
            print("📊 SET_FAVORITE: ✅ Database changes flushed to disk")

            return true
        } catch {
            print("❌ SET_FAVORITE ERROR: \(error.localizedDescription)")
            return false
        }
    }
}
