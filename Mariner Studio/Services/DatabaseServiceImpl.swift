import Foundation
// Using conditional import to handle cases where SQLite.swift might not be available
// Make sure to add the SQLite.swift package to your project:
// Swift Package Manager: https://github.com/stephencelis/SQLite.swift.git
// Or CocoaPods: pod 'SQLite.swift', '~> 0.14.0'
#if canImport(SQLite)
import SQLite
#endif

class DatabaseServiceImpl: DatabaseService, ObservableObject {
    // MARK: - Singleton
    private static var _shared: DatabaseServiceImpl?
    
    /// Provides access to the singleton instance
    static var shared: DatabaseServiceImpl {
        if _shared == nil {
            _shared = DatabaseServiceImpl()
        }
        return _shared!
    }
    
    // MARK: - Properties
    private var connection: Connection?
    private let dbFileName = "app.db"
    private let versionPreferenceKey = "DatabaseVersion"
    private let currentDatabaseVersion = 1
    
    // MARK: - Tables
    private let tideStationFavorites = Table("TideStationFavorites")
    private let tidalCurrentStationFavorites = Table("TidalCurrentStationFavorites")
    private let navUnits = Table("NavUnit")
    private let tugs = Table("Tug")
    private let barges = Table("Barge")
    private let personalNotes = Table("PersonalNote")
    private let changeRecommendations = Table("ChangeRecommendation")
    private let navUnitPhotos = Table("NavUnitPhoto")
    private let tugPhotos = Table("TugPhoto")
    private let tugNotes = Table("TugNote")
    private let tugChangeRecommendations = Table("TugChangeRecommendation")
    private let bargePhotos = Table("BargePhoto")
    private let buoyStationFavorites = Table("BuoyStationFavorites")
    private let moonPhases = Table("MoonPhase")
    private let weatherLocationFavorites = Table("WeatherLocationFavorite")
    
    // MARK: - Columns
    // TideStationFavorites
    private let colStationId = Expression<String>("station_id")
    private let colIsFavorite = Expression<Bool>("is_favorite")
    
    // TidalCurrentStationFavorites
    private let colCurrentBin = Expression<Int>("current_bin")
    
    // NavUnit
    private let colNavUnitId = Expression<String>("NavUnitId")
    private let colNavUnitName = Expression<String>("NavUnitName")
    private let colNavUnitIsFavorite = Expression<Bool>("IsFavorite")
    
    // Tug/Barge
    private let colVesselId = Expression<String>("VesselId")
    private let colVesselName = Expression<String>("VesselName")
    
    // Common
    private let colId = Expression<Int>("Id")
    private let colCreatedAt = Expression<Date>("CreatedAt")
    private let colModifiedAt = Expression<Date?>("ModifiedAt")
    
    // Notes
    private let colNoteText = Expression<String>("NoteText")
    
    // Change Recommendations
    private let colRecommendationText = Expression<String>("RecommendationText")
    private let colStatus = Expression<Int>("Status")
    
    // Photos
    private let colFilePath = Expression<String>("FilePath")
    private let colFileName = Expression<String>("FileName")
    private let colThumbPath = Expression<String?>("ThumbPath")
    
    // Weather Location Favorites
    private let colLatitude = Expression<Double>("Latitude")
    private let colLongitude = Expression<Double>("Longitude")
    private let colLocationName = Expression<String>("LocationName")
    
    // Moon Phases
    private let colDate = Expression<String>("Date")
    private let colPhase = Expression<String>("Phase")
    
    // MARK: - Singleton
    private static let sharedInstance = DatabaseServiceImpl()
        
    /// Provides access to the singleton instance
    static func getInstance() -> DatabaseServiceImpl {
        return sharedInstance
    }

    // MARK: - Initialization
    private init() {
        print("📊 DatabaseServiceImpl singleton being initialized")
    }

    // For testing purposes
    public convenience init(forTesting: Bool) {
        self.init()
        if forTesting {
            print("📊 Creating test instance of DatabaseServiceImpl")
        }
    }
    
    // MARK: - Connection Management
    /// Ensures connection is valid before performing operations
    private func ensureConnection() throws -> Connection {
        guard let db = connection else {
            print("❌ Database connection is nil, attempting to reinitialize")
            // Attempt to recover by initializing the database
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbPath = documentsDirectory.appendingPathComponent("SS1.db").path
            try openConnection(atPath: dbPath)
            
            // If still nil, throw error
            guard let recoveredConnection = connection else {
                throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection could not be reinitialized"])
            }
            
            return recoveredConnection
        }
        
        return db
    }
    
    /// Method to check connection health and optionally reset it
    public func checkConnectionHealth() -> Bool {
        guard let db = connection else {
            print("❌ No connection to check health for")
            return false
        }
        
        do {
            // Execute a simple query to test the connection
            let _ = try db.scalar("SELECT 1")
            return true
        } catch {
            print("❌ Connection health check failed: \(error.localizedDescription)")
            connection = nil
            return false
        }
    }

    // MARK: - TidalCurrentStationFavorite Functions

    // Check if a current station is marked as favorite
    public func isCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        do {
            let db = try ensureConnection()
            
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
    public func toggleCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        do {
            let db = try ensureConnection()
            
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
            try await flushDatabaseAsync()
            return result
        } catch {
            print("❌ TOGGLE ERROR: \(error.localizedDescription)")
            print("❌ TOGGLE ERROR DETAILS: \(error)")
            return false
        }
    }

    // Check if a current station is marked as favorite (without bin)
    public func isCurrentStationFavorite(id: String) async -> Bool {
        do {
            let db = try ensureConnection()
            
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
    public func toggleCurrentStationFavorite(id: String) async -> Bool {
        do {
            let db = try ensureConnection()
            
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
                try await flushDatabaseAsync()
                return true
            } else {
                // Get current state from first record (assuming all should be the same)
                let currentValue = records.first![colIsFavorite]
                let newValue = !currentValue
                print("📊 TOGGLE: Found \(records.count) records with favorite status: \(currentValue), toggling all to \(newValue)")
                
                // Update all records for this station
                let count = try db.run(tidalCurrentStationFavorites.filter(colStationId == id).update(colIsFavorite <- newValue))
                print("📊 TOGGLE: Updated \(count) records")
                
                try await flushDatabaseAsync()
                return newValue
            }
        } catch {
            print("❌ TOGGLE ERROR: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - TideStationFavorite Functions

    // Check if a tide station is marked as favorite
    public func isTideStationFavorite(id: String) async -> Bool {
        do {
            let db = try ensureConnection()
            
            print("📊 CHECK: Checking favorite status for tide station \(id)")
            let query = tideStationFavorites.filter(colStationId == id)
            
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

    // Toggle favorite status for a tide station
    public func toggleTideStationFavorite(id: String) async -> Bool {
        do {
            let db = try ensureConnection()
            
            print("📊 TOGGLE: Beginning toggle for tide station \(id)")
            
            // Variable to store the result outside transaction
            var result = false
            
            try db.transaction {
                let query = tideStationFavorites.filter(colStationId == id)
                
                if let favorite = try db.pluck(query) {
                    let currentValue = favorite[colIsFavorite]
                    let newValue = !currentValue
                    
                    print("📊 TOGGLE: Found existing record with favorite status: \(currentValue), toggling to \(newValue)")
                    
                    let updatedRow = tideStationFavorites.filter(colStationId == id)
                    let count = try db.run(updatedRow.update(colIsFavorite <- newValue))
                    
                    print("📊 TOGGLE: Updated record with result: \(count) rows affected")
                    result = newValue
                } else {
                    print("📊 TOGGLE: No existing record found, creating new favorite")
                    
                    let insert = tideStationFavorites.insert(
                        colStationId <- id,
                        colIsFavorite <- true
                    )
                    
                    let rowId = try db.run(insert)
                    print("📊 TOGGLE: Inserted new favorite with rowId: \(rowId)")
                    result = true
                }
            }
            
            // Force a disk flush after toggling favorites
            try await flushDatabaseAsync()
            return result
        } catch {
            print("❌ TOGGLE ERROR: \(error.localizedDescription)")
            print("❌ TOGGLE ERROR DETAILS: \(error)")
            return false
        }
    }
    
    // Method to explicitly flush database to disk
    public func flushDatabaseAsync() async throws {
        do {
            let db = try ensureConnection()
            
            print("📊 Flushing database changes to disk")
            try db.execute("PRAGMA wal_checkpoint(FULL)")
            print("📊 Database flush completed")
        } catch {
            print("❌ Error flushing database: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Table Initialization Functions

    // Initialize tide station favorites table with extensive error logging
    public func initializeTideStationFavoritesTableAsync() async throws {
        do {
            let db = try ensureConnection()
            
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
            try db.run(tideStationFavorites.create(ifNotExists: true) { table in
                table.column(colStationId, primaryKey: true)
                table.column(colIsFavorite)
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
                try db.run(tideStationFavorites.insert(or: .replace,
                    colStationId <- "TEST_INIT",
                    colIsFavorite <- true
                ))
                
                // Verify write worked
                let testQuery = tideStationFavorites.filter(colStationId == "TEST_INIT")
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

    // Initialize current station favorites table with extensive error logging
    public func initializeCurrentStationFavoritesTableAsync() async throws {
        do {
            let db = try ensureConnection()
            
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

    // Write permissions check function
    private func checkDatabaseWritePermissions() {
        do {
            let db = try ensureConnection()
            
            let testTableName = "write_test_\(Int(Date().timeIntervalSince1970))"
            
            // Try to create a temporary test table
            try db.execute("CREATE TABLE \(testTableName) (id INTEGER PRIMARY KEY, value TEXT)")
            print("✅ Successfully created test table - write permissions OK")
            
            // Insert a test row
            try db.execute("INSERT INTO \(testTableName) (value) VALUES ('test_value')")
            print("✅ Successfully inserted test row - write permissions OK")
            
            // Clean up
            try db.execute("DROP TABLE \(testTableName)")
            print("✅ Successfully dropped test table - write permissions OK")
        } catch {
            print("❌ Write permissions check failed: \(error.localizedDescription)")
        }
    }
    
    public func initializeAsync() async throws {
        if connection != nil {
            print("📊 Database connection already initialized, reusing existing connection")
            return
        }
        
        let fileManager = FileManager.default
        
        // Use Documents directory for persistent storage instead of app support
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsDirectory.appendingPathComponent("SS1.db").path
        
        print("📊 Database path: \(dbPath)")
        
        if !fileManager.fileExists(atPath: dbPath) {
            print("📊 Database not found in documents directory. Attempting to copy from resources.")
            try copyDatabaseFromBundle(to: dbPath)
            print("📊 Database successfully copied to documents directory.")
        } else {
            print("📊 Database already exists in documents directory.")
        }
        
        // Check if we have write permissions
        if fileManager.isWritableFile(atPath: dbPath) {
            print("📊 Database file is writable")
        } else {
            print("❌ Database file is not writable")
        }
        
        if fileManager.fileExists(atPath: dbPath) {
            if let attributes = try? fileManager.attributesOfItem(atPath: dbPath),
               let fileSize = attributes[.size] as? UInt64 {
                print("📊 Database file confirmed at: \(dbPath)")
                print("📊 File size: \(fileSize) bytes")
            }
        } else {
            throw NSError(domain: "DatabaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database file not found after copy attempt."])
        }
        
        try openConnection(atPath: dbPath)
        
        // Configure the connection for better performance and reliability
        if let db = connection {
            try db.execute("PRAGMA busy_timeout = 5000")
            try db.execute("PRAGMA journal_mode = WAL")
            try db.execute("PRAGMA synchronous = NORMAL")
        }
        
        // Create favorites tables if they don't exist
        try await initializeTideStationFavoritesTableAsync()
        try await initializeCurrentStationFavoritesTableAsync()
        print("📊 Tables initialized")
        
        // Test database operations to verify connection
        try await checkConnectionWithTestQuery()
        
        let tableNames = try await getTableNamesAsync()
        print("📊 Tables in the database: \(tableNames.joined(separator: ", "))")
    }
    
    private func copyDatabaseFromBundle(to path: String) throws {
        guard let bundleDBPath = Bundle.main.path(forResource: "SS1", ofType: "db") else {
            throw NSError(domain: "DatabaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Database file not found in app bundle."])
        }
        
        try FileManager.default.copyItem(atPath: bundleDBPath, toPath: path)
    }
    
    private func openConnection(atPath path: String) throws {
        do {
            connection = try Connection(path)
            print("📊 Successfully opened database connection")
        } catch {
            print("❌ Error opening database connection: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Check connection with a test query
    private func checkConnectionWithTestQuery() async throws {
        do {
            let db = try ensureConnection()
            
            print("📊 Testing database connection...")
            // Try to read a record first to check if table exists
            let testQuery = tideStationFavorites.filter(colStationId == "TEST_ID")
            if let testRecord = try? db.pluck(testQuery) {
                print("📊 Found existing test record: \(testRecord[colIsFavorite])")
            } else {
                // Insert a test record
                try db.run(tideStationFavorites.insert(
                    colStationId <- "TEST_ID",
                    colIsFavorite <- true
                ))
                print("📊 Wrote test record to database")
            
                // Verify it was written
                if let testRecord = try? db.pluck(testQuery) {
                    print("📊 Successfully read test record: \(testRecord[colIsFavorite])")
                } else {
                    print("❌ Could not read test record")
                }
            }
        } catch {
            print("❌ Test database operation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Table Names
    public func getTableNamesAsync() async throws -> [String] {
        do {
            let db = try ensureConnection()
            
            let query = "SELECT name FROM sqlite_master WHERE type='table'"
            
            var tableNames: [String] = []
            for row in try db.prepare(query) {
                if let tableName = row[0] as? String {
                    tableNames.append(tableName)
                }
            }
            print("📊 Found \(tableNames.count) tables in database")
            return tableNames
        } catch {
            print("❌ Error getting table names: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Navigation Units
    public func getNavUnitsAsync() async throws -> [NavUnit] {
        do {
            let db = try ensureConnection()
            
            let query = navUnits.order(colNavUnitName.asc)
            var results: [NavUnit] = []
            
            for row in try db.prepare(query) {
                let unit = NavUnit(
                    navUnitId: row[colNavUnitId],
                    navUnitName: row[colNavUnitName],
                    isFavorite: row[colNavUnitIsFavorite]
                )
                results.append(unit)
            }
            
            return results
        } catch {
            print("Error fetching nav units: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func toggleFavoriteNavUnitAsync(navUnitId: String) async throws -> Bool {
        do {
            let db = try ensureConnection()
            
            let query = navUnits.filter(colNavUnitId == navUnitId)
            
            guard let unit = try db.pluck(query) else {
                return false
            }
            
            let currentValue = unit[colNavUnitIsFavorite]
            let newValue = !currentValue
            
            let updatedRow = navUnits.filter(colNavUnitId == navUnitId)
            try db.run(updatedRow.update(colNavUnitIsFavorite <- newValue))
            
            // Flush changes to disk
            try await flushDatabaseAsync()
            return newValue
        } catch {
            print("Error toggling favorite: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Tugs and Barges
    public func getTugsAsync() async throws -> [Tug] {
        do {
            let db = try ensureConnection()
            
            let query = tugs.order(colVesselName.asc)
            var results: [Tug] = []
            
            for row in try db.prepare(query) {
                let tug = Tug(
                    tugId: row[colVesselId],
                    vesselName: row[colVesselName]
                )
                results.append(tug)
            }
            
            return results
        } catch {
            print("Error fetching tugs: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func getBargesAsync() async throws -> [Barge] {
        do {
            let db = try ensureConnection()
            
            let query = barges.order(colVesselName.asc)
            var results: [Barge] = []
            
            for row in try db.prepare(query) {
                let barge = Barge(
                    bargeId: row[colVesselId],
                    vesselName: row[colVesselName]
                )
                results.append(barge)
            }
            
            return results
        } catch {
            print("Error fetching barges: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Personal Notes
    public func getPersonalNotesAsync(navUnitId: String) async throws -> [PersonalNote] {
        do {
            let db = try ensureConnection()
            
            let query = personalNotes.filter(colNavUnitId == navUnitId).order(colCreatedAt.desc)
            var results: [PersonalNote] = []
            
            for row in try db.prepare(query) {
                let note = PersonalNote(
                    id: row[colId],
                    navUnitId: row[colNavUnitId],
                    noteText: row[colNoteText],
                    createdAt: row[colCreatedAt],
                    modifiedAt: row[colModifiedAt]
                )
                results.append(note)
            }
            
            return results
        } catch {
            print("Error fetching personal notes: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func addPersonalNoteAsync(note: PersonalNote) async throws -> Int {
        do {
            let db = try ensureConnection()
            
            let insert = personalNotes.insert(
                colNavUnitId <- note.navUnitId,
                colNoteText <- note.noteText,
                colCreatedAt <- Date()
            )
            
            let rowId = try db.run(insert)
            
            // Flush changes to disk
            try await flushDatabaseAsync()
            return Int(rowId)
        } catch {
            print("Error adding personal note: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func updatePersonalNoteAsync(note: PersonalNote) async throws -> Int {
        do {
            let db = try ensureConnection()
            
            let updatedRow = personalNotes.filter(colId == note.id)
            try db.run(updatedRow.update(
                colNoteText <- note.noteText,
                colModifiedAt <- Date()
            ))
            
            // Flush changes to disk
            try await flushDatabaseAsync()
            return 1
        } catch {
            print("Error updating personal note: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func deletePersonalNoteAsync(noteId: Int) async throws -> Int {
        do {
            let db = try ensureConnection()
            
            let query = personalNotes.filter(colId == noteId)
            try db.run(query.delete())
            
            // Flush changes to disk
            try await flushDatabaseAsync()
            return 1
        } catch {
            print("Error deleting personal note: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Change Recommendations
    public func getChangeRecommendationsAsync(navUnitId: String) async throws -> [ChangeRecommendation] {
            do {
                let db = try ensureConnection()
                
                let query = changeRecommendations.filter(colNavUnitId == navUnitId).order(colCreatedAt.desc)
                var results: [ChangeRecommendation] = []
                
                for row in try db.prepare(query) {
                    let statusInt = row[colStatus]
                    let status = RecommendationStatus(rawValue: statusInt) ?? .pending
                    
                    let recommendation = ChangeRecommendation(
                        id: row[colId],
                        navUnitId: row[colNavUnitId],
                        recommendationText: row[colRecommendationText],
                        createdAt: row[colCreatedAt],
                        status: status
                    )
                    results.append(recommendation)
                }
                
                return results
            } catch {
                print("Error fetching change recommendations: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func addChangeRecommendationAsync(recommendation: ChangeRecommendation) async throws -> Int {
            do {
                let db = try ensureConnection()
                
                let insert = changeRecommendations.insert(
                    colNavUnitId <- recommendation.navUnitId,
                    colRecommendationText <- recommendation.recommendationText,
                    colCreatedAt <- Date(),
                    colStatus <- RecommendationStatus.pending.rawValue
                )
                
                let rowId = try db.run(insert)
                try await flushDatabaseAsync()
                return Int(rowId)
            } catch {
                print("Error adding change recommendation: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func updateChangeRecommendationStatusAsync(recommendationId: Int, status: RecommendationStatus) async throws -> Int {
            do {
                let db = try ensureConnection()
                
                let updatedRow = changeRecommendations.filter(colId == recommendationId)
                try db.run(updatedRow.update(colStatus <- status.rawValue))
                try await flushDatabaseAsync()
                return 1
            } catch {
                print("Error updating change recommendation status: \(error.localizedDescription)")
                throw error
            }
        }
        
        // MARK: - Photos
        public func initializePhotosTableAsync() async throws {
            do {
                let db = try ensureConnection()
                
                try db.run(navUnitPhotos.create(ifNotExists: true) { table in
                    table.column(colId, primaryKey: .autoincrement)
                    table.column(colNavUnitId)
                    table.column(colFilePath)
                    table.column(colFileName)
                    table.column(colThumbPath)
                    table.column(colCreatedAt)
                })
            } catch {
                print("Error initializing photos table: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func getNavUnitPhotosAsync(navUnitId: String) async throws -> [NavUnitPhoto] {
            do {
                let db = try ensureConnection()
                
                let query = navUnitPhotos.filter(colNavUnitId == navUnitId).order(colCreatedAt.desc)
                var results: [NavUnitPhoto] = []
                
                for row in try db.prepare(query) {
                    let photo = NavUnitPhoto(
                        id: row[colId],
                        navUnitId: row[colNavUnitId],
                        filePath: row[colFilePath],
                        fileName: row[colFileName],
                        thumbPath: row[colThumbPath],
                        createdAt: row[colCreatedAt]
                    )
                    results.append(photo)
                }
                
                return results
            } catch {
                print("Error fetching nav unit photos: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func addNavUnitPhotoAsync(photo: NavUnitPhoto) async throws -> Int {
            do {
                let db = try ensureConnection()
                
                let insert = navUnitPhotos.insert(
                    colNavUnitId <- photo.navUnitId,
                    colFilePath <- photo.filePath,
                    colFileName <- photo.fileName,
                    colThumbPath <- photo.thumbPath,
                    colCreatedAt <- photo.createdAt
                )
                
                let rowId = try db.run(insert)
                try await flushDatabaseAsync()
                return Int(rowId)
            } catch {
                print("Error adding nav unit photo: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func deleteNavUnitPhotoAsync(photoId: Int) async throws -> Int {
            do {
                let db = try ensureConnection()
                
                // First get the photo to delete the file
                let photoQuery = navUnitPhotos.filter(colId == photoId)
                
                if let photo = try db.pluck(photoQuery) {
                    let filePath = photo[colFilePath]
                    
                    // Delete the file if it exists
                    if FileManager.default.fileExists(atPath: filePath) {
                        try FileManager.default.removeItem(atPath: filePath)
                    }
                    
                    // Delete the database record
                    try db.run(photoQuery.delete())
                }
                
                try await flushDatabaseAsync()
                return 1
            } catch {
                print("Error deleting tug photo: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func getTugNotesAsync(tugId: String) async throws -> [TugNote] {
            do {
                let db = try ensureConnection()
                
                let query = tugNotes.filter(colVesselId == tugId).order(colCreatedAt.desc)
                var results: [TugNote] = []
                
                for row in try db.prepare(query) {
                    let note = TugNote(
                        id: row[colId],
                        tugId: row[colVesselId],
                        noteText: row[colNoteText],
                        createdAt: row[colCreatedAt],
                        modifiedAt: row[colModifiedAt]
                    )
                    results.append(note)
                }
                
                return results
            } catch {
                print("Error fetching tug notes: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func addTugNoteAsync(note: TugNote) async throws -> Int {
            do {
                let db = try ensureConnection()
                
                let insert = tugNotes.insert(
                    colVesselId <- note.tugId,
                    colNoteText <- note.noteText,
                    colCreatedAt <- Date()
                )
                
                let rowId = try db.run(insert)
                try await flushDatabaseAsync()
                return Int(rowId)
            } catch {
                print("Error adding tug note: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func updateTugNoteAsync(note: TugNote) async throws -> Int {
            do {
                let db = try ensureConnection()
                
                let updatedRow = tugNotes.filter(colId == note.id)
                try db.run(updatedRow.update(
                    colNoteText <- note.noteText,
                    colModifiedAt <- Date()
                ))
                
                try await flushDatabaseAsync()
                return 1
            } catch {
                print("Error updating tug note: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func deleteTugNoteAsync(noteId: Int) async throws -> Int {
            do {
                let db = try ensureConnection()
                
                let query = tugNotes.filter(colId == noteId)
                try db.run(query.delete())
                try await flushDatabaseAsync()
                return 1
            } catch {
                print("Error deleting tug note: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func getTugChangeRecommendationsAsync(tugId: String) async throws -> [TugChangeRecommendation] {
            do {
                let db = try ensureConnection()
                
                let query = tugChangeRecommendations.filter(colVesselId == tugId).order(colCreatedAt.desc)
                var results: [TugChangeRecommendation] = []
                
                for row in try db.prepare(query) {
                    let statusInt = row[colStatus]
                    let status = RecommendationStatus(rawValue: statusInt) ?? .pending
                    
                    let recommendation = TugChangeRecommendation(
                        id: row[colId],
                        tugId: row[colVesselId],
                        recommendationText: row[colRecommendationText],
                        createdAt: row[colCreatedAt],
                        status: status
                    )
                    results.append(recommendation)
                }
                
                return results
            } catch {
                print("Error fetching tug change recommendations: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func addTugChangeRecommendationAsync(recommendation: TugChangeRecommendation) async throws -> Int {
            do {
                let db = try ensureConnection()
                
                let insert = tugChangeRecommendations.insert(
                    colVesselId <- recommendation.tugId,
                    colRecommendationText <- recommendation.recommendationText,
                    colCreatedAt <- Date(),
                    colStatus <- RecommendationStatus.pending.rawValue
                )
                
                let rowId = try db.run(insert)
                try await flushDatabaseAsync()
                return Int(rowId)
            } catch {
                print("Error adding tug change recommendation: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func updateTugChangeRecommendationStatusAsync(recommendationId: Int, status: RecommendationStatus) async throws -> Int {
            do {
                let db = try ensureConnection()
                
                let updatedRow = tugChangeRecommendations.filter(colId == recommendationId)
                try db.run(updatedRow.update(colStatus <- status.rawValue))
                try await flushDatabaseAsync()
                return 1
            } catch {
                print("Error updating tug change recommendation status: \(error.localizedDescription)")
                throw error
            }
        }
        
        // MARK: - Barge Photos
        public func initializeBargePhotosTableAsync() async throws {
            do {
                let db = try ensureConnection()
                
                try db.run(bargePhotos.create(ifNotExists: true) { table in
                    table.column(colId, primaryKey: .autoincrement)
                    table.column(colVesselId)
                    table.column(colFilePath)
                    table.column(colFileName)
                    table.column(colThumbPath)
                    table.column(colCreatedAt)
                })
            } catch {
                print("Error initializing barge photos table: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func getBargePhotosAsync(bargeId: String) async throws -> [BargePhoto] {
            do {
                let db = try ensureConnection()
                
                let query = bargePhotos.filter(colVesselId == bargeId).order(colCreatedAt.desc)
                var results: [BargePhoto] = []
                
                for row in try db.prepare(query) {
                    let photo = BargePhoto(
                        id: row[colId],
                        bargeId: row[colVesselId],
                        filePath: row[colFilePath],
                        fileName: row[colFileName],
                        thumbPath: row[colThumbPath],
                        createdAt: row[colCreatedAt]
                    )
                    results.append(photo)
                }
                
                return results
            } catch {
                print("Error fetching barge photos: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func addBargePhotoAsync(photo: BargePhoto) async throws -> Int {
            do {
                let db = try ensureConnection()
                
                let insert = bargePhotos.insert(
                    colVesselId <- photo.bargeId,
                    colFilePath <- photo.filePath,
                    colFileName <- photo.fileName,
                    colThumbPath <- photo.thumbPath,
                    colCreatedAt <- photo.createdAt
                )
                
                let rowId = try db.run(insert)
                try await flushDatabaseAsync()
                return Int(rowId)
            } catch {
                print("Error adding barge photo: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func deleteBargePhotoAsync(photoId: Int) async throws -> Int {
            do {
                let db = try ensureConnection()
                
                // First get the photo to delete the file
                let photoQuery = bargePhotos.filter(colId == photoId)
                
                if let photo = try db.pluck(photoQuery) {
                    let filePath = photo[colFilePath]
                    
                    // Delete the file if it exists
                    if FileManager.default.fileExists(atPath: filePath) {
                        try FileManager.default.removeItem(atPath: filePath)
                    }
                    
                    // Delete the database record
                    try db.run(photoQuery.delete())
                }
                
                try await flushDatabaseAsync()
                return 1
            } catch {
                print("Error deleting barge photo: \(error.localizedDescription)")
                throw error
            }
        }
        
        // MARK: - Buoy Station Favorites
        public func isBuoyStationFavoriteAsync(stationId: String) async -> Bool {
            do {
                let db = try ensureConnection()
                
                let query = buoyStationFavorites.filter(colStationId == stationId)
                
                if let favorite = try db.pluck(query) {
                    return favorite[colIsFavorite]
                }
                return false
            } catch {
                print("Error checking buoy station favorite: \(error.localizedDescription)")
                return false
            }
        }
        
        public func toggleBuoyStationFavoriteAsync(stationId: String) async -> Bool {
            do {
                let db = try ensureConnection()
                
                let query = buoyStationFavorites.filter(colStationId == stationId)
                
                if let favorite = try db.pluck(query) {
                    let currentValue = favorite[colIsFavorite]
                    let newValue = !currentValue
                    
                    let updatedRow = buoyStationFavorites.filter(colStationId == stationId)
                    try db.run(updatedRow.update(colIsFavorite <- newValue))
                    
                    try await flushDatabaseAsync()
                    return newValue
                } else {
                    try db.run(buoyStationFavorites.insert(
                        colStationId <- stationId,
                        colIsFavorite <- true
                    ))
                    try await flushDatabaseAsync()
                    return true
                }
            } catch {
                print("Error toggling buoy station favorite: \(error.localizedDescription)")
                return false
            }
        }
        
        // MARK: - Moon Phases
        public func getMoonPhaseForDateAsync(date: String) async throws -> MoonPhase? {
            do {
                let db = try ensureConnection()
                
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
        
        // MARK: - Weather Location Favorites
        public func initializeWeatherLocationFavoritesTableAsync() async throws {
            do {
                let db = try ensureConnection()
                
                try db.run(weatherLocationFavorites.create(ifNotExists: true) { table in
                    table.column(colLatitude)
                    table.column(colLongitude)
                    table.column(colLocationName)
                    table.column(colIsFavorite)
                    table.column(colCreatedAt)
                    table.primaryKey(colLatitude, colLongitude)
                })
            } catch {
                print("Error initializing weather location favorites table: \(error.localizedDescription)")
                throw error
            }
        }
        
        public func isWeatherLocationFavoriteAsync(latitude: Double, longitude: Double) async -> Bool {
            do {
                let db = try ensureConnection()
                
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
        
        public func toggleWeatherLocationFavoriteAsync(latitude: Double, longitude: Double, locationName: String) async -> Bool {
            do {
                let db = try ensureConnection()
                
                let query = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
                
                if let favorite = try db.pluck(query) {
                    let currentValue = favorite[colIsFavorite]
                    let newValue = !currentValue
                    
                    let updatedRow = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
                    try db.run(updatedRow.update(
                        colIsFavorite <- newValue,
                        colLocationName <- locationName
                    ))
                    
                    try await flushDatabaseAsync()
                    return newValue
                } else {
                    try db.run(weatherLocationFavorites.insert(
                        colLatitude <- latitude,
                        colLongitude <- longitude,
                        colLocationName <- locationName,
                        colIsFavorite <- true,
                        colCreatedAt <- Date()
                    ))
                    try await flushDatabaseAsync()
                    return true
                }
            } catch {
                print("Error toggling weather location favorite: \(error.localizedDescription)")
                return false
            }
        }
        
        public func getFavoriteWeatherLocationsAsync() async throws -> [WeatherLocationFavorite] {
            do {
                let db = try ensureConnection()
                
                let query = weatherLocationFavorites.filter(colIsFavorite == true).order(colCreatedAt.desc)
                var results: [WeatherLocationFavorite] = []
                
                for row in try db.prepare(query) {
                    let favorite = WeatherLocationFavorite(
                        latitude: row[colLatitude],
                        longitude: row[colLongitude],
                        locationName: row[colLocationName],
                        isFavorite: row[colIsFavorite],
                        createdAt: row[colCreatedAt]
                    )
                    results.append(favorite)
                }
                
                return results
            } catch {
                print("Error fetching favorite weather locations: \(error.localizedDescription)")
                throw error
            }
        }
    }
