
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
    let buoyDatabaseService: BuoyDatabaseService
    let buoyApiservice: BuoyApiService
    let weatherService: WeatherDatabaseService
    let mapOverlayService: MapOverlayDatabaseService
    let routeFavoritesService: RouteFavoritesDatabaseService
    let allRoutesService: AllRoutesDatabaseService
    
    // MARK: - Weather Services
    let openMeteoService: WeatherService
    let geocodingService: GeocodingService
    let currentLocalWeatherService: CurrentLocalWeatherService
    
    // MARK: - Navigation Services
    let navUnitFtpService: NavUnitFtpService
    let favoritesService: FavoritesService
    let noaaChartService: NOAAChartService

    
    // MARK: - GPX and Route Services
    let gpxService: ExtendedGpxServiceProtocol
    let routeCalculationService: RouteCalculationService
    
    // MARK: - Recommendation Services
    let recommendationService: RecommendationCloudService
    
    // MARK: - Sync Services
    let currentStationSyncService: CurrentStationSyncService
    let navUnitSyncService: NavUnitSyncService
    let weatherStationSyncService: WeatherStationSyncService
    
    // MARK: - Initialization
    init(locationService: LocationService? = nil) {
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
        
        // Initialize Database Services
        self.tideStationService = TideStationDatabaseService(databaseCore: databaseCore)
        self.currentStationService = CurrentStationDatabaseService(databaseCore: databaseCore)
        self.currentStationSyncService = CurrentStationSyncService(databaseService: self.currentStationService)
        self.navUnitService = NavUnitDatabaseService(databaseCore: databaseCore)
        
        // FIXED: Initialize NavUnitSyncService with dependency injection instead of singleton
        self.navUnitSyncService = NavUnitSyncService(
            navUnitService: self.navUnitService,
            supabaseManager: SupabaseManager.shared
        )
        
        // Initialize WeatherStationSyncService using singleton pattern (like TideStationSyncService)
        self.weatherStationSyncService = WeatherStationSyncService.shared
        
        self.vesselService = VesselDatabaseService(databaseCore: databaseCore)
        self.buoyDatabaseService = BuoyDatabaseService(databaseCore: databaseCore)
        self.weatherService = WeatherDatabaseService(databaseCore: databaseCore)
        self.mapOverlayService = MapOverlayDatabaseService(databaseCore: databaseCore)
        self.routeFavoritesService = RouteFavoritesDatabaseService(databaseCore: databaseCore)
        self.allRoutesService = AllRoutesDatabaseService(databaseCore: databaseCore)
        print("📦 ServiceProvider: Initialized all database services.")
        
        print("📦 ServiceProvider: Initialized sync services (TideStation, CurrentStation, NavUnit, WeatherStation).")
        
        // Initialize Weather Services
        self.openMeteoService = WeatherServiceImpl()
        self.geocodingService = GeocodingServiceImpl()
        self.currentLocalWeatherService = CurrentLocalWeatherServiceImpl()
        print("📦 ServiceProvider: Initialized weather services.")
        
        // Initialize Navigation Services
        self.navUnitFtpService = NavUnitFtpServiceImpl()
        self.favoritesService = FavoritesServiceImpl()
        self.buoyApiservice = BuoyServiceImpl()
        self.noaaChartService = NOAAChartServiceImpl()
        
        
        // Initialize GPX and Route Services
        self.gpxService = GpxServiceFactory.shared.getDefaultGpxService()
        self.routeCalculationService = RouteCalculationServiceImpl()
        print("📦 ServiceProvider: Initialized GPX and route services.")
        
        // Initialize Recommendation Service (using Supabase)
        self.recommendationService = RecommendationSupabaseService()
        print("📦 ServiceProvider: Initialized recommendation Supabase service.")
        
        print("📦 ServiceProvider initialization complete (sync portion).")
        self.setupAsyncTasks()
    }
    
    // This method is called after all properties have been initialized
    private func setupAsyncTasks() {
        // Task 1: Initialize database
        Task(priority: .utility) {
            do {
                print("🚀 ServiceProvider: Initializing Database...")
                try await self.databaseCore.initializeAsync()
                
                // Initialize tables
                try await self.tideStationService.initializeTideStationFavoritesTableAsync()
                try await self.currentStationService.initializeCurrentStationFavoritesTableAsync()
                try await self.mapOverlayService.initializeMapOverlaySettingsTableAsync()
                try await self.routeFavoritesService.initializeRouteFavoritesTableAsync()
                
                print("📊 Tables initialized including RouteFavorites")
                
                // Test database operations to verify connection
                try await self.databaseCore.checkConnectionWithTestQuery()
                
                let tableNames = try await self.databaseCore.getTableNamesAsync()
                print("📊 Tables in the database: \(tableNames.joined(separator: ", "))")
                
                print("✅ ServiceProvider: Database successfully initialized.")
                
            } catch {
                print("❌ ServiceProvider: Error during database initialization: \(error.localizedDescription)")
                // Handle initialization error appropriately
            }
        }
        
        // Task 2: Request location permission if needed and start updates
        Task(priority: .utility) {
            do {
                print("🚀 ServiceProvider: Requesting location permission...")
                await self.locationService.requestLocationPermission()
                
                // Start location updates if permission was granted
                let permissionStatus = self.locationService.permissionStatus
                print("📍 ServiceProvider: Location permission status: \(permissionStatus)")
                
                if permissionStatus == .authorizedWhenInUse || permissionStatus == .authorizedAlways {
                    DispatchQueue.main.async {
                        print("📍 ServiceProvider: Location permission granted. Starting updates.")
                        self.locationService.startUpdatingLocation()
                    }
                } else {
                    print("⚠️ ServiceProvider: Location permission not authorized at launch. Updates not started.")
                }
            } catch {
                print("❌ ServiceProvider: Error during location permission request task: \(error.localizedDescription)")
            }
        }
        

        
        // Task 4: Initialize recommendation service and setup notifications
        Task(priority: .utility) {
            do {
                // Wait for other services to initialize first
                try await Task.sleep(for: .seconds(1))
                
                print("🚀 ServiceProvider: Setting up recommendation service...")
                
                // Check account status (Supabase authentication)
                let isAuthenticated = await self.recommendationService.checkAccountStatus()
                
                if isAuthenticated {
                    print("✅ ServiceProvider: Supabase account authenticated for recommendations")
                    
                    // Setup notification subscription (placeholder for now)
                    try await self.recommendationService.setupNotificationSubscription()
                    print("🔔 ServiceProvider: Recommendation notifications configured")
                } else {
                    print("⚠️ ServiceProvider: Supabase account not authenticated for recommendations")
                }
                
            } catch {
                print("❌ ServiceProvider: Error setting up recommendation service: \(error.localizedDescription)")
                // Don't fail app startup for recommendation service issues
            }
        }
        
        print("📦 ServiceProvider initialization complete (async tasks launched).")
    }
    
    // Helper method to ensure PhotoDatabaseService has the getAllNavUnitPhotosAsync method
    private func addGetAllPhotosMethodIfNeeded(_ photoService: PhotoDatabaseService) async throws {
        print("📦 ServiceProvider: Verifying PhotoDatabaseService methods...")
        // This is a placeholder - the actual implementation should be in PhotoDatabaseService
        // We'll assume the method exists or add it via extension if needed
    }
}




















