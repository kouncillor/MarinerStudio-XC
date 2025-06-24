//import Foundation
//#if canImport(SQLite)
//import SQLite
//#endif
//
//class CurrentStationDatabaseService {
//    // MARK: - Table Definitions
//    private let tidalCurrentStationFavorites = Table("TidalCurrentStationFavorites")
//    
//    // MARK: - Column Definitions
//    private let colStationId = Expression<String>("station_id")
//    private let colCurrentBin = Expression<Int>("current_bin")
//    private let colIsFavorite = Expression<Bool>("is_favorite")
//    
//    // MARK: - Properties
//    private let databaseCore: DatabaseCore
//    
//    // MARK: - Initialization
//    init(databaseCore: DatabaseCore) {
//        self.databaseCore = databaseCore
//    }
//    
//    // MARK: - Methods
//    
//   
//    
//    // Initialize current station favorites table with extensive error logging
//    func initializeCurrentStationFavoritesTableAsync() async throws {
//        do {
//            let db = try databaseCore.ensureConnection()
//            
//            print("📊 Creating TidalCurrentStationFavorites table if it doesn't exist")
//            
//            // Get current tables first
//            let tablesQuery = "SELECT name FROM sqlite_master WHERE type='table'"
//            var tableNames: [String] = []
//            for row in try db.prepare(tablesQuery) {
//                if let tableName = row[0] as? String {
//                    tableNames.append(tableName)
//                }
//            }
//            print("📊 Current tables: \(tableNames.joined(separator: ", "))")
//            
//            // Create table
//            try db.run(tidalCurrentStationFavorites.create(ifNotExists: true) { table in
//                table.column(colStationId)
//                table.column(colCurrentBin)
//                table.column(colIsFavorite)
//                table.primaryKey(colStationId, colCurrentBin)
//            })
//            
//            // Verify table was created
//            tableNames = []
//            for row in try db.prepare(tablesQuery) {
//                if let tableName = row[0] as? String {
//                    tableNames.append(tableName)
//                }
//            }
//            
//            if tableNames.contains("TidalCurrentStationFavorites") {
//                print("📊 TidalCurrentStationFavorites table created or already exists")
//                
//                // Check if we can write to the table
//                try db.run(tidalCurrentStationFavorites.insert(or: .replace,
//                    colStationId <- "TEST_INIT",
//                    colCurrentBin <- 0,
//                    colIsFavorite <- true
//                ))
//                
//                // Verify write worked
//                let testQuery = tidalCurrentStationFavorites.filter(colStationId == "TEST_INIT")
//                if (try? db.pluck(testQuery)) != nil {
//                    print("📊 Successfully wrote and read test record")
//                } else {
//                    print("❌ Could not verify test record")
//                }
//            } else {
//                print("❌ Failed to create TidalCurrentStationFavorites table")
//                throw NSError(domain: "DatabaseService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create table"])
//            }
//        } catch {
//            print("❌ Error creating TidalCurrentStationFavorites table: \(error.localizedDescription)")
//            throw error
//        }
//    }
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    // Check if a current station is marked as favorite
//    func isCurrentStationFavorite(id: String, bin: Int) async -> Bool {
//        do {
//            let db = try databaseCore.ensureConnection()
//            
//       //     print("📊 CHECK: Checking favorite status for station \(id), bin \(bin)")
//            let query = tidalCurrentStationFavorites.filter(colStationId == id && colCurrentBin == bin)
//            
//            if let favorite = try db.pluck(query) {
//                let result = favorite[colIsFavorite]
//       //         print("📊 CHECK: Found favorite status: \(result)")
//                return result
//            }
//     //       print("📊 CHECK: No favorite record found")
//            return false
//        } catch {
//     //       print("❌ CHECK ERROR: \(error.localizedDescription)")
//            return false
//        }
//    }
//    
//    // Toggle favorite status for a current station with bin
//    func toggleCurrentStationFavorite(id: String, bin: Int) async -> Bool {
//        do {
//            let db = try databaseCore.ensureConnection()
//            
//            print("📊 TOGGLE: Beginning toggle for station \(id), bin \(bin)")
//            
//            // Variable to store the result outside transaction
//            var result = false
//            
//            try db.transaction {
//                let query = tidalCurrentStationFavorites.filter(colStationId == id && colCurrentBin == bin)
//                
//                if let favorite = try db.pluck(query) {
//                    let currentValue = favorite[colIsFavorite]
//                    let newValue = !currentValue
//                    
//                    print("📊 TOGGLE: Found existing record with favorite status: \(currentValue), toggling to \(newValue)")
//                    
//                    let updatedRow = tidalCurrentStationFavorites.filter(colStationId == id && colCurrentBin == bin)
//                    let count = try db.run(updatedRow.update(colIsFavorite <- newValue))
//                    
//                    print("📊 TOGGLE: Updated record with result: \(count) rows affected")
//                    result = newValue
//                } else {
//                    print("📊 TOGGLE: No existing record found, creating new favorite")
//                    
//                    let insert = tidalCurrentStationFavorites.insert(
//                        colStationId <- id,
//                        colCurrentBin <- bin,
//                        colIsFavorite <- true
//                    )
//                    
//                    let rowId = try db.run(insert)
//                    print("📊 TOGGLE: Inserted new favorite with rowId: \(rowId)")
//                    result = true
//                }
//            }
//            
//            // Force a disk flush after toggling favorites
//            try await databaseCore.flushDatabaseAsync()
//            return result
//        } catch {
//            print("❌ TOGGLE ERROR: \(error.localizedDescription)")
//            print("❌ TOGGLE ERROR DETAILS: \(error)")
//            return false
//        }
//    }
//    
//    // Check if a current station is marked as favorite (without bin)
//    func isCurrentStationFavorite(id: String) async -> Bool {
//        do {
//            let db = try databaseCore.ensureConnection()
//            
//          //  print("📊 CHECK: Checking any favorite status for station \(id)")
//            let query = tidalCurrentStationFavorites.filter(colStationId == id)
//            
//            // Check if any record exists and is marked as favorite
//            for row in try db.prepare(query) {
//                if row[colIsFavorite] {
//          //          print("📊 CHECK: Found favorite status true for bin \(row[colCurrentBin])")
//                    return true
//                }
//            }
//         //   print("📊 CHECK: No favorite record found for any bin")
//            return false
//        } catch {
//        //    print("❌ CHECK ERROR: \(error.localizedDescription)")
//            return false
//        }
//    }
//    
//    // Toggle favorite status for a current station (without bin) - applies to all bins
//    func toggleCurrentStationFavorite(id: String) async -> Bool {
//        do {
//            let db = try databaseCore.ensureConnection()
//            
//            print("📊 TOGGLE: Beginning toggle for all bins of station \(id)")
//            
//            // Check if any records exist
//            let query = tidalCurrentStationFavorites.filter(colStationId == id)
//            let records = Array(try db.prepare(query))
//            
//            if records.isEmpty {
//                // No records found, create a default one with bin 0
//                print("📊 TOGGLE: No records found, creating default with bin 0")
//                try db.run(tidalCurrentStationFavorites.insert(
//                    colStationId <- id,
//                    colCurrentBin <- 0,
//                    colIsFavorite <- true
//                ))
//                try await databaseCore.flushDatabaseAsync()
//                return true
//            } else {
//                // Get current state from first record (assuming all should be the same)
//                let currentValue = records.first![colIsFavorite]
//                let newValue = !currentValue
//                print("📊 TOGGLE: Found \(records.count) records with favorite status: \(currentValue), toggling all to \(newValue)")
//                
//                // Update all records for this station
//                let count = try db.run(tidalCurrentStationFavorites.filter(colStationId == id).update(colIsFavorite <- newValue))
//                print("📊 TOGGLE: Updated \(count) records")
//                
//                try await databaseCore.flushDatabaseAsync()
//                return newValue
//            }
//        } catch {
//            print("❌ TOGGLE ERROR: \(error.localizedDescription)")
//            return false
//        }
//    }
//}


















import Foundation
import UIKit
#if canImport(SQLite)
import SQLite
#endif

class CurrentStationDatabaseService {
    // MARK: - Table Definitions
    private let tidalCurrentStationFavorites = Table("TidalCurrentStationFavorites")
    
    // MARK: - Column Definitions (Updated to match Supabase schema)
    private let colId = Expression<Int>("id")                                    // AUTO INCREMENT PRIMARY KEY
    private let colUserId = Expression<String?>("user_id")                       // UUID from authentication
    private let colStationId = Expression<String>("station_id")                 // NOAA station ID
    private let colCurrentBin = Expression<Int>("current_bin")                  // Bin number
    private let colIsFavorite = Expression<Bool>("is_favorite")                 // Favorite status
    private let colLastModified = Expression<Date>("last_modified")             // For sync conflict resolution
    private let colDeviceId = Expression<String>("device_id")                   // Device identifier
    private let colStationName = Expression<String?>("station_name")            // Optional station name
    private let colLatitude = Expression<Double?>("latitude")                   // Optional latitude
    private let colLongitude = Expression<Double?>("longitude")                 // Optional longitude
    private let colDepth = Expression<Double?>("depth")                         // Optional depth
    private let colDepthType = Expression<String?>("depth_type")                // Optional depth type
    
    // MARK: - Properties
    private let databaseCore: DatabaseCore
    
    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }
    
    // MARK: - Methods
    
    // Initialize current station favorites table with Supabase-aligned schema
    func initializeCurrentStationFavoritesTableAsync() async throws {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 Creating TidalCurrentStationFavorites table if it doesn't exist (Supabase-aligned schema)")
            
            // Get current tables first
            let tablesQuery = "SELECT name FROM sqlite_master WHERE type='table'"
            var tableNames: [String] = []
            for row in try db.prepare(tablesQuery) {
                if let tableName = row[0] as? String {
                    tableNames.append(tableName)
                }
            }
            print("📊 Current tables: \(tableNames.joined(separator: ", "))")
            
            // Create table with new schema
            try db.run(tidalCurrentStationFavorites.create(ifNotExists: true) { table in
                table.column(colId, primaryKey: .autoincrement)                 // Primary key
                table.column(colUserId)                                         // User ID from auth
                table.column(colStationId)                                      // Station ID
                table.column(colCurrentBin)                                     // Bin number
                table.column(colIsFavorite)                                     // Favorite status
                table.column(colLastModified)                                   // Last modified timestamp
                table.column(colDeviceId)                                       // Device ID
                table.column(colStationName)                                    // Optional station name
                table.column(colLatitude)                                       // Optional latitude
                table.column(colLongitude)                                      // Optional longitude
                table.column(colDepth)                                          // Optional depth
                table.column(colDepthType)                                      // Optional depth type
                
                // Create unique constraint to prevent duplicate favorites per user/station/bin
                table.unique(colUserId, colStationId, colCurrentBin)
            })
            
            // Add columns if they don't exist (for migration from old schema)
            try await addColumnIfNeeded(db: db, tableName: "TidalCurrentStationFavorites", columnName: "id", columnType: "INTEGER PRIMARY KEY AUTOINCREMENT")
            try await addColumnIfNeeded(db: db, tableName: "TidalCurrentStationFavorites", columnName: "user_id", columnType: "TEXT")
            try await addColumnIfNeeded(db: db, tableName: "TidalCurrentStationFavorites", columnName: "last_modified", columnType: "DATETIME")
            try await addColumnIfNeeded(db: db, tableName: "TidalCurrentStationFavorites", columnName: "device_id", columnType: "TEXT")
            try await addColumnIfNeeded(db: db, tableName: "TidalCurrentStationFavorites", columnName: "station_name", columnType: "TEXT")
            try await addColumnIfNeeded(db: db, tableName: "TidalCurrentStationFavorites", columnName: "latitude", columnType: "REAL")
            try await addColumnIfNeeded(db: db, tableName: "TidalCurrentStationFavorites", columnName: "longitude", columnType: "REAL")
            try await addColumnIfNeeded(db: db, tableName: "TidalCurrentStationFavorites", columnName: "depth", columnType: "REAL")
            try await addColumnIfNeeded(db: db, tableName: "TidalCurrentStationFavorites", columnName: "depth_type", columnType: "TEXT")
            
            // Verify table was created
            tableNames = []
            for row in try db.prepare(tablesQuery) {
                if let tableName = row[0] as? String {
                    tableNames.append(tableName)
                }
            }
            
            if tableNames.contains("TidalCurrentStationFavorites") {
                print("📊 TidalCurrentStationFavorites table created or already exists with Supabase-aligned schema")
                
                // Test write capability with new schema
                let deviceId = await getDeviceId()
                try db.run(tidalCurrentStationFavorites.insert(or: .replace,
                    colUserId <- "TEST_USER_ID",
                    colStationId <- "TEST_INIT",
                    colCurrentBin <- 0,
                    colIsFavorite <- true,
                    colLastModified <- Date(),
                    colDeviceId <- deviceId,
                    colStationName <- "Test Station",
                    colLatitude <- 0.0,
                    colLongitude <- 0.0
                ))
                
                // Verify write worked
                let testQuery = tidalCurrentStationFavorites.filter(colStationId == "TEST_INIT")
                if (try? db.pluck(testQuery)) != nil {
                    print("📊 Successfully wrote and read test record with new schema")
                    // Clean up test record
                    try db.run(testQuery.delete())
                } else {
                    print("❌ Could not verify test record with new schema")
                }
            } else {
                print("❌ Failed to create TidalCurrentStationFavorites table")
                throw NSError(domain: "DatabaseService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create table"])
            }
        } catch {
            print("❌ Error creating TidalCurrentStationFavorites table: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Helper method to add columns for migration
    private func addColumnIfNeeded(db: Connection, tableName: String, columnName: String, columnType: String) async throws {
        let tableInfo = try db.prepare("PRAGMA table_info(\(tableName))")
        var columnExists = false
        for row in tableInfo {
            if let name = row[1] as? String, name == columnName {
                columnExists = true
                break
            }
        }
        
        if !columnExists {
            print("📊 Adding missing column '\(columnName)' to table '\(tableName)'")
            try db.execute("ALTER TABLE \(tableName) ADD COLUMN \(columnName) \(columnType)")
        }
    }
    
    // Get device ID for sync tracking
    private func getDeviceId() async -> String {
        // Use device identifier or generate a unique one
        if let deviceId = await UIDevice.current.identifierForVendor?.uuidString {
            return deviceId
        } else {
            // Fallback to a generated UUID if identifierForVendor is nil
            return UUID().uuidString
        }
    }
    
    // Get current user ID from authentication
    private func getCurrentUserId() async -> String? {
        do {
            let session = try await SupabaseManager.shared.getSession()
            return session.user.id.uuidString
        } catch {
            print("❌ Could not get current user ID: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Check if a current station is marked as favorite
    func isCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            guard let userId = await getCurrentUserId() else {
                print("⚠️ No authenticated user, cannot check favorites")
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
                return result
            }
            return false
        } catch {
            print("❌ CHECK ERROR: \(error.localizedDescription)")
            return false
        }
    }
    
    // Toggle favorite status for a current station with bin
    func toggleCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            guard let userId = await getCurrentUserId() else {
                print("❌ No authenticated user, cannot toggle favorites")
                return false
            }
            
            print("📊 TOGGLE: Beginning toggle for station \(id), bin \(bin), user \(userId)")
            
            let deviceId = await getDeviceId()
            var result = false
            
            try db.transaction {
                let query = tidalCurrentStationFavorites.filter(
                    colUserId == userId &&
                    colStationId == id &&
                    colCurrentBin == bin
                )
                
                if let favorite = try db.pluck(query) {
                    let currentValue = favorite[colIsFavorite]
                    let newValue = !currentValue
                    
                    print("📊 TOGGLE: Found existing record with favorite status: \(currentValue), toggling to \(newValue)")
                    
                    let updatedRow = tidalCurrentStationFavorites.filter(
                        colUserId == userId &&
                        colStationId == id &&
                        colCurrentBin == bin
                    )
                    let count = try db.run(updatedRow.update(
                        colIsFavorite <- newValue,
                        colLastModified <- Date(),
                        colDeviceId <- deviceId
                    ))
                    
                    print("📊 TOGGLE: Updated record with result: \(count) rows affected")
                    result = newValue
                } else {
                    print("📊 TOGGLE: No existing record found, creating new favorite")
                    
                    let insert = tidalCurrentStationFavorites.insert(
                        colUserId <- userId,
                        colStationId <- id,
                        colCurrentBin <- bin,
                        colIsFavorite <- true,
                        colLastModified <- Date(),
                        colDeviceId <- deviceId
                    )
                    
                    let rowId = try db.run(insert)
                    print("📊 TOGGLE: Inserted new favorite with rowId: \(rowId)")
                    result = true
                }
            }
            
            // Force a disk flush after toggling favorites
            try await databaseCore.flushDatabaseAsync()
            return result
        } catch {
            print("❌ TOGGLE ERROR: \(error.localizedDescription)")
            print("❌ TOGGLE ERROR DETAILS: \(error)")
            return false
        }
    }
    
    // Check if a current station is marked as favorite (without bin - checks any bin)
    func isCurrentStationFavorite(id: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            guard let userId = await getCurrentUserId() else {
                print("⚠️ No authenticated user, cannot check favorites")
                return false
            }
            
            let query = tidalCurrentStationFavorites.filter(
                colUserId == userId &&
                colStationId == id &&
                colIsFavorite == true
            )
            
            // Check if any record exists and is marked as favorite
            for row in try db.prepare(query) {
                if row[colIsFavorite] {
                    return true
                }
            }
            return false
        } catch {
            print("❌ CHECK ERROR: \(error.localizedDescription)")
            return false
        }
    }
    
    // Toggle favorite status for a current station (without bin) - applies to all bins
    func toggleCurrentStationFavorite(id: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            guard let userId = await getCurrentUserId() else {
                print("❌ No authenticated user, cannot toggle favorites")
                return false
            }
            
            print("📊 TOGGLE: Beginning toggle for all bins of station \(id), user \(userId)")
            
            let deviceId = await getDeviceId()
            
            // Check if any records exist for this user and station
            let query = tidalCurrentStationFavorites.filter(
                colUserId == userId &&
                colStationId == id
            )
            let records = Array(try db.prepare(query))
            
            if records.isEmpty {
                // No records found, create a default one with bin 0
                print("📊 TOGGLE: No records found, creating default with bin 0")
                try db.run(tidalCurrentStationFavorites.insert(
                    colUserId <- userId,
                    colStationId <- id,
                    colCurrentBin <- 0,
                    colIsFavorite <- true,
                    colLastModified <- Date(),
                    colDeviceId <- deviceId
                ))
                try await databaseCore.flushDatabaseAsync()
                return true
            } else {
                // Get current state from first record (assuming all should be the same)
                let currentValue = records.first![colIsFavorite]
                let newValue = !currentValue
                print("📊 TOGGLE: Found \(records.count) records with favorite status: \(currentValue), toggling all to \(newValue)")
                
                // Update all records for this user and station
                let count = try db.run(tidalCurrentStationFavorites.filter(
                    colUserId == userId &&
                    colStationId == id
                ).update(
                    colIsFavorite <- newValue,
                    colLastModified <- Date(),
                    colDeviceId <- deviceId
                ))
                print("📊 TOGGLE: Updated \(count) records")
                
                try await databaseCore.flushDatabaseAsync()
                return newValue
            }
        } catch {
            print("❌ TOGGLE ERROR: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - New Methods for Sync Support
    
    // Get all favorites for the current user (for sync operations)
    func getAllCurrentStationFavoritesForUser() async throws -> [TidalCurrentFavoriteRecord] {
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
        depthType: String? = nil
    ) async throws {
        let db = try databaseCore.ensureConnection()
        guard let userId = await getCurrentUserId() else {
            throw NSError(domain: "DatabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let deviceId = await getDeviceId()
        
        try db.run(tidalCurrentStationFavorites.insert(or: .replace,
            colUserId <- userId,
            colStationId <- stationId,
            colCurrentBin <- currentBin,
            colIsFavorite <- isFavorite,
            colLastModified <- Date(),
            colDeviceId <- deviceId,
            colStationName <- stationName,
            colLatitude <- latitude,
            colLongitude <- longitude,
            colDepth <- depth,
            colDepthType <- depthType
        ))
        
        try await databaseCore.flushDatabaseAsync()
    }
}

// MARK: - Supporting Data Models

struct TidalCurrentFavoriteRecord {
    let id: Int
    let userId: String?
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
}
