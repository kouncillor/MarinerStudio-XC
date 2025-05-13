import Foundation
import SwiftUI
import CoreLocation

// This class will hold our service instances
class ServiceProvider: ObservableObject {
    // MARK: - Core Services
    let databaseCore: DatabaseCore
    let locationService: LocationService
    
    // MARK: - Database Services
    let tideStationService: TideStationDatabaseService
    let currentStationService: CurrentStationDatabaseService
    let navUnitService: NavUnitDatabaseService
    let vesselService: VesselDatabaseService
    let photoService: PhotoDatabaseService
    let buoyService: BuoyDatabaseService
    let weatherService: WeatherDatabaseService
    
    // MARK: - Weather Services
    let openMeteoService: WeatherService
    let geocodingService: GeocodingService
    let currentLocalWeatherService: CurrentLocalWeatherService
    
    // MARK: - Added Services for Nav Unit Details
    let navUnitFtpService: NavUnitFtpService
    let imageCacheService: ImageCacheService
    let favoritesService: FavoritesService
    
    // MARK: - Initialization
    init(locationService: LocationService? = nil) {
        // --- Initialize Core Services ---
        
        // Initialize DatabaseCore
        self.databaseCore = DatabaseCore()
        print("📦 ServiceProvider: Initialized DatabaseCore.")
        
        // Initialize LocationService
        if let providedLocationService = locationService {
            self.locationService = providedLocationService
            print("📦 ServiceProvider: Initialized with provided LocationService.")
        } else {
            self.locationService = LocationServiceImpl()
            print("📦 ServiceProvider: Initialized with default LocationServiceImpl.")
        }
        
        // --- Initialize Database Services ---
        self.tideStationService = TideStationDatabaseService(databaseCore: databaseCore)
        self.currentStationService = CurrentStationDatabaseService(databaseCore: databaseCore)
        self.navUnitService = NavUnitDatabaseService(databaseCore: databaseCore)
        self.vesselService = VesselDatabaseService(databaseCore: databaseCore)
        self.photoService = PhotoDatabaseService(databaseCore: databaseCore)
        self.buoyService = BuoyDatabaseService(databaseCore: databaseCore)
        self.weatherService = WeatherDatabaseService(databaseCore: databaseCore)
        print("📦 ServiceProvider: Initialized all database services.")
        
        // --- Initialize Weather Services ---
        self.openMeteoService = WeatherServiceImpl()
        self.geocodingService = GeocodingServiceImpl()
        self.currentLocalWeatherService = CurrentLocalWeatherServiceImpl()
        print("📦 ServiceProvider: Initialized weather services.")
        
        // --- Initialize Added Services ---
        self.navUnitFtpService = NavUnitFtpServiceImpl()
        self.imageCacheService = ImageCacheServiceImpl()
        self.favoritesService = FavoritesServiceImpl()
        print("📦 ServiceProvider: Initialized NavUnit detail services.")
        
        // --- Asynchronous Initialization Tasks ---
        
        // Task 1: Initialize database
        Task(priority: .utility) {
            do {
                print("🚀 ServiceProvider: Initializing Database...")
                try await self.databaseCore.initializeAsync()
                
                // Initialize tables
                try await self.tideStationService.initializeTideStationFavoritesTableAsync()
                try await self.currentStationService.initializeCurrentStationFavoritesTableAsync()
                try await self.photoService.initializePhotosTableAsync()
                try await self.photoService.initializeBargePhotosTableAsync()
                try await self.weatherService.initializeWeatherLocationFavoritesTableAsync()
                
                print("📊 Tables initialized")
                
                // Test database operations to verify connection
                try await self.databaseCore.checkConnectionWithTestQuery()
                
                let tableNames = try await self.databaseCore.getTableNamesAsync()
                print("📊 Tables in the database: \(tableNames.joined(separator: ", "))")
                
                print("✅ ServiceProvider: Database successfully initialized.")
            } catch {
                // Log error, but don't necessarily block app launch
                print("❌ ServiceProvider: Error initializing database: \(error.localizedDescription)")
            }
        }
        
        // Task 2: Request location permission and start updates early
        Task(priority: .utility) {
            do {
                print("🚀 ServiceProvider: Requesting location permission...")
                // Optional: Small delay to allow UI to settle before permission prompt
                try await Task.sleep(for: .seconds(0.5))
                
                let authorized = await self.locationService.requestLocationPermission()
                
                await MainActor.run {
                    if authorized {
                        print("✅ ServiceProvider: Location permission granted/exists. Starting updates.")
                        // Start location updates if authorized
                        self.locationService.startUpdatingLocation()
                    } else {
                        // This case is expected if user denies, restricts, or hasn't decided yet
                        print("⚠️ ServiceProvider: Location permission not authorized at launch. Updates not started.")
                    }
                }
            } catch {
                print("❌ ServiceProvider: Error during location permission request task: \(error.localizedDescription)")
            }
        }
        
        print("📦 ServiceProvider initialization complete (async tasks launched).")
    }
}




