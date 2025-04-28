import Foundation
import Combine

// MARK: - Database Service Protocol
protocol DatabaseService {
    /// Initialize database connection and tables
    func initializeAsync() async throws
    
    /// Get all table names from the database
    func getTableNamesAsync() async throws -> [String]
    
    /// Initialize tide station favorites table
    func initializeTideStationFavoritesTableAsync() async throws
    
    /// Check if a tide station is marked as favorite
    func isTideStationFavorite(id: String) async -> Bool
    
    /// Toggle favorite status for a tide station
    func toggleTideStationFavorite(id: String) async -> Bool
    
    /// Initialize current station favorites table
    func initializeCurrentStationFavoritesTableAsync() async throws
    
    /// Check if a current station is marked as favorite
    func isCurrentStationFavorite(id: String, bin: Int) async -> Bool
    
    /// Toggle favorite status for a current station with bin
    func toggleCurrentStationFavorite(id: String, bin: Int) async -> Bool
    
    /// Check if a current station is marked as favorite (without bin)
    func isCurrentStationFavorite(id: String) async -> Bool
    
    /// Toggle favorite status for a current station (without bin)
    func toggleCurrentStationFavorite(id: String) async -> Bool
    
    /// Get all navigation units
    func getNavUnitsAsync() async throws -> [NavUnit]
    
    /// Toggle favorite status for a navigation unit
    func toggleFavoriteNavUnitAsync(navUnitId: String) async throws -> Bool
    
    /// Get all tugs
    func getTugsAsync() async throws -> [Tug]
    
    /// Get all barges
    func getBargesAsync() async throws -> [Barge]
    
    /// Get personal notes for a navigation unit
    func getPersonalNotesAsync(navUnitId: String) async throws -> [PersonalNote]
    
    /// Add a new personal note
    func addPersonalNoteAsync(note: PersonalNote) async throws -> Int
    
    /// Update an existing personal note
    func updatePersonalNoteAsync(note: PersonalNote) async throws -> Int
    
    /// Delete a personal note
    func deletePersonalNoteAsync(noteId: Int) async throws -> Int
    
    /// Get change recommendations for a navigation unit
    func getChangeRecommendationsAsync(navUnitId: String) async throws -> [ChangeRecommendation]
    
    /// Add a new change recommendation
    func addChangeRecommendationAsync(recommendation: ChangeRecommendation) async throws -> Int
    
    /// Update change recommendation status
    func updateChangeRecommendationStatusAsync(recommendationId: Int, status: RecommendationStatus) async throws -> Int
    
    /// Initialize photos table
    func initializePhotosTableAsync() async throws
    
    /// Get photos for a navigation unit
    func getNavUnitPhotosAsync(navUnitId: String) async throws -> [NavUnitPhoto]
    
    /// Add a new photo for a navigation unit
    func addNavUnitPhotoAsync(photo: NavUnitPhoto) async throws -> Int
    
    /// Delete a photo
    func deleteNavUnitPhotoAsync(photoId: Int) async throws -> Int

    
    /// Initialize barge photos table
    func initializeBargePhotosTableAsync() async throws
    
    /// Get photos for a barge
    func getBargePhotosAsync(bargeId: String) async throws -> [BargePhoto]
    
    /// Add a new photo for a barge
    func addBargePhotoAsync(photo: BargePhoto) async throws -> Int
    
    /// Delete a barge photo
    func deleteBargePhotoAsync(photoId: Int) async throws -> Int
    
    /// Check if a buoy station is marked as favorite
    func isBuoyStationFavoriteAsync(stationId: String) async -> Bool
    
    /// Toggle favorite status for a buoy station
    func toggleBuoyStationFavoriteAsync(stationId: String) async -> Bool
    
    /// Get moon phase for a specific date
    func getMoonPhaseForDateAsync(date: String) async throws -> MoonPhase?
    
    /// Initialize weather location favorites table
    func initializeWeatherLocationFavoritesTableAsync() async throws
    
    /// Check if a weather location is marked as favorite
    func isWeatherLocationFavoriteAsync(latitude: Double, longitude: Double) async -> Bool
    
    /// Toggle favorite status for a weather location
    func toggleWeatherLocationFavoriteAsync(latitude: Double, longitude: Double, locationName: String) async -> Bool
    
    /// Get all favorite weather locations
    func getFavoriteWeatherLocationsAsync() async throws -> [WeatherLocationFavorite]
}
