import Foundation
#if canImport(SQLite)
import SQLite
#endif

class CurrentStationDatabaseService {
    // MARK: - Table Definitions
    private let tidalCurrentStationFavorites = Table("TidalCurrentStationFavorites")
    
    // MARK: - Column Definitions
    private let colStationId = Expression<String>("station_id")
    private let colCurrentBin = Expression<Int>("current_bin")
    private let colIsFavorite = Expression<Bool>("is_favorite")
    
    // MARK: - Properties
    private let databaseCore: DatabaseCore
    
    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }
    
    // MARK: - Methods
    
   
    
    // Initialize current station favorites table with extensive error logging
    func initializeCurrentStationFavoritesTableAsync() async throws {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 Creating TidalCurrentStationFavorites table if it doesn't exist")
            
            // Get current tables first
            let tablesQuery = "SELECT name FROM sqlite_master WHERE type='table'"
            var tableNames: [String] = []
            for row in try db.prepare(tablesQuery) {
                if let tableName = row[0] as? String {
                    tableNames.append(tableName)
                }
            }
            print("📊 Current tables: \(tableNames.joined(separator: ", "))")
            
            // Create table
            try db.run(tidalCurrentStationFavorites.create(ifNotExists: true) { table in
                table.column(colStationId)
                table.column(colCurrentBin)
                table.column(colIsFavorite)
                table.primaryKey(colStationId, colCurrentBin)
            })
            
            // Verify table was created
            tableNames = []
            for row in try db.prepare(tablesQuery) {
                if let tableName = row[0] as? String {
                    tableNames.append(tableName)
                }
            }
            
            if tableNames.contains("TidalCurrentStationFavorites") {
                print("📊 TidalCurrentStationFavorites table created or already exists")
                
                // Check if we can write to the table
                try db.run(tidalCurrentStationFavorites.insert(or: .replace,
                    colStationId <- "TEST_INIT",
                    colCurrentBin <- 0,
                    colIsFavorite <- true
                ))
                
                // Verify write worked
                let testQuery = tidalCurrentStationFavorites.filter(colStationId == "TEST_INIT")
                if (try? db.pluck(testQuery)) != nil {
                    print("📊 Successfully wrote and read test record")
                } else {
                    print("❌ Could not verify test record")
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
    
    
    
    
    
    
    
    
    
    
    
    
    
    // Check if a current station is marked as favorite
    func isCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 CHECK: Checking favorite status for station \(id), bin \(bin)")
            let query = tidalCurrentStationFavorites.filter(colStationId == id && colCurrentBin == bin)
            
            if let favorite = try db.pluck(query) {
                let result = favorite[colIsFavorite]
                print("📊 CHECK: Found favorite status: \(result)")
                return result
            }
            print("📊 CHECK: No favorite record found")
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
            
            print("📊 TOGGLE: Beginning toggle for station \(id), bin \(bin)")
            
            // Variable to store the result outside transaction
            var result = false
            
            try db.transaction {
                let query = tidalCurrentStationFavorites.filter(colStationId == id && colCurrentBin == bin)
                
                if let favorite = try db.pluck(query) {
                    let currentValue = favorite[colIsFavorite]
                    let newValue = !currentValue
                    
                    print("📊 TOGGLE: Found existing record with favorite status: \(currentValue), toggling to \(newValue)")
                    
                    let updatedRow = tidalCurrentStationFavorites.filter(colStationId == id && colCurrentBin == bin)
                    let count = try db.run(updatedRow.update(colIsFavorite <- newValue))
                    
                    print("📊 TOGGLE: Updated record with result: \(count) rows affected")
                    result = newValue
                } else {
                    print("📊 TOGGLE: No existing record found, creating new favorite")
                    
                    let insert = tidalCurrentStationFavorites.insert(
                        colStationId <- id,
                        colCurrentBin <- bin,
                        colIsFavorite <- true
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
    
    // Check if a current station is marked as favorite (without bin)
    func isCurrentStationFavorite(id: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 CHECK: Checking any favorite status for station \(id)")
            let query = tidalCurrentStationFavorites.filter(colStationId == id)
            
            // Check if any record exists and is marked as favorite
            for row in try db.prepare(query) {
                if row[colIsFavorite] {
                    print("📊 CHECK: Found favorite status true for bin \(row[colCurrentBin])")
                    return true
                }
            }
            print("📊 CHECK: No favorite record found for any bin")
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
            
            print("📊 TOGGLE: Beginning toggle for all bins of station \(id)")
            
            // Check if any records exist
            let query = tidalCurrentStationFavorites.filter(colStationId == id)
            let records = Array(try db.prepare(query))
            
            if records.isEmpty {
                // No records found, create a default one with bin 0
                print("📊 TOGGLE: No records found, creating default with bin 0")
                try db.run(tidalCurrentStationFavorites.insert(
                    colStationId <- id,
                    colCurrentBin <- 0,
                    colIsFavorite <- true
                ))
                try await databaseCore.flushDatabaseAsync()
                return true
            } else {
                // Get current state from first record (assuming all should be the same)
                let currentValue = records.first![colIsFavorite]
                let newValue = !currentValue
                print("📊 TOGGLE: Found \(records.count) records with favorite status: \(currentValue), toggling all to \(newValue)")
                
                // Update all records for this station
                let count = try db.run(tidalCurrentStationFavorites.filter(colStationId == id).update(colIsFavorite <- newValue))
                print("📊 TOGGLE: Updated \(count) records")
                
                try await databaseCore.flushDatabaseAsync()
                return newValue
            }
        } catch {
            print("❌ TOGGLE ERROR: \(error.localizedDescription)")
            return false
        }
    }
}
