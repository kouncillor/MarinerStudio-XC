//
//import Foundation
//import SwiftUI
//import CoreLocation
//
//// This class will hold our service instances
//class ServiceProvider: ObservableObject {
//    // MARK: - Core Services
//    let databaseCore: DatabaseCore
//    let locationService: LocationService
//    
//    // MARK: - Database Services
//    let tideStationService: TideStationDatabaseService
//    let currentStationService: CurrentStationDatabaseService
//    let navUnitService: NavUnitDatabaseService
//    let vesselService: VesselDatabaseService
//    let photoService: PhotoDatabaseService
//    let buoyDatabaseService: BuoyDatabaseService
//    let buoyApiservice: BuoyApiService
//    let weatherService: WeatherDatabaseService
//    let mapOverlayService: MapOverlayDatabaseService
//    let routeFavoritesService: RouteFavoritesDatabaseService
//    
//    // MARK: - Weather Services
//    let openMeteoService: WeatherService
//    let geocodingService: GeocodingService
//    let currentLocalWeatherService: CurrentLocalWeatherService
//    
//    // MARK: - Navigation Services
//    let navUnitFtpService: NavUnitFtpService
//    let imageCacheService: ImageCacheService
//    let favoritesService: FavoritesService
//    let noaaChartService: NOAAChartService
//    
//    // MARK: - GPX and Route Services
//    let gpxService: ExtendedGpxServiceProtocol
//    let routeCalculationService: RouteCalculationService
//    
//    // MARK: - Initialization
//    init(locationService: LocationService? = nil) {
//        // Initialize DatabaseCore
//        self.databaseCore = DatabaseCore()
//        print("📦 ServiceProvider: Initialized DatabaseCore.")
//        
//        // Initialize LocationService
//        if let providedLocationService = locationService {
//            self.locationService = providedLocationService
//            print("📦 ServiceProvider: Initialized with provided LocationService.")
//        } else {
//            self.locationService = LocationServiceImpl()
//            print("📦 ServiceProvider: Initialized with default LocationServiceImpl.")
//        }
//        
//        // Initialize Database Services
//        self.tideStationService = TideStationDatabaseService(databaseCore: databaseCore)
//        self.currentStationService = CurrentStationDatabaseService(databaseCore: databaseCore)
//        self.navUnitService = NavUnitDatabaseService(databaseCore: databaseCore)
//        self.vesselService = VesselDatabaseService(databaseCore: databaseCore)
//        self.photoService = PhotoDatabaseService(databaseCore: databaseCore)
//        self.buoyDatabaseService = BuoyDatabaseService(databaseCore: databaseCore)
//        self.weatherService = WeatherDatabaseService(databaseCore: databaseCore)
//        self.mapOverlayService = MapOverlayDatabaseService(databaseCore: databaseCore)
//        self.routeFavoritesService = RouteFavoritesDatabaseService(databaseCore: databaseCore)
//        print("📦 ServiceProvider: Initialized all database services.")
//        
//        // Initialize Weather Services
//        self.openMeteoService = WeatherServiceImpl()
//        self.geocodingService = GeocodingServiceImpl()
//        self.currentLocalWeatherService = CurrentLocalWeatherServiceImpl()
//        print("📦 ServiceProvider: Initialized weather services.")
//        
//        // Initialize Navigation Services
//        self.navUnitFtpService = NavUnitFtpServiceImpl()
//        self.imageCacheService = ImageCacheServiceImpl()
//        self.favoritesService = FavoritesServiceImpl()
//        self.buoyApiservice = BuoyServiceImpl()
//        self.noaaChartService = NOAAChartServiceImpl()
//        print("📦 ServiceProvider: Initialized navigation services.")
//        
//        // Initialize GPX and Route Services
//        self.gpxService = GpxServiceFactory.shared.getDefaultGpxService()
//        self.routeCalculationService = RouteCalculationServiceImpl()
//        print("📦 ServiceProvider: Initialized GPX and route services.")
//        
//        print("📦 ServiceProvider initialization complete (sync portion).")
//        self.setupAsyncTasks()
//    }
//    
//    // This method is called after all properties have been initialized
//    private func setupAsyncTasks() {
//        // Task 1: Initialize database
//        Task(priority: .utility) {
//            do {
//                print("🚀 ServiceProvider: Initializing Database...")
//                try await self.databaseCore.initializeAsync()
//                
//                // Initialize tables
//                try await self.tideStationService.initializeTideStationFavoritesTableAsync()
//                try await self.currentStationService.initializeCurrentStationFavoritesTableAsync()
//                try await self.photoService.initializePhotosTableAsync()
//                try await self.photoService.initializeBargePhotosTableAsync()
//                try await self.weatherService.initializeWeatherLocationFavoritesTableAsync()
//                try await self.mapOverlayService.initializeMapOverlaySettingsTableAsync()
//                try await self.routeFavoritesService.initializeRouteFavoritesTableAsync()
//                
//                print("📊 Tables initialized including RouteFavorites")
//                
//                // Test database operations to verify connection
//                try await self.databaseCore.checkConnectionWithTestQuery()
//                
//                let tableNames = try await self.databaseCore.getTableNamesAsync()
//                print("📊 Tables in the database: \(tableNames.joined(separator: ", "))")
//                
//                print("✅ ServiceProvider: Database successfully initialized.")
//            } catch {
//                print("❌ ServiceProvider: Error initializing database: \(error.localizedDescription)")
//            }
//        }
//        
//        // Task 2: Request location permission and start updates early
//        Task(priority: .utility) {
//            do {
//                print("🚀 ServiceProvider: Requesting location permission...")
//                try await Task.sleep(for: .seconds(0.5))
//                
//                let authorized = await self.locationService.requestLocationPermission()
//                
//                await MainActor.run {
//                    if authorized {
//                        print("✅ ServiceProvider: Location permission granted/exists. Starting updates.")
//                        self.locationService.startUpdatingLocation()
//                    } else {
//                        print("⚠️ ServiceProvider: Location permission not authorized at launch. Updates not started.")
//                    }
//                }
//            } catch {
//                print("❌ ServiceProvider: Error during location permission request task: \(error.localizedDescription)")
//            }
//        }
//        
//        print("📦 ServiceProvider initialization complete (async tasks launched).")
//    }
//}





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
    let buoyDatabaseService: BuoyDatabaseService
    let buoyApiservice: BuoyApiService
    let weatherService: WeatherDatabaseService
    let mapOverlayService: MapOverlayDatabaseService
    let routeFavoritesService: RouteFavoritesDatabaseService
    
    // MARK: - Weather Services
    let openMeteoService: WeatherService
    let geocodingService: GeocodingService
    let currentLocalWeatherService: CurrentLocalWeatherService
    
    // MARK: - Navigation Services
    let navUnitFtpService: NavUnitFtpService
    let imageCacheService: ImageCacheService
    let favoritesService: FavoritesService
    let noaaChartService: NOAAChartService
    
    // MARK: - Photo Services
    let photoCaptureService: PhotoCaptureService
    let fileStorageService: FileStorageService
    
    // MARK: - GPX and Route Services
    let gpxService: ExtendedGpxServiceProtocol
    let routeCalculationService: RouteCalculationService
    
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
        self.navUnitService = NavUnitDatabaseService(databaseCore: databaseCore)
        self.vesselService = VesselDatabaseService(databaseCore: databaseCore)
        self.photoService = PhotoDatabaseService(databaseCore: databaseCore)
        self.buoyDatabaseService = BuoyDatabaseService(databaseCore: databaseCore)
        self.weatherService = WeatherDatabaseService(databaseCore: databaseCore)
        self.mapOverlayService = MapOverlayDatabaseService(databaseCore: databaseCore)
        self.routeFavoritesService = RouteFavoritesDatabaseService(databaseCore: databaseCore)
        print("📦 ServiceProvider: Initialized all database services.")
        
        // Initialize Weather Services
        self.openMeteoService = WeatherServiceImpl()
        self.geocodingService = GeocodingServiceImpl()
        self.currentLocalWeatherService = CurrentLocalWeatherServiceImpl()
        print("📦 ServiceProvider: Initialized weather services.")
        
        // Initialize Navigation Services
        self.navUnitFtpService = NavUnitFtpServiceImpl()
        self.imageCacheService = ImageCacheServiceImpl()
        self.favoritesService = FavoritesServiceImpl()
        self.buoyApiservice = BuoyServiceImpl()
        self.noaaChartService = NOAAChartServiceImpl()
        
        // Initialize Photo Services
        do {
            self.fileStorageService = try FileStorageServiceImpl()
        } catch {
            print("❌ ServiceProvider: Failed to initialize FileStorageService: \(error.localizedDescription)")
            fatalError("Critical error: Cannot initialize file storage service")
        }
        self.photoCaptureService = PhotoCaptureServiceImpl()
        
        print("📦 ServiceProvider: Initialized navigation and photo services.")
        
        // Initialize GPX and Route Services
        self.gpxService = GpxServiceFactory.shared.getDefaultGpxService()
        self.routeCalculationService = RouteCalculationServiceImpl()
        print("📦 ServiceProvider: Initialized GPX and route services.")
        
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
                try await self.photoService.initializePhotosTableAsync()
                try await self.photoService.initializeBargePhotosTableAsync()
                try await self.weatherService.initializeWeatherLocationFavoritesTableAsync()
                try await self.mapOverlayService.initializeMapOverlaySettingsTableAsync()
                try await self.routeFavoritesService.initializeRouteFavoritesTableAsync()
                
                print("📊 Tables initialized including RouteFavorites")
                
                // Test database operations to verify connection
                try await self.databaseCore.checkConnectionWithTestQuery()
                
                let tableNames = try await self.databaseCore.getTableNamesAsync()
                print("📊 Tables in the database: \(tableNames.joined(separator: ", "))")
                
                print("✅ ServiceProvider: Database successfully initialized.")
            } catch {
                print("❌ ServiceProvider: Error initializing database: \(error.localizedDescription)")
            }
        }
        
        // Task 2: Request location permission and start updates early
        Task(priority: .utility) {
            do {
                print("🚀 ServiceProvider: Requesting location permission...")
                try await Task.sleep(for: .seconds(0.5))
                
                let authorized = await self.locationService.requestLocationPermission()
                
                await MainActor.run {
                    if authorized {
                        print("✅ ServiceProvider: Location permission granted/exists. Starting updates.")
                        self.locationService.startUpdatingLocation()
                    } else {
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
