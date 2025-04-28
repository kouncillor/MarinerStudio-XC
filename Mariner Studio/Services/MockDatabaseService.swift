import Foundation
import Combine

/// Mock implementation of DatabaseService for testing
class MockDatabaseService: ObservableObject, DatabaseService {
    // In-memory storage for favorites
    private var tideStationFavorites: [String: Bool] = [:]
    private var currentStationFavorites: [String: Bool] = [:]
    private var currentStationWithBinFavorites: [(String, Int, Bool)] = []
    
    // MARK: - Initialization
    func initializeAsync() async throws {
        // No initialization needed for mock
        print("Mock database initialized")
    }
    
    func getTableNamesAsync() async throws -> [String] {
        return ["MockTables"]
    }
    
    // MARK: - Tide Station Favorites
    func initializeTideStationFavoritesTableAsync() async throws {
        // No-op for mock
    }
    
    func isTideStationFavorite(id: String) async -> Bool {
        return tideStationFavorites[id] ?? false
    }
    
    func toggleTideStationFavorite(id: String) async -> Bool {
        let newValue = !(tideStationFavorites[id] ?? false)
        tideStationFavorites[id] = newValue
        return newValue
    }
    
    // MARK: - Current Station Favorites
    func initializeCurrentStationFavoritesTableAsync() async throws {
        // No-op for mock
    }
    
    func isCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        return currentStationWithBinFavorites.first(where: { $0.0 == id && $0.1 == bin })?.2 ?? false
    }
    
    func toggleCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        if let index = currentStationWithBinFavorites.firstIndex(where: { $0.0 == id && $0.1 == bin }) {
            let current = currentStationWithBinFavorites[index].2
            let newValue = !current
            currentStationWithBinFavorites[index] = (id, bin, newValue)
            return newValue
        } else {
            currentStationWithBinFavorites.append((id, bin, true))
            return true
        }
    }
    
    func isCurrentStationFavorite(id: String) async -> Bool {
        return currentStationFavorites[id] ?? false
    }
    
    func toggleCurrentStationFavorite(id: String) async -> Bool {
        let newValue = !(currentStationFavorites[id] ?? false)
        currentStationFavorites[id] = newValue
        return newValue
    }
    
    // MARK: - Navigation Units
    func getNavUnitsAsync() async throws -> [NavUnit] {
        return []
    }
    
    func toggleFavoriteNavUnitAsync(navUnitId: String) async throws -> Bool {
        return true
    }
    
    // MARK: - Tugs and Barges
    func getTugsAsync() async throws -> [Tug] {
        return []
    }
    
    func getBargesAsync() async throws -> [Barge] {
        return []
    }
    
    // MARK: - Personal Notes
    func getPersonalNotesAsync(navUnitId: String) async throws -> [PersonalNote] {
        return []
    }
    
    func addPersonalNoteAsync(note: PersonalNote) async throws -> Int {
        return 1
    }
    
    func updatePersonalNoteAsync(note: PersonalNote) async throws -> Int {
        return 1
    }
    
    func deletePersonalNoteAsync(noteId: Int) async throws -> Int {
        return 1
    }
    
    // MARK: - Change Recommendations
    func getChangeRecommendationsAsync(navUnitId: String) async throws -> [ChangeRecommendation] {
        return []
    }
    
    func addChangeRecommendationAsync(recommendation: ChangeRecommendation) async throws -> Int {
        return 1
    }
    
    func updateChangeRecommendationStatusAsync(recommendationId: Int, status: RecommendationStatus) async throws -> Int {
        return 1
    }
    
    // MARK: - Photos
    func initializePhotosTableAsync() async throws {
        // No-op for mock
    }
    
    func getNavUnitPhotosAsync(navUnitId: String) async throws -> [NavUnitPhoto] {
        return []
    }
    
    func addNavUnitPhotoAsync(photo: NavUnitPhoto) async throws -> Int {
        return 1
    }
    
    func deleteNavUnitPhotoAsync(photoId: Int) async throws -> Int {
        return 1
    }
    
    // MARK: - Tug Operations
    func initializeTugTablesAsync() async throws {
        // No-op for mock
    }
    
    func getTugPhotosAsync(tugId: String) async throws -> [TugPhoto] {
        return []
    }
    
    func addTugPhotoAsync(photo: TugPhoto) async throws -> Int {
        return 1
    }
    
    func deleteTugPhotoAsync(photoId: Int) async throws -> Int {
        return 1
    }
    
    func getTugNotesAsync(tugId: String) async throws -> [TugNote] {
        return []
    }
    
    func addTugNoteAsync(note: TugNote) async throws -> Int {
        return 1
    }
    
    func updateTugNoteAsync(note: TugNote) async throws -> Int {
        return 1
    }
    
    func deleteTugNoteAsync(noteId: Int) async throws -> Int {
        return 1
    }
    
    func getTugChangeRecommendationsAsync(tugId: String) async throws -> [TugChangeRecommendation] {
        return []
    }
    
    func addTugChangeRecommendationAsync(recommendation: TugChangeRecommendation) async throws -> Int {
        return 1
    }
    
    func updateTugChangeRecommendationStatusAsync(recommendationId: Int, status: RecommendationStatus) async throws -> Int {
        return 1
    }
    
    // MARK: - Barge Photos
    func initializeBargePhotosTableAsync() async throws {
        // No-op for mock
    }
    
    func getBargePhotosAsync(bargeId: String) async throws -> [BargePhoto] {
        return []
    }
    
    func addBargePhotoAsync(photo: BargePhoto) async throws -> Int {
        return 1
    }
    
    func deleteBargePhotoAsync(photoId: Int) async throws -> Int {
        return 1
    }
    
    // MARK: - Buoy Station Favorites
    func isBuoyStationFavoriteAsync(stationId: String) async -> Bool {
        return false
    }
    
    func toggleBuoyStationFavoriteAsync(stationId: String) async -> Bool {
        return true
    }
    
    // MARK: - Moon Phases
    func getMoonPhaseForDateAsync(date: String) async throws -> MoonPhase? {
        return nil
    }
    
    // MARK: - Weather Location Favorites
    func initializeWeatherLocationFavoritesTableAsync() async throws {
        // No-op for mock
    }
    
    func isWeatherLocationFavoriteAsync(latitude: Double, longitude: Double) async -> Bool {
        return false
    }
    
    func toggleWeatherLocationFavoriteAsync(latitude: Double, longitude: Double, locationName: String) async -> Bool {
        return true
    }
    
    func getFavoriteWeatherLocationsAsync() async throws -> [WeatherLocationFavorite] {
        return []
    }
}
