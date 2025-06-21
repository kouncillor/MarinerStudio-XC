////
////import Foundation
////#if canImport(SQLite)
////import SQLite
////#endif
////
////class TideStationDatabaseService {
////    // MARK: - Table Definitions
////    private let tideStationFavorites = Table("TideStationFavorites")
////    
////    // MARK: - Column Definitions
////    private let colStationId = Expression<String>("station_id")
////    private let colIsFavorite = Expression<Bool>("is_favorite")
////    
////    // MARK: - Properties
////    private let databaseCore: DatabaseCore
////    
////    // MARK: - Initialization
////    init(databaseCore: DatabaseCore) {
////        self.databaseCore = databaseCore
////    }
////    
////    // MARK: - Methods
////    
////    // Initialize tide station favorites table with extensive error logging
////    func initializeTideStationFavoritesTableAsync() async throws {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////         //   print("📊 Creating TideStationFavorites table if it doesn't exist")
////            
////            // Get current tables first
////            let tablesQuery = "SELECT name FROM sqlite_master WHERE type='table'"
////            var tableNames: [String] = []
////            for row in try db.prepare(tablesQuery) {
////                if let tableName = row[0] as? String {
////                    tableNames.append(tableName)
////                }
////            }
////        //    print("📊 Current tables: \(tableNames.joined(separator: ", "))")
////            
////            // Create table
////            try db.run(tideStationFavorites.create(ifNotExists: true) { table in
////                table.column(colStationId, primaryKey: true)
////                table.column(colIsFavorite)
////            })
////            
////            // Verify table was created
////            tableNames = []
////            for row in try db.prepare(tablesQuery) {
////                if let tableName = row[0] as? String {
////                    tableNames.append(tableName)
////                }
////            }
////            
////            if tableNames.contains("TideStationFavorites") {
////         //       print("📊 TideStationFavorites table created or already exists")
////                
////                // Check if we can write to the table
////                try db.run(tideStationFavorites.insert(or: .replace,
////                    colStationId <- "TEST_INIT",
////                    colIsFavorite <- true
////                ))
////                
////                // Verify write worked - FIX 1: Changed to boolean test instead of unused variable
////                let testQuery = tideStationFavorites.filter(colStationId == "TEST_INIT")
////                if try db.pluck(testQuery) != nil {
////        //            print("📊 Successfully wrote and read test record")
////                } else {
////          //          print("❌ Could not verify test record")
////                }
////            } else {
////         //       print("❌ Failed to create TideStationFavorites table")
////                throw NSError(domain: "DatabaseService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create table"])
////            }
////        } catch {
////      //      print("❌ Error creating TideStationFavorites table: \(error.localizedDescription)")
////            throw error
////        }
////    }
////    
////    // Check if a tide station is marked as favorite
////    func isTideStationFavorite(id: String) async -> Bool {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////        //    print("📊 CHECK: Checking favorite status for tide station \(id)")
////            let query = tideStationFavorites.filter(colStationId == id)
////            
////            if let favorite = try db.pluck(query) {
////                let result = favorite[colIsFavorite]
////        //        print("📊 CHECK: Found favorite status: \(result)")
////                return result
////            }
////        //    print("📊 CHECK: No favorite record found")
////            return false
////        } catch {
////        //    print("❌ CHECK ERROR: \(error.localizedDescription)")
////            return false
////        }
////    }
////    
////    // Toggle favorite status for a tide station
////    func toggleTideStationFavorite(id: String) async -> Bool {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////       //     print("📊 TOGGLE: Beginning toggle for tide station \(id)")
////            
////            // Variable to store the result outside transaction
////            var result = false
////            
////            try db.transaction {
////                let query = tideStationFavorites.filter(colStationId == id)
////                
////                if let favorite = try db.pluck(query) {
////                    let currentValue = favorite[colIsFavorite]
////                    let newValue = !currentValue
////                    
////       //             print("📊 TOGGLE: Found existing record with favorite status: \(currentValue), toggling to \(newValue)")
////                    
////                    let updatedRow = tideStationFavorites.filter(colStationId == id)
////                    // FIX 2: Changed to underscore for unused count variable
////                    _ = try db.run(updatedRow.update(colIsFavorite <- newValue))
////                    
////        //            print("📊 TOGGLE: Updated record with result: \(count) rows affected")
////                    result = newValue
////                } else {
////        //            print("📊 TOGGLE: No existing record found, creating new favorite")
////                    
////                    let insert = tideStationFavorites.insert(
////                        colStationId <- id,
////                        colIsFavorite <- true
////                    )
////                    
////                    // FIX 3: Changed to underscore for unused rowId variable
////                    _ = try db.run(insert)
////        //            print("📊 TOGGLE: Inserted new favorite with rowId: \(rowId)")
////                    result = true
////                }
////            }
////            
////            // Force a disk flush after toggling favorites
////            try await databaseCore.flushDatabaseAsync()
////            return result
////        } catch {
////       //     print("❌ TOGGLE ERROR: \(error.localizedDescription)")
////       //     print("❌ TOGGLE ERROR DETAILS: \(error)")
////            return false
////        }
////    }
////    
////    // MARK: - Sync Support Methods (Step 3)
////    
////    /// Get all station IDs that are marked as favorites (for sync operations)
////    func getAllFavoriteStationIds() async -> Set<String> {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////            var favoriteIds = Set<String>()
////            
////            for favorite in try db.prepare(tideStationFavorites.filter(colIsFavorite == true)) {
////                favoriteIds.insert(favorite[colStationId])
////            }
////            
////            print("🌊 SYNC SUPPORT: Found \(favoriteIds.count) local favorites")
////            return favoriteIds
////            
////        } catch {
////            print("❌ SYNC SUPPORT ERROR: \(error.localizedDescription)")
////            return Set<String>()
////        }
////    }
////    
////    /// Get all favorite stations with their status (for detailed sync operations)
////    func getAllFavoriteStations() async -> [(stationId: String, isFavorite: Bool)] {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////            var stations: [(String, Bool)] = []
////            
////            for favorite in try db.prepare(tideStationFavorites) {
////                stations.append((favorite[colStationId], favorite[colIsFavorite]))
////            }
////            
////            print("🌊 SYNC SUPPORT: Found \(stations.count) total station records")
////            return stations
////            
////        } catch {
////            print("❌ SYNC SUPPORT ERROR: \(error.localizedDescription)")
////            return []
////        }
////    }
////    
////    /// Set favorite status without toggling (for sync operations)
////    func setTideStationFavorite(id: String, isFavorite: Bool) async -> Bool {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////            print("🌊 SYNC SET: Setting station \(id) to favorite=\(isFavorite)")
////            
////            try db.run(tideStationFavorites.insert(or: .replace,
////                colStationId <- id,
////                colIsFavorite <- isFavorite
////            ))
////            
////            // Force a disk flush after sync operations
////            try await databaseCore.flushDatabaseAsync()
////            
////            print("🌊 SYNC SET: Successfully set station \(id)")
////            return true
////            
////        } catch {
////            print("❌ SYNC SET ERROR: \(error.localizedDescription)")
////            return false
////        }
////    }
////}
////
////
////
//
//
//
//
//
//// Mariner Studio/Services/Database/TideStationDatabaseService.swift
//import Foundation
//#if canImport(SQLite)
//import SQLite
//#endif
//
//class TideStationDatabaseService {
//    // MARK: - Table Definitions
//    private let tideStationFavorites = Table("TideStationFavorites")
//    
//    // MARK: - Column Definitions
//    private let colStationId = Expression<String>("station_id")
//    private let colIsFavorite = Expression<Bool>("is_favorite")
//    private let colStationName = Expression<String>("station_name") // NEW
//    private let colLatitude = Expression<Double?>("latitude")     // NEW
//    private let colLongitude = Expression<Double?>("longitude")    // NEW
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
//    // Initialize tide station favorites table with extensive error logging
//    func initializeTideStationFavoritesTableAsync() async throws {
//        do {
//            let db = try databaseCore.ensureConnection()
//            
//            print("📊 Creating TideStationFavorites table if it doesn't exist")
//            
//            // Create table with new columns
//            try db.run(tideStationFavorites.create(ifNotExists: true) { table in
//                table.column(colStationId, primaryKey: true)
//                table.column(colIsFavorite)
//                table.column(colStationName, defaultValue: "") // Set a default value for existing rows
//                table.column(colLatitude)
//                table.column(colLongitude)
//            })
//            
//            // Migration: Add new columns if they don't exist in an older database version
//            try addColumnIfNeeded(db: db, tableName: "TideStationFavorites", columnName: "station_name", columnType: "TEXT", defaultValue: "''")
//            try addColumnIfNeeded(db: db, tableName: "TideStationFavorites", columnName: "latitude", columnType: "REAL")
//            try addColumnIfNeeded(db: db, tableName: "TideStationFavorites", columnName: "longitude", columnType: "REAL")
//            
//            // Verify table was created and columns exist
//            let tableInfo = try db.prepare("PRAGMA table_info(TideStationFavorites)")
//            var columnNames: Set<String> = []
//            for row in tableInfo {
//                if let name = row[1] as? String { // Column name is at index 1
//                    columnNames.insert(name)
//                }
//            }
//            
//            let expectedColumns: Set<String> = ["station_id", "is_favorite", "station_name", "latitude", "longitude"]
//            let allColumnsExist = expectedColumns.isSubset(of: columnNames)
//            
//            if allColumnsExist {
//                print("📊 TideStationFavorites table created or already exists with all required columns")
//                
//                // Check if we can write to the table with all columns
//                try db.run(tideStationFavorites.insert(or: .replace,
//                    colStationId <- "TEST_INIT_V2",
//                    colIsFavorite <- true,
//                    colStationName <- "Test Station Name",
//                    colLatitude <- 0.0,
//                    colLongitude <- 0.0
//                ))
//                
//                let testQuery = tideStationFavorites.filter(colStationId == "TEST_INIT_V2")
//                if try db.pluck(testQuery) != nil {
//                    print("📊 Successfully wrote and read test record with new columns")
//                    // Clean up test record
//                    _ = try db.run(testQuery.delete())
//                } else {
//                    print("❌ Could not verify test record with new columns")
//                }
//            } else {
//                print("❌ Failed to create TideStationFavorites table or missing columns. Found: \(columnNames)")
//                throw NSError(domain: "DatabaseService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create table or missing columns"])
//            }
//        } catch {
//            print("❌ Error creating TideStationFavorites table: \(error.localizedDescription)")
//            throw error
//        }
//    }
//    
//    private func addColumnIfNeeded(db: Connection, tableName: String, columnName: String, columnType: String, defaultValue: String? = nil) throws {
//        let tableInfo = try db.prepare("PRAGMA table_info(\(tableName))")
//        var columnExists = false
//        for row in tableInfo {
//            if let name = row[1] as? String, name == columnName { // Column name is at index 1
//                columnExists = true
//                break
//            }
//        }
//        
//        if !columnExists {
//            var alterStatement = "ALTER TABLE \(tableName) ADD COLUMN \(columnName) \(columnType)"
//            if let defaultValue = defaultValue {
//                alterStatement += " DEFAULT \(defaultValue)"
//            }
//            print("📊 Attempting to add column '\(columnName)' to '\(tableName)' table.")
//            try db.run(alterStatement)
//            print("✅ Successfully added column '\(columnName)' to '\(tableName)'")
//        } else {
//            print("📊 Column '\(columnName)' already exists in '\(tableName)' table. No migration needed for this column.")
//        }
//    }
//    
//    // Check if a tide station is marked as favorite
//    func isTideStationFavorite(id: String) async -> Bool {
//        do {
//            let db = try databaseCore.ensureConnection()
//            
//            print("📊 CHECK: Checking favorite status for tide station \(id)")
//            let query = tideStationFavorites.filter(colStationId == id)
//            
//            if let favorite = try db.pluck(query) {
//                let result = favorite[colIsFavorite]
//                print("📊 CHECK: Found favorite status: \(result)")
//                return result
//            }
//            print("📊 CHECK: No favorite record found")
//            return false
//        } catch {
//            print("❌ CHECK ERROR: \(error.localizedDescription)")
//            return false
//        }
//    }
//    
//    // Toggle favorite status for a tide station, now accepting full station details
//    func toggleTideStationFavorite(id: String, name: String, latitude: Double?, longitude: Double?) async -> Bool {
//        do {
//            let db = try databaseCore.ensureConnection()
//            
//            print("📊 TOGGLE: Beginning toggle for tide station \(id)")
//            
//            var result = false
//            
//            try db.transaction {
//                let query = tideStationFavorites.filter(colStationId == id)
//                
//                if let favorite = try db.pluck(query) {
//                    let currentValue = favorite[colIsFavorite]
//                    let newValue = !currentValue
//                    
//                    print("📊 TOGGLE: Found existing record with favorite status: \(currentValue), toggling to \(newValue)")
//                    
//                    let updatedRow = tideStationFavorites.filter(colStationId == id)
//                    _ = try db.run(updatedRow.update(
//                        colIsFavorite <- newValue,
//                        colStationName <- name,
//                        colLatitude <- latitude,
//                        colLongitude <- longitude
//                    ))
//                    
//                    print("📊 TOGGLE: Updated record.")
//                    result = newValue
//                } else {
//                    print("📊 TOGGLE: No existing record found, creating new favorite")
//                    
//                    let insert = tideStationFavorites.insert(
//                        colStationId <- id,
//                        colIsFavorite <- true,
//                        colStationName <- name,
//                        colLatitude <- latitude,
//                        colLongitude <- longitude
//                    )
//                    
//                    _ = try db.run(insert)
//                    print("📊 TOGGLE: Inserted new favorite.")
//                    result = true
//                }
//            }
//            
//            try await databaseCore.flushDatabaseAsync()
//            return result
//        } catch {
//            print("❌ TOGGLE ERROR: \(error.localizedDescription)")
//            print("❌ TOGGLE ERROR DETAILS: \(error)")
//            return false
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
//    
//    
//    
//    
//    
//    
//    
//    
//    // MARK: - Sync Support Methods (Step 3)
//    
//    /// Get all favorite stations with their full details
//    func getAllFavoriteStations() async -> [TideStationFavorite] {
//        do {
//            let db = try databaseCore.ensureConnection()
//            
//            var favoriteStations: [TideStationFavorite] = []
//            
//            for favorite in try db.prepare(tideStationFavorites.filter(colIsFavorite == true)) {
//                let station = TideStationFavorite(
//                    stationId: favorite[colStationId],
//                    stationName: favorite[colStationName],
//                    latitude: favorite[colLatitude],
//                    longitude: favorite[colLongitude],
//                    isFavorite: favorite[colIsFavorite]
//                )
//                favoriteStations.append(station)
//            }
//            
//            print("🌊 SYNC SUPPORT: Found \(favoriteStations.count) local favorites with full details")
//            return favoriteStations
//            
//        } catch {
//            print("❌ SYNC SUPPORT ERROR: \(error.localizedDescription)")
//            return []
//        }
//    }
//    
//    /// Set favorite status without toggling (for sync operations), now accepting full station details
//    func setTideStationFavorite(id: String, name: String, latitude: Double?, longitude: Double?, isFavorite: Bool) async -> Bool {
//        do {
//            let db = try databaseCore.ensureConnection()
//            
//            print("🌊 SYNC SET: Setting station \(id) to favorite=\(isFavorite)")
//            
//            try db.run(tideStationFavorites.insert(or: .replace,
//                colStationId <- id,
//                colIsFavorite <- isFavorite,
//                colStationName <- name,
//                colLatitude <- latitude,
//                colLongitude <- longitude
//            ))
//            
//            try await databaseCore.flushDatabaseAsync()
//            
//            print("🌊 SYNC SET: Successfully set station \(id)")
//            return true
//            
//        } catch {
//            print("❌ SYNC SET ERROR: \(error.localizedDescription)")
//            return false
//        }
//    }
//    
//    // Old method for compatibility (should be phased out or renamed if no longer needed)
//    func getAllFavoriteStationIds() async -> Set<String> {
//        do {
//            let db = try databaseCore.ensureConnection()
//            
//            var favoriteIds = Set<String>()
//            
//            for favorite in try db.prepare(tideStationFavorites.filter(colIsFavorite == true)) {
//                favoriteIds.insert(favorite[colStationId])
//            }
//            
//            print("🌊 SYNC SUPPORT: Found \(favoriteIds.count) local favorite IDs (Legacy)")
//            return favoriteIds
//            
//        } catch {
//            print("❌ SYNC SUPPORT ERROR (Legacy): \(error.localizedDescription)")
//            return Set<String>()
//        }
//    }
//}










import Foundation
#if canImport(SQLite)
import SQLite
#endif

class TideStationDatabaseService {
    // MARK: - Table Definitions
    private let tideStationFavorites = Table("TideStationFavorites")
    
    // MARK: - Column Definitions
    private let colStationId = Expression<String>("station_id")
    private let colIsFavorite = Expression<Bool>("is_favorite")
    private let colStationName = Expression<String>("station_name")
    private let colLatitude = Expression<Double?>("latitude")
    private let colLongitude = Expression<Double?>("longitude")
    
    // MARK: - Properties
    private let databaseCore: DatabaseCore
    
    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }
    
    // MARK: - Table Initialization
    
    func initializeTideStationFavoritesTableAsync() async throws {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 Creating TideStationFavorites table if it doesn't exist")
            
            // Create table with new columns
            try db.run(tideStationFavorites.create(ifNotExists: true) { table in
                table.column(colStationId, primaryKey: true)
                table.column(colIsFavorite)
                table.column(colStationName, defaultValue: "")
                table.column(colLatitude)
                table.column(colLongitude)
            })
            
            // Migration: Add new columns if they don't exist in an older database version
            try addColumnIfNeeded(db: db, tableName: "TideStationFavorites", columnName: "station_name", columnType: "TEXT", defaultValue: "''")
            try addColumnIfNeeded(db: db, tableName: "TideStationFavorites", columnName: "latitude", columnType: "REAL")
            try addColumnIfNeeded(db: db, tableName: "TideStationFavorites", columnName: "longitude", columnType: "REAL")
            
            // Verify table was created and columns exist
            let tableInfo = try db.prepare("PRAGMA table_info(TideStationFavorites)")
            var columnNames: Set<String> = []
            for row in tableInfo {
                if let name = row[1] as? String {
                    columnNames.insert(name)
                }
            }
            
            let expectedColumns: Set<String> = ["station_id", "is_favorite", "station_name", "latitude", "longitude"]
            let allColumnsExist = expectedColumns.isSubset(of: columnNames)
            
            if allColumnsExist {
                print("📊 TideStationFavorites table created or already exists with all required columns")
                
                // Test write with all columns
                try db.run(tideStationFavorites.insert(or: .replace,
                    colStationId <- "TEST_INIT_V2",
                    colIsFavorite <- true,
                    colStationName <- "Test Station Name",
                    colLatitude <- 0.0,
                    colLongitude <- 0.0
                ))
                
                let testQuery = tideStationFavorites.filter(colStationId == "TEST_INIT_V2")
                if try db.pluck(testQuery) != nil {
                    print("📊 Successfully wrote and read test record with new columns")
                    _ = try db.run(testQuery.delete())
                } else {
                    print("❌ Could not verify test record with new columns")
                }
            } else {
                print("❌ Failed to create TideStationFavorites table or missing columns. Found: \(columnNames)")
                throw NSError(domain: "DatabaseService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create table or missing columns"])
            }
        } catch {
            print("❌ Error creating TideStationFavorites table: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func addColumnIfNeeded(db: Connection, tableName: String, columnName: String, columnType: String, defaultValue: String? = nil) throws {
        let tableInfo = try db.prepare("PRAGMA table_info(\(tableName))")
        var columnExists = false
        for row in tableInfo {
            if let name = row[1] as? String, name == columnName {
                columnExists = true
                break
            }
        }
        
        if !columnExists {
            var alterStatement = "ALTER TABLE \(tableName) ADD COLUMN \(columnName) \(columnType)"
            if let defaultValue = defaultValue {
                alterStatement += " DEFAULT \(defaultValue)"
            }
            print("📊 Adding column '\(columnName)' to '\(tableName)' table")
            try db.run(alterStatement)
            print("✅ Successfully added column '\(columnName)' to '\(tableName)'")
        } else {
            print("📊 Column '\(columnName)' already exists in '\(tableName)' table")
        }
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
    
    func toggleTideStationFavorite(id: String, name: String, latitude: Double?, longitude: Double?) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 TOGGLE: Beginning toggle for tide station \(id)")
            
            var result = false
            
            try db.transaction {
                let query = tideStationFavorites.filter(colStationId == id)
                
                if let favorite = try db.pluck(query) {
                    let currentValue = favorite[colIsFavorite]
                    let newValue = !currentValue
                    
                    print("📊 TOGGLE: Found existing record with favorite status: \(currentValue), toggling to \(newValue)")
                    
                    let updatedRow = tideStationFavorites.filter(colStationId == id)
                    _ = try db.run(updatedRow.update(
                        colIsFavorite <- newValue,
                        colStationName <- name,
                        colLatitude <- latitude,
                        colLongitude <- longitude
                    ))
                    
                    print("📊 TOGGLE: Updated record")
                    result = newValue
                } else {
                    print("📊 TOGGLE: No existing record found, creating new favorite")
                    
                    let insert = tideStationFavorites.insert(
                        colStationId <- id,
                        colIsFavorite <- true,
                        colStationName <- name,
                        colLatitude <- latitude,
                        colLongitude <- longitude
                    )
                    
                    _ = try db.run(insert)
                    print("📊 TOGGLE: Inserted new favorite")
                    result = true
                }
            }
            
            try await databaseCore.flushDatabaseAsync()
            return result
        } catch {
            print("❌ TOGGLE ERROR: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Query Methods
    
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
    
    func getAllFavoriteStationsWithDetails() async -> [TidalHeightStation] {
        do {
            let db = try databaseCore.ensureConnection()
            
            var favoriteStations: [TidalHeightStation] = []
            
            for favorite in try db.prepare(tideStationFavorites.filter(colIsFavorite == true)) {
                let station = TidalHeightStation(
                    id: favorite[colStationId],
                    name: favorite[colStationName].isEmpty ? "Station \(favorite[colStationId])" : favorite[colStationName],
                    latitude: favorite[colLatitude],
                    longitude: favorite[colLongitude],
                    state: nil,
                    type: "tidepredictions",
                    referenceId: favorite[colStationId],
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
            
            print("🌊 SYNC SUPPORT: Found \(stations.count) total station records")
            return stations
            
        } catch {
            print("❌ SYNC SUPPORT ERROR: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Sync Support Methods
    
    func setTideStationFavorite(id: String, isFavorite: Bool) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("🌊 SYNC SET: Setting station \(id) to favorite=\(isFavorite)")
            
            // Check if record exists to preserve name and coordinates
            let query = tideStationFavorites.filter(colStationId == id)
            
            if let existingRecord = try db.pluck(query) {
                // Update existing record, preserving name and coordinates
                _ = try db.run(query.update(colIsFavorite <- isFavorite))
            } else {
                // Insert new record with basic info
                try db.run(tideStationFavorites.insert(
                    colStationId <- id,
                    colIsFavorite <- isFavorite,
                    colStationName <- "Station \(id)",
                    colLatitude <- nil,
                    colLongitude <- nil
                ))
            }
            
            try await databaseCore.flushDatabaseAsync()
            
            print("🌊 SYNC SET: Successfully set station \(id)")
            return true
            
        } catch {
            print("❌ SYNC SET ERROR: \(error.localizedDescription)")
            return false
        }
    }
    
    func setTideStationFavorite(id: String, name: String, latitude: Double?, longitude: Double?, isFavorite: Bool) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("🌊 SYNC SET: Setting station \(id) (\(name)) to favorite=\(isFavorite)")
            
            try db.run(tideStationFavorites.insert(or: .replace,
                colStationId <- id,
                colIsFavorite <- isFavorite,
                colStationName <- name,
                colLatitude <- latitude,
                colLongitude <- longitude
            ))
            
            try await databaseCore.flushDatabaseAsync()
            
            print("🌊 SYNC SET: Successfully set station \(id) with full details")
            return true
            
        } catch {
            print("❌ SYNC SET ERROR: \(error.localizedDescription)")
            return false
        }
    }
}
