
import Foundation
import UIKit
#if canImport(SQLite)
import SQLite
#endif

class NavUnitDatabaseService {
    // MARK: - Table Definitions
    private let navUnits = Table("NavUnits")
    private let personalNotes = Table("PersonalNote")
    private let changeRecommendations = Table("ChangeRecommendation")
    private let navUnitFavorites = Table("NavUnitFavorites")
    
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
    
    // MARK: - Column Definitions for NavUnitFavorites (Sync-enabled schema)
    private let colUserId = Expression<String>("user_id")
    private let colNavUnitIdFav = Expression<String>("nav_unit_id") // Primary key for favorites
    private let colIsFavoriteNav = Expression<Bool>("is_favorite")
    private let colLastModified = Expression<Date>("last_modified")
    private let colDeviceId = Expression<String>("device_id")
    private let colNavUnitNameFav = Expression<String?>("nav_unit_name")
    private let colLatitudeFav = Expression<Double?>("latitude")
    private let colLongitudeFav = Expression<Double?>("longitude")
    private let colFacilityTypeFav = Expression<String?>("facility_type")
    
    // MARK: - Properties
    private let databaseCore: DatabaseCore
    
    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }
    
    // MARK: - Utility Methods for Favorites
    
    private func getDeviceId() async -> String {
        return await UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }
    
    private func getCurrentUserId() async -> String? {
        do {
            let session = try await SupabaseManager.shared.getSession()
            let userId = session.user.id.uuidString
            print("👤 NAV_UNIT_DB_SERVICE: Retrieved user ID: \(userId)")
            return userId
        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Could not get current user ID: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func addColumnIfNeeded(db: Connection, tableName: String, columnName: String, columnType: String) async throws {
        print("🔧 NAV_UNIT_DB_SERVICE: Checking if column '\(columnName)' exists in table '\(tableName)'")
        
        let pragmaQuery = "PRAGMA table_info(\(tableName))"
        var columnExists = false
        
        for row in try db.prepare(pragmaQuery) {
            if let name = row[1] as? String, name == columnName {
                columnExists = true
                print("✅ NAV_UNIT_DB_SERVICE: Column '\(columnName)' already exists")
                break
            }
        }
        
        if !columnExists {
            let alterQuery = "ALTER TABLE \(tableName) ADD COLUMN \(columnName) \(columnType)"
            print("🔧 NAV_UNIT_DB_SERVICE: Adding column '\(columnName)' with query: \(alterQuery)")
            try db.execute(alterQuery)
            print("✅ NAV_UNIT_DB_SERVICE: Successfully added column '\(columnName)'")
        }
    }
    
    // MARK: - Table Initialization
    
    func initializeNavUnitFavoritesTableAsync() async throws {
        print("🚀 NAV_UNIT_DB_SERVICE: Starting NavUnit favorites table initialization")
        let startTime = Date()
        
        do {
            let db = try databaseCore.ensureConnection()
            print("✅ NAV_UNIT_DB_SERVICE: Database connection established")
            
            // Get current tables first
            let tablesQuery = "SELECT name FROM sqlite_master WHERE type='table'"
            var tableNames: [String] = []
            for row in try db.prepare(tablesQuery) {
                if let tableName = row[0] as? String {
                    tableNames.append(tableName)
                }
            }
            print("📊 NAV_UNIT_DB_SERVICE: Current tables: \(tableNames.joined(separator: ", "))")
            
            // Create table with Supabase-aligned schema
            print("🔧 NAV_UNIT_DB_SERVICE: Creating NavUnitFavorites table")
            try db.run(navUnitFavorites.create(ifNotExists: true) { table in
                table.column(colUserId)
                table.column(colNavUnitIdFav, primaryKey: true)
                table.column(colIsFavoriteNav)
                table.column(colLastModified)
                table.column(colDeviceId)
                table.column(colNavUnitNameFav)
                table.column(colLatitudeFav)
                table.column(colLongitudeFav)
                table.column(colFacilityTypeFav)
                // Unique constraint on user_id and nav_unit_id combination
                table.unique(colUserId, colNavUnitIdFav)
            })
            
            // Add columns if they don't exist (for migration from older versions)
            try await addColumnIfNeeded(db: db, tableName: "NavUnitFavorites", columnName: "user_id", columnType: "TEXT")
            try await addColumnIfNeeded(db: db, tableName: "NavUnitFavorites", columnName: "last_modified", columnType: "DATETIME")
            try await addColumnIfNeeded(db: db, tableName: "NavUnitFavorites", columnName: "device_id", columnType: "TEXT")
            try await addColumnIfNeeded(db: db, tableName: "NavUnitFavorites", columnName: "nav_unit_name", columnType: "TEXT")
            try await addColumnIfNeeded(db: db, tableName: "NavUnitFavorites", columnName: "latitude", columnType: "REAL")
            try await addColumnIfNeeded(db: db, tableName: "NavUnitFavorites", columnName: "longitude", columnType: "REAL")
            try await addColumnIfNeeded(db: db, tableName: "NavUnitFavorites", columnName: "facility_type", columnType: "TEXT")
            
            // Verify table creation
            tableNames = []
            for row in try db.prepare(tablesQuery) {
                if let tableName = row[0] as? String {
                    tableNames.append(tableName)
                }
            }
            
            if tableNames.contains("NavUnitFavorites") {
                print("✅ NAV_UNIT_DB_SERVICE: NavUnitFavorites table created/verified with sync-enabled schema")
                
                // Test write capability
                let deviceId = await getDeviceId()
                try db.run(navUnitFavorites.insert(or: .replace,
                    colUserId <- "TEST_USER_ID",
                    colNavUnitIdFav <- "TEST_NAV_INIT",
                    colIsFavoriteNav <- true,
                    colLastModified <- Date(),
                    colDeviceId <- deviceId,
                    colNavUnitNameFav <- "Test Navigation Unit",
                    colLatitudeFav <- 0.0,
                    colLongitudeFav <- 0.0,
                    colFacilityTypeFav <- "Test Facility"
                ))
                
                // Verify and clean up test record
                let testQuery = navUnitFavorites.filter(colNavUnitIdFav == "TEST_NAV_INIT")
                if let testRecord = try? db.pluck(testQuery) {
                    print("✅ NAV_UNIT_DB_SERVICE: Write test successful")
                    try db.run(testQuery.delete())
                    print("🧹 NAV_UNIT_DB_SERVICE: Test record cleaned up")
                }
                
                try await databaseCore.flushDatabaseAsync()
                
                let duration = Date().timeIntervalSince(startTime)
                print("⏱️ NAV_UNIT_DB_SERVICE: NavUnit favorites table initialization completed in \(String(format: "%.3f", duration))s")
                
            } else {
                throw NSError(domain: "DatabaseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create NavUnitFavorites table"])
            }
        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: NavUnit favorites initialization failed: \(error.localizedDescription)")
            throw error
        }
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
    
    // MARK: - Sync-Enabled Favorites Query Methods
    
    // Check if a navigation unit is marked as favorite for the current user
    func isNavUnitFavoriteForUser(navUnitId: String) async -> Bool {
        print("🔍 NAV_UNIT_DB_SERVICE: Checking favorite status for nav unit \(navUnitId)")
        let startTime = Date()
        
        do {
            let db = try databaseCore.ensureConnection()
            guard let userId = await getCurrentUserId() else {
                print("⚠️ NAV_UNIT_DB_SERVICE: No authenticated user, cannot check favorite status")
                return false
            }
            
            let query = navUnitFavorites.filter(colUserId == userId && colNavUnitIdFav == navUnitId)
            
            if let favoriteRecord = try db.pluck(query) {
                let isFavorite = favoriteRecord[colIsFavoriteNav]
                let duration = Date().timeIntervalSince(startTime)
                print("✅ NAV_UNIT_DB_SERVICE: Found favorite record for \(navUnitId): \(isFavorite) (Duration: \(String(format: "%.3f", duration))s)")
                return isFavorite
            } else {
                let duration = Date().timeIntervalSince(startTime)
                print("📭 NAV_UNIT_DB_SERVICE: No favorite record found for \(navUnitId) (Duration: \(String(format: "%.3f", duration))s)")
                return false
            }
        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error checking favorite status for \(navUnitId): \(error.localizedDescription)")
            return false
        }
    }
    
    // Get all favorite nav unit IDs for the current user (for sync operations)
    func getAllFavoriteNavUnitIds() async -> Set<String> {
        print("🔄 NAV_UNIT_DB_SERVICE: Getting all favorite nav unit IDs for sync")
        let startTime = Date()
        
        do {
            let db = try databaseCore.ensureConnection()
            guard let userId = await getCurrentUserId() else {
                print("⚠️ NAV_UNIT_DB_SERVICE: No authenticated user, returning empty set")
                return Set<String>()
            }
            
            let query = navUnitFavorites.filter(colUserId == userId && colIsFavoriteNav == true)
            var favoriteIds = Set<String>()
            
            for row in try db.prepare(query) {
                let navUnitId = row[colNavUnitIdFav]
                favoriteIds.insert(navUnitId)
            }
            
            let duration = Date().timeIntervalSince(startTime)
            print("✅ NAV_UNIT_DB_SERVICE: Retrieved \(favoriteIds.count) favorite nav unit IDs in \(String(format: "%.3f", duration))s")
            
            if !favoriteIds.isEmpty {
                print("📋 NAV_UNIT_DB_SERVICE: Favorite IDs: \(Array(favoriteIds).sorted())")
            }
            
            return favoriteIds
        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error getting favorite nav unit IDs: \(error.localizedDescription)")
            return Set<String>()
        }
    }
    
    // Set nav unit favorite status with full metadata (for sync operations)
    func setNavUnitFavorite(
        navUnitId: String,
        isFavorite: Bool,
        navUnitName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        facilityType: String? = nil
    ) async throws -> Bool {
        print("📝 NAV_UNIT_DB_SERVICE: Setting favorite status for \(navUnitId) to \(isFavorite)")
        let startTime = Date()
        
        do {
            let db = try databaseCore.ensureConnection()
            guard let userId = await getCurrentUserId() else {
                throw NSError(domain: "DatabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
            }
            
            let deviceId = await getDeviceId()
            let now = Date()
            
            if isFavorite {
                // Insert or update favorite record
                try db.run(navUnitFavorites.insert(or: .replace,
                    colUserId <- userId,
                    colNavUnitIdFav <- navUnitId,
                    colIsFavoriteNav <- true,
                    colLastModified <- now,
                    colDeviceId <- deviceId,
                    colNavUnitNameFav <- navUnitName,
                    colLatitudeFav <- latitude,
                    colLongitudeFav <- longitude,
                    colFacilityTypeFav <- facilityType
                ))
                print("✅ NAV_UNIT_DB_SERVICE: Added/updated favorite record for \(navUnitId)")
            } else {
                // Remove favorite record or update to false
                let query = navUnitFavorites.filter(colUserId == userId && colNavUnitIdFav == navUnitId)
                try db.run(query.delete())
                print("✅ NAV_UNIT_DB_SERVICE: Removed favorite record for \(navUnitId)")
            }
            
            try await databaseCore.flushDatabaseAsync()
            
            let duration = Date().timeIntervalSince(startTime)
            print("⏱️ NAV_UNIT_DB_SERVICE: Set favorite operation completed in \(String(format: "%.3f", duration))s")
            
            return isFavorite
        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error setting favorite status for \(navUnitId): \(error.localizedDescription)")
            throw error
        }
    }
    
    // Enhanced toggle method that uses the new sync-enabled structure
    func toggleFavoriteNavUnitAsyncEnhanced(navUnitId: String) async throws -> Bool {
        print("🔄 NAV_UNIT_DB_SERVICE: Toggling favorite for nav unit \(navUnitId) (enhanced)")
        
        // Get current status
        let currentStatus = await isNavUnitFavoriteForUser(navUnitId: navUnitId)
        let newStatus = !currentStatus
        
        // Get nav unit details for metadata
        let navUnits = try await getNavUnitsAsync()
        let navUnit = navUnits.first { $0.navUnitId == navUnitId }
        
        // Set new status with metadata
        return try await setNavUnitFavorite(
            navUnitId: navUnitId,
            isFavorite: newStatus,
            navUnitName: navUnit?.navUnitName,
            latitude: navUnit?.latitude,
            longitude: navUnit?.longitude,
            facilityType: navUnit?.facilityType
        )
    }
    
    // Get all nav unit favorites with metadata for the current user (for sync operations)
    func getAllNavUnitFavoritesForUser() async throws -> [NavUnitFavoriteRecord] {
        print("🔄 NAV_UNIT_DB_SERVICE: Getting all nav unit favorites with metadata for sync")
        let startTime = Date()
        
        let db = try databaseCore.ensureConnection()
        guard let userId = await getCurrentUserId() else {
            throw NSError(domain: "DatabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let query = navUnitFavorites.filter(colUserId == userId)
        var results: [NavUnitFavoriteRecord] = []
        
        for row in try db.prepare(query) {
            let record = NavUnitFavoriteRecord(
                userId: row[colUserId],
                navUnitId: row[colNavUnitIdFav],
                isFavorite: row[colIsFavoriteNav],
                lastModified: row[colLastModified],
                deviceId: row[colDeviceId],
                navUnitName: row[colNavUnitNameFav],
                latitude: row[colLatitudeFav],
                longitude: row[colLongitudeFav],
                facilityType: row[colFacilityTypeFav]
            )
            results.append(record)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ NAV_UNIT_DB_SERVICE: Retrieved \(results.count) nav unit favorites with metadata in \(String(format: "%.3f", duration))s")
        
        return results
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

    // Add a personal note for a navigation unit
    func addPersonalNoteAsync(navUnitId: String, noteText: String) async throws -> PersonalNote {
        do {
            let db = try databaseCore.ensureConnection()

            let now = Date()
            let insertStatement = personalNotes.insert(
                colNavUnitId <- navUnitId,
                colNoteText <- noteText,
                colCreatedAt <- now
            )

            let rowId = try db.run(insertStatement)

            let newNote = PersonalNote(
                id: Int(rowId),
                navUnitId: navUnitId,
                noteText: noteText,
                createdAt: now
            )

            return newNote
        } catch {
            print("Error adding personal note: \(error.localizedDescription)")
            throw error
        }
    }

    // Update a personal note
    func updatePersonalNoteAsync(noteId: Int, noteText: String) async throws -> PersonalNote {
        do {
            let db = try databaseCore.ensureConnection()

            let now = Date()
            let noteToUpdate = personalNotes.filter(colId == noteId)

            try db.run(noteToUpdate.update(
                colNoteText <- noteText,
                colModifiedAt <- now
            ))

            // Fetch the updated note
            guard let updatedRow = try db.pluck(noteToUpdate) else {
                throw NSError(domain: "DatabaseService", code: 7, userInfo: [NSLocalizedDescriptionKey: "Note not found after update."])
            }

            return PersonalNote(
                id: updatedRow[colId],
                navUnitId: updatedRow[colNavUnitId],
                noteText: updatedRow[colNoteText],
                createdAt: updatedRow[colCreatedAt]
            )
        } catch {
            print("Error updating personal note: \(error.localizedDescription)")
            throw error
        }
    }

    // Delete a personal note
    func deletePersonalNoteAsync(noteId: Int) async throws {
        do {
            let db = try databaseCore.ensureConnection()

            let noteToDelete = personalNotes.filter(colId == noteId)
            try db.run(noteToDelete.delete())

        } catch {
            print("Error deleting personal note: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Change Recommendations Methods

    // Get change recommendations for a navigation unit
    func getChangeRecommendationsAsync(navUnitId: String) async throws -> [ChangeRecommendation] {
        do {
            let db = try databaseCore.ensureConnection()

            let query = changeRecommendations.filter(colNavUnitId == navUnitId).order(colCreatedAt.desc)
            var results: [ChangeRecommendation] = []

            for row in try db.prepare(query) {
                let recommendation = ChangeRecommendation(
                    id: row[colId],
                    navUnitId: row[colNavUnitId],
                    recommendationText: row[colRecommendationText],
                    createdAt: row[colCreatedAt],
                    status: RecommendationStatus(rawValue: row[colStatus]) ?? .pending
                )
                results.append(recommendation)
            }

            return results
        } catch {
            print("Error fetching change recommendations: \(error.localizedDescription)")
            throw error
        }
    }

    // Add a change recommendation for a navigation unit
    func addChangeRecommendationAsync(navUnitId: String, recommendationText: String) async throws -> ChangeRecommendation {
        do {
            let db = try databaseCore.ensureConnection()

            let now = Date()
            let insertStatement = changeRecommendations.insert(
                colNavUnitId <- navUnitId,
                colRecommendationText <- recommendationText,
                colStatus <- RecommendationStatus.pending.rawValue,
                colCreatedAt <- now
            )

            let rowId = try db.run(insertStatement)

            let newRecommendation = ChangeRecommendation(
                id: Int(rowId),
                navUnitId: navUnitId,
                recommendationText: recommendationText,
                createdAt: now,
                status: .pending
               
            )

            return newRecommendation
        } catch {
            print("Error adding change recommendation: \(error.localizedDescription)")
            throw error
        }
    }

    // Update a change recommendation status
    func updateChangeRecommendationStatusAsync(recommendationId: Int, status: RecommendationStatus) async throws -> ChangeRecommendation {
        do {
            let db = try databaseCore.ensureConnection()

            let now = Date()
            let recommendationToUpdate = changeRecommendations.filter(colId == recommendationId)

            try db.run(recommendationToUpdate.update(
                colStatus <- status.rawValue,
                colModifiedAt <- now
            ))

            // Fetch the updated recommendation
            guard let updatedRow = try db.pluck(recommendationToUpdate) else {
                throw NSError(domain: "DatabaseService", code: 8, userInfo: [NSLocalizedDescriptionKey: "Recommendation not found after update."])
            }

            return ChangeRecommendation(
                id: updatedRow[colId],
                navUnitId: updatedRow[colNavUnitId],
                recommendationText: updatedRow[colRecommendationText],
                createdAt: updatedRow[colCreatedAt],
                status: RecommendationStatus(rawValue: updatedRow[colStatus]) ?? .pending
            )
        } catch {
            print("Error updating change recommendation status: \(error.localizedDescription)")
            throw error
        }
    }

    // Delete a change recommendation
    func deleteChangeRecommendationAsync(recommendationId: Int) async throws {
        do {
            let db = try databaseCore.ensureConnection()

            let recommendationToDelete = changeRecommendations.filter(colId == recommendationId)
            try db.run(recommendationToDelete.delete())

        } catch {
            print("Error deleting change recommendation: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Supporting Data Structures

struct NavUnitFavoriteRecord {
    let userId: String
    let navUnitId: String
    let isFavorite: Bool
    let lastModified: Date
    let deviceId: String
    let navUnitName: String?
    let latitude: Double?
    let longitude: Double?
    let facilityType: String?
    
    // Convert to NavUnit for display purposes
    func toNavUnit() -> NavUnit {
        return NavUnit(
            navUnitId: navUnitId,
            unloCode: nil,
            navUnitName: navUnitName ?? "Unknown Nav Unit",
            locationDescription: nil,
            facilityType: facilityType,
            streetAddress: nil,
            cityOrTown: nil,
            statePostalCode: nil,
            zipCode: nil,
            countyName: nil,
            countyFipsCode: nil,
            congress: nil,
            congressFips: nil,
            waterwayName: nil,
            portName: nil,
            mile: nil,
            bank: nil,
            latitude: latitude ?? 0.0,
            longitude: longitude ?? 0.0,
            operators: nil,
            owners: nil,
            purpose: nil,
            highwayNote: nil,
            railwayNote: nil,
            location: nil,
            dock: nil,
            commodities: nil,
            construction: nil,
            mechanicalHandling: nil,
            remarks: nil,
            verticalDatum: nil,
            depthMin: nil,
            depthMax: nil,
            berthingLargest: nil,
            berthingTotal: nil,
            deckHeightMin: nil,
            deckHeightMax: nil,
            serviceInitiationDate: nil,
            serviceTerminationDate: nil,
            isFavorite: isFavorite
        )
    }
}
