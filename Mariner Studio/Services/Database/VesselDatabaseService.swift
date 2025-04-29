import Foundation
#if canImport(SQLite)
import SQLite
#endif

class VesselDatabaseService {
    // MARK: - Properties
    private let databaseCore: DatabaseCore
    
    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }
    
    // MARK: - Tug Methods
    
    // Get all tugs
    func getTugsAsync() async throws -> [Tug] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = databaseCore.tugs.order(databaseCore.colVesselName.asc)
            var results: [Tug] = []
            
            for row in try db.prepare(query) {
                let tug = Tug(
                    tugId: row[databaseCore.colVesselId],
                    vesselName: row[databaseCore.colVesselName]
                )
                results.append(tug)
            }
            
            return results
        } catch {
            print("Error fetching tugs: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Get tug notes
    func getTugNotesAsync(tugId: String) async throws -> [TugNote] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = databaseCore.tugNotes.filter(databaseCore.colVesselId == tugId).order(databaseCore.colCreatedAt.desc)
            var results: [TugNote] = []
            
            for row in try db.prepare(query) {
                let note = TugNote(
                    id: row[databaseCore.colId],
                    tugId: row[databaseCore.colVesselId],
                    noteText: row[databaseCore.colNoteText],
                    createdAt: row[databaseCore.colCreatedAt],
                    modifiedAt: row[databaseCore.colModifiedAt]
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
            
            let insert = databaseCore.tugNotes.insert(
                databaseCore.colVesselId <- note.tugId,
                databaseCore.colNoteText <- note.noteText,
                databaseCore.colCreatedAt <- Date()
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
            
            let updatedRow = databaseCore.tugNotes.filter(databaseCore.colId == note.id)
            try db.run(updatedRow.update(
                databaseCore.colNoteText <- note.noteText,
                databaseCore.colModifiedAt <- Date()
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
            
            let query = databaseCore.tugNotes.filter(databaseCore.colId == noteId)
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
            
            let query = databaseCore.tugChangeRecommendations.filter(databaseCore.colVesselId == tugId).order(databaseCore.colCreatedAt.desc)
            var results: [TugChangeRecommendation] = []
            
            for row in try db.prepare(query) {
                let statusInt = row[databaseCore.colStatus]
                let status = RecommendationStatus(rawValue: statusInt) ?? .pending
                
                let recommendation = TugChangeRecommendation(
                    id: row[databaseCore.colId],
                    tugId: row[databaseCore.colVesselId],
                    recommendationText: row[databaseCore.colRecommendationText],
                    createdAt: row[databaseCore.colCreatedAt],
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
            
            let insert = databaseCore.tugChangeRecommendations.insert(
                databaseCore.colVesselId <- recommendation.tugId,
                databaseCore.colRecommendationText <- recommendation.recommendationText,
                databaseCore.colCreatedAt <- Date(),
                databaseCore.colStatus <- RecommendationStatus.pending.rawValue
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
            
            let updatedRow = databaseCore.tugChangeRecommendations.filter(databaseCore.colId == recommendationId)
            try db.run(updatedRow.update(databaseCore.colStatus <- status.rawValue))
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
            
            let query = databaseCore.barges.order(databaseCore.colVesselName.asc)
            var results: [Barge] = []
            
            for row in try db.prepare(query) {
                let barge = Barge(
                    bargeId: row[databaseCore.colVesselId],
                    vesselName: row[databaseCore.colVesselName]
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
