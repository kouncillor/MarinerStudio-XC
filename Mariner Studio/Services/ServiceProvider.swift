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
    let weatherLocationService: WeatherLocationService
    let geocodingService: GeocodingService
    
    // MARK: - Added Services for Nav Unit Details
    let navUnitFtpService: NavUnitFtpService
    let imageCacheService: ImageCacheService
    let favoritesService: FavoritesService
    
    // MARK: - Navigation Service
    let navigationService: NavigationService
    
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
        self.openMeteoService = OpenMeteoWeatherService()
        self.weatherLocationService = WeatherLocationManager()
        self.geocodingService = GeocodingServiceImpl()
        print("📦 ServiceProvider: Initialized weather services.")
        
        // --- Initialize Navigation Service ---
        self.navigationService = NavigationServiceImpl()
        print("📦 ServiceProvider: Initialized navigation service.")
        
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
                        
                        // Also start updates for the weather location service
                        (self.weatherLocationService as? WeatherLocationManager)?.startLocationUpdates()
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

// MARK: - Navigation Service

protocol NavigationService {
    func navigateTo(destination: String, parameters: [String: Any]) async
    func goBack() async
}

class NavigationServiceImpl: NavigationService {
    func navigateTo(destination: String, parameters: [String: Any]) async {
        // In a real implementation, this would use UIKit or SwiftUI navigation
        print("📱 NavigationService: Navigating to \(destination) with parameters: \(parameters)")
        
        // The actual implementation would depend on how navigation is structured in the app
        // For example, with a NavigationStack, it might push a new view onto the stack
    }
    
    func goBack() async {
        // In a real implementation, this would use UIKit or SwiftUI navigation
        print("📱 NavigationService: Going back")
        
        // The actual implementation would depend on how navigation is structured in the app
        // For example, with a NavigationStack, it might pop the current view
    }
}

// MARK: - Geocoding Service

protocol GeocodingService {
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> GeocodingResponse
}

struct GeocodingResponse {
    struct Result {
        let name: String
        let state: String
    }
    
    let results: [Result]
}

class GeocodingServiceImpl: GeocodingService {
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> GeocodingResponse {
        // In a real implementation, this would call a geocoding API
        // For now, we'll return a placeholder response
        
        // Simulate network delay
        try await Task.sleep(for: .seconds(0.5))
        
        // Return a placeholder response
        return GeocodingResponse(
            results: [
                GeocodingResponse.Result(
                    name: "New York",
                    state: "NY"
                )
            ]
        )
    }
}
