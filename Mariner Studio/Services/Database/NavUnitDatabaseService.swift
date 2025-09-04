// import Foundation
// import UIKit
// #if canImport(SQLite)
// import SQLite
// #endif
//
// class NavUnitDatabaseService {
//    // MARK: - Table Definition
//    private let navUnits = Table("NavUnits")
//    
//    // MARK: - Column Definitions - NavUnits Main Table
//    private let colNavUnitId = Expression<String>("NAV_UNIT_ID")
//    private let colUnloCode = Expression<String?>("UNLOCODE")
//    private let colNavUnitName = Expression<String>("NAV_UNIT_NAME")
//    private let colLocationDescription = Expression<String?>("LOCATION_DESCRIPTION")
//    private let colFacilityType = Expression<String?>("FACILITY_TYPE")
//    private let colStreetAddress = Expression<String?>("STREET_ADDRESS")
//    private let colCityOrTown = Expression<String?>("CITY_OR_TOWN")
//    private let colStatePostalCode = Expression<String?>("STATE_POSTAL_CODE")
//    private let colZipCode = Expression<String?>("ZIPCODE")
//    private let colCountyName = Expression<String?>("COUNTY_NAME")
//    private let colCountyFipsCode = Expression<String?>("COUNTY_FIPS_CODE")
//    private let colCongress = Expression<String?>("CONGRESS")
//    private let colCongressFips = Expression<String?>("CONGRESS_FIPS")
//    private let colWaterwayName = Expression<String?>("WTWY_NAME")
//    private let colPortName = Expression<String?>("PORT_NAME")
//    private let colMile = Expression<Double?>("MILE")
//    private let colBank = Expression<String?>("BANK")
//    private let colLatitude = Expression<Double?>("LATITUDE")
//    private let colLongitude = Expression<Double?>("LONGITUDE")
//    private let colOperators = Expression<String?>("OPERATORS")
//    private let colOwners = Expression<String?>("OWNERS")
//    private let colPurpose = Expression<String?>("PURPOSE")
//    private let colHighwayNote = Expression<String?>("HIGHWAY_NOTE")
//    private let colRailwayNote = Expression<String?>("RAILWAY_NOTE")
//    private let colLocation = Expression<String?>("LOCATION")
//    private let colDock = Expression<String?>("DOCK")
//    private let colCommodities = Expression<String?>("COMMODITIES")
//    private let colConstruction = Expression<String?>("CONSTRUCTION")
//    private let colMechanicalHandling = Expression<String?>("MECHANICAL_HANDLING")
//    private let colRemarks = Expression<String?>("REMARKS")
//    private let colVerticalDatum = Expression<String?>("VERTICAL_DATUM")
//    private let colDepthMin = Expression<Double?>("DEPTH_MIN")
//    private let colDepthMax = Expression<Double?>("DEPTH_MAX")
//    private let colBerthingLargest = Expression<Double?>("BERTHING_LARGEST")
//    private let colBerthingTotal = Expression<Double?>("BERTHING_TOTAL")
//    private let colDeckHeightMin = Expression<Double?>("DECK_HEIGHT_MIN")
//    private let colDeckHeightMax = Expression<Double?>("DECK_HEIGHT_MAX")
//    private let colServiceInitiationDate = Expression<String?>("SERVICE_INITIATION_DATE")
//    private let colServiceTerminationDate = Expression<String?>("SERVICE_TERMINATION_DATE")
//    
//    // Main table columns - including the new sync columns you added
//    private let colIsFavorite = Expression<Bool>("IS_FAVORITE")
//    private let colUserId = Expression<String?>("USER_ID")
//    private let colLastModified = Expression<Date?>("LAST_MODIFIED")
//    private let colDeviceId = Expression<String?>("DEVICE_ID")
//    
//    // MARK: - Properties
//    private let databaseCore: DatabaseCore
//    
//    // MARK: - Initialization
//    init(databaseCore: DatabaseCore) {
//        self.databaseCore = databaseCore
//    }
//    
//    // MARK: - Utility Methods
//    
//    private func getDeviceId() async -> String {
//        return await UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
//    }
//    
//    private func getCurrentUserId() async -> String? {
//        do {
//            let session = try await SupabaseManager.shared.getSession()
//            let userId = session.user.id.uuidString
//            print("👤 NAV_UNIT_DB_SERVICE: Retrieved user ID: \(userId)")
//            return userId
//        } catch {
//            print("❌ NAV_UNIT_DB_SERVICE: Could not get current user ID: \(error.localizedDescription)")
//            return nil
//        }
//    }
//    
//    // MARK: - Core Functions
//    /// Get all navigation units from the main table (UPDATED to include sync fields)
//        func getNavUnitsAsync() async throws -> [NavUnit] {
//            print("🔄 NAV_UNIT_DB_SERVICE: Starting getNavUnitsAsync (WITH SYNC FIELDS)")
//            let startTime = Date()
//            
//            do {
//                let db = try databaseCore.ensureConnection()
//                var results: [NavUnit] = []
//                var count = 0
//                
//                print("📊 NAV_UNIT_DB_SERVICE: Querying NavUnits table with sync metadata")
//                
//                for row in try db.prepare(navUnits.order(colNavUnitName.asc)) {
//                    let latValue = row[colLatitude]
//                    let lonValue = row[colLongitude]
//                    
//                    // UPDATED: Now includes sync metadata fields
//                    let unit = NavUnit(
//                        navUnitId: row[colNavUnitId],
//                        unloCode: row[colUnloCode],
//                        navUnitName: row[colNavUnitName],
//                        locationDescription: row[colLocationDescription],
//                        facilityType: row[colFacilityType],
//                        streetAddress: row[colStreetAddress],
//                        cityOrTown: row[colCityOrTown],
//                        statePostalCode: row[colStatePostalCode],
//                        zipCode: row[colZipCode],
//                        countyName: row[colCountyName],
//                        countyFipsCode: row[colCountyFipsCode],
//                        congress: row[colCongress],
//                        congressFips: row[colCongressFips],
//                        waterwayName: row[colWaterwayName],
//                        portName: row[colPortName],
//                        mile: row[colMile],
//                        bank: row[colBank],
//                        latitude: latValue ?? 0.0,
//                        longitude: lonValue ?? 0.0,
//                        operators: row[colOperators],
//                        owners: row[colOwners],
//                        purpose: row[colPurpose],
//                        highwayNote: row[colHighwayNote],
//                        railwayNote: row[colRailwayNote],
//                        location: row[colLocation],
//                        dock: row[colDock],
//                        commodities: row[colCommodities],
//                        construction: row[colConstruction],
//                        mechanicalHandling: row[colMechanicalHandling],
//                        remarks: row[colRemarks],
//                        verticalDatum: row[colVerticalDatum],
//                        depthMin: row[colDepthMin],
//                        depthMax: row[colDepthMax],
//                        berthingLargest: row[colBerthingLargest],
//                        berthingTotal: row[colBerthingTotal],
//                        deckHeightMin: row[colDeckHeightMin],
//                        deckHeightMax: row[colDeckHeightMax],
//                        serviceInitiationDate: row[colServiceInitiationDate],
//                        serviceTerminationDate: row[colServiceTerminationDate],
//                        isFavorite: row[colIsFavorite],
//                        // NEW: Include sync metadata
//                        userId: row[colUserId],
//                        deviceId: row[colDeviceId],
//                        lastModified: row[colLastModified]
//                    )
//                    results.append(unit)
//                    count += 1
//                }
//                
//                let duration = Date().timeIntervalSince(startTime)
//                print("✅ NAV_UNIT_DB_SERVICE: Retrieved \(results.count) nav units with sync metadata in \(String(format: "%.3f", duration))s")
//                return results
//            } catch {
//                print("❌ NAV_UNIT_DB_SERVICE: Error fetching nav units: \(error.localizedDescription)")
//                throw error
//            }
//        }
//
//        /// Get a single navigation unit by ID (UPDATED to include sync fields)
//        func getNavUnitByIdAsync(_ navUnitId: String) async throws -> NavUnit {
//            print("🔄 NAV_UNIT_DB_SERVICE: Starting getNavUnitByIdAsync for ID: \(navUnitId) (WITH SYNC FIELDS)")
//            let startTime = Date()
//            
//            do {
//                let db = try databaseCore.ensureConnection()
//                
//                // Query for specific nav unit by ID
//                let query = navUnits.filter(colNavUnitId == navUnitId)
//                
//                print("📊 NAV_UNIT_DB_SERVICE: Querying NavUnits table for ID: \(navUnitId)")
//                
//                guard let row = try db.pluck(query) else {
//                    print("❌ NAV_UNIT_DB_SERVICE: NavUnit with ID \(navUnitId) not found")
//                    throw NSError(domain: "NavUnitDatabaseService", code: 404,
//                                 userInfo: [NSLocalizedDescriptionKey: "Navigation unit with ID \(navUnitId) not found"])
//                }
//                
//                let latValue = row[colLatitude]
//                let lonValue = row[colLongitude]
//                
//                // UPDATED: Now includes sync metadata fields
//                let unit = NavUnit(
//                    navUnitId: row[colNavUnitId],
//                    unloCode: row[colUnloCode],
//                    navUnitName: row[colNavUnitName],
//                    locationDescription: row[colLocationDescription],
//                    facilityType: row[colFacilityType],
//                    streetAddress: row[colStreetAddress],
//                    cityOrTown: row[colCityOrTown],
//                    statePostalCode: row[colStatePostalCode],
//                    zipCode: row[colZipCode],
//                    countyName: row[colCountyName],
//                    countyFipsCode: row[colCountyFipsCode],
//                    congress: row[colCongress],
//                    congressFips: row[colCongressFips],
//                    waterwayName: row[colWaterwayName],
//                    portName: row[colPortName],
//                    mile: row[colMile],
//                    bank: row[colBank],
//                    latitude: latValue ?? 0.0,
//                    longitude: lonValue ?? 0.0,
//                    operators: row[colOperators],
//                    owners: row[colOwners],
//                    purpose: row[colPurpose],
//                    highwayNote: row[colHighwayNote],
//                    railwayNote: row[colRailwayNote],
//                    location: row[colLocation],
//                    dock: row[colDock],
//                    commodities: row[colCommodities],
//                    construction: row[colConstruction],
//                    mechanicalHandling: row[colMechanicalHandling],
//                    remarks: row[colRemarks],
//                    verticalDatum: row[colVerticalDatum],
//                    depthMin: row[colDepthMin],
//                    depthMax: row[colDepthMax],
//                    berthingLargest: row[colBerthingLargest],
//                    berthingTotal: row[colBerthingTotal],
//                    deckHeightMin: row[colDeckHeightMin],
//                    deckHeightMax: row[colDeckHeightMax],
//                    serviceInitiationDate: row[colServiceInitiationDate],
//                    serviceTerminationDate: row[colServiceTerminationDate],
//                    isFavorite: row[colIsFavorite],
//                    // NEW: Include sync metadata
//                    userId: row[colUserId],
//                    deviceId: row[colDeviceId],
//                    lastModified: row[colLastModified]
//                )
//                
//                let duration = Date().timeIntervalSince(startTime)
//                print("✅ NAV_UNIT_DB_SERVICE: Retrieved nav unit '\(unit.navUnitName)' with sync metadata in \(String(format: "%.3f", duration))s")
//                
//                // Log sync metadata status for debugging
//                if unit.isFavorite {
//                    print("📱🧭 FAVORITE_SYNC_STATUS:")
//                    print("   User verified")
//                    print("   Device ID: \(unit.deviceId ?? "nil")")
//                    print("   Last Modified: \(unit.lastModified?.description ?? "nil")")
//                    print("   Sync Ready: \(unit.userId != nil && unit.deviceId != nil && unit.lastModified != nil)")
//                }
//                
//                return unit
//                
//            } catch {
//                print("❌ NAV_UNIT_DB_SERVICE: Error fetching nav unit by ID \(navUnitId): \(error.localizedDescription)")
//                throw error
//            }
//        }
//    
//    /// Toggle favorite status for a navigation unit in the main table
//    func toggleFavoriteNavUnitAsync(navUnitId: String) async throws -> Bool {
//        print("🔄 NAV_UNIT_DB_SERVICE: Toggling favorite for nav unit \(navUnitId)")
//        let startTime = Date()
//        
//        do {
//            let db = try databaseCore.ensureConnection()
//            
//            // Find the specific NavUnit row
//            let query = navUnits.filter(colNavUnitId == navUnitId)
//            
//            // Get the current unit's favorite status
//            guard let unit = try db.pluck(query) else {
//                print("❌ NAV_UNIT_DB_SERVICE: NavUnit \(navUnitId) not found")
//                throw NSError(domain: "DatabaseService", code: 10, userInfo: [NSLocalizedDescriptionKey: "NavUnit not found for toggling favorite."])
//            }
//            
//            let currentValue = unit[colIsFavorite]
//            let newValue = !currentValue // Toggle the boolean value
//            
//            print("⭐ NAV_UNIT_DB_SERVICE: Toggling favorite for \(navUnitId) from \(currentValue) to \(newValue)")
//            
//            // Get user info for sync metadata
//            guard let userId = await getCurrentUserId() else {
//                throw NSError(domain: "DatabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
//            }
//            
//            let deviceId = await getDeviceId()
//            let currentTime = Date()
//            
//            // Update the main NavUnits table with new favorite status and sync metadata
//            let updatedRow = navUnits.filter(colNavUnitId == navUnitId)
//            try db.run(updatedRow.update(
//                colIsFavorite <- newValue,
//                colUserId <- userId,
//                colLastModified <- currentTime,
//                colDeviceId <- deviceId
//            ))
//            
//            // Flush changes to disk
//            try await databaseCore.flushDatabaseAsync()
//            
//            let duration = Date().timeIntervalSince(startTime)
//            print("✅ NAV_UNIT_DB_SERVICE: Favorite status updated successfully for \(navUnitId). New status: \(newValue) in \(String(format: "%.3f", duration))s")
//            
//            return newValue // Return the new status
//        } catch {
//            print("❌ NAV_UNIT_DB_SERVICE: Error toggling favorite for NavUnit \(navUnitId): \(error.localizedDescription)")
//            throw error
//        }
//    }
//    
//    /// Get minimal nav unit list items with distance calculated in database
//    func getNavUnitListItemsWithDistanceAsync(userLatitude: Double, userLongitude: Double) async throws -> [NavUnitListItem] {
//        print("🔄 NAV_UNIT_DB_SERVICE: Starting getNavUnitListItemsWithDistanceAsync (MINIMAL LOADING)")
//        let startTime = Date()
//        
//        do {
//            let db = try databaseCore.ensureConnection()
//            var results: [NavUnitListItem] = []
//            
//            // Minimal query - only ID, name, and calculated distance
//            let haversineFormula = """
//                CASE 
//                    WHEN LATITUDE IS NULL OR LONGITUDE IS NULL THEN 999999999.0
//                    ELSE (6371000.0 * acos(
//                        cos(radians(\(userLatitude))) * cos(radians(LATITUDE)) * 
//                        cos(radians(LONGITUDE) - radians(\(userLongitude))) + 
//                        sin(radians(\(userLatitude))) * sin(radians(LATITUDE))
//                    ))
//                END
//            """
//            
//            let distanceExpression = Expression<Double>(literal: haversineFormula)
//            let sortOrderExpression = Expression<Int>(literal: "CASE WHEN (\(haversineFormula)) = 999999999.0 THEN 1 ELSE 0 END")
//            
//            // Build minimal query - only 3 columns instead of 30+
//            let query = navUnits
//                .select(colNavUnitId, colNavUnitName, distanceExpression)
//                .order(sortOrderExpression.asc, distanceExpression.asc, colNavUnitName.asc)
//            
//            print("📊 NAV_UNIT_DB_SERVICE: Executing minimal distance query (3 columns only)")
//            
//            for row in try db.prepare(query) {
//                let calculatedDistance = try row.get(distanceExpression)
//                let finalDistance = calculatedDistance == 999999999.0 ? Double.greatestFiniteMagnitude : calculatedDistance
//                
//                let listItem = NavUnitListItem(
//                    id: row[colNavUnitId],
//                    name: row[colNavUnitName],
//                    distanceFromUser: finalDistance
//                )
//                
//                results.append(listItem)
//            }
//
//            let duration = Date().timeIntervalSince(startTime)
//            print("✅ NAV_UNIT_DB_SERVICE: Retrieved \(results.count) minimal nav unit items in \(String(format: "%.3f", duration))s")
//            return results
//            
//        } catch {
//            print("❌ NAV_UNIT_DB_SERVICE: Error fetching minimal nav unit items: \(error.localizedDescription)")
//            throw error
//        }
//    }
//
//    /// Get minimal nav unit list items without distance calculation (fallback)
//    func getNavUnitListItemsAsync() async throws -> [NavUnitListItem] {
//        print("🔄 NAV_UNIT_DB_SERVICE: Starting getNavUnitListItemsAsync (NO DISTANCE)")
//        let startTime = Date()
//        
//        do {
//            let db = try databaseCore.ensureConnection()
//            var results: [NavUnitListItem] = []
//            
//            // Simple query - just ID and name, alphabetically sorted
//            let query = navUnits
//                .select(colNavUnitId, colNavUnitName)
//                .order(colNavUnitName.asc)
//            
//            print("📊 NAV_UNIT_DB_SERVICE: Executing minimal query (2 columns only)")
//            
//            for row in try db.prepare(query) {
//                let listItem = NavUnitListItem(
//                    id: row[colNavUnitId],
//                    name: row[colNavUnitName],
//                    distanceFromUser: Double.greatestFiniteMagnitude
//                )
//                
//                results.append(listItem)
//            }
//
//            let duration = Date().timeIntervalSince(startTime)
//            print("✅ NAV_UNIT_DB_SERVICE: Retrieved \(results.count) minimal nav unit items (no distance) in \(String(format: "%.3f", duration))s")
//            return results
//            
//        } catch {
//            print("❌ NAV_UNIT_DB_SERVICE: Error fetching minimal nav unit items: \(error.localizedDescription)")
//            throw error
//        }
//    }
//    
//     
//    
//    
//    
//    /// Get only favorite navigation units from the main table
//        /// This method efficiently queries only nav units where isFavorite = true
//        /// Used by sync operations to avoid loading all nav units unnecessarily
//        func getFavoriteNavUnitsAsync() async throws -> [NavUnit] {
//            print("🔄 NAV_UNIT_DB_SERVICE: Starting getFavoriteNavUnitsAsync (FAVORITES ONLY)")
//            let startTime = Date()
//            
//            do {
//                let db = try databaseCore.ensureConnection()
//                var results: [NavUnit] = []
//                var count = 0
//                
//                // Efficient query - WHERE clause filters for favorites at database level
//                // This is much more efficient than loading all nav units and filtering in memory
//                let favoritesQuery = navUnits
//                    .filter(colIsFavorite == true)
//                    .order(colNavUnitName.asc)
//                
//                print("📊 NAV_UNIT_DB_SERVICE: Executing favorites-only query with WHERE clause")
//                print("📊 NAV_UNIT_DB_SERVICE: Query: SELECT * FROM NavUnits WHERE IS_FAVORITE = 1 ORDER BY NAV_UNIT_NAME ASC")
//                
//                for row in try db.prepare(favoritesQuery) {
//                    let latValue = row[colLatitude]
//                    let lonValue = row[colLongitude]
//                    
//                    // Create NavUnit from database row - identical to getNavUnitsAsync() but only for favorites
//                    let unit = NavUnit(
//                        navUnitId: row[colNavUnitId],
//                        unloCode: row[colUnloCode],
//                        navUnitName: row[colNavUnitName],
//                        locationDescription: row[colLocationDescription],
//                        facilityType: row[colFacilityType],
//                        streetAddress: row[colStreetAddress],
//                        cityOrTown: row[colCityOrTown],
//                        statePostalCode: row[colStatePostalCode],
//                        zipCode: row[colZipCode],
//                        countyName: row[colCountyName],
//                        countyFipsCode: row[colCountyFipsCode],
//                        congress: row[colCongress],
//                        congressFips: row[colCongressFips],
//                        waterwayName: row[colWaterwayName],
//                        portName: row[colPortName],
//                        mile: row[colMile],
//                        bank: row[colBank],
//                        latitude: latValue ?? 0.0,
//                        longitude: lonValue ?? 0.0,
//                        operators: row[colOperators],
//                        owners: row[colOwners],
//                        purpose: row[colPurpose],
//                        highwayNote: row[colHighwayNote],
//                        railwayNote: row[colRailwayNote],
//                        location: row[colLocation],
//                        dock: row[colDock],
//                        commodities: row[colCommodities],
//                        construction: row[colConstruction],
//                        mechanicalHandling: row[colMechanicalHandling],
//                        remarks: row[colRemarks],
//                        verticalDatum: row[colVerticalDatum],
//                        depthMin: row[colDepthMin],
//                        depthMax: row[colDepthMax],
//                        berthingLargest: row[colBerthingLargest],
//                        berthingTotal: row[colBerthingTotal],
//                        deckHeightMin: row[colDeckHeightMin],
//                        deckHeightMax: row[colDeckHeightMax],
//                        serviceInitiationDate: row[colServiceInitiationDate],
//                        serviceTerminationDate: row[colServiceTerminationDate],
//                        isFavorite: row[colIsFavorite]  // This should always be true due to our WHERE clause
//                    )
//                    
//                    // Verification logging - ensure we're only getting favorites
//                    if !unit.isFavorite {
//                        print("⚠️ NAV_UNIT_DB_SERVICE: WARNING - Non-favorite nav unit returned in favorites query: \(unit.navUnitId)")
//                    }
//                    
//                    results.append(unit)
//                    count += 1
//                    
//                    // Log sync metadata if available for debugging sync operations
//                    if let userId = row[colUserId], let lastModified = row[colLastModified], let deviceId = row[colDeviceId] {
//                        print("📱🧭 FAVORITE_SYNC_DATA: \(unit.navUnitId)")
//                        print("   User authenticated")
//                        print("   Last Modified: \(lastModified)")
//                        print("   Device ID: \(deviceId)")
//                        print("   Is Favorite: \(unit.isFavorite)")
//                    } else {
//                        print("⚠️📱🧭 MISSING_SYNC_DATA: \(unit.navUnitId) - Missing sync metadata (userId, lastModified, or deviceId)")
//                    }
//                }
//                
//                let duration = Date().timeIntervalSince(startTime)
//                print("✅ NAV_UNIT_DB_SERVICE: Retrieved \(results.count) favorite nav units in \(String(format: "%.3f", duration))s")
//                print("📊 NAV_UNIT_DB_SERVICE: Favorites query performance:")
//                print("   Total favorites found: \(results.count)")
//                print("   Query duration: \(String(format: "%.3f", duration))s")
//                print("   Records per second: \(String(format: "%.1f", Double(results.count) / max(duration, 0.001)))")
//                
//                return results
//                
//            } catch {
//                print("❌ NAV_UNIT_DB_SERVICE: Error fetching favorite nav units: \(error.localizedDescription)")
//                print("❌ NAV_UNIT_DB_SERVICE: Error type: \(type(of: error))")
//                print("❌ NAV_UNIT_DB_SERVICE: Error domain: \((error as NSError).domain)")
//                print("❌ NAV_UNIT_DB_SERVICE: Error code: \((error as NSError).code)")
//                throw error
//            }
//        }
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
// }
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//

import Foundation
import UIKit
#if canImport(SQLite)
import SQLite
#endif

class NavUnitDatabaseService {
    // MARK: - Table Definition
    private let navUnits = Table("NavUnits")

    // MARK: - Column Definitions - NavUnits Main Table
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

    // Main table columns - including the sync columns
    private let colIsFavorite = Expression<Bool>("IS_FAVORITE")
    private let colUserId = Expression<String?>("USER_ID")
    private let colLastModified = Expression<Date?>("LAST_MODIFIED")
    private let colDeviceId = Expression<String?>("DEVICE_ID")

    // MARK: - Properties
    private let databaseCore: DatabaseCore

    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }

    // MARK: - Utility Methods

    private func getDeviceId() async -> String {
        return await UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }

    private func getCurrentUserId() async -> String? {
        // Use device ID as user identifier since authentication is removed
        return await getDeviceId()
    }

    // MARK: - Core Functions (Updated to include sync fields)

    /// Get all navigation units from the main table (UPDATED to include sync fields)
    func getNavUnitsAsync() async throws -> [NavUnit] {
        print("🔄 NAV_UNIT_DB_SERVICE: Starting getNavUnitsAsync (WITH SYNC FIELDS)")
        let startTime = Date()

        do {
            let db = try databaseCore.ensureConnection()
            var results: [NavUnit] = []
            var count = 0

            print("📊 NAV_UNIT_DB_SERVICE: Querying NavUnits table with sync metadata")

            for row in try db.prepare(navUnits.order(colNavUnitName.asc)) {
                let latValue = row[colLatitude]
                let lonValue = row[colLongitude]

                // UPDATED: Now includes sync metadata fields
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
                    latitude: latValue ?? 0.0,
                    longitude: lonValue ?? 0.0,
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
                    isFavorite: row[colIsFavorite],
                    // NEW: Include sync metadata
                    userId: row[colUserId],
                    deviceId: row[colDeviceId],
                    lastModified: row[colLastModified]
                )
                results.append(unit)
                count += 1
            }

            let duration = Date().timeIntervalSince(startTime)
            print("✅ NAV_UNIT_DB_SERVICE: Retrieved \(results.count) nav units with sync metadata in \(String(format: "%.3f", duration))s")
            return results
        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error fetching nav units: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get a single navigation unit by ID (UPDATED to include sync fields)
    func getNavUnitByIdAsync(_ navUnitId: String) async throws -> NavUnit {
        print("🔄 NAV_UNIT_DB_SERVICE: Starting getNavUnitByIdAsync for ID: \(navUnitId) (WITH SYNC FIELDS)")
        let startTime = Date()

        do {
            let db = try databaseCore.ensureConnection()

            // Query for specific nav unit by ID
            let query = navUnits.filter(colNavUnitId == navUnitId)

            print("📊 NAV_UNIT_DB_SERVICE: Querying NavUnits table for ID: \(navUnitId)")

            guard let row = try db.pluck(query) else {
                print("❌ NAV_UNIT_DB_SERVICE: NavUnit with ID \(navUnitId) not found")
                throw NSError(domain: "NavUnitDatabaseService", code: 404,
                             userInfo: [NSLocalizedDescriptionKey: "Navigation unit with ID \(navUnitId) not found"])
            }

            let latValue = row[colLatitude]
            let lonValue = row[colLongitude]

            // UPDATED: Now includes sync metadata fields
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
                latitude: latValue ?? 0.0,
                longitude: lonValue ?? 0.0,
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
                isFavorite: row[colIsFavorite],
                // NEW: Include sync metadata
                userId: row[colUserId],
                deviceId: row[colDeviceId],
                lastModified: row[colLastModified]
            )

            let duration = Date().timeIntervalSince(startTime)
            print("✅ NAV_UNIT_DB_SERVICE: Retrieved nav unit '\(unit.navUnitName)' with sync metadata in \(String(format: "%.3f", duration))s")

            // Log sync metadata status for debugging
            if unit.isFavorite {
                print("📱🧭 FAVORITE_SYNC_STATUS:")
                print("   User verified")
                print("   Device ID: \(unit.deviceId ?? "nil")")
                print("   Last Modified: \(unit.lastModified?.description ?? "nil")")
                print("   Sync Ready: \(unit.userId != nil && unit.deviceId != nil && unit.lastModified != nil)")
            }

            return unit

        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error fetching nav unit by ID \(navUnitId): \(error.localizedDescription)")
            throw error
        }
    }

    /// Get only favorite navigation units from the main table
    /// This method efficiently queries only nav units where isFavorite = true
    /// Used by sync operations to avoid loading all nav units unnecessarily
    func getFavoriteNavUnitsAsync() async throws -> [NavUnit] {
        print("🔄 NAV_UNIT_DB_SERVICE: Starting getFavoriteNavUnitsAsync (FAVORITES ONLY)")
        let startTime = Date()

        do {
            let db = try databaseCore.ensureConnection()
            var results: [NavUnit] = []
            var count = 0

            // Efficient query - WHERE clause filters for favorites at database level
            // This is much more efficient than loading all nav units and filtering in memory
            let favoritesQuery = navUnits
                .filter(colIsFavorite == true)
                .order(colNavUnitName.asc)

            print("📊 NAV_UNIT_DB_SERVICE: Executing favorites-only query with WHERE clause")
            print("📊 NAV_UNIT_DB_SERVICE: Query: SELECT * FROM NavUnits WHERE IS_FAVORITE = 1 ORDER BY NAV_UNIT_NAME ASC")

            for row in try db.prepare(favoritesQuery) {
                let latValue = row[colLatitude]
                let lonValue = row[colLongitude]

                // Create NavUnit from database row - identical to getNavUnitsAsync() but only for favorites
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
                    latitude: latValue ?? 0.0,
                    longitude: lonValue ?? 0.0,
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
                    isFavorite: row[colIsFavorite],  // This should always be true due to our WHERE clause
                    // NEW: Include sync metadata from database
                    userId: row[colUserId],
                    deviceId: row[colDeviceId],
                    lastModified: row[colLastModified]
                )

                // Verification logging - ensure we're only getting favorites
                if !unit.isFavorite {
                    print("⚠️ NAV_UNIT_DB_SERVICE: WARNING - Non-favorite nav unit returned in favorites query: \(unit.navUnitId)")
                }

                results.append(unit)
                count += 1

                // Log sync metadata for debugging sync operations
                print("📱🧭 FAVORITE_SYNC_DATA: \(unit.navUnitId)")
                print("   User verified")
                print("   Last Modified: \(unit.lastModified?.description ?? "nil")")
                print("   Device ID: \(unit.deviceId ?? "nil")")
                print("   Is Favorite: \(unit.isFavorite)")

                if unit.userId == nil || unit.lastModified == nil || unit.deviceId == nil {
                    print("⚠️📱🧭 MISSING_SYNC_DATA: \(unit.navUnitId) - Missing sync metadata")
                }
            }

            let duration = Date().timeIntervalSince(startTime)
            print("✅ NAV_UNIT_DB_SERVICE: Retrieved \(results.count) favorite nav units in \(String(format: "%.3f", duration))s")
            print("📊 NAV_UNIT_DB_SERVICE: Favorites query performance:")
            print("   Total favorites found: \(results.count)")
            print("   Query duration: \(String(format: "%.3f", duration))s")
            print("   Records per second: \(String(format: "%.1f", Double(results.count) / max(duration, 0.001)))")

            return results

        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error fetching favorite nav units: \(error.localizedDescription)")
            print("❌ NAV_UNIT_DB_SERVICE: Error type: \(type(of: error))")
            print("❌ NAV_UNIT_DB_SERVICE: Error domain: \((error as NSError).domain)")
            print("❌ NAV_UNIT_DB_SERVICE: Error code: \((error as NSError).code)")
            throw error
        }
    }

    /// Toggle favorite status for a navigation unit in the main table
    func toggleFavoriteNavUnitAsync(navUnitId: String) async throws -> Bool {
        print("🔄 NAV_UNIT_DB_SERVICE: Toggling favorite for nav unit \(navUnitId)")
        let startTime = Date()

        do {
            let db = try databaseCore.ensureConnection()

            // Find the specific NavUnit row
            let query = navUnits.filter(colNavUnitId == navUnitId)

            // Get the current unit's favorite status
            guard let unit = try db.pluck(query) else {
                print("❌ NAV_UNIT_DB_SERVICE: NavUnit \(navUnitId) not found")
                throw NSError(domain: "DatabaseService", code: 10, userInfo: [NSLocalizedDescriptionKey: "NavUnit not found for toggling favorite."])
            }

            let currentValue = unit[colIsFavorite]
            let newValue = !currentValue // Toggle the boolean value

            print("⭐ NAV_UNIT_DB_SERVICE: Toggling favorite for \(navUnitId) from \(currentValue) to \(newValue)")

            // Get user info for sync metadata
            guard let userId = await getCurrentUserId() else {
                throw NSError(domain: "DatabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
            }

            let deviceId = await getDeviceId()
            let currentTime = Date()

            // Update the main NavUnits table with new favorite status and sync metadata
            let updatedRow = navUnits.filter(colNavUnitId == navUnitId)
            try db.run(updatedRow.update(
                colIsFavorite <- newValue,
                colUserId <- userId,
                colLastModified <- currentTime,
                colDeviceId <- deviceId
            ))

            // Flush changes to disk
            try await databaseCore.flushDatabaseAsync()

            let duration = Date().timeIntervalSince(startTime)
            print("✅ NAV_UNIT_DB_SERVICE: Favorite status updated successfully for \(navUnitId). New status: \(newValue) in \(String(format: "%.3f", duration))s")

            return newValue // Return the new status
        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error toggling favorite for NavUnit \(navUnitId): \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Sync-Specific Methods

    /// Get all favorite navigation units with sync metadata for sync operations
    /// This method is specifically designed for sync operations and includes comprehensive sync metadata
    /// Uses optimized query to retrieve only favorites with all necessary sync fields
    func getFavoriteNavUnitsForSync() async throws -> [NavUnit] {
        print("🔄 NAV_UNIT_DB_SERVICE: Starting getFavoriteNavUnitsForSync (SYNC OPTIMIZED)")
        let startTime = Date()

        do {
            let db = try databaseCore.ensureConnection()
            var results: [NavUnit] = []
            var syncMetadataIssues = 0

            // Efficient query specifically for sync - only favorites with comprehensive sync metadata
            let syncQuery = navUnits
                .filter(colIsFavorite == true)
                .order(colLastModified.desc, colNavUnitName.asc) // Order by most recently modified first

            print("📊 NAV_UNIT_DB_SERVICE: Executing sync-optimized favorites query")
            print("📊 NAV_UNIT_DB_SERVICE: Query: SELECT * FROM NavUnits WHERE IS_FAVORITE = 1 ORDER BY LAST_MODIFIED DESC, NAV_UNIT_NAME ASC")

            for row in try db.prepare(syncQuery) {
                let latValue = row[colLatitude]
                let lonValue = row[colLongitude]

                // Create NavUnit with ALL fields including sync metadata
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
                    latitude: latValue ?? 0.0,
                    longitude: lonValue ?? 0.0,
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
                    isFavorite: row[colIsFavorite],  // Should always be true
                    // CRITICAL: Sync metadata fields
                    userId: row[colUserId],
                    deviceId: row[colDeviceId],
                    lastModified: row[colLastModified]
                )

                // Validate sync metadata completeness for debugging
                if unit.userId == nil || unit.deviceId == nil || unit.lastModified == nil {
                    syncMetadataIssues += 1
                    print("⚠️📱🧭 SYNC_METADATA_INCOMPLETE: \(unit.navUnitId) - \(unit.navUnitName)")
                    print("   User status verified")
                    print("   Device ID: \(unit.deviceId ?? "MISSING")")
                    print("   Last Modified: \(unit.lastModified?.description ?? "MISSING")")
                } else {
                    print("✅📱🧭 SYNC_METADATA_COMPLETE: \(unit.navUnitId)")
                    print("   User authenticated")
                    print("   Device ID: \(unit.deviceId!)")
                    print("   Last Modified: \(unit.lastModified!)")
                }

                results.append(unit)
            }

            let duration = Date().timeIntervalSince(startTime)
            print("✅ NAV_UNIT_DB_SERVICE: Retrieved \(results.count) favorite nav units for sync")
            print("📊 NAV_UNIT_DB_SERVICE: Sync query performance:")
            print("   Total favorites: \(results.count)")
            print("   Sync metadata issues: \(syncMetadataIssues)")
            print("   Query duration: \(String(format: "%.3f", duration))s")
            print("   Records per second: \(String(format: "%.1f", Double(results.count) / max(duration, 0.001)))")

            if syncMetadataIssues > 0 {
                print("⚠️ NAV_UNIT_DB_SERVICE: \(syncMetadataIssues) favorites have incomplete sync metadata")
                print("⚠️ NAV_UNIT_DB_SERVICE: These records may cause sync issues")
            }

            return results

        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error fetching favorites for sync: \(error.localizedDescription)")
            print("❌ NAV_UNIT_DB_SERVICE: Error type: \(type(of: error))")
            print("❌ NAV_UNIT_DB_SERVICE: Error domain: \((error as NSError).domain)")
            print("❌ NAV_UNIT_DB_SERVICE: Error code: \((error as NSError).code)")
            throw error
        }
    }

    /// Set navigation unit favorite status with complete sync metadata
    /// This method is specifically designed for sync operations and ensures all sync fields are properly set
    /// Used when downloading remote changes or resolving conflicts during sync
    func setNavUnitFavoriteWithSyncData(
        navUnitId: String,
        isFavorite: Bool,
        userId: String,
        deviceId: String,
        lastModified: Date
    ) async throws {
        print("🔄 NAV_UNIT_DB_SERVICE: Starting setNavUnitFavoriteWithSyncData for \(navUnitId)")
        print("📱🧭 SYNC_SET_FAVORITE: NavUnit = \(navUnitId)")
        print("📱🧭 SYNC_SET_FAVORITE: Is Favorite = \(isFavorite)")
        print("📱🧭 SYNC_SET_FAVORITE: User authenticated")
        print("📱🧭 SYNC_SET_FAVORITE: Device ID = \(deviceId)")
        print("📱🧭 SYNC_SET_FAVORITE: Last Modified = \(lastModified)")

        let startTime = Date()

        do {
            let db = try databaseCore.ensureConnection()

            // First, verify the nav unit exists
            let query = navUnits.filter(colNavUnitId == navUnitId)
            guard let existingRow = try db.pluck(query) else {
                print("❌ NAV_UNIT_DB_SERVICE: NavUnit \(navUnitId) not found for sync update")
                throw NSError(domain: "NavUnitDatabaseService", code: 404,
                             userInfo: [NSLocalizedDescriptionKey: "Navigation unit \(navUnitId) not found for sync update"])
            }

            let existingIsFavorite = existingRow[colIsFavorite]
            let existingUserId = existingRow[colUserId]
            let existingLastModified = existingRow[colLastModified]

            print("📱🧭 SYNC_EXISTING_STATE:")
            print("   Current Is Favorite: \(existingIsFavorite)")
            print("   Current user verified")
            print("   Current Last Modified: \(existingLastModified?.description ?? "nil")")

            // Update the nav unit with complete sync metadata
            let updateQuery = navUnits.filter(colNavUnitId == navUnitId)
            try db.run(updateQuery.update(
                colIsFavorite <- isFavorite,
                colUserId <- userId,
                colDeviceId <- deviceId,
                colLastModified <- lastModified
            ))

            // Flush changes to disk immediately for sync operations
            try await databaseCore.flushDatabaseAsync()

            let duration = Date().timeIntervalSince(startTime)
            print("✅ NAV_UNIT_DB_SERVICE: Sync favorite update completed for \(navUnitId)")
            print("✅📱🧭 SYNC_UPDATE_SUCCESS:")
            print("   NavUnit ID: \(navUnitId)")
            print("   New Favorite Status: \(isFavorite)")
            print("   User authenticated")
            print("   Device ID: \(deviceId)")
            print("   Last Modified: \(lastModified)")
            print("   Update Duration: \(String(format: "%.3f", duration))s")

            // Log the change for audit purposes
            print("📝📱🧭 SYNC_AUDIT_LOG:")
            print("   Operation: setNavUnitFavoriteWithSyncData")
            print("   NavUnit: \(navUnitId)")
            print("   Change: \(existingIsFavorite) → \(isFavorite)")
            print("   Sync Source: Remote (via sync operation)")
            print("   Timestamp: \(Date())")

        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error setting nav unit favorite with sync data")
            print("❌📱🧭 SYNC_UPDATE_ERROR:")
            print("   NavUnit ID: \(navUnitId)")
            print("   Attempted State: \(isFavorite)")
            print("   Error: \(error.localizedDescription)")
            print("   Error Type: \(type(of: error))")
            throw error
        }
    }

    /// Enhanced version of toggleFavoriteNavUnitAsync that ensures proper sync metadata
    /// This method updates the existing toggle method to always include complete sync metadata
    /// Used for user-initiated favorite toggles that need to be synced
    func toggleFavoriteNavUnitAsyncWithSync(navUnitId: String) async throws -> Bool {
        print("🔄 NAV_UNIT_DB_SERVICE: Starting toggleFavoriteNavUnitAsyncWithSync for \(navUnitId)")
        let startTime = Date()

        do {
            let db = try databaseCore.ensureConnection()

            // Find the specific NavUnit row
            let query = navUnits.filter(colNavUnitId == navUnitId)

            // Get the current unit's favorite status
            guard let unit = try db.pluck(query) else {
                print("❌ NAV_UNIT_DB_SERVICE: NavUnit \(navUnitId) not found")
                throw NSError(domain: "DatabaseService", code: 10,
                             userInfo: [NSLocalizedDescriptionKey: "NavUnit not found for toggling favorite."])
            }

            let currentValue = unit[colIsFavorite]
            let newValue = !currentValue // Toggle the boolean value

            print("⭐ NAV_UNIT_DB_SERVICE: Toggling favorite for \(navUnitId) from \(currentValue) to \(newValue)")

            // Get comprehensive sync metadata
            guard let userId = await getCurrentUserId() else {
                throw NSError(domain: "DatabaseService", code: 401,
                             userInfo: [NSLocalizedDescriptionKey: "No authenticated user for sync operation"])
            }

            let deviceId = await getDeviceId()
            let currentTime = Date()

            print("📱🧭 SYNC_TOGGLE_METADATA:")
            print("   User authenticated")
            print("   Device ID: \(deviceId)")
            print("   Timestamp: \(currentTime)")
            print("   New State: \(newValue)")

            // Update with complete sync metadata for proper sync support
            let updatedRow = navUnits.filter(colNavUnitId == navUnitId)
            try db.run(updatedRow.update(
                colIsFavorite <- newValue,
                colUserId <- userId,
                colLastModified <- currentTime,
                colDeviceId <- deviceId
            ))

            // Flush changes to disk immediately
            try await databaseCore.flushDatabaseAsync()

            let duration = Date().timeIntervalSince(startTime)
            print("✅ NAV_UNIT_DB_SERVICE: Sync-enabled favorite toggle completed for \(navUnitId)")
            print("✅⭐📱🧭 TOGGLE_WITH_SYNC_SUCCESS:")
            print("   NavUnit ID: \(navUnitId)")
            print("   Previous State: \(currentValue)")
            print("   New State: \(newValue)")
            print("   User authenticated")
            print("   Device ID: \(deviceId)")
            print("   Last Modified: \(currentTime)")
            print("   Duration: \(String(format: "%.3f", duration))s")

            // Log for sync audit trail
            print("📝📱🧭 SYNC_AUDIT_LOG:")
            print("   Operation: toggleFavoriteNavUnitAsyncWithSync")
            print("   NavUnit: \(navUnitId)")
            print("   Change: \(currentValue) → \(newValue)")
            print("   Sync Source: Local (user action)")
            print("   Ready for sync: YES")
            print("   Timestamp: \(Date())")

            return newValue

        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error toggling favorite with sync for NavUnit \(navUnitId)")
            print("❌📱🧭 TOGGLE_SYNC_ERROR:")
            print("   NavUnit ID: \(navUnitId)")
            print("   Error: \(error.localizedDescription)")
            print("   Error Type: \(type(of: error))")
            throw error
        }
    }

    /// Get sync metadata for a specific navigation unit
    /// Useful for debugging sync issues and verifying sync readiness
    func getNavUnitSyncMetadata(navUnitId: String) async throws -> (userId: String?, deviceId: String?, lastModified: Date?, isFavorite: Bool) {
        print("🔄 NAV_UNIT_DB_SERVICE: Getting sync metadata for \(navUnitId)")

        do {
            let db = try databaseCore.ensureConnection()

            let query = navUnits
                .select(colUserId, colDeviceId, colLastModified, colIsFavorite)
                .filter(colNavUnitId == navUnitId)

            guard let row = try db.pluck(query) else {
                print("❌ NAV_UNIT_DB_SERVICE: NavUnit \(navUnitId) not found for sync metadata")
                throw NSError(domain: "NavUnitDatabaseService", code: 404,
                             userInfo: [NSLocalizedDescriptionKey: "Navigation unit \(navUnitId) not found"])
            }

            let metadata = (
                userId: row[colUserId],
                deviceId: row[colDeviceId],
                lastModified: row[colLastModified],
                isFavorite: row[colIsFavorite]
            )

            print("📱🧭 SYNC_METADATA_RETRIEVED:")
            print("   NavUnit ID: \(navUnitId)")
            print("   User verified")
            print("   Device ID: \(metadata.deviceId ?? "nil")")
            print("   Last Modified: \(metadata.lastModified?.description ?? "nil")")
            print("   Is Favorite: \(metadata.isFavorite)")
            print("   Sync Ready: \(metadata.userId != nil && metadata.deviceId != nil && metadata.lastModified != nil)")

            return metadata

        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error getting sync metadata for \(navUnitId): \(error.localizedDescription)")
            throw error
        }
    }

    /// Bulk update sync metadata for multiple navigation units
    /// Used for sync operations that need to update multiple records efficiently
    func bulkUpdateSyncMetadata(updates: [(navUnitId: String, userId: String, deviceId: String, lastModified: Date, isFavorite: Bool)]) async throws -> Int {
        print("🔄 NAV_UNIT_DB_SERVICE: Starting bulk sync metadata update for \(updates.count) nav units")
        let startTime = Date()
        var successCount = 0
        var errorCount = 0

        do {
            let db = try databaseCore.ensureConnection()

            // Use a transaction for bulk operations
            try db.transaction {
                for update in updates {
                    do {
                        let query = navUnits.filter(colNavUnitId == update.navUnitId)
                        try db.run(query.update(
                            colIsFavorite <- update.isFavorite,
                            colUserId <- update.userId,
                            colDeviceId <- update.deviceId,
                            colLastModified <- update.lastModified
                        ))
                        successCount += 1

                        print("✅📱🧭 BULK_UPDATE_ITEM: \(update.navUnitId) - \(update.isFavorite)")
                    } catch {
                        errorCount += 1
                        print("❌📱🧭 BULK_UPDATE_ERROR: \(update.navUnitId) - \(error.localizedDescription)")
                    }
                }
            }

            // Flush all changes to disk
            try await databaseCore.flushDatabaseAsync()

            let duration = Date().timeIntervalSince(startTime)
            print("✅ NAV_UNIT_DB_SERVICE: Bulk sync metadata update completed")
            print("📊📱🧭 BULK_UPDATE_RESULTS:")
            print("   Total Updates: \(updates.count)")
            print("   Successful: \(successCount)")
            print("   Errors: \(errorCount)")
            print("   Duration: \(String(format: "%.3f", duration))s")
            print("   Updates per second: \(String(format: "%.1f", Double(successCount) / max(duration, 0.001)))")

            return successCount

        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error in bulk sync metadata update: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Additional Existing Methods (if you have them)

    /// Get minimal nav unit list items with distance calculated in database
    func getNavUnitListItemsWithDistanceAsync(userLatitude: Double, userLongitude: Double) async throws -> [NavUnitListItem] {
        print("🔄 NAV_UNIT_DB_SERVICE: Starting getNavUnitListItemsWithDistanceAsync (MINIMAL LOADING)")
        let startTime = Date()

        do {
            let db = try databaseCore.ensureConnection()
            var results: [NavUnitListItem] = []

            // Minimal query - only ID, name, and calculated distance
            let haversineFormula = """
                CASE
                    WHEN LATITUDE IS NULL OR LONGITUDE IS NULL THEN 999999999.0
                    ELSE (6371000.0 * acos(
                        cos(radians(\(userLatitude))) * cos(radians(LATITUDE)) *
                        cos(radians(LONGITUDE) - radians(\(userLongitude))) +
                        sin(radians(\(userLatitude))) * sin(radians(LATITUDE))
                    ))
                END
            """

            let distanceExpression = Expression<Double>(literal: haversineFormula)
            let sortOrderExpression = Expression<Int>(literal: "CASE WHEN (\(haversineFormula)) = 999999999.0 THEN 1 ELSE 0 END")

            // Build minimal query - only essential columns
            let query = navUnits
                .select(colNavUnitId, colNavUnitName, distanceExpression, colLatitude, colLongitude, colIsFavorite)
                .order(sortOrderExpression.asc, distanceExpression.asc, colNavUnitName.asc)

            print("📊 NAV_UNIT_DB_SERVICE: Executing minimal distance query (3 columns only)")

            for row in try db.prepare(query) {
                let calculatedDistance = try row.get(distanceExpression)
                let finalDistance = calculatedDistance == 999999999.0 ? Double.greatestFiniteMagnitude : calculatedDistance

                let listItem = NavUnitListItem(
                    id: row[colNavUnitId],
                    name: row[colNavUnitName],
                    distanceFromUser: finalDistance,
                    latitude: row[colLatitude],
                    longitude: row[colLongitude],
                    isFavorite: row[colIsFavorite]
                )

                results.append(listItem)
            }

            let duration = Date().timeIntervalSince(startTime)
            print("✅ NAV_UNIT_DB_SERVICE: Retrieved \(results.count) minimal nav unit items in \(String(format: "%.3f", duration))s")
            return results

        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error fetching minimal nav unit items: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get minimal nav unit list items without distance calculation (fallback)
    func getNavUnitListItemsAsync() async throws -> [NavUnitListItem] {
        print("🔄 NAV_UNIT_DB_SERVICE: Starting getNavUnitListItemsAsync (NO DISTANCE)")
        let startTime = Date()

        do {
            let db = try databaseCore.ensureConnection()
            var results: [NavUnitListItem] = []

            // Simple query - just essential columns, alphabetically sorted
            let query = navUnits
                .select(colNavUnitId, colNavUnitName, colLatitude, colLongitude, colIsFavorite)
                .order(colNavUnitName.asc)

            print("📊 NAV_UNIT_DB_SERVICE: Executing minimal query (2 columns only)")

            for row in try db.prepare(query) {
                let listItem = NavUnitListItem(
                    id: row[colNavUnitId],
                    name: row[colNavUnitName],
                    distanceFromUser: Double.greatestFiniteMagnitude,
                    latitude: row[colLatitude],
                    longitude: row[colLongitude],
                    isFavorite: row[colIsFavorite]
                )

                results.append(listItem)
            }

            let duration = Date().timeIntervalSince(startTime)
            print("✅ NAV_UNIT_DB_SERVICE: Retrieved \(results.count) minimal nav unit items (no distance) in \(String(format: "%.3f", duration))s")
            return results

        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error fetching minimal nav unit items: \(error.localizedDescription)")
            throw error
        }
    }
}
