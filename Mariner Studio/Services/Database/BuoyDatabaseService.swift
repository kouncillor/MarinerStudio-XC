import Foundation
#if canImport(SQLite)
import SQLite
#endif

class BuoyDatabaseService {
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
            
            let query = databaseCore.buoyStationFavorites.filter(databaseCore.colStationId == stationId)
            
            if let favorite = try db.pluck(query) {
                return favorite[databaseCore.colIsFavorite]
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
            
            let query = databaseCore.buoyStationFavorites.filter(databaseCore.colStationId == stationId)
            
            if let favorite = try db.pluck(query) {
                let currentValue = favorite[databaseCore.colIsFavorite]
                let newValue = !currentValue
                
                let updatedRow = databaseCore.buoyStationFavorites.filter(databaseCore.colStationId == stationId)
                try db.run(updatedRow.update(databaseCore.colIsFavorite <- newValue))
                
                try await databaseCore.flushDatabaseAsync()
                return newValue
            } else {
                try db.run(databaseCore.buoyStationFavorites.insert(
                    databaseCore.colStationId <- stationId,
                    databaseCore.colIsFavorite <- true
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
