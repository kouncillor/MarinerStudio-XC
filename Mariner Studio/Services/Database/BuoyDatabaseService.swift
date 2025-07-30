import Foundation
#if canImport(SQLite)
import SQLite
#endif

class BuoyDatabaseService {
    // MARK: - Table Definitions
    private let buoyStationFavorites = Table("BuoyStationFavorites")

    // MARK: - Column Definitions
    private let colStationId = Expression<String>("station_id")
    private let colIsFavorite = Expression<Bool>("is_favorite")

    // MARK: - Properties
    private let databaseCore: DatabaseCore

    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }

    // MARK: - Methods

    // Check if a buoy station is marked as favorite
    func isBuoyStationFavoriteAsync(stationId: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()

            let query = buoyStationFavorites.filter(colStationId == stationId)

            if let favorite = try db.pluck(query) {
                return favorite[colIsFavorite]
            }
            return false
        } catch {
            print("Error checking buoy station favorite: \(error.localizedDescription)")
            return false
        }
    }

    // Toggle favorite status for a buoy station
    func toggleBuoyStationFavoriteAsync(stationId: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()

            let query = buoyStationFavorites.filter(colStationId == stationId)

            if let favorite = try db.pluck(query) {
                let currentValue = favorite[colIsFavorite]
                let newValue = !currentValue

                let updatedRow = buoyStationFavorites.filter(colStationId == stationId)
                try db.run(updatedRow.update(colIsFavorite <- newValue))

                try await databaseCore.flushDatabaseAsync()
                return newValue
            } else {
                try db.run(buoyStationFavorites.insert(
                    colStationId <- stationId,
                    colIsFavorite <- true
                ))
                try await databaseCore.flushDatabaseAsync()
                return true
            }
        } catch {
            print("Error toggling buoy station favorite: \(error.localizedDescription)")
            return false
        }
    }
}
