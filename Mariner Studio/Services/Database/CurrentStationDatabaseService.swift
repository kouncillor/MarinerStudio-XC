import Foundation
import UIKit
#if canImport(SQLite)
import SQLite
#endif

class CurrentStationDatabaseService {
    // MARK: - Table Definitions
    private let tidalCurrentStationFavorites = Table("TidalCurrentStationFavorites")

    // MARK: - Column Definitions (Updated to match Supabase schema)
    private let colId = Expression<Int64>("id")
    private let colUserId = Expression<String>("user_id")
    private let colStationId = Expression<String>("station_id")
    private let colCurrentBin = Expression<Int>("current_bin")
    private let colIsFavorite = Expression<Bool>("is_favorite")
    private let colLastModified = Expression<Date>("last_modified")
    private let colDeviceId = Expression<String>("device_id")
    private let colStationName = Expression<String?>("station_name")
    private let colLatitude = Expression<Double?>("latitude")
    private let colLongitude = Expression<Double?>("longitude")
    private let colDepth = Expression<Double?>("depth")
    private let colDepthType = Expression<String?>("depth_type")

    // MARK: - Properties
    private let databaseCore: DatabaseCore

    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
        // print("🏗️ CURRENT_DB_SERVICE: Initialized with databaseCore")
    }

    // MARK: - Utility Methods

    private func getDeviceId() async -> String {
        return await UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }

    private func getCurrentUserId() async -> String? {
        do {
            let session = try await SupabaseManager.shared.getSession()
            let userId = session.user.id.uuidString
            // print("👤 CURRENT_DB_SERVICE: Retrieved user ID: \(userId)")
            return userId
        } catch {
            // print("❌ CURRENT_DB_SERVICE: Could not get current user ID: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Note: Table Schema Management
    // TidalCurrentStationFavorites table schema is manually managed
    // Table must exist with all required columns before app startup

    // MARK: - Favorites Query Methods

    // Check if a current station is marked as favorite (without bin)
    func isCurrentStationFavorite(id: String) async -> Bool {
        print("🔍 CURRENT_DB_SERVICE: Checking favorite status for station \(id) (any bin)")
        let startTime = Date()

        do {
            let db = try databaseCore.ensureConnection()
            guard let userId = await getCurrentUserId() else {
                print("⚠️ CURRENT_DB_SERVICE: No authenticated user, cannot check favorites")
                return false
            }

            let query = tidalCurrentStationFavorites.filter(
                colUserId == userId &&
                colStationId == id &&
                colIsFavorite == true
            )

            let records = Array(try db.prepare(query))
            let hasFavorites = !records.isEmpty

            let duration = Date().timeIntervalSince(startTime)
            print("✅ CURRENT_DB_SERVICE: Station \(id) favorite check completed in \(String(format: "%.3f", duration))s - Result: \(hasFavorites) (\(records.count) records)")

            return hasFavorites
        } catch {
            print("❌ CURRENT_DB_SERVICE: Check error for station \(id): \(error.localizedDescription)")
            return false
        }
    }

    // Check if a current station is marked as favorite (with specific bin)
    func isCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        print("🔍 CURRENT_DB_SERVICE: Checking favorite status for station \(id), bin \(bin)")
        let startTime = Date()

        do {
            let db = try databaseCore.ensureConnection()
            guard let userId = await getCurrentUserId() else {
                print("⚠️ CURRENT_DB_SERVICE: No authenticated user, cannot check favorites")
                return false
            }

            let query = tidalCurrentStationFavorites.filter(
                colUserId == userId &&
                colStationId == id &&
                colCurrentBin == bin &&
                colIsFavorite == true
            )

            if let favorite = try db.pluck(query) {
                let result = favorite[colIsFavorite]
                let duration = Date().timeIntervalSince(startTime)
                print("✅ CURRENT_DB_SERVICE: Station \(id) bin \(bin) favorite check completed in \(String(format: "%.3f", duration))s - Result: \(result)")
                return result
            }

            let duration = Date().timeIntervalSince(startTime)
            print("✅ CURRENT_DB_SERVICE: Station \(id) bin \(bin) favorite check completed in \(String(format: "%.3f", duration))s - Result: false (no record)")
            return false
        } catch {
            print("❌ CURRENT_DB_SERVICE: Check error for station \(id) bin \(bin): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Toggle Methods
    /// Toggle favorite status with full station metadata - preferred method for rich data storage
    func toggleCurrentStationFavoriteWithMetadata(
        id: String,
        bin: Int,
        stationName: String?,
        latitude: Double?,
        longitude: Double?,
        depth: Double?,
        depthType: String?
    ) async -> Bool {
        print("🔄 CURRENT_DB_SERVICE: Beginning toggle with metadata for station \(id), bin \(bin)")
        print("📊 CURRENT_DB_SERVICE: Metadata - Name: \(stationName ?? "nil"), Lat: \(latitude?.description ?? "nil"), Lon: \(longitude?.description ?? "nil")")
        let startTime = Date()

        do {
            let db = try databaseCore.ensureConnection()
            guard let userId = await getCurrentUserId() else {
                print("❌ CURRENT_DB_SERVICE: No authenticated user, cannot toggle favorites")
                return false
            }

            let deviceId = await getDeviceId()

            // Check if record exists for this specific user, station, and bin
            let query = tidalCurrentStationFavorites.filter(
                colUserId == userId &&
                colStationId == id &&
                colCurrentBin == bin
            )

            if let existing = try db.pluck(query) {
                // Record exists, toggle its value and update metadata
                let currentValue = existing[colIsFavorite]
                let newValue = !currentValue
                print("🔄 CURRENT_DB_SERVICE: Found existing record with status: \(currentValue), toggling to \(newValue) and updating metadata")

                let count = try db.run(query.update(
                    colIsFavorite <- newValue,
                    colLastModified <- Date(),
                    colDeviceId <- deviceId,
                    colStationName <- stationName,
                    colLatitude <- latitude,
                    colLongitude <- longitude,
                    colDepth <- depth,
                    colDepthType <- depthType
                ))

                try await databaseCore.flushDatabaseAsync()
                let duration = Date().timeIntervalSince(startTime)
                print("✅ CURRENT_DB_SERVICE: Station \(id) bin \(bin) toggle with metadata completed in \(String(format: "%.3f", duration))s - Updated \(count) records to \(newValue)")
                return newValue
            } else {
                // No record exists, create new one as favorite with full metadata
                print("📝 CURRENT_DB_SERVICE: No record found for station \(id) bin \(bin), creating new favorite with metadata")
                try db.run(tidalCurrentStationFavorites.insert(
                    colUserId <- userId,
                    colStationId <- id,
                    colCurrentBin <- bin,
                    colIsFavorite <- true,
                    colLastModified <- Date(),
                    colDeviceId <- deviceId,
                    colStationName <- stationName,
                    colLatitude <- latitude,
                    colLongitude <- longitude,
                    colDepth <- depth,
                    colDepthType <- depthType
                ))

                try await databaseCore.flushDatabaseAsync()
                let duration = Date().timeIntervalSince(startTime)
                print("✅ CURRENT_DB_SERVICE: Station \(id) bin \(bin) toggle with metadata completed in \(String(format: "%.3f", duration))s - Created new favorite")
                return true
            }
        } catch {
            print("❌ CURRENT_DB_SERVICE: Toggle with metadata error for station \(id) bin \(bin): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - NEW: Efficient Favorites Retrieval

    /// Get all current station favorites for the authenticated user with full metadata
    /// This is the most efficient way to load favorites for the UI
    func getCurrentStationFavoritesWithMetadata() async throws -> [TidalCurrentFavoriteRecord] {
        print("📋 CURRENT_DB_SERVICE: Starting efficient favorites retrieval")
        let startTime = Date()

        let db = try databaseCore.ensureConnection()
        guard let userId = await getCurrentUserId() else {
            throw NSError(domain: "DatabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        print("👤 CURRENT_DB_SERVICE: Querying favorites for user: \(userId)")

        // Query only favorite records for this user
        let query = tidalCurrentStationFavorites.filter(
            colUserId == userId &&
            colIsFavorite == true
        ).order(colStationName.asc, colCurrentBin.asc)

        var results: [TidalCurrentFavoriteRecord] = []
        let queryStartTime = Date()

        for row in try db.prepare(query) {
            let record = TidalCurrentFavoriteRecord(
                id: row[colId],
                userId: row[colUserId],
                stationId: row[colStationId],
                currentBin: row[colCurrentBin],
                isFavorite: row[colIsFavorite],
                lastModified: row[colLastModified],
                deviceId: row[colDeviceId],
                stationName: row[colStationName],
                latitude: row[colLatitude],
                longitude: row[colLongitude],
                depth: row[colDepth],
                depthType: row[colDepthType]
            )
            results.append(record)
        }

        let queryDuration = Date().timeIntervalSince(queryStartTime)
        let totalDuration = Date().timeIntervalSince(startTime)

        print("✅ CURRENT_DB_SERVICE: Retrieved \(results.count) favorite records")
        print("⏱️ CURRENT_DB_SERVICE: Query took \(String(format: "%.3f", queryDuration))s, total \(String(format: "%.3f", totalDuration))s")

        // Log sample of results for debugging
        if !results.isEmpty {
            let first = results.first!
            print("📄 CURRENT_DB_SERVICE: Sample record - Station: \(first.stationName ?? "Unknown"), ID: \(first.stationId), Bin: \(first.currentBin)")
        }

        return results
    }

    // MARK: - Sync Support Methods

    // Get all favorites for the current user (for sync operations)
    func getAllCurrentStationFavoritesForUser() async throws -> [TidalCurrentFavoriteRecord] {
        print("🔄 CURRENT_DB_SERVICE: Getting all favorites for sync operations")
        let startTime = Date()

        let db = try databaseCore.ensureConnection()
        guard let userId = await getCurrentUserId() else {
            throw NSError(domain: "DatabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        let query = tidalCurrentStationFavorites.filter(colUserId == userId)
        var results: [TidalCurrentFavoriteRecord] = []

        for row in try db.prepare(query) {
            let record = TidalCurrentFavoriteRecord(
                id: row[colId],
                userId: row[colUserId],
                stationId: row[colStationId],
                currentBin: row[colCurrentBin],
                isFavorite: row[colIsFavorite],
                lastModified: row[colLastModified],
                deviceId: row[colDeviceId],
                stationName: row[colStationName],
                latitude: row[colLatitude],
                longitude: row[colLongitude],
                depth: row[colDepth],
                depthType: row[colDepthType]
            )
            results.append(record)
        }

        let duration = Date().timeIntervalSince(startTime)
        print("✅ CURRENT_DB_SERVICE: Retrieved \(results.count) total records for sync in \(String(format: "%.3f", duration))s")

        return results
    }

    // Set station favorite status with full metadata (for sync operations)
    func setCurrentStationFavorite(
        stationId: String,
        currentBin: Int,
        isFavorite: Bool,
        stationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        depth: Double? = nil,
        depthType: String? = nil,
        lastModified: Date? = nil
    ) async throws {
        let timestampSource = lastModified != nil ? "provided" : "current"
        print("💾 CURRENT_DB_SERVICE: Setting favorite status for station \(stationId) bin \(currentBin) to \(isFavorite) with \(timestampSource) timestamp")
        let startTime = Date()

        let db = try databaseCore.ensureConnection()
        guard let userId = await getCurrentUserId() else {
            throw NSError(domain: "DatabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        let deviceId = await getDeviceId()
        let timestampToUse = lastModified ?? Date()

        let query = tidalCurrentStationFavorites.filter(
            colUserId == userId &&
            colStationId == stationId &&
            colCurrentBin == currentBin
        )

        if try db.pluck(query) != nil {
            // Update existing record
            let count = try db.run(query.update(
                colIsFavorite <- isFavorite,
                colLastModified <- timestampToUse,
                colDeviceId <- deviceId,
                colStationName <- stationName,
                colLatitude <- latitude,
                colLongitude <- longitude,
                colDepth <- depth,
                colDepthType <- depthType
            ))
            print("📝 CURRENT_DB_SERVICE: Updated \(count) existing records")
        } else {
            // Insert new record
            try db.run(tidalCurrentStationFavorites.insert(
                colUserId <- userId,
                colStationId <- stationId,
                colCurrentBin <- currentBin,
                colIsFavorite <- isFavorite,
                colLastModified <- timestampToUse,
                colDeviceId <- deviceId,
                colStationName <- stationName,
                colLatitude <- latitude,
                colLongitude <- longitude,
                colDepth <- depth,
                colDepthType <- depthType
            ))
            print("📝 CURRENT_DB_SERVICE: Inserted new record")
        }

        try await databaseCore.flushDatabaseAsync()

        let duration = Date().timeIntervalSince(startTime)
        print("✅ CURRENT_DB_SERVICE: Set favorite operation completed in \(String(format: "%.3f", duration))s")
    }
}

// MARK: - Supporting Data Models

struct TidalCurrentFavoriteRecord {
    let id: Int64
    let userId: String
    let stationId: String
    let currentBin: Int
    let isFavorite: Bool
    let lastModified: Date
    let deviceId: String
    let stationName: String?
    let latitude: Double?
    let longitude: Double?
    let depth: Double?
    let depthType: String?

    /// Convert database record to TidalCurrentStation model
    func toTidalCurrentStation() -> TidalCurrentStation {
        return TidalCurrentStation(
            id: stationId,
            name: stationName ?? "Unknown Station",
            latitude: latitude,
            longitude: longitude,
            state: nil, // Not stored in favorites table
            type: "Current Station",
            depth: depth,
            depthType: depthType,
            currentBin: currentBin,
            timezoneOffset: nil,
            currentPredictionOffsets: nil,
            harmonicConstituents: nil,
            selfUrl: nil,
            expand: nil,
            isFavorite: isFavorite
        )
    }
}
