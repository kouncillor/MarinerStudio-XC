import Foundation
import SwiftUI
import Combine
import CoreLocation

/// Core Data + CloudKit Buoy Favorites ViewModel - Seamless sync!
class BuoyFavoritesViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var favorites: [BuoyStation] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    // MARK: - Dependencies  
    private let coreDataManager: CoreDataManager
    private var locationService: LocationService?

    // MARK: - Initialization
    init(coreDataManager: CoreDataManager = CoreDataManager.shared,
         locationService: LocationService? = nil) {
        self.coreDataManager = coreDataManager
        self.locationService = locationService

        print("🎯 INIT: BuoyFavoritesViewModel (CORE DATA + CLOUDKIT) created at \(Date())")
    }

    // MARK: - Core Operations

    /// Load favorites from Core Data (CloudKit syncs automatically)
    @MainActor
    func loadFavorites() async {
        print("🚀 LOAD_FAVORITES: Starting Core Data + CloudKit load")
        isLoading = true
        errorMessage = ""

        // Get favorites from Core Data
        let buoyFavorites = coreDataManager.getBuoyFavorites()
        
        // Convert Core Data entities to BuoyStation objects
        var stations: [BuoyStation] = buoyFavorites.map { favorite in
            var station = BuoyStation(
                id: favorite.stationId,
                name: favorite.name,
                latitude: favorite.latitude,
                longitude: favorite.longitude,
                elevation: nil,
                type: "Unknown",
                meteorological: nil,
                currents: nil,
                waterQuality: nil,
                dart: nil
            )
            return station
        }

        print("✅ LOAD_FAVORITES: Retrieved \(stations.count) stations from Core Data")

        // Calculate distances if location available
        if let locationService = locationService,
           let userLocation = locationService.currentLocation {

            for i in 0..<stations.count {
                if let lat = stations[i].latitude,
                   let lon = stations[i].longitude {
                    let stationLocation = CLLocation(latitude: lat, longitude: lon)
                    let distanceInMeters = userLocation.distance(from: stationLocation)
                    let distanceInMiles = distanceInMeters * 0.000621371
                    stations[i].distanceFromUser = distanceInMiles
                }
            }
        }

        // Sort by distance, then alphabetically
        favorites = stations.sorted { station1, station2 in
            if let distance1 = station1.distanceFromUser,
               let distance2 = station2.distanceFromUser {
                return distance1 < distance2
            } else if station1.distanceFromUser != nil {
                return true
            } else if station2.distanceFromUser != nil {
                return false
            } else {
                return station1.name < station2.name
            }
        }

        print("✅ LOAD_FAVORITES: Loaded and sorted \(favorites.count) favorites (CloudKit syncs automatically)")
        isLoading = false
    }

    /// Remove favorite from Core Data (CloudKit syncs automatically!)
    @MainActor
    func removeFavorite(stationId: String) async {
        print("🗑️ REMOVE_FAVORITE: Removing station \(stationId) from Core Data")

        coreDataManager.removeBuoyFavorite(stationId: stationId)
        
        print("✅ REMOVE_FAVORITE: Successfully removed from Core Data (CloudKit will sync)")
        // Immediately update UI by removing from local array
        favorites.removeAll { $0.id == stationId }
        print("✅ REMOVE_FAVORITE: Updated local UI, station removed")
    }

    /// Remove favorite by index (for swipe actions)
    func removeFavorite(at offsets: IndexSet) {
        print("🗑️ REMOVE_FAVORITE: Removing favorites at offsets \(Array(offsets))")
        Task { @MainActor in
            for index in offsets {
                guard index < favorites.count else { continue }
                let station = favorites[index]
                print("🗑️ REMOVE_FAVORITE: Processing station \(station.id) - \(station.name)")
                await removeFavorite(stationId: station.id)
            }
        }
    }

    /// Initialize with services (for dependency injection from ServiceProvider)
    func initialize(
        buoyFavoritesCloudService: CoreDataManager,
        locationService: LocationService?
    ) {
        print("🔧 INITIALIZE: Setting Core Data manager and location service")
        self.locationService = locationService
    }

    /// Cleanup method (much simpler now)
    func cleanup() {
        print("🧹 CLEANUP: Cloud-only cleanup (minimal)")
        // No complex cleanup needed - no sync tasks or local database
    }
}
