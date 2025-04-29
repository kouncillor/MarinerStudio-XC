import Foundation
#if canImport(SQLite)
import SQLite
#endif

class CurrentStationDatabaseService {
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
            try db.run(databaseCore.tidalCurrentStationFavorites.create(ifNotExists: true) { table in
                table.column(databaseCore.colStationId)
                table.column(databaseCore.colCurrentBin)
                table.column(databaseCore.colIsFavorite)
                table.primaryKey(databaseCore.colStationId, databaseCore.colCurrentBin)
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
                try db.run(databaseCore.tidalCurrentStationFavorites.insert(or: .replace,
                    databaseCore.colStationId <- "TEST_INIT",
                    databaseCore.colCurrentBin <- 0,
                    databaseCore.colIsFavorite <- true
                ))
                
                // Verify write worked
                let testQuery = databaseCore.tidalCurrentStationFavorites.filter(databaseCore.colStationId == "TEST_INIT")
                if let _testRecord = try? db.pluck(testQuery) {
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
            let query = databaseCore.tidalCurrentStationFavorites.filter(databaseCore.colStationId == id && databaseCore.colCurrentBin == bin)
            
            if let favorite = try db.pluck(query) {
                let result = favorite[databaseCore.colIsFavorite]
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
                let query = databaseCore.tidalCurrentStationFavorites.filter(databaseCore.colStationId == id && databaseCore.colCurrentBin == bin)
                
                if let favorite = try db.pluck(query) {
                    let currentValue = favorite[databaseCore.colIsFavorite]
                    let newValue = !currentValue
                    
                    print("📊 TOGGLE: Found existing record with favorite status: \(currentValue), toggling to \(newValue)")
                    
                    let updatedRow = databaseCore.tidalCurrentStationFavorites.filter(databaseCore.colStationId == id && databaseCore.colCurrentBin == bin)
                    let count = try db.run(updatedRow.update(databaseCore.colIsFavorite <- newValue))
                    
                    print("📊 TOGGLE: Updated record with result: \(count) rows affected")
                    result = newValue
                } else {
                    print("📊 TOGGLE: No existing record found, creating new favorite")
                    
                    let insert = databaseCore.tidalCurrentStationFavorites.insert(
                        databaseCore.colStationId <- id,
                        databaseCore.colCurrentBin <- bin,
                        databaseCore.colIsFavorite <- true
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
            let query = databaseCore.tidalCurrentStationFavorites.filter(databaseCore.colStationId == id)
            
            // Check if any record exists and is marked as favorite
            for row in try db.prepare(query) {
                if row[databaseCore.colIsFavorite] {
                    print("📊 CHECK: Found favorite status true for bin \(row[databaseCore.colCurrentBin])")
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
            let query = databaseCore.tidalCurrentStationFavorites.filter(databaseCore.colStationId == id)
            let records = Array(try db.prepare(query))
            
            if records.isEmpty {
                // No records found, create a default one with bin 0
                print("📊 TOGGLE: No records found, creating default with bin 0")
                try db.run(databaseCore.tidalCurrentStationFavorites.insert(
                    databaseCore.colStationId <- id,
                    databaseCore.colCurrentBin <- 0,
                    databaseCore.colIsFavorite <- true
                ))
                try await databaseCore.flushDatabaseAsync()
                return true
            } else {
                // Get current state from first record (assuming all should be the same)
                let currentValue = records.first![databaseCore.colIsFavorite]
                let newValue = !currentValue
                print("📊 TOGGLE: Found \(records.count) records with favorite status: \(currentValue), toggling all to \(newValue)")
                
                // Update all records for this station
                let count = try db.run(databaseCore.tidalCurrentStationFavorites.filter(databaseCore.colStationId == id).update(databaseCore.colIsFavorite <- newValue))
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
