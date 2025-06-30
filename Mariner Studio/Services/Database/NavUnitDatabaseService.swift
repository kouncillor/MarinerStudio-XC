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
    
    // Main table columns - including the new sync columns you added
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
    
    // MARK: - Core Functions
    
    /// Get all navigation units from the main table
    func getNavUnitsAsync() async throws -> [NavUnit] {
        print("🔄 NAV_UNIT_DB_SERVICE: Starting getNavUnitsAsync")
        let startTime = Date()
        
        do {
            let db = try databaseCore.ensureConnection()
            var results: [NavUnit] = []
            var count = 0
            
            print("📊 NAV_UNIT_DB_SERVICE: Querying NavUnits table")
            
            for row in try db.prepare(navUnits.order(colNavUnitName.asc)) {
                let latValue = row[colLatitude]
                let lonValue = row[colLongitude]
                
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
                    isFavorite: row[colIsFavorite]
                )
                results.append(unit)
                count += 1
            }

            let duration = Date().timeIntervalSince(startTime)
            print("✅ NAV_UNIT_DB_SERVICE: Retrieved \(results.count) nav units in \(String(format: "%.3f", duration))s")
            return results
        } catch {
            print("❌ NAV_UNIT_DB_SERVICE: Error fetching nav units: \(error.localizedDescription)")
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
}
