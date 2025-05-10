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
    
    // Add this method to VesselDatabaseService.swift

    func getTugDetailsAsync(tugId: String) async throws -> Tug? {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 VesselDatabaseService: Fetching details for tug \(tugId)")
            
            let query = tugs.filter(colTugId == tugId)
            
            // Attempt to get the single row for this tug
            if let row = try db.pluck(query) {
                // Create a full Tug model with all available properties
                let tug = Tug(
                    tugId: row[colTugId],
                    vesselName: row[colVesselName],
                    vesselNumber: row[colVesselNumber],
                    cgNumber: row[colCgNumber],
                    vtcc: nil, // Add this column if it exists in your database
                    icst: nil, // Add this column if it exists in your database
                    nrt: nil, // Add this column if it exists in your database
                    horsepower: row[colHorsepower],
                    registeredLength: nil, // Add this column if it exists in your database
                    overallLength: row[colOverallLength],
                    registeredBreadth: nil, // Add this column if it exists in your database
                    overallBreadth: nil, // Add this column if it exists in your database
                    hfp: nil, // Add this column if it exists in your database
                    capacityRef: nil, // Add this column if it exists in your database
                    passengerCapacity: nil, // Add this column if it exists in your database
                    tonnageCapacity: nil, // Add this column if it exists in your database
                    year: nil, // Add this column if it exists in your database
                    rebuilt: nil, // Add this column if it exists in your database
                    yearRebuilt: nil, // Add this column if it exists in your database
                    vesselYear: nil, // Add this column if it exists in your database
                    loadDraft: nil, // Add this column if it exists in your database
                    lightDraft: nil, // Add this column if it exists in your database
                    equipment1: nil, // Add this column if it exists in your database
                    equipment2: nil, // Add this column if it exists in your database
                    state: row[colState],
                    basePort1: row[colBasePort1],
                    basePort2: row[colBasePort2],
                    region: nil, // Add this column if it exists in your database
                    operator_: row[colOperator],
                    fleetYear: nil // Add this column if it exists in your database
                )
                
                print("📊 VesselDatabaseService: Successfully fetched details for tug \(tugId)")
                return tug
            } else {
                print("📊 VesselDatabaseService: No tug found with ID \(tugId)")
                return nil
            }
        } catch {
            print("Error fetching tug details: \(error.localizedDescription)")
            print("Error details: \(error)")
            throw error
        }
    }
    
    
    
    
    
    
    
    
    
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

    // Add these column definitions to VesselDatabaseService.swift
    // MARK: - Column Definitions - BARGES table
    private let colBargeId = Expression<String>("BARGE_ID")
    private let colBargeVesselName = Expression<String>("VS_NAME")
    private let colBargeVesselNumber = Expression<String?>("VS_NUMBER")
    private let colBargeCgNumber = Expression<String?>("CG_NUMBER")
    private let colBargeVtcc = Expression<String?>("VTCC")
    private let colBargeIcst = Expression<String?>("ICST")
    private let colBargeNrt = Expression<String?>("NRT")
    private let colBargeHorsepower = Expression<String?>("HP")
    private let colBargeRegLength = Expression<String?>("REG_LNGTH")
    private let colBargeOverLength = Expression<String?>("OVER_LNGTH")
    private let colBargeRegBreadth = Expression<String?>("REG_BRDTH")
    private let colBargeOverBreadth = Expression<String?>("OVER_BRDTH")
    private let colBargeHfp = Expression<String?>("HFP")
    private let colBargeCapRef = Expression<String?>("CAP_REF")
    private let colBargeCapPass = Expression<String?>("CAP_PASS")
    private let colBargeCapTons = Expression<String?>("CAP_TONS")
    private let colBargeYear = Expression<String?>("YEAR")
    private let colBargeReblt = Expression<String?>("REBLT")
    private let colBargeYearRebuilt = Expression<String?>("YEAR_REBUILT")
    private let colBargeYearVessel = Expression<String?>("YEAR_VESSEL")
    private let colBargeLoadDraft = Expression<String?>("LOAD_DRAFT")
    private let colBargeLightDraft = Expression<String?>("LIGHT_DRAFT")
    private let colBargeEquip1 = Expression<String?>("EQUP1")
    private let colBargeEquip2 = Expression<String?>("EQUIP2")
    private let colBargeState = Expression<String?>("STATE")
    private let colBargeBase1 = Expression<String?>("BASE1")
    private let colBargeBase2 = Expression<String?>("BASE2")
    private let colBargeRegion = Expression<String?>("REGION")
    private let colBargeOperator = Expression<String?>("TS_OPER")
    private let colBargeFleetYear = Expression<String?>("FL_YR")

    // MARK: - Barge Methods

    // Get all barges
    func getBargesAsync() async throws -> [Barge] {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 VesselDatabaseService: Fetching barges from database")
            
            let query = barges.order(colBargeVesselName.asc)
            print("📊 VesselDatabaseService: Executing query on BARGES table")
            
            var results: [Barge] = []
            
            for row in try db.prepare(query) {
                // Create a basic Barge model with minimal properties
                let barge = Barge(
                    bargeId: row[colBargeId],
                    vesselName: row[colBargeVesselName]
                )
                results.append(barge)
            }
            
            print("📊 VesselDatabaseService: Successfully fetched \(results.count) barges")
            return results
        } catch {
            print("Error fetching barges: \(error.localizedDescription)")
            print("Error details: \(error)")
            throw error
        }
    }

    // Get detailed information for a single barge
    func getBargeDetailsAsync(bargeId: String) async throws -> Barge? {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 VesselDatabaseService: Fetching details for barge \(bargeId)")
            
            let query = barges.filter(colBargeId == bargeId)
            
            // Attempt to get the single row for this barge
            if let row = try db.pluck(query) {
                // Create a full Barge model with all available properties
                let barge = Barge(
                    bargeId: row[colBargeId],
                    vesselName: row[colBargeVesselName],
                    vesselNumber: row[colBargeVesselNumber],
                    cgNumber: row[colBargeCgNumber],
                    vtcc: row[colBargeVtcc],
                    icst: row[colBargeIcst],
                    nrt: row[colBargeNrt],
                    horsepower: row[colBargeHorsepower],
                    registeredLength: row[colBargeRegLength],
                    overallLength: row[colBargeOverLength],
                    registeredBreadth: row[colBargeRegBreadth],
                    overallBreadth: row[colBargeOverBreadth],
                    hfp: row[colBargeHfp],
                    capacityRef: row[colBargeCapRef],
                    passengerCapacity: row[colBargeCapPass],
                    tonnageCapacity: row[colBargeCapTons],
                    year: row[colBargeYear],
                    rebuilt: row[colBargeReblt],
                    yearRebuilt: row[colBargeYearRebuilt],
                    vesselYear: row[colBargeYearVessel],
                    loadDraft: row[colBargeLoadDraft],
                    lightDraft: row[colBargeLightDraft],
                    equipment1: row[colBargeEquip1],
                    equipment2: row[colBargeEquip2],
                    state: row[colBargeState],
                    basePort1: row[colBargeBase1],
                    basePort2: row[colBargeBase2],
                    region: row[colBargeRegion],
                    operator_: row[colBargeOperator],
                    fleetYear: row[colBargeFleetYear]
                )
                
                print("📊 VesselDatabaseService: Successfully fetched details for barge \(bargeId)")
                return barge
            } else {
                print("📊 VesselDatabaseService: No barge found with ID \(bargeId)")
                return nil
            }
        } catch {
            print("Error fetching barge details: \(error.localizedDescription)")
            print("Error details: \(error)")
            throw error
        }
    }
    
}
