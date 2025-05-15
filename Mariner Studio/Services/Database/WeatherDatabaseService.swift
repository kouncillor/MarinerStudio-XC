import Foundation
#if canImport(SQLite)
import SQLite
#endif

class WeatherDatabaseService {
    // MARK: - Table Definitions
    private let moonPhases = Table("MoonPhase")
    private let weatherLocationFavorites = Table("WeatherLocationFavorite")
    
    // MARK: - Column Definitions - MoonPhase
    private let colDate = Expression<String>("Date")
    private let colPhase = Expression<String>("Phase")
    
    // MARK: - Column Definitions - WeatherLocationFavorite
    private let colLatitude = Expression<Double>("Latitude")
    private let colLongitude = Expression<Double>("Longitude")
    private let colLocationName = Expression<String>("LocationName")
    private let colIsFavorite = Expression<Bool>("is_favorite")
    private let colCreatedAt = Expression<Date>("CreatedAt")
    
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
            
            let query = moonPhases.filter(colDate == date)
            
            if let row = try db.pluck(query) {
                let phase = MoonPhase(
                    date: row[colDate],
                    phase: row[colPhase]
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
            
            try db.run(weatherLocationFavorites.create(ifNotExists: true) { table in
                table.column(colLatitude)
                table.column(colLongitude)
                table.column(colLocationName)
                table.column(colIsFavorite)
                table.column(colCreatedAt)
                table.primaryKey(colLatitude, colLongitude)
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
            
            let query = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
            
            if let favorite = try db.pluck(query) {
                return favorite[colIsFavorite]
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
            
            let query = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
            
            if let favorite = try db.pluck(query) {
                let currentValue = favorite[colIsFavorite]
                let newValue = !currentValue
                
                let updatedRow = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
                try db.run(updatedRow.update(
                    colIsFavorite <- newValue,
                    colLocationName <- locationName
                ))
                
                try await databaseCore.flushDatabaseAsync()
                return newValue
            } else {
                try db.run(weatherLocationFavorites.insert(
                    colLatitude <- latitude,
                    colLongitude <- longitude,
                    colLocationName <- locationName,
                    colIsFavorite <- true,
                    colCreatedAt <- Date()
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
            
            let query = weatherLocationFavorites.filter(colIsFavorite == true).order(colCreatedAt.desc)
            var results: [WeatherLocationFavorite] = []
            
            for row in try db.prepare(query) {
                let favorite = WeatherLocationFavorite(
                    latitude: row[colLatitude],
                    longitude: row[colLongitude],
                    locationName: row[colLocationName],
                    isFavorite: row[colIsFavorite],
                    createdAt: row[colCreatedAt]
                )
                results.append(favorite)
            }
            
            return results
        } catch {
            print("Error fetching favorite weather locations: \(error.localizedDescription)")
            throw error
        }
    }
    
    
    
    
    // Add this method to WeatherDatabaseService
    func updateWeatherLocationNameAsync(latitude: Double, longitude: Double, newName: String) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
            
            if let favorite = try db.pluck(query) {
                let updatedRow = weatherLocationFavorites.filter(colLatitude == latitude && colLongitude == longitude)
                try db.run(updatedRow.update(
                    colLocationName <- newName
                ))
                
                try await databaseCore.flushDatabaseAsync()
                return true
            } else {
                return false
            }
        } catch {
            print("Error updating weather location name: \(error.localizedDescription)")
            return false
        }
    }
    
    
    
    
    
    
}
