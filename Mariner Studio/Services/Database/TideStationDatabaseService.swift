import Foundation
#if canImport(SQLite)
import SQLite
#endif

class TideStationDatabaseService {
    // MARK: - Properties
    private let databaseCore: DatabaseCore
    
    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }
    
    // MARK: - Methods
    
    // Initialize tide station favorites table with extensive error logging
    func initializeTideStationFavoritesTableAsync() async throws {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 Creating TideStationFavorites table if it doesn't exist")
            
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
            try db.run(databaseCore.tideStationFavorites.create(ifNotExists: true) { table in
                table.column(databaseCore.colStationId, primaryKey: true)
                table.column(databaseCore.colIsFavorite)
            })
            
            // Verify table was created
            tableNames = []
            for row in try db.prepare(tablesQuery) {
                if let tableName = row[0] as? String {
                    tableNames.append(tableName)
                }
            }
            
            if tableNames.contains("TideStationFavorites") {
                print("📊 TideStationFavorites table created or already exists")
                
                // Check if we can write to the table
                try db.run(databaseCore.tideStationFavorites.insert(or: .replace,
                    databaseCore.colStationId <- "TEST_INIT",
                    databaseCore.colIsFavorite <- true
                ))
                
                // Verify write worked
                let testQuery = databaseCore.tideStationFavorites.filter(databaseCore.colStationId == "TEST_INIT")
                if let _testRecord = try? db.pluck(testQuery) {
                    print("📊 Successfully wrote and read test record")
                } else {
                    print("❌ Could not verify test record")
                }
            } else {
                print("❌ Failed to create TideStationFavorites table")
                throw NSError(domain: "DatabaseService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create table"])
            }
        } catch {
            print("❌ Error creating TideStationFavorites table: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Check if a tide station is marked as favorite
    func isTideStationFavorite(id: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 CHECK: Checking favorite status for tide station \(id)")
            let query = databaseCore.tideStationFavorites.filter(databaseCore.colStationId == id)
            
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
    
    // Toggle favorite status for a tide station
    func toggleTideStationFavorite(id: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 TOGGLE: Beginning toggle for tide station \(id)")
            
            // Variable to store the result outside transaction
            var result = false
            
            try db.transaction {
                let query = databaseCore.tideStationFavorites.filter(databaseCore.colStationId == id)
                
                if let favorite = try db.pluck(query) {
                    let currentValue = favorite[databaseCore.colIsFavorite]
                    let newValue = !currentValue
                    
                    print("📊 TOGGLE: Found existing record with favorite status: \(currentValue), toggling to \(newValue)")
                    
                    let updatedRow = databaseCore.tideStationFavorites.filter(databaseCore.colStationId == id)
                    let count = try db.run(updatedRow.update(databaseCore.colIsFavorite <- newValue))
                    
                    print("📊 TOGGLE: Updated record with result: \(count) rows affected")
                    result = newValue
                } else {
                    print("📊 TOGGLE: No existing record found, creating new favorite")
                    
                    let insert = databaseCore.tideStationFavorites.insert(
                        databaseCore.colStationId <- id,
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
}
