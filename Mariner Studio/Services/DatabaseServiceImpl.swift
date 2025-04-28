import Foundation
// Using conditional import to handle cases where SQLite.swift might not be available
// Make sure to add the SQLite.swift package to your project:
// Swift Package Manager: https://github.com/stephencelis/SQLite.swift.git
// Or CocoaPods: pod 'SQLite.swift', '~> 0.14.0'
#if canImport(SQLite)
import SQLite
#endif

class DatabaseServiceImpl: DatabaseService {
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
    
    // MARK: - Initialization
    public init() {}
    
    public func initializeAsync() async throws {
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
        
        // Create favorites tables if they don't exist
        try await initializeTideStationFavoritesTableAsync()
        try await initializeCurrentStationFavoritesTableAsync()
        print("📊 Tables initialized")
        
        // Test database operations
        if let db = connection {
            do {
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
            }
        }
        
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
    
    // MARK: - Table Names
    public func getTableNamesAsync() async throws -> [String] {
        guard let db = connection else {
            print("❌ Database connection not initialized when getting table names")
            return []
        }
        
        let query = "SELECT name FROM sqlite_master WHERE type='table'"
        
        do {
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
    
    // MARK: - Tide Station Favorites
    public func initializeTideStationFavoritesTableAsync() async throws {
        guard let db = connection else {
            print("❌ Database connection not initialized when initializing tide station favorites table")
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            try db.run(tideStationFavorites.create(ifNotExists: true) { table in
                table.column(colStationId, primaryKey: true)
                table.column(colIsFavorite)
            })
            print("📊 TideStationFavorites table created or already exists")
        } catch {
            print("❌ Error creating TideStationFavorites table: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func isTideStationFavorite(id: String) async -> Bool {
        guard let db = connection else {
            print("❌ Database connection not initialized when checking tide station favorite")
            return false
        }
        
        do {
            let query = tideStationFavorites.filter(colStationId == id)
            
            if let favorite = try db.pluck(query) {
                let result = favorite[colIsFavorite]
                print("📊 Found favorite status for station \(id): \(result)")
                return result
            }
            print("📊 No favorite status found for station \(id)")
            return false
        } catch {
            print("❌ Error checking tide station favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    public func toggleTideStationFavorite(id: String) async -> Bool {
        guard let db = connection else {
            print("❌ Database connection not initialized when toggling tide station favorite")
            return false
        }
        
        do {
            let query = tideStationFavorites.filter(colStationId == id)
            
            if let favorite = try db.pluck(query) {
                let currentValue = favorite[colIsFavorite]
                let newValue = !currentValue
                
                let updatedRow = tideStationFavorites.filter(colStationId == id)
                let count = try db.run(updatedRow.update(colIsFavorite <- newValue))
                
                print("📊 Updated favorite status for station \(id) to \(newValue), affected rows: \(count)")
                return newValue
            } else {
                let rowId = try db.run(tideStationFavorites.insert(
                    colStationId <- id,
                    colIsFavorite <- true
                ))
                print("📊 Inserted new favorite for station \(id), row ID: \(rowId)")
                return true
            }
        } catch {
            print("❌ Error toggling tide station favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Current Station Favorites
    public func initializeCurrentStationFavoritesTableAsync() async throws {
        guard let db = connection else {
            print("❌ Database connection not initialized when initializing current station favorites table")
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            try db.run(tidalCurrentStationFavorites.create(ifNotExists: true) { table in
                table.column(colStationId)
                table.column(colCurrentBin)
                table.column(colIsFavorite)
                table.primaryKey(colStationId, colCurrentBin)
            })
            print("📊 TidalCurrentStationFavorites table created or already exists")
        } catch {
            print("❌ Error creating TidalCurrentStationFavorites table: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func isCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        guard let db = connection else {
            print("❌ Database connection not initialized when checking current station favorite")
            return false
        }
        
        do {
            let query = tidalCurrentStationFavorites.filter(colStationId == id && colCurrentBin == bin)
            
            if let favorite = try db.pluck(query) {
                let result = favorite[colIsFavorite]
                print("📊 Found favorite status for current station \(id), bin \(bin): \(result)")
                return result
            }
            print("📊 No favorite status found for current station \(id), bin \(bin)")
            return false
        } catch {
            print("❌ Error checking current station favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    public func toggleCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        guard let db = connection else {
            print("❌ Database connection not initialized when toggling current station favorite")
            return false
        }
        
        do {
            let query = tidalCurrentStationFavorites.filter(colStationId == id && colCurrentBin == bin)
            
            if let favorite = try db.pluck(query) {
                let currentValue = favorite[colIsFavorite]
                let newValue = !currentValue
                
                let updatedRow = tidalCurrentStationFavorites.filter(colStationId == id && colCurrentBin == bin)
                let count = try db.run(updatedRow.update(colIsFavorite <- newValue))
                
                print("📊 Updated favorite status for current station \(id), bin \(bin) to \(newValue), affected rows: \(count)")
                return newValue
            } else {
                let rowId = try db.run(tidalCurrentStationFavorites.insert(
                    colStationId <- id,
                    colCurrentBin <- bin,
                    colIsFavorite <- true
                ))
                print("📊 Inserted new favorite for current station \(id), bin \(bin), row ID: \(rowId)")
                return true
            }
        } catch {
            print("❌ Error toggling current station favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    // Overloaded methods for current station without bin
    public func isCurrentStationFavorite(id: String) async -> Bool {
        return await isCurrentStationFavorite(id: id, bin: 0)
    }
    
    public func toggleCurrentStationFavorite(id: String) async -> Bool {
        return await toggleCurrentStationFavorite(id: id, bin: 0)
    }
    
    // MARK: - Navigation Units
    public func getNavUnitsAsync() async throws -> [NavUnit] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = navUnits.filter(colNavUnitId == navUnitId)
            
            guard let unit = try db.pluck(query) else {
                return false
            }
            
            let currentValue = unit[colNavUnitIsFavorite]
            let newValue = !currentValue
            
            let updatedRow = navUnits.filter(colNavUnitId == navUnitId)
            try db.run(updatedRow.update(colNavUnitIsFavorite <- newValue))
            
            return newValue
        } catch {
            print("Error toggling favorite: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Tugs and Barges
    public func getTugsAsync() async throws -> [Tug] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let insert = personalNotes.insert(
                colNavUnitId <- note.navUnitId,
                colNoteText <- note.noteText,
                colCreatedAt <- Date()
            )
            
            let rowId = try db.run(insert)
            return Int(rowId)
        } catch {
            print("Error adding personal note: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func updatePersonalNoteAsync(note: PersonalNote) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let updatedRow = personalNotes.filter(colId == note.id)
            try db.run(updatedRow.update(
                colNoteText <- note.noteText,
                colModifiedAt <- Date()
            ))
            
            return 1
        } catch {
            print("Error updating personal note: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func deletePersonalNoteAsync(noteId: Int) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = personalNotes.filter(colId == noteId)
            try db.run(query.delete())
            return 1
        } catch {
            print("Error deleting personal note: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Change Recommendations
    public func getChangeRecommendationsAsync(navUnitId: String) async throws -> [ChangeRecommendation] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let insert = changeRecommendations.insert(
                colNavUnitId <- recommendation.navUnitId,
                colRecommendationText <- recommendation.recommendationText,
                colCreatedAt <- Date(),
                colStatus <- RecommendationStatus.pending.rawValue
            )
            
            let rowId = try db.run(insert)
            return Int(rowId)
        } catch {
            print("Error adding change recommendation: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func updateChangeRecommendationStatusAsync(recommendationId: Int, status: RecommendationStatus) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let updatedRow = changeRecommendations.filter(colId == recommendationId)
            try db.run(updatedRow.update(colStatus <- status.rawValue))
            return 1
        } catch {
            print("Error updating change recommendation status: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Photos
    public func initializePhotosTableAsync() async throws {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        try db.run(navUnitPhotos.create(ifNotExists: true) { table in
            table.column(colId, primaryKey: .autoincrement)
            table.column(colNavUnitId)
            table.column(colFilePath)
            table.column(colFileName)
            table.column(colThumbPath)
            table.column(colCreatedAt)
        })
    }
    
    public func getNavUnitPhotosAsync(navUnitId: String) async throws -> [NavUnitPhoto] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let insert = navUnitPhotos.insert(
                colNavUnitId <- photo.navUnitId,
                colFilePath <- photo.filePath,
                colFileName <- photo.fileName,
                colThumbPath <- photo.thumbPath,
                colCreatedAt <- photo.createdAt
            )
            
            let rowId = try db.run(insert)
            return Int(rowId)
        } catch {
            print("Error adding nav unit photo: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func deleteNavUnitPhotoAsync(photoId: Int) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
            
            return 1
        } catch {
            print("Error deleting tug photo: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func getTugNotesAsync(tugId: String) async throws -> [TugNote] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let insert = tugNotes.insert(
                colVesselId <- note.tugId,
                colNoteText <- note.noteText,
                colCreatedAt <- Date()
            )
            
            let rowId = try db.run(insert)
            return Int(rowId)
        } catch {
            print("Error adding tug note: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func updateTugNoteAsync(note: TugNote) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let updatedRow = tugNotes.filter(colId == note.id)
            try db.run(updatedRow.update(
                colNoteText <- note.noteText,
                colModifiedAt <- Date()
            ))
            
            return 1
        } catch {
            print("Error updating tug note: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func deleteTugNoteAsync(noteId: Int) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = tugNotes.filter(colId == noteId)
            try db.run(query.delete())
            return 1
        } catch {
            print("Error deleting tug note: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func getTugChangeRecommendationsAsync(tugId: String) async throws -> [TugChangeRecommendation] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let insert = tugChangeRecommendations.insert(
                colVesselId <- recommendation.tugId,
                colRecommendationText <- recommendation.recommendationText,
                colCreatedAt <- Date(),
                colStatus <- RecommendationStatus.pending.rawValue
            )
            
            let rowId = try db.run(insert)
            return Int(rowId)
        } catch {
            print("Error adding tug change recommendation: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func updateTugChangeRecommendationStatusAsync(recommendationId: Int, status: RecommendationStatus) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let updatedRow = tugChangeRecommendations.filter(colId == recommendationId)
            try db.run(updatedRow.update(colStatus <- status.rawValue))
            return 1
        } catch {
            print("Error updating tug change recommendation status: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Barge Photos
    public func initializeBargePhotosTableAsync() async throws {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        try db.run(bargePhotos.create(ifNotExists: true) { table in
            table.column(colId, primaryKey: .autoincrement)
            table.column(colVesselId)
            table.column(colFilePath)
            table.column(colFileName)
            table.column(colThumbPath)
            table.column(colCreatedAt)
        })
    }
    
    public func getBargePhotosAsync(bargeId: String) async throws -> [BargePhoto] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let insert = bargePhotos.insert(
                colVesselId <- photo.bargeId,
                colFilePath <- photo.filePath,
                colFileName <- photo.fileName,
                colThumbPath <- photo.thumbPath,
                colCreatedAt <- photo.createdAt
            )
            
            let rowId = try db.run(insert)
            return Int(rowId)
        } catch {
            print("Error adding barge photo: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func deleteBargePhotoAsync(photoId: Int) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
            
            return 1
        } catch {
            print("Error deleting barge photo: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Buoy Station Favorites
    public func isBuoyStationFavoriteAsync(stationId: String) async -> Bool {
        guard let db = connection else {
            print("Database connection not initialized")
            return false
        }
        
        do {
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
        guard let db = connection else {
            print("Database connection not initialized")
            return false
        }
        
        do {
            let query = buoyStationFavorites.filter(colStationId == stationId)
            
            if let favorite = try db.pluck(query) {
                let currentValue = favorite[colIsFavorite]
                let newValue = !currentValue
                
                let updatedRow = buoyStationFavorites.filter(colStationId == stationId)
                try db.run(updatedRow.update(colIsFavorite <- newValue))
                
                return newValue
            } else {
                try db.run(buoyStationFavorites.insert(
                    colStationId <- stationId,
                    colIsFavorite <- true
                ))
                return true
            }
        } catch {
            print("Error toggling buoy station favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Moon Phases
    public func getMoonPhaseForDateAsync(date: String) async throws -> MoonPhase? {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        try db.run(weatherLocationFavorites.create(ifNotExists: true) { table in
            table.column(colLatitude)
            table.column(colLongitude)
            table.column(colLocationName)
            table.column(colIsFavorite)
            table.column(colCreatedAt)
            table.primaryKey(colLatitude, colLongitude)
        })
    }
    
    public func isWeatherLocationFavoriteAsync(latitude: Double, longitude: Double) async -> Bool {
        guard let db = connection else {
            print("Database connection not initialized")
            return false
        }
        
        do {
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
        guard let db = connection else {
            print("Database connection not initialized")
            return false
        }
        
        do {
            let query = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
            
            if let favorite = try db.pluck(query) {
                let currentValue = favorite[colIsFavorite]
                let newValue = !currentValue
                
                let updatedRow = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
                try db.run(updatedRow.update(
                    colIsFavorite <- newValue,
                    colLocationName <- locationName
                ))
                
                return newValue
            } else {
                try db.run(weatherLocationFavorites.insert(
                    colLatitude <- latitude,
                    colLongitude <- longitude,
                    colLocationName <- locationName,
                    colIsFavorite <- true,
                    colCreatedAt <- Date()
                ))
                return true
            }
        } catch {
            print("Error toggling weather location favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    public func getFavoriteWeatherLocationsAsync() async throws -> [WeatherLocationFavorite] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
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
