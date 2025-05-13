import Foundation
#if canImport(SQLite)
import SQLite
#endif

class NavUnitDatabaseService {
    // MARK: - Table Definitions
    private let navUnits = Table("NavUnits")
    private let personalNotes = Table("PersonalNote")
    private let changeRecommendations = Table("ChangeRecommendation")
    
    // MARK: - Column Definitions - NavUnits
    private let colNavUnitId = Expression<String>("NAV_UNIT_ID")
    private let colUnloCode = Expression<String?>("UNLOCODE")
    private let colNavUnitName = Expression<String>("NAV_UNIT_NAME")
    private let colLocationDescription = Expression<String?>("LOCATION_DESCRIPTION")
    private let colFacilityType = Expression<String?>("FACILITY_TYPE")
    private let colStreetAddress = Expression<String?>("STREET_ADDRESS")
    private let colCityOrTown = Expression<String?>("CITY_OR_TOWN")
    private let colStatePostalCode = Expression<String?>("STATE_POSTAL_CODE")
    private let colZipCode = Expression<String?>("ZIPCODE")
    private let colCountyName = Expression<String?>("COUNTY_NAME")
    private let colCountyFipsCode = Expression<String?>("COUNTY_FIPS_CODE")
    private let colCongress = Expression<String?>("CONGRESS")
    private let colCongressFips = Expression<String?>("CONGRESS_FIPS")
    private let colWaterwayName = Expression<String?>("WTWY_NAME")
    private let colPortName = Expression<String?>("PORT_NAME")
    private let colMile = Expression<Double?>("MILE")
    private let colBank = Expression<String?>("BANK")
    // FIX: Changed these from non-optional to optional
    private let colLatitude = Expression<Double?>("LATITUDE")
    private let colLongitude = Expression<Double?>("LONGITUDE")
    private let colOperators = Expression<String?>("OPERATORS")
    private let colOwners = Expression<String?>("OWNERS")
    private let colPurpose = Expression<String?>("PURPOSE")
    private let colHighwayNote = Expression<String?>("HIGHWAY_NOTE")
    private let colRailwayNote = Expression<String?>("RAILWAY_NOTE")
    private let colLocation = Expression<String?>("LOCATION")
    private let colDock = Expression<String?>("DOCK")
    private let colCommodities = Expression<String?>("COMMODITIES")
    private let colConstruction = Expression<String?>("CONSTRUCTION")
    private let colMechanicalHandling = Expression<String?>("MECHANICAL_HANDLING")
    private let colRemarks = Expression<String?>("REMARKS")
    private let colVerticalDatum = Expression<String?>("VERTICAL_DATUM")
    private let colDepthMin = Expression<Double?>("DEPTH_MIN")
    private let colDepthMax = Expression<Double?>("DEPTH_MAX")
    private let colBerthingLargest = Expression<Double?>("BERTHING_LARGEST")
    private let colBerthingTotal = Expression<Double?>("BERTHING_TOTAL")
    private let colDeckHeightMin = Expression<Double?>("DECK_HEIGHT_MIN")
    private let colDeckHeightMax = Expression<Double?>("DECK_HEIGHT_MAX")
    private let colServiceInitiationDate = Expression<String?>("SERVICE_INITIATION_DATE")
    private let colServiceTerminationDate = Expression<String?>("SERVICE_TERMINATION_DATE")
    private let colIsFavorite = Expression<Bool>("is_favorite")
    
    // MARK: - Column Definitions - Common
    private let colId = Expression<Int>("Id")
    private let colCreatedAt = Expression<Date>("CreatedAt")
    private let colModifiedAt = Expression<Date?>("ModifiedAt")
    
    // MARK: - Column Definitions - PersonalNote
    private let colNoteText = Expression<String>("NoteText")
    
    // MARK: - Column Definitions - ChangeRecommendation
    private let colRecommendationText = Expression<String>("RecommendationText")
    private let colStatus = Expression<Int>("Status")
    
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
            
            // Query using our locally defined columns
            let query = navUnits.order(colNavUnitName.asc)
            
            var results: [NavUnit] = []
            var count = 0 // Counter for logging
            
            print(" S NavUnitDatabaseService: Starting fetch...")
            
            for row in try db.prepare(query) {
                // Log raw values for debugging
                let latValue = row[colLatitude]
                let lonValue = row[colLongitude]
                let _ = row[colNavUnitId]
                if count < 10 {
         //           print(" S NavUnitDB (\(count)): ID \(unitId) - Raw Lat: \(String(describing: latValue)), Raw Lon: \(String(describing: lonValue))")
                }
                
                // FIX: Use default values of 0 when latitude/longitude are nil
                // Create NavUnit with all fields properly mapped
                let unit = NavUnit(
                    navUnitId: row[colNavUnitId],
                    unloCode: row[colUnloCode],
                    navUnitName: row[colNavUnitName],
                    locationDescription: row[colLocationDescription],
                    facilityType: row[colFacilityType],
                    streetAddress: row[colStreetAddress],
                    cityOrTown: row[colCityOrTown],
                    statePostalCode: row[colStatePostalCode],
                    zipCode: row[colZipCode],
                    countyName: row[colCountyName],
                    countyFipsCode: row[colCountyFipsCode],
                    congress: row[colCongress],
                    congressFips: row[colCongressFips],
                    waterwayName: row[colWaterwayName],
                    portName: row[colPortName],
                    mile: row[colMile],
                    bank: row[colBank],
                    latitude: latValue ?? 0.0,  // Use 0.0 as default if nil
                    longitude: lonValue ?? 0.0, // Use 0.0 as default if nil
                    operators: row[colOperators],
                    owners: row[colOwners],
                    purpose: row[colPurpose],
                    highwayNote: row[colHighwayNote],
                    railwayNote: row[colRailwayNote],
                    location: row[colLocation],
                    dock: row[colDock],
                    commodities: row[colCommodities],
                    construction: row[colConstruction],
                    mechanicalHandling: row[colMechanicalHandling],
                    remarks: row[colRemarks],
                    verticalDatum: row[colVerticalDatum],
                    depthMin: row[colDepthMin],
                    depthMax: row[colDepthMax],
                    berthingLargest: row[colBerthingLargest],
                    berthingTotal: row[colBerthingTotal],
                    deckHeightMin: row[colDeckHeightMin],
                    deckHeightMax: row[colDeckHeightMax],
                    serviceInitiationDate: row[colServiceInitiationDate],
                    serviceTerminationDate: row[colServiceTerminationDate],
                    isFavorite: row[colIsFavorite]
                )
                results.append(unit)
                count += 1
            }

          //  print(" S NavUnitDatabaseService: Fetched \(results.count) units.")
            return results
        } catch {
       //     print(" S NavUnitDatabaseService: Error fetching nav units: \(error.localizedDescription)")
            throw error
        }
    }

    // Toggle favorite status with locally defined columns
    func toggleFavoriteNavUnitAsync(navUnitId: String) async throws -> Bool {
        do {
            let db = try databaseCore.ensureConnection()

            // Find the specific NavUnit row
            let query = navUnits.filter(colNavUnitId == navUnitId)

            // Try to get the current unit's favorite status
            guard let unit = try db.pluck(query) else {
                print(" S NavUnitDatabaseService: Error toggling favorite - NavUnit \(navUnitId) not found.")
                throw NSError(domain: "DatabaseService", code: 10, userInfo: [NSLocalizedDescriptionKey: "NavUnit not found for toggling favorite."])
            }

            let currentValue = unit[colIsFavorite]
            let newValue = !currentValue // Toggle the boolean value

            print(" S NavUnitDatabaseService: Toggling favorite for \(navUnitId) from \(currentValue) to \(newValue)")

            // Prepare the update statement
            let updatedRow = navUnits.filter(colNavUnitId == navUnitId)
            // Execute the update
            try db.run(updatedRow.update(colIsFavorite <- newValue))

            // Flush changes to disk
            try await databaseCore.flushDatabaseAsync()
            print(" S NavUnitDatabaseService: Favorite status updated successfully for \(navUnitId). New status: \(newValue)")
            return newValue // Return the new status
        } catch {
            print(" S NavUnitDatabaseService: Error toggling favorite for NavUnit \(navUnitId): \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Personal Notes Methods

    // Get personal notes for a navigation unit
    func getPersonalNotesAsync(navUnitId: String) async throws -> [PersonalNote] {
        do {
            let db = try databaseCore.ensureConnection()

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

    // Add a new personal note
    func addPersonalNoteAsync(note: PersonalNote) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()

            let insert = personalNotes.insert(
                colNavUnitId <- note.navUnitId,
                colNoteText <- note.noteText,
                colCreatedAt <- Date()
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

            let updatedRow = personalNotes.filter(colId == note.id)
            let affectedRows = try db.run(updatedRow.update(
                colNoteText <- note.noteText,
                colModifiedAt <- Date()
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

            let query = personalNotes.filter(colId == noteId)
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

    // Add a new change recommendation
    func addChangeRecommendationAsync(recommendation: ChangeRecommendation) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()

            let insert = changeRecommendations.insert(
                colNavUnitId <- recommendation.navUnitId,
                colRecommendationText <- recommendation.recommendationText,
                colCreatedAt <- Date(),
                colStatus <- RecommendationStatus.pending.rawValue
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

            let updatedRow = changeRecommendations.filter(colId == recommendationId)
            let affectedRows = try db.run(updatedRow.update(colStatus <- status.rawValue))
            try await databaseCore.flushDatabaseAsync()
            return affectedRows
        } catch {
            print("Error updating change recommendation status: \(error.localizedDescription)")
            throw error
        }
    }
}
