import Foundation
#if canImport(SQLite)
import SQLite
#endif

class WeatherDatabaseService {
    // MARK: - Properties
    private let databaseCore: DatabaseCore
    
    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }
    
    // MARK: - Moon Phase Methods
    
    // Get moon phase for a specific date
    func getMoonPhaseForDateAsync(date: String) async throws -> MoonPhase? {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = databaseCore.moonPhases.filter(databaseCore.colDate == date)
            
            if let row = try db.pluck(query) {
                let phase = MoonPhase(
                    date: row[databaseCore.colDate],
                    phase: row[databaseCore.colPhase]
                )
                print("Looking up moon phase for date: \(date)")
                print("Found: \(phase.phase)")
                
                return phase
            }
            
            print("Looking up moon phase for date: \(date)")
            print("Found: no phase")
            
            return nil
        } catch {
            print("Error getting moon phase: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Weather Location Methods
    
    // Initialize weather location favorites table
    func initializeWeatherLocationFavoritesTableAsync() async throws {
        do {
            let db = try databaseCore.ensureConnection()
            
            try db.run(databaseCore.weatherLocationFavorites.create(ifNotExists: true) { table in
                table.column(databaseCore.colLatitude)
                table.column(databaseCore.colLongitude)
                table.column(databaseCore.colLocationName)
                table.column(databaseCore.colIsFavorite)
                table.column(databaseCore.colCreatedAt)
                table.primaryKey(databaseCore.colLatitude, databaseCore.colLongitude)
            })
        } catch {
            print("Error initializing weather location favorites table: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Check if a weather location is marked as favorite
    func isWeatherLocationFavoriteAsync(latitude: Double, longitude: Double) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = databaseCore.weatherLocationFavorites.filter(databaseCore.colLatitude == latitude && databaseCore.colLongitude == longitude)
            
            if let favorite = try db.pluck(query) {
                return favorite[databaseCore.colIsFavorite]
            }
            return false
        } catch {
            print("Error checking weather location favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    // Toggle favorite status for a weather location
    func toggleWeatherLocationFavoriteAsync(latitude: Double, longitude: Double, locationName: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = databaseCore.weatherLocationFavorites.filter(databaseCore.colLatitude == latitude && databaseCore.colLongitude == longitude)
            
            if let favorite = try db.pluck(query) {
                let currentValue = favorite[databaseCore.colIsFavorite]
                let newValue = !currentValue
                
                let updatedRow = databaseCore.weatherLocationFavorites.filter(databaseCore.colLatitude == latitude && databaseCore.colLongitude == longitude)
                try db.run(updatedRow.update(
                    databaseCore.colIsFavorite <- newValue,
                    databaseCore.colLocationName <- locationName
                ))
                
                try await databaseCore.flushDatabaseAsync()
                return newValue
            } else {
                try db.run(databaseCore.weatherLocationFavorites.insert(
                    databaseCore.colLatitude <- latitude,
                    databaseCore.colLongitude <- longitude,
                    databaseCore.colLocationName <- locationName,
                    databaseCore.colIsFavorite <- true,
                    databaseCore.colCreatedAt <- Date()
                ))
                try await databaseCore.flushDatabaseAsync()
                return true
            }
        } catch {
            print("Error toggling weather location favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    // Get all favorite weather locations
    func getFavoriteWeatherLocationsAsync() async throws -> [WeatherLocationFavorite] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = databaseCore.weatherLocationFavorites.filter(databaseCore.colIsFavorite == true).order(databaseCore.colCreatedAt.desc)
            var results: [WeatherLocationFavorite] = []
            
            for row in try db.prepare(query) {
                let favorite = WeatherLocationFavorite(
                    latitude: row[databaseCore.colLatitude],
                    longitude: row[databaseCore.colLongitude],
                    locationName: row[databaseCore.colLocationName],
                    isFavorite: row[databaseCore.colIsFavorite],
                    createdAt: row[databaseCore.colCreatedAt]
                )
                results.append(favorite)
            }
            
            return results
        } catch {
            print("Error fetching favorite weather locations: \(error.localizedDescription)")
            throw error
        }
    }
}
