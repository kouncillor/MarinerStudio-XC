import Foundation
#if canImport(SQLite)
import SQLite
#endif

class DatabaseServiceImpl: DatabaseService, ObservableObject {
    // MARK: - Singleton
    private static var _shared: DatabaseServiceImpl?
    
    /// Provides access to the singleton instance
    static var shared: DatabaseServiceImpl {
        if _shared == nil {
            _shared = DatabaseServiceImpl()
        }
        return _shared!
    }
    
    // MARK: - Services
    private let databaseCore: DatabaseCore
    private let tideStationService: TideStationDatabaseService
    private let currentStationService: CurrentStationDatabaseService
    private let navUnitService: NavUnitDatabaseService
    private let vesselService: VesselDatabaseService
    private let photoService: PhotoDatabaseService
    private let buoyService: BuoyDatabaseService
    private let weatherService: WeatherDatabaseService
    
    // MARK: - Singleton
    private static let sharedInstance = DatabaseServiceImpl()
        
    /// Provides access to the singleton instance
    static func getInstance() -> DatabaseServiceImpl {
        return sharedInstance
    }

    // MARK: - Initialization
    private init() {
        print("📊 DatabaseServiceImpl singleton being initialized")
        
        // Initialize services
        databaseCore = DatabaseCore()
        tideStationService = TideStationDatabaseService(databaseCore: databaseCore)
        currentStationService = CurrentStationDatabaseService(databaseCore: databaseCore)
        navUnitService = NavUnitDatabaseService(databaseCore: databaseCore)
        vesselService = VesselDatabaseService(databaseCore: databaseCore)
        photoService = PhotoDatabaseService(databaseCore: databaseCore)
        buoyService = BuoyDatabaseService(databaseCore: databaseCore)
        weatherService = WeatherDatabaseService(databaseCore: databaseCore)
    }

    // For testing purposes
    public convenience init(forTesting: Bool) {
        self.init()
        if forTesting {
            print("📊 Creating test instance of DatabaseServiceImpl")
        }
    }
    
    // MARK: - DatabaseService Protocol Implementation
    
    /// Initialize database connection and tables
    public func initializeAsync() async throws {
        try await databaseCore.initializeAsync()
        
        // Initialize tables
        try await tideStationService.initializeTideStationFavoritesTableAsync()
        try await currentStationService.initializeCurrentStationFavoritesTableAsync()
        try await photoService.initializePhotosTableAsync()
        try await photoService.initializeBargePhotosTableAsync()
        try await weatherService.initializeWeatherLocationFavoritesTableAsync()
        
        print("📊 Tables initialized")
        
        // Test database operations to verify connection
        try await databaseCore.checkConnectionWithTestQuery()
        
        let tableNames = try await databaseCore.getTableNamesAsync()
        print("📊 Tables in the database: \(tableNames.joined(separator: ", "))")
    }
    
    /// Get all table names from the database
    public func getTableNamesAsync() async throws -> [String] {
        return try await databaseCore.getTableNamesAsync()
    }
    
    // MARK: - Tide Station Methods
    
    /// Initialize tide station favorites table
    public func initializeTideStationFavoritesTableAsync() async throws {
        try await tideStationService.initializeTideStationFavoritesTableAsync()
    }
    
    /// Check if a tide station is marked as favorite
    public func isTideStationFavorite(id: String) async -> Bool {
        return await tideStationService.isTideStationFavorite(id: id)
    }
    
    /// Toggle favorite status for a tide station
    public func toggleTideStationFavorite(id: String) async -> Bool {
        return await tideStationService.toggleTideStationFavorite(id: id)
    }
    
    // MARK: - Current Station Methods
    
    /// Initialize current station favorites table
    public func initializeCurrentStationFavoritesTableAsync() async throws {
        try await currentStationService.initializeCurrentStationFavoritesTableAsync()
    }
    
    /// Check if a current station is marked as favorite
    public func isCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        return await currentStationService.isCurrentStationFavorite(id: id, bin: bin)
    }
    
    /// Toggle favorite status for a current station with bin
    public func toggleCurrentStationFavorite(id: String, bin: Int) async -> Bool {
        return await currentStationService.toggleCurrentStationFavorite(id: id, bin: bin)
    }
    
    /// Check if a current station is marked as favorite (without bin)
    public func isCurrentStationFavorite(id: String) async -> Bool {
        return await currentStationService.isCurrentStationFavorite(id: id)
    }
    
    /// Toggle favorite status for a current station (without bin)
    public func toggleCurrentStationFavorite(id: String) async -> Bool {
        return await currentStationService.toggleCurrentStationFavorite(id: id)
    }
    
    // MARK: - Nav Unit Methods
    
    /// Get all navigation units
    public func getNavUnitsAsync() async throws -> [NavUnit] {
        return try await navUnitService.getNavUnitsAsync()
    }
    
    /// Toggle favorite status for a navigation unit
    public func toggleFavoriteNavUnitAsync(navUnitId: String) async throws -> Bool {
        return try await navUnitService.toggleFavoriteNavUnitAsync(navUnitId: navUnitId)
    }
    
    // MARK: - Vessel Methods (Tugs and Barges)
    
    /// Get all tugs
    public func getTugsAsync() async throws -> [Tug] {
        return try await vesselService.getTugsAsync()
    }
    
    /// Get all barges
    public func getBargesAsync() async throws -> [Barge] {
        return try await vesselService.getBargesAsync()
    }
    
    // MARK: - Personal Notes Methods
    
    /// Get personal notes for a navigation unit
    public func getPersonalNotesAsync(navUnitId: String) async throws -> [PersonalNote] {
        return try await navUnitService.getPersonalNotesAsync(navUnitId: navUnitId)
    }
    
    /// Add a new personal note
    public func addPersonalNoteAsync(note: PersonalNote) async throws -> Int {
        return try await navUnitService.addPersonalNoteAsync(note: note)
    }
    
    /// Update an existing personal note
    public func updatePersonalNoteAsync(note: PersonalNote) async throws -> Int {
        return try await navUnitService.updatePersonalNoteAsync(note: note)
    }
    
    /// Delete a personal note
    public func deletePersonalNoteAsync(noteId: Int) async throws -> Int {
        return try await navUnitService.deletePersonalNoteAsync(noteId: noteId)
    }
    
    // MARK: - Change Recommendation Methods
    
    /// Get change recommendations for a navigation unit
    public func getChangeRecommendationsAsync(navUnitId: String) async throws -> [ChangeRecommendation] {
        return try await navUnitService.getChangeRecommendationsAsync(navUnitId: navUnitId)
    }
    
    /// Add a new change recommendation
    public func addChangeRecommendationAsync(recommendation: ChangeRecommendation) async throws -> Int {
        return try await navUnitService.addChangeRecommendationAsync(recommendation: recommendation)
    }
    
    /// Update change recommendation status
    public func updateChangeRecommendationStatusAsync(recommendationId: Int, status: RecommendationStatus) async throws -> Int {
        return try await navUnitService.updateChangeRecommendationStatusAsync(recommendationId: recommendationId, status: status)
    }
    
    // MARK: - Photo Methods
    
    /// Initialize photos table
    public func initializePhotosTableAsync() async throws {
        try await photoService.initializePhotosTableAsync()
    }
    
    /// Get photos for a navigation unit
    public func getNavUnitPhotosAsync(navUnitId: String) async throws -> [NavUnitPhoto] {
        return try await photoService.getNavUnitPhotosAsync(navUnitId: navUnitId)
    }
    
    /// Add a new photo for a navigation unit
    public func addNavUnitPhotoAsync(photo: NavUnitPhoto) async throws -> Int {
        return try await photoService.addNavUnitPhotoAsync(photo: photo)
    }
    
    /// Delete a photo
    public func deleteNavUnitPhotoAsync(photoId: Int) async throws -> Int {
        return try await photoService.deleteNavUnitPhotoAsync(photoId: photoId)
    }
    
    // MARK: - Barge Photo Methods
    
    /// Initialize barge photos table
    public func initializeBargePhotosTableAsync() async throws {
        try await photoService.initializeBargePhotosTableAsync()
    }
    
    /// Get photos for a barge
    public func getBargePhotosAsync(bargeId: String) async throws -> [BargePhoto] {
        return try await photoService.getBargePhotosAsync(bargeId: bargeId)
    }
    
    /// Add a new photo for a barge
    public func addBargePhotoAsync(photo: BargePhoto) async throws -> Int {
        return try await photoService.addBargePhotoAsync(photo: photo)
    }
    
    /// Delete a barge photo
    public func deleteBargePhotoAsync(photoId: Int) async throws -> Int {
        return try await photoService.deleteBargePhotoAsync(photoId: photoId)
    }
    
    // MARK: - Buoy Methods
    
    /// Check if a buoy station is marked as favorite
    public func isBuoyStationFavoriteAsync(stationId: String) async -> Bool {
        return await buoyService.isBuoyStationFavoriteAsync(stationId: stationId)
    }
    
    /// Toggle favorite status for a buoy station
    public func toggleBuoyStationFavoriteAsync(stationId: String) async -> Bool {
        return await buoyService.toggleBuoyStationFavoriteAsync(stationId: stationId)
    }
    
    // MARK: - Weather Methods
    
    /// Get moon phase for a specific date
    public func getMoonPhaseForDateAsync(date: String) async throws -> MoonPhase? {
        return try await weatherService.getMoonPhaseForDateAsync(date: date)
    }
    
    /// Initialize weather location favorites table
    public func initializeWeatherLocationFavoritesTableAsync() async throws {
        try await weatherService.initializeWeatherLocationFavoritesTableAsync()
    }
    
    /// Check if a weather location is marked as favorite
    public func isWeatherLocationFavoriteAsync(latitude: Double, longitude: Double) async -> Bool {
        return await weatherService.isWeatherLocationFavoriteAsync(latitude: latitude, longitude: longitude)
    }
    
    /// Toggle favorite status for a weather location
    public func toggleWeatherLocationFavoriteAsync(latitude: Double, longitude: Double, locationName: String) async -> Bool {
        return await weatherService.toggleWeatherLocationFavoriteAsync(latitude: latitude, longitude: longitude, locationName: locationName)
    }
    
    /// Get all favorite weather locations
    public func getFavoriteWeatherLocationsAsync() async throws -> [WeatherLocationFavorite] {
        return try await weatherService.getFavoriteWeatherLocationsAsync()
    }
}
