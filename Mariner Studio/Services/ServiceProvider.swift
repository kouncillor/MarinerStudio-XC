import Foundation
import SwiftUI
import CoreLocation

// This class will hold our service instances
class ServiceProvider: ObservableObject {
    // MARK: - Core Services
    let databaseCore: DatabaseCore
    let locationService: LocationService

    // MARK: - Core Data + CloudKit Services
    let coreDataManager: CoreDataManager
    let cloudKitManager: CloudKitManager
    let currentStationService: CurrentStationDatabaseService
    let navUnitService: NavUnitDatabaseService
    let vesselService: VesselDatabaseService
    let buoyDatabaseService: BuoyDatabaseService
    let buoyApiservice: BuoyApiService
    let weatherService: WeatherDatabaseService
    let mapOverlayService: MapOverlayDatabaseService
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

    // MARK: - Photo Services
    let photoService: PhotoService

    // MARK: - Initialization
    init(locationService: LocationService? = nil) {
        // Initialize DatabaseCore
        self.databaseCore = DatabaseCore()

        // Initialize LocationService
        if let providedLocationService = locationService {
            self.locationService = providedLocationService
        } else {
            self.locationService = LocationServiceImpl()
        }

        // Initialize Core Data + CloudKit Services
        self.coreDataManager = CoreDataManager.shared
        self.cloudKitManager = CloudKitManager.shared
        DebugLogger.shared.log("📦 ServiceProvider: Initialized Core Data + CloudKit", category: "SERVICE_INIT")
        
        self.currentStationService = CurrentStationDatabaseService(databaseCore: databaseCore)
        self.navUnitService = NavUnitDatabaseService(databaseCore: databaseCore)
        self.vesselService = VesselDatabaseService(databaseCore: databaseCore)
        self.buoyDatabaseService = BuoyDatabaseService(databaseCore: databaseCore)
        self.weatherService = WeatherDatabaseService(databaseCore: databaseCore)
        self.mapOverlayService = MapOverlayDatabaseService(databaseCore: databaseCore)
        self.allRoutesService = AllRoutesDatabaseService(databaseCore: databaseCore)

        // Initialize Weather Services
        self.openMeteoService = WeatherServiceImpl()
        self.geocodingService = GeocodingServiceImpl()
        self.currentLocalWeatherService = CurrentLocalWeatherServiceImpl()

        // Initialize Navigation Services
        self.navUnitFtpService = NavUnitFtpServiceImpl()
        self.favoritesService = FavoritesServiceImpl()
        self.buoyApiservice = BuoyServiceImpl()
        self.noaaChartService = NOAAChartServiceImpl()

        // Initialize GPX and Route Services
        self.gpxService = GpxServiceFactory.shared.getDefaultGpxService()
        self.routeCalculationService = RouteCalculationServiceImpl()

        // Initialize Photo Service (Core Data + CloudKit)
        self.photoService = CoreDataPhotoService(coreDataManager: CoreDataManager.shared)
        DebugLogger.shared.log("📦 ServiceProvider: Initialized Core Data photo service", category: "SERVICE_INIT")

        DebugLogger.shared.log("📦 ServiceProvider: Initialization complete", category: "SERVICE_INIT")
        self.setupAsyncTasks()
    }

    // This method is called after all properties have been initialized
    private func setupAsyncTasks() {
        // Task 1: Initialize database
        Task(priority: .utility) {
            do {
                try await self.databaseCore.initializeAsync()

                // Initialize tables
                try await self.mapOverlayService.initializeMapOverlaySettingsTableAsync()

                // Test database operations to verify connection
                try await self.databaseCore.checkConnectionWithTestQuery()

                let tableNames = try await self.databaseCore.getTableNamesAsync()
                DebugLogger.shared.log("📊 Database tables: \(tableNames.joined(separator: ", "))", category: "SERVICE_ASYNC")
                DebugLogger.shared.log("✅ ServiceProvider: Database successfully initialized", category: "SERVICE_ASYNC")

            } catch {
                DebugLogger.shared.log("❌ ServiceProvider: Database initialization error: \(error.localizedDescription)", category: "SERVICE_ASYNC")
            }
        }

        // Task 2: Request location permission if needed and start updates
        Task(priority: .utility) {
            do {
                await self.locationService.requestLocationPermission()

                // Start location updates if permission was granted
                let permissionStatus = self.locationService.permissionStatus

                if permissionStatus == .authorizedWhenInUse || permissionStatus == .authorizedAlways {
                    DispatchQueue.main.async {
                        self.locationService.startUpdatingLocation()
                    }
                    DebugLogger.shared.log("📍 ServiceProvider: Location updates started", category: "SERVICE_ASYNC")
                } else {
                    DebugLogger.shared.log("⚠️ ServiceProvider: Location permission not granted", category: "SERVICE_ASYNC")
                }
            } catch {
                DebugLogger.shared.log("❌ ServiceProvider: Location setup error: \(error.localizedDescription)", category: "SERVICE_ASYNC")
            }
        }
    }
}