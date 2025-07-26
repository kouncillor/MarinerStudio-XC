
import Foundation
import SwiftUI
import CoreLocation

// This class will hold our service instances
class ServiceProvider: ObservableObject {
    // MARK: - Core Services
    let databaseCore: DatabaseCore
    let locationService: LocationService
    
    // MARK: - Database Services
    // ❌ REMOVED: let tideStationService: TideStationDatabaseService - replaced with cloud service
    
    // MARK: - Cloud Services  
    let tideFavoritesCloudService: TideFavoritesCloudService
    let currentFavoritesCloudService: CurrentFavoritesCloudService
    let weatherFavoritesCloudService: WeatherFavoritesCloudService
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
    
    // MARK: - Photo Services
    let photoService: PhotoService
    
    // MARK: - Sync Services
    let currentStationSyncService: CurrentStationSyncService
    let navUnitSyncService: NavUnitSyncService
    let weatherStationSyncService: WeatherStationSyncService
    
    // MARK: - Initialization
    init(locationService: LocationService? = nil) {
        // Initialize DatabaseCore
        self.databaseCore = DatabaseCore()
        DebugLogger.shared.log("📦 ServiceProvider: Initialized DatabaseCore.", category: "SERVICE_INIT")
        
        // Initialize LocationService
        if let providedLocationService = locationService {
            self.locationService = providedLocationService
            DebugLogger.shared.log("📦 ServiceProvider: Initialized with provided LocationService.", category: "SERVICE_INIT")
        } else {
            self.locationService = LocationServiceImpl()
            DebugLogger.shared.log("📦 ServiceProvider: Initialized with default LocationServiceImpl.", category: "SERVICE_INIT")
        }
        
        // Initialize Database Services
        // ❌ REMOVED: self.tideStationService = TideStationDatabaseService(databaseCore: databaseCore)
        
        // Initialize Cloud Services
        self.tideFavoritesCloudService = TideFavoritesCloudService()
        self.currentFavoritesCloudService = CurrentFavoritesCloudService()
        self.weatherFavoritesCloudService = WeatherFavoritesCloudService()
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
        DebugLogger.shared.log("📦 ServiceProvider: Initialized all database services.", category: "SERVICE_INIT")
        
        DebugLogger.shared.log("📦 ServiceProvider: Initialized sync services (TideStation, CurrentStation, NavUnit, WeatherStation).", category: "SERVICE_INIT")
        
        // Initialize Weather Services
        self.openMeteoService = WeatherServiceImpl()
        self.geocodingService = GeocodingServiceImpl()
        self.currentLocalWeatherService = CurrentLocalWeatherServiceImpl()
        DebugLogger.shared.log("📦 ServiceProvider: Initialized weather services.", category: "SERVICE_INIT")
        
        // Initialize Navigation Services
        self.navUnitFtpService = NavUnitFtpServiceImpl()
        self.favoritesService = FavoritesServiceImpl()
        self.buoyApiservice = BuoyServiceImpl()
        self.noaaChartService = NOAAChartServiceImpl()
        
        
        // Initialize GPX and Route Services
        self.gpxService = GpxServiceFactory.shared.getDefaultGpxService()
        self.routeCalculationService = RouteCalculationServiceImpl()
        DebugLogger.shared.log("📦 ServiceProvider: Initialized GPX and route services.", category: "SERVICE_INIT")
        
        // Initialize Recommendation Service (using Supabase)
        self.recommendationService = RecommendationSupabaseService()
        DebugLogger.shared.log("📦 ServiceProvider: Initialized recommendation Supabase service.", category: "SERVICE_INIT")
        
        // Initialize Photo Service
        do {
            let photoCacheService = try PhotoCacheServiceImpl()
            let photoDatabaseService = PhotoDatabaseServiceImpl(databaseCore: databaseCore)
            let photoSupabaseService = PhotoSupabaseServiceImpl()
            
            self.photoService = PhotoServiceImpl(
                databaseService: photoDatabaseService,
                cacheService: photoCacheService,
                supabaseService: photoSupabaseService
            )
            DebugLogger.shared.log("📦 ServiceProvider: Initialized photo service with all components.", category: "SERVICE_INIT")
        } catch {
            // Create a mock photo service if initialization fails
            self.photoService = MockPhotoService()
            DebugLogger.shared.log("❌ ServiceProvider: Failed to initialize photo service, using mock: \(error)", category: "SERVICE_INIT")
        }
        
        DebugLogger.shared.log("📦 ServiceProvider initialization complete (sync portion).", category: "SERVICE_INIT")
        self.setupAsyncTasks()
    }
    
    // This method is called after all properties have been initialized
    private func setupAsyncTasks() {
        // Task 1: Initialize database
        Task(priority: .utility) {
            do {
                DebugLogger.shared.log("🚀 ServiceProvider: Initializing Database...", category: "SERVICE_ASYNC")
                try await self.databaseCore.initializeAsync()
                
                // Initialize tables
                // Note: TidalCurrentStationFavorites table is manually managed
                try await self.mapOverlayService.initializeMapOverlaySettingsTableAsync()
                try await self.routeFavoritesService.initializeRouteFavoritesTableAsync()
                
                DebugLogger.shared.log("📊 Tables initialized including RouteFavorites", category: "SERVICE_ASYNC")
                
                // Test database operations to verify connection
                try await self.databaseCore.checkConnectionWithTestQuery()
                
                let tableNames = try await self.databaseCore.getTableNamesAsync()
                DebugLogger.shared.log("📊 Tables in the database: \(tableNames.joined(separator: ", "))", category: "SERVICE_ASYNC")
                
                DebugLogger.shared.log("✅ ServiceProvider: Database successfully initialized.", category: "SERVICE_ASYNC")
                
            } catch {
                DebugLogger.shared.log("❌ ServiceProvider: Error during database initialization: \(error.localizedDescription)", category: "SERVICE_ASYNC")
                // Handle initialization error appropriately
            }
        }
        
        // Task 2: Request location permission if needed and start updates
        Task(priority: .utility) {
            do {
                DebugLogger.shared.log("🚀 ServiceProvider: Requesting location permission...", category: "SERVICE_ASYNC")
                await self.locationService.requestLocationPermission()
                
                // Start location updates if permission was granted
                let permissionStatus = self.locationService.permissionStatus
                DebugLogger.shared.log("📍 ServiceProvider: Location permission status: \(permissionStatus)", category: "SERVICE_ASYNC")
                
                if permissionStatus == .authorizedWhenInUse || permissionStatus == .authorizedAlways {
                    DispatchQueue.main.async {
                        DebugLogger.shared.log("📍 ServiceProvider: Location permission granted. Starting updates.", category: "SERVICE_ASYNC")
                        self.locationService.startUpdatingLocation()
                    }
                } else {
                    DebugLogger.shared.log("⚠️ ServiceProvider: Location permission not authorized at launch. Updates not started.", category: "SERVICE_ASYNC")
                }
            } catch {
                DebugLogger.shared.log("❌ ServiceProvider: Error during location permission request task: \(error.localizedDescription)", category: "SERVICE_ASYNC")
            }
        }
        

        
        // Task 4: Initialize recommendation service and setup notifications
        Task(priority: .utility) {
            do {
                // Wait for other services to initialize first
                try await Task.sleep(for: .seconds(1))
                
                DebugLogger.shared.log("🚀 ServiceProvider: Setting up recommendation service...", category: "SERVICE_ASYNC")
                
                // Check account status (Supabase authentication)
                let isAuthenticated = await self.recommendationService.checkAccountStatus()
                
                if isAuthenticated {
                    DebugLogger.shared.log("✅ ServiceProvider: Supabase account authenticated for recommendations", category: "SERVICE_ASYNC")
                    
                    // Setup notification subscription (placeholder for now)
                    try await self.recommendationService.setupNotificationSubscription()
                    DebugLogger.shared.log("🔔 ServiceProvider: Recommendation notifications configured", category: "SERVICE_ASYNC")
                } else {
                    DebugLogger.shared.log("⚠️ ServiceProvider: Supabase account not authenticated for recommendations", category: "SERVICE_ASYNC")
                }
                
            } catch {
                DebugLogger.shared.log("❌ ServiceProvider: Error setting up recommendation service: \(error.localizedDescription)", category: "SERVICE_ASYNC")
                // Don't fail app startup for recommendation service issues
            }
        }
        
        DebugLogger.shared.log("📦 ServiceProvider initialization complete (async tasks launched).", category: "SERVICE_INIT")
    }
    
}

// MARK: - Mock Photo Service for Fallback

class MockPhotoService: PhotoService {
    func getPhotos(for navUnitId: String) async throws -> [NavUnitPhoto] {
        return []
    }
    
    func takePhoto(for navUnitId: String, image: UIImage) async throws -> NavUnitPhoto {
        return NavUnitPhoto(navUnitId: navUnitId, localFileName: "mock.jpg")
    }
    
    func deletePhoto(_ photo: NavUnitPhoto) async throws {
        // Mock implementation
    }
    
    func getPhotoCount(for navUnitId: String) async throws -> Int {
        return 0
    }
    
    func uploadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus {
        return .empty
    }
    
    func downloadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus {
        return .empty
    }
    
    func getSyncStatus(for navUnitId: String) async throws -> PhotoSyncStatus {
        return .empty
    }
    
    func loadPhotoImage(_ photo: NavUnitPhoto) async throws -> UIImage {
        return UIImage(systemName: "photo") ?? UIImage()
    }
    
    func loadThumbnailImage(_ photo: NavUnitPhoto) async throws -> UIImage {
        return UIImage(systemName: "photo") ?? UIImage()
    }
    
    func isAtPhotoLimit(for navUnitId: String) async throws -> Bool {
        return false
    }
}




















