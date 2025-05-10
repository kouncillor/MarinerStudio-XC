import Foundation
#if canImport(SQLite)
import SQLite
#endif

class VesselDatabaseService {
    // MARK: - Table Definitions
    private let tugs = Table("TUGS")
    private let tugNotes = Table("TugNotes")
    private let tugChangeRecommendations = Table("TugChangeRecommendations")
    private let barges = Table("BARGES")
    
    // MARK: - Column Definitions - Common for notes/recommendations
    private let colId = Expression<Int>("Id")
    private let colVesselId = Expression<String>("VesselId")  // Used in notes/recommendations tables
    private let colCreatedAt = Expression<Date>("CreatedAt")
    private let colModifiedAt = Expression<Date?>("ModifiedAt")
    
    // MARK: - Column Definitions - TUGS table
    private let colTugId = Expression<String>("TUG_ID")
    private let colVesselName = Expression<String>("VS_NAME")
    private let colVesselNumber = Expression<String?>("VS_NUMBER")
    private let colCgNumber = Expression<String?>("CG_NUMBER")
    private let colHorsepower = Expression<String?>("HP")
    private let colState = Expression<String?>("STATE")
    private let colBasePort1 = Expression<String?>("BASE1")
    private let colBasePort2 = Expression<String?>("BASE2")
    private let colOperator = Expression<String?>("TS_OPER")
    private let colOverallLength = Expression<String?>("OVER_LNGTH")
    
    // MARK: - Column Definitions - Notes
    private let colNoteText = Expression<String>("NoteText")
    
    // MARK: - Column Definitions - Change Recommendations
    private let colRecommendationText = Expression<String>("RecommendationText")
    private let colStatus = Expression<Int>("Status")
    
    // MARK: - Properties
    private let databaseCore: DatabaseCore
    
    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }
    
    // MARK: - Tug Methods
    
    // Get all tugs - Updated to use correct column names
    func getTugsAsync() async throws -> [Tug] {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 VesselDatabaseService: Fetching tugs from database")
            
            let query = tugs.order(colVesselName.asc)
            print("📊 VesselDatabaseService: Executing query on TUGS table")
            
            var results: [Tug] = []
            
            for row in try db.prepare(query) {
                // Create an enhanced Tug model with additional properties
                let tug = Tug(
                    tugId: row[colTugId],
                    vesselName: row[colVesselName]
                )
                results.append(tug)
            }
            
            print("📊 VesselDatabaseService: Successfully fetched \(results.count) tugs")
            return results
        } catch {
            print("Error fetching tugs: \(error.localizedDescription)")
            print("Error details: \(error)")
            throw error
        }
    }
    
    // Get tug notes
    func getTugNotesAsync(tugId: String) async throws -> [TugNote] {
        do {
            let db = try databaseCore.ensureConnection()
            
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
    
    // Add tug note
    func addTugNoteAsync(note: TugNote) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let insert = tugNotes.insert(
                colVesselId <- note.tugId,
                colNoteText <- note.noteText,
                colCreatedAt <- Date()
            )
            
            let rowId = try db.run(insert)
            try await databaseCore.flushDatabaseAsync()
            return Int(rowId)
        } catch {
            print("Error adding tug note: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Update tug note
    func updateTugNoteAsync(note: TugNote) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let updatedRow = tugNotes.filter(colId == note.id)
            try db.run(updatedRow.update(
                colNoteText <- note.noteText,
                colModifiedAt <- Date()
            ))
            
            try await databaseCore.flushDatabaseAsync()
            return 1
        } catch {
            print("Error updating tug note: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Delete tug note
    func deleteTugNoteAsync(noteId: Int) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = tugNotes.filter(colId == noteId)
            try db.run(query.delete())
            try await databaseCore.flushDatabaseAsync()
            return 1
        } catch {
            print("Error deleting tug note: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Get tug change recommendations
    func getTugChangeRecommendationsAsync(tugId: String) async throws -> [TugChangeRecommendation] {
        do {
            let db = try databaseCore.ensureConnection()
            
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
    
    // Add tug change recommendation
    func addTugChangeRecommendationAsync(recommendation: TugChangeRecommendation) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let insert = tugChangeRecommendations.insert(
                colVesselId <- recommendation.tugId,
                colRecommendationText <- recommendation.recommendationText,
                colCreatedAt <- Date(),
                colStatus <- RecommendationStatus.pending.rawValue
            )
            
            let rowId = try db.run(insert)
            try await databaseCore.flushDatabaseAsync()
            return Int(rowId)
        } catch {
            print("Error adding tug change recommendation: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Update tug change recommendation status
    func updateTugChangeRecommendationStatusAsync(recommendationId: Int, status: RecommendationStatus) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let updatedRow = tugChangeRecommendations.filter(colId == recommendationId)
            try db.run(updatedRow.update(colStatus <- status.rawValue))
            try await databaseCore.flushDatabaseAsync()
            return 1
        } catch {
            print("Error updating tug change recommendation status: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Barge Methods
    
    // Get all barges
    func getBargesAsync() async throws -> [Barge] {
        do {
            let db = try databaseCore.ensureConnection()
            
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
}
