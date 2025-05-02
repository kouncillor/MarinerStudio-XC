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

            // REMOVED the 'let columns = [...]' array definition

            // This query implicitly selects all columns defined for the 'navUnits' table
            let query = databaseCore.navUnits.order(databaseCore.colNavUnitName.asc)

            var results: [NavUnit] = []
            var count = 0 // Counter for logging

            print(" S NavUnitDatabaseService: Starting fetch...") // Add start log

            for row in try db.prepare(query) {

                // *** Log Raw Values ***
                let latValue = row[databaseCore.colLatitude]
                let lonValue = row[databaseCore.colLongitude]
                let unitId = row[databaseCore.colNavUnitId] // Get ID for context
                if count < 10 { // Log first 10
                    print(" S NavUnitDB (\(count)): ID \(unitId) - Raw Lat: \(String(describing: latValue)), Raw Lon: \(String(describing: lonValue))")
                }
                // **********************

                // Construct the NavUnit using the full initializer
                // Ensure mappings here are correct based on DatabaseCore definitions
                let unit = NavUnit(
                    navUnitId: row[databaseCore.colNavUnitId],
                    navUnitName: row[databaseCore.colNavUnitName] ?? "N/A",
                    // ... map ALL other necessary NavUnit properties from 'row' ...
                    // Make sure DatabaseCore defines Expressions for all needed columns.
                    // Example: facilityType: row[databaseCore.colFacilityType],
                    latitude: latValue, // Use the logged value
                    longitude: lonValue, // Use the logged value
                    // ... map other properties ...
                    isFavorite: row[databaseCore.colNavUnitIsFavorite] // Assuming non-optional Bool
                )
                results.append(unit)
                count += 1 // Increment counter
            }

            print(" S NavUnitDatabaseService: Fetched \(results.count) units.") // Add end log
            return results
        } catch {
            print(" S NavUnitDatabaseService: Error fetching nav units: \(error.localizedDescription)")
            throw error
        }
    }

    
    
    
    
    
    
    
    // Add this method within the NavUnitDatabaseService class in
    // MarinerStudio-XC/Mariner Studio/Services/Database/NavUnitDatabaseService.swift

        // Toggle favorite status for a navigation unit
        func toggleFavoriteNavUnitAsync(navUnitId: String) async throws -> Bool {
            do {
                let db = try databaseCore.ensureConnection()

                // Find the specific NavUnit row
                let query = databaseCore.navUnits.filter(databaseCore.colNavUnitId == navUnitId)

                // Try to get the current unit's favorite status
                guard let unit = try db.pluck(query) else {
                    // If the unit doesn't exist in the table for some reason, throw an error or return false
                    print(" S NavUnitDatabaseService: Error toggling favorite - NavUnit \(navUnitId) not found.")
                    // Depending on desired behavior, you might throw an error:
                     throw NSError(domain: "DatabaseService", code: 10, userInfo: [NSLocalizedDescriptionKey: "NavUnit not found for toggling favorite."])
                    // Or simply return false if non-existence implies not favorited:
                    // return false
                }

                let currentValue = unit[databaseCore.colNavUnitIsFavorite]
                let newValue = !currentValue // Toggle the boolean value

                print(" S NavUnitDatabaseService: Toggling favorite for \(navUnitId) from \(currentValue) to \(newValue)")

                // Prepare the update statement
                let updatedRow = databaseCore.navUnits.filter(databaseCore.colNavUnitId == navUnitId)
                // Execute the update
                try db.run(updatedRow.update(databaseCore.colNavUnitIsFavorite <- newValue))

                // Flush changes to disk
                try await databaseCore.flushDatabaseAsync()
                print(" S NavUnitDatabaseService: Favorite status updated successfully for \(navUnitId). New status: \(newValue)")
                return newValue // Return the new status
            } catch {
                print(" S NavUnitDatabaseService: Error toggling favorite for NavUnit \(navUnitId): \(error.localizedDescription)")
                throw error // Re-throw the error to be handled by the caller (e.g., the ViewModel)
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
            let affectedRows = try db.run(updatedRow.update(
                databaseCore.colNoteText <- note.noteText,
                databaseCore.colModifiedAt <- Date()
            ))
            try await databaseCore.flushDatabaseAsync()
            return affectedRows
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
            let affectedRows = try db.run(query.delete())
            try await databaseCore.flushDatabaseAsync()
            return affectedRows
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
            let affectedRows = try db.run(updatedRow.update(databaseCore.colStatus <- status.rawValue))
            try await databaseCore.flushDatabaseAsync()
            return affectedRows
        } catch {
            print("Error updating change recommendation status: \(error.localizedDescription)")
            throw error
        }
    }
}
