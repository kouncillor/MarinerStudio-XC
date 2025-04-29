import Foundation
#if canImport(SQLite)
import SQLite
#endif

class NavUnitDatabaseService {
    // MARK: - Properties
    private let databaseCore: DatabaseCore
    
    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }
    
    // MARK: - NavUnit Methods
    
    // Get all navigation units
    func getNavUnitsAsync() async throws -> [NavUnit] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = databaseCore.navUnits.order(databaseCore.colNavUnitName.asc)
            var results: [NavUnit] = []
            
            for row in try db.prepare(query) {
                let unit = NavUnit(
                    navUnitId: row[databaseCore.colNavUnitId],
                    navUnitName: row[databaseCore.colNavUnitName],
                    isFavorite: row[databaseCore.colNavUnitIsFavorite]
                )
                results.append(unit)
            }
            
            return results
        } catch {
            print("Error fetching nav units: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Toggle favorite status for a navigation unit
    func toggleFavoriteNavUnitAsync(navUnitId: String) async throws -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = databaseCore.navUnits.filter(databaseCore.colNavUnitId == navUnitId)
            
            guard let unit = try db.pluck(query) else {
                return false
            }
            
            let currentValue = unit[databaseCore.colNavUnitIsFavorite]
            let newValue = !currentValue
            
            let updatedRow = databaseCore.navUnits.filter(databaseCore.colNavUnitId == navUnitId)
            try db.run(updatedRow.update(databaseCore.colNavUnitIsFavorite <- newValue))
            
            // Flush changes to disk
            try await databaseCore.flushDatabaseAsync()
            return newValue
        } catch {
            print("Error toggling favorite: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Personal Notes Methods
    
    // Get personal notes for a navigation unit
    func getPersonalNotesAsync(navUnitId: String) async throws -> [PersonalNote] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = databaseCore.personalNotes.filter(databaseCore.colNavUnitId == navUnitId).order(databaseCore.colCreatedAt.desc)
            var results: [PersonalNote] = []
            
            for row in try db.prepare(query) {
                let note = PersonalNote(
                    id: row[databaseCore.colId],
                    navUnitId: row[databaseCore.colNavUnitId],
                    noteText: row[databaseCore.colNoteText],
                    createdAt: row[databaseCore.colCreatedAt],
                    modifiedAt: row[databaseCore.colModifiedAt]
                )
                results.append(note)
            }
            
            return results
        } catch {
            print("Error fetching personal notes: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Add a new personal note
    func addPersonalNoteAsync(note: PersonalNote) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let insert = databaseCore.personalNotes.insert(
                databaseCore.colNavUnitId <- note.navUnitId,
                databaseCore.colNoteText <- note.noteText,
                databaseCore.colCreatedAt <- Date()
            )
            
            let rowId = try db.run(insert)
            
            // Flush changes to disk
            try await databaseCore.flushDatabaseAsync()
            return Int(rowId)
        } catch {
            print("Error adding personal note: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Update an existing personal note
    func updatePersonalNoteAsync(note: PersonalNote) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let updatedRow = databaseCore.personalNotes.filter(databaseCore.colId == note.id)
            try db.run(updatedRow.update(
                databaseCore.colNoteText <- note.noteText,
                databaseCore.colModifiedAt <- Date()
            ))
            
            // Flush changes to disk
            try await databaseCore.flushDatabaseAsync()
            return 1
        } catch {
            print("Error updating personal note: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Delete a personal note
    func deletePersonalNoteAsync(noteId: Int) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = databaseCore.personalNotes.filter(databaseCore.colId == noteId)
            try db.run(query.delete())
            
            // Flush changes to disk
            try await databaseCore.flushDatabaseAsync()
            return 1
        } catch {
            print("Error deleting personal note: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Change Recommendation Methods
    
    // Get change recommendations for a navigation unit
    func getChangeRecommendationsAsync(navUnitId: String) async throws -> [ChangeRecommendation] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = databaseCore.changeRecommendations.filter(databaseCore.colNavUnitId == navUnitId).order(databaseCore.colCreatedAt.desc)
            var results: [ChangeRecommendation] = []
            
            for row in try db.prepare(query) {
                let statusInt = row[databaseCore.colStatus]
                let status = RecommendationStatus(rawValue: statusInt) ?? .pending
                
                let recommendation = ChangeRecommendation(
                    id: row[databaseCore.colId],
                    navUnitId: row[databaseCore.colNavUnitId],
                    recommendationText: row[databaseCore.colRecommendationText],
                    createdAt: row[databaseCore.colCreatedAt],
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
    
    // Add a new change recommendation
    func addChangeRecommendationAsync(recommendation: ChangeRecommendation) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let insert = databaseCore.changeRecommendations.insert(
                databaseCore.colNavUnitId <- recommendation.navUnitId,
                databaseCore.colRecommendationText <- recommendation.recommendationText,
                databaseCore.colCreatedAt <- Date(),
                databaseCore.colStatus <- RecommendationStatus.pending.rawValue
            )
            
            let rowId = try db.run(insert)
            try await databaseCore.flushDatabaseAsync()
            return Int(rowId)
        } catch {
            print("Error adding change recommendation: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Update change recommendation status
    func updateChangeRecommendationStatusAsync(recommendationId: Int, status: RecommendationStatus) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let updatedRow = databaseCore.changeRecommendations.filter(databaseCore.colId == recommendationId)
            try db.run(updatedRow.update(databaseCore.colStatus <- status.rawValue))
            try await databaseCore.flushDatabaseAsync()
            return 1
        } catch {
            print("Error updating change recommendation status: \(error.localizedDescription)")
            throw error
        }
    }
}
