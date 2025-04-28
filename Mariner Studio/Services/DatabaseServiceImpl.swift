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
        let appSupportDir = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dbPath = appSupportDir.appendingPathComponent("SS1.db").path
        
        if !fileManager.fileExists(atPath: dbPath) {
            print("Database not found in app support directory. Attempting to copy from resources.")
            try copyDatabaseFromBundle(to: dbPath)
            print("Database successfully copied to app support directory.")
        } else {
            print("Database already exists in app support directory.")
        }
        
        if fileManager.fileExists(atPath: dbPath) {
            if let attributes = try? fileManager.attributesOfItem(atPath: dbPath),
               let fileSize = attributes[.size] as? UInt64 {
                print("Database file confirmed at: \(dbPath)")
                print("File size: \(fileSize) bytes")
            }
        } else {
            throw NSError(domain: "DatabaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database file not found after copy attempt."])
        }
        
        try openConnection(atPath: dbPath)
        
        let tableNames = try await getTableNamesAsync()
        print("Tables in the database: \(tableNames.joined(separator: ", "))")
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
        } catch {
            print("Error opening database connection: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Table Names
    public func getTableNamesAsync() async throws -> [String] {
        guard let db = connection else {
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
            return tableNames
        } catch {
            print("Error getting table names: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Tide Station Favorites
    public func initializeTideStationFavoritesTableAsync() async throws {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        try db.run(tideStationFavorites.create(ifNotExists: true) { table in
            table.column(colStationId, primaryKey: true)
            table.column(colIsFavorite)
        })
    }
    
    public func isTideStationFavorite(id: String) async -> Bool {
        guard let db = connection else {
            print("Database connection not initialized")
            return false
        }
        
        do {
            let query = tideStationFavorites.filter(colStationId == id)
            
            if let favorite = try db.pluck(query) {
                return favorite[colIsFavorite]
            }
            return false
        } catch {
            print("Error checking tide station favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    public func toggleTideStationFavorite(id: String) async -> Bool {
        guard let db = connection else {
            print("Database connection not initialized")
            return false
        }
        
        do {
            let query = tideStationFavorites.filter(colStationId == id)
            
            if let favorite = try db.pluck(query) {
                let currentValue = favorite[colIsFavorite]
                let newValue = !currentValue
                
                let updatedRow = tideStationFavorites.filter(colStationId == id)
                try db.run(updatedRow.update(colIsFavorite <- newValue))
                
                return newValue
            } else {
                try db.run(tideStationFavorites.insert(
                    colStationId <- id,
                    colIsFavorite <- true
                ))
                return true
            }
        } catch {
            print("Error toggling tide station favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Current Station Favorites
    public func initializeCurrentStationFavoritesTableAsync() async throws {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        try db.run(tidalCurrentStationFavorites.create(ifNotExists: true) { table in
            table.column(colStationId)
            table.column(colCurrentBin)
            table.column(colIsFavorite)
            table.primaryKey(colStationId, colCurrentBin)
        })
    }
    
    public func isCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        guard let db = connection else {
            print("Database connection not initialized")
            return false
        }
        
        do {
            let query = tidalCurrentStationFavorites.filter(colStationId == id && colCurrentBin == bin)
            
            if let favorite = try db.pluck(query) {
                return favorite[colIsFavorite]
            }
            return false
        } catch {
            print("Error checking current station favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    public func toggleCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        guard let db = connection else {
            print("Database connection not initialized")
            return false
        }
        
        do {
            let query = tidalCurrentStationFavorites.filter(colStationId == id && colCurrentBin == bin)
            
            if let favorite = try db.pluck(query) {
                let currentValue = favorite[colIsFavorite]
                let newValue = !currentValue
                
                let updatedRow = tidalCurrentStationFavorites.filter(colStationId == id && colCurrentBin == bin)
                try db.run(updatedRow.update(colIsFavorite <- newValue))
                
                return newValue
            } else {
                try db.run(tidalCurrentStationFavorites.insert(
                    colStationId <- id,
                    colCurrentBin <- bin,
                    colIsFavorite <- true
                ))
                return true
            }
        } catch {
            print("Error toggling current station favorite: \(error.localizedDescription)")
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
    
    public func toggleFavoriteNavUnitAsync(navUnitId id: String) async throws -> Bool {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = navUnits.filter(colNavUnitId == id)
            
            guard let unit = try db.pluck(query) else {
                return false
            }
            
            let currentValue = try unit.get(colNavUnitIsFavorite)
            let newValue = !currentValue
            
            let updatedRow = navUnits.filter(colNavUnitId == id)
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
                    tugId: try row.get(colVesselId),
                    vesselName: try row.get(colVesselName)
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
                    bargeId: try row.get(colVesselId),
                    vesselName: try row.get(colVesselName)
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
    public func getPersonalNotesAsync(navUnitId id: String) async throws -> [PersonalNote] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = personalNotes.filter(colNavUnitId == id).order(colCreatedAt.desc)
            var results: [PersonalNote] = []
            
            for row in try db.prepare(query) {
                let note = PersonalNote(
                    id: try row.get(colId),
                    navUnitId: try row.get(colNavUnitId),
                    noteText: try row.get(colNoteText),
                    createdAt: try row.get(colCreatedAt),
                    modifiedAt: try row.get(colModifiedAt)
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
    
    public func deletePersonalNoteAsync(noteId id: Int) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = personalNotes.filter(colId == id)
            try db.run(query.delete())
            return 1
        } catch {
            print("Error deleting personal note: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Change Recommendations
    public func getChangeRecommendationsAsync(navUnitId id: String) async throws -> [ChangeRecommendation] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = changeRecommendations.filter(colNavUnitId == id).order(colCreatedAt.desc)
            var results: [ChangeRecommendation] = []
            
            for row in try db.prepare(query) {
                let statusInt = try row.get(colStatus)
                let status = RecommendationStatus(rawValue: statusInt) ?? .pending
                
                let recommendation = ChangeRecommendation(
                    id: try row.get(colId),
                    navUnitId: try row.get(colNavUnitId),
                    recommendationText: try row.get(colRecommendationText),
                    createdAt: try row.get(colCreatedAt),
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
    
    public func getNavUnitPhotosAsync(navUnitId id: String) async throws -> [NavUnitPhoto] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = navUnitPhotos.filter(colNavUnitId == id).order(colCreatedAt.desc)
            var results: [NavUnitPhoto] = []
            
            for row in try db.prepare(query) {
                let photo = NavUnitPhoto(
                    id: try row.get(colId),
                    navUnitId: try row.get(colNavUnitId),
                    filePath: try row.get(colFilePath),
                    fileName: try row.get(colFileName),
                    thumbPath: try row.get(colThumbPath),
                    createdAt: try row.get(colCreatedAt)
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
    
    public func deleteNavUnitPhotoAsync(photoId id: Int) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            // First get the photo to delete the file
            let photoQuery = navUnitPhotos.filter(colId == id)
            
            if let photo = try db.pluck(photoQuery) {
                let filePath = try photo.get(colFilePath)
                
                // Delete the file if it exists
                if FileManager.default.fileExists(atPath: filePath) {
                    try FileManager.default.removeItem(atPath: filePath)
                }
                
                // Delete the database record
                try db.run(photoQuery.delete())
            }
            
            return 1
        } catch {
            print("Error deleting nav unit photo: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Tug Operations
    public func initializeTugTablesAsync() async throws {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        try db.run(tugPhotos.create(ifNotExists: true) { table in
            table.column(colId, primaryKey: .autoincrement)
            table.column(colVesselId)
            table.column(colFilePath)
            table.column(colFileName)
            table.column(colThumbPath)
            table.column(colCreatedAt)
        })
        
        try db.run(tugNotes.create(ifNotExists: true) { table in
            table.column(colId, primaryKey: .autoincrement)
            table.column(colVesselId)
            table.column(colNoteText)
            table.column(colCreatedAt)
            table.column(colModifiedAt)
        })
        
        try db.run(tugChangeRecommendations.create(ifNotExists: true) { table in
            table.column(colId, primaryKey: .autoincrement)
            table.column(colVesselId)
            table.column(colRecommendationText)
            table.column(colCreatedAt)
            table.column(colStatus)
        })
    }
    
    public func getTugPhotosAsync(tugId id: String) async throws -> [TugPhoto] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = tugPhotos.filter(colVesselId == id).order(colCreatedAt.desc)
            var results: [TugPhoto] = []
            
            for row in try db.prepare(query) {
                let photo = TugPhoto(
                    id: try row.get(colId),
                    tugId: try row.get(colVesselId),
                    filePath: try row.get(colFilePath),
                    fileName: try row.get(colFileName),
                    thumbPath: try row.get(colThumbPath),
                    createdAt: try row.get(colCreatedAt)
                )
                results.append(photo)
            }
            
            return results
        } catch {
            print("Error fetching tug photos: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func addTugPhotoAsync(photo: TugPhoto) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let insert = tugPhotos.insert(
                colVesselId <- photo.tugId,
                colFilePath <- photo.filePath,
                colFileName <- photo.fileName,
                colThumbPath <- photo.thumbPath,
                colCreatedAt <- photo.createdAt
            )
            
            let rowId = try db.run(insert)
            return Int(rowId)
        } catch {
            print("Error adding tug photo: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func deleteTugPhotoAsync(photoId id: Int) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            // First get the photo to delete the file
            let photoQuery = tugPhotos.filter(colId == id)
            
            if let photo = try db.pluck(photoQuery) {
                let filePath = try photo.get(colFilePath)
                
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
    
    public func getTugNotesAsync(tugId id: String) async throws -> [TugNote] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = tugNotes.filter(colVesselId == id).order(colCreatedAt.desc)
            var results: [TugNote] = []
            
            for row in try db.prepare(query) {
                let note = TugNote(
                    id: try row.get(colId),
                    tugId: try row.get(colVesselId),
                    noteText: try row.get(colNoteText),
                    createdAt: try row.get(colCreatedAt),
                    modifiedAt: try row.get(colModifiedAt)
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
    
    public func deleteTugNoteAsync(noteId id: Int) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = tugNotes.filter(colId == id)
            try db.run(query.delete())
            return 1
        } catch {
            print("Error deleting tug note: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func getTugChangeRecommendationsAsync(tugId id: String) async throws -> [TugChangeRecommendation] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = tugChangeRecommendations.filter(colVesselId == id).order(colCreatedAt.desc)
            var results: [TugChangeRecommendation] = []
            
            for row in try db.prepare(query) {
                let statusInt = try row.get(colStatus)
                let status = RecommendationStatus(rawValue: statusInt) ?? .pending
                
                let recommendation = TugChangeRecommendation(
                    id: try row.get(colId),
                    tugId: try row.get(colVesselId),
                    recommendationText: try row.get(colRecommendationText),
                    createdAt: try row.get(colCreatedAt),
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
    
    public func getBargePhotosAsync(bargeId id: String) async throws -> [BargePhoto] {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            let query = bargePhotos.filter(colVesselId == id).order(colCreatedAt.desc)
            var results: [BargePhoto] = []
            
            for row in try db.prepare(query) {
                let photo = BargePhoto(
                    id: try row.get(colId),
                    bargeId: try row.get(colVesselId),
                    filePath: try row.get(colFilePath),
                    fileName: try row.get(colFileName),
                    thumbPath: try row.get(colThumbPath),
                    createdAt: try row.get(colCreatedAt)
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
    
    public func deleteBargePhotoAsync(photoId id: Int) async throws -> Int {
        guard let db = connection else {
            throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection not initialized"])
        }
        
        do {
            // First get the photo to delete the file
            let photoQuery = bargePhotos.filter(colId == id)
            
            if let photo = try db.pluck(photoQuery) {
                let filePath = try photo.get(colFilePath)
                
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
    public func isBuoyStationFavoriteAsync(stationId id: String) async -> Bool {
        guard let db = connection else {
            print("Database connection not initialized")
            return false
        }
        
        do {
            let query = buoyStationFavorites.filter(colStationId == id)
            
            if let favorite = try db.pluck(query) {
                return try favorite.get(colIsFavorite)
            }
            return false
        } catch {
            print("Error checking buoy station favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    public func toggleBuoyStationFavoriteAsync(stationId id: String) async -> Bool {
        guard let db = connection else {
            print("Database connection not initialized")
            return false
        }
        
        do {
            let query = buoyStationFavorites.filter(colStationId == id)
            
            if let favorite = try db.pluck(query) {
                let currentValue = try favorite.get(colIsFavorite)
                let newValue = !currentValue
                
                let updatedRow = buoyStationFavorites.filter(colStationId == id)
                try db.run(updatedRow.update(colIsFavorite <- newValue))
                
                return newValue
            } else {
                try db.run(buoyStationFavorites.insert(
                    colStationId <- id,
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
                    date: try row.get(colDate),
                    phase: try row.get(colPhase)
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
    
    public func isWeatherLocationFavoriteAsync(latitude lat: Double, longitude lon: Double) async -> Bool {
        guard let db = connection else {
            print("Database connection not initialized")
            return false
        }
        
        do {
            let query = weatherLocationFavorites.filter(colLatitude == lat && colLongitude == lon)
            
            if let favorite = try db.pluck(query) {
                return try favorite.get(colIsFavorite)
            }
            return false
        } catch {
            print("Error checking weather location favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    public func toggleWeatherLocationFavoriteAsync(latitude lat: Double, longitude lon: Double, locationName name: String) async -> Bool {
        guard let db = connection else {
            print("Database connection not initialized")
            return false
        }
        
        do {
            let query = weatherLocationFavorites.filter(colLatitude == lat && colLongitude == lon)
            
            if let favorite = try db.pluck(query) {
                let currentValue = try favorite.get(colIsFavorite)
                let newValue = !currentValue
                
                let updatedRow = weatherLocationFavorites.filter(colLatitude == lat && colLongitude == lon)
                try db.run(updatedRow.update(
                    colIsFavorite <- newValue,
                    colLocationName <- name
                ))
                
                return newValue
            } else {
                try db.run(weatherLocationFavorites.insert(
                    colLatitude <- lat,
                    colLongitude <- lon,
                    colLocationName <- name,
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
                    latitude: try row.get(colLatitude),
                    longitude: try row.get(colLongitude),
                    locationName: try row.get(colLocationName),
                    isFavorite: try row.get(colIsFavorite),
                    createdAt: try row.get(colCreatedAt)
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
