
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
            
            // ENHANCED LOGGING: Show all input parameters
            print("📊 TOGGLE: Beginning toggle for tide station \(id)")
            print("📊 TOGGLE: Input parameters:")
            print("📊 TOGGLE:   - Station ID: '\(id)'")
            print("📊 TOGGLE:   - Station Name: '\(name)'")
            if let lat = latitude {
                print("📊 TOGGLE:   - Latitude: \(lat)")
            } else {
                print("📊 TOGGLE:   - Latitude: nil")
            }
            if let lng = longitude {
                print("📊 TOGGLE:   - Longitude: \(lng)")
            } else {
                print("📊 TOGGLE:   - Longitude: nil")
            }
            
            var result = false
            
            try db.transaction {
                let query = tideStationFavorites.filter(colStationId == id)
                
                if let favorite = try db.pluck(query) {
                    let currentValue = favorite[colIsFavorite]
                    let newValue = !currentValue
                    
                    print("📊 TOGGLE: Found existing record with favorite status: \(currentValue), toggling to \(newValue)")
                    print("📊 TOGGLE: Updating existing record with:")
                    print("📊 TOGGLE:   - colIsFavorite = \(newValue)")
                    print("📊 TOGGLE:   - colStationName = '\(name)'")
                    if let lat = latitude {
                        print("📊 TOGGLE:   - colLatitude = \(lat)")
                    } else {
                        print("📊 TOGGLE:   - colLatitude = nil")
                    }
                    if let lng = longitude {
                        print("📊 TOGGLE:   - colLongitude = \(lng)")
                    } else {
                        print("📊 TOGGLE:   - colLongitude = nil")
                    }
                    
                    let updatedRow = tideStationFavorites.filter(colStationId == id)
                    let updateCount = try db.run(updatedRow.update(
                        colIsFavorite <- newValue,
                        colStationName <- name,
                        colLatitude <- latitude,
                        colLongitude <- longitude
                    ))
                    
                    print("📊 TOGGLE: ✅ UPDATE SUCCESS - \(updateCount) row(s) updated")
                    result = newValue
                } else {
                    print("📊 TOGGLE: No existing record found, creating new favorite")
                    print("📊 TOGGLE: Inserting new record with:")
                    print("📊 TOGGLE:   - colStationId = '\(id)'")
                    print("📊 TOGGLE:   - colIsFavorite = true")
                    print("📊 TOGGLE:   - colStationName = '\(name)'")
                    if let lat = latitude {
                        print("📊 TOGGLE:   - colLatitude = \(lat)")
                    } else {
                        print("📊 TOGGLE:   - colLatitude = nil")
                    }
                    if let lng = longitude {
                        print("📊 TOGGLE:   - colLongitude = \(lng)")
                    } else {
                        print("📊 TOGGLE:   - colLongitude = nil")
                    }
                    
                    let insert = tideStationFavorites.insert(
                        colStationId <- id,
                        colIsFavorite <- true,
                        colStationName <- name,
                        colLatitude <- latitude,
                        colLongitude <- longitude
                    )
                    
                    let insertRowId = try db.run(insert)
                    print("📊 TOGGLE: ✅ INSERT SUCCESS - New record created with rowid: \(insertRowId)")
                    result = true
                }
            }
            
            // ENHANCED LOGGING: Verify the data was actually saved
            print("📊 TOGGLE: Verifying data was saved correctly...")
            let verificationQuery = tideStationFavorites.filter(colStationId == id)
            if let savedRecord = try db.pluck(verificationQuery) {
                print("📊 TOGGLE: ✅ VERIFICATION SUCCESS - Record found in database:")
                print("📊 TOGGLE:   - Saved Station ID: '\(savedRecord[colStationId])'")
                print("📊 TOGGLE:   - Saved Is Favorite: \(savedRecord[colIsFavorite])")
                print("📊 TOGGLE:   - Saved Station Name: '\(savedRecord[colStationName])'")
                if let savedLat = savedRecord[colLatitude] {
                    print("📊 TOGGLE:   - Saved Latitude: \(savedLat)")
                } else {
                    print("📊 TOGGLE:   - Saved Latitude: nil")
                }
                if let savedLng = savedRecord[colLongitude] {
                    print("📊 TOGGLE:   - Saved Longitude: \(savedLng)")
                } else {
                    print("📊 TOGGLE:   - Saved Longitude: nil")
                }
            } else {
                print("📊 TOGGLE: ❌ VERIFICATION FAILED - Record not found after save!")
            }
            
            try await databaseCore.flushDatabaseAsync()
            print("📊 TOGGLE: ✅ Database changes flushed to disk")
            
            return result
        } catch {
            print("❌ TOGGLE ERROR: \(error.localizedDescription)")
            print("❌ TOGGLE ERROR DETAILS: \(error)")
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
