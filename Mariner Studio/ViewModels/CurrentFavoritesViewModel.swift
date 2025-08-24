import Foundation
import SwiftUI
import Combine
import CoreLocation

/// Core Data + CloudKit Current Favorites ViewModel - Seamless sync!
class CurrentFavoritesViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var favorites: [TidalCurrentStation] = []
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

        print("🎯 INIT: CurrentFavoritesViewModel (CORE DATA + CLOUDKIT) created at \(Date())")
    }

    // MARK: - Core Operations

    /// Load favorites from Core Data (CloudKit syncs automatically)
    @MainActor
    func loadFavorites() async {
        print("🚀 LOAD_FAVORITES: Starting Core Data + CloudKit load")
        isLoading = true
        errorMessage = ""

        // Get favorites from Core Data
        let currentFavorites = coreDataManager.getCurrentFavorites()
        
        // Convert Core Data entities to TidalCurrentStation objects
        let stations: [TidalCurrentStation] = currentFavorites.map { favorite in
            TidalCurrentStation(
                id: favorite.stationId,
                name: favorite.name,
                latitude: favorite.latitude,
                longitude: favorite.longitude,
                type: "current",
                depth: favorite.depth > 0 ? favorite.depth : nil,
                depthType: nil,
                currentBin: Int(favorite.currentBin),
                isFavorite: true,
                distanceFromUser: nil
            )
        }

        print("✅ LOAD_FAVORITES: Retrieved \(stations.count) stations from Core Data")

        // Calculate distances if location available
        var stationsWithDistance = stations
        if let locationService = locationService,
           let userLocation = locationService.currentLocation {

            for i in 0..<stationsWithDistance.count {
                let stationLocation = CLLocation(latitude: stationsWithDistance[i].latitude!, longitude: stationsWithDistance[i].longitude!)
                let distanceInMeters = userLocation.distance(from: stationLocation)
                let distanceInMiles = distanceInMeters * 0.000621371
                stationsWithDistance[i].distanceFromUser = distanceInMiles
            }
        }

        // Sort by distance, then alphabetically
        favorites = stationsWithDistance.sorted { station1, station2 in
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
    func removeFavorite(stationId: String, currentBin: Int) async {
        print("🗑️ REMOVE_FAVORITE: Removing station \(stationId), bin \(currentBin) from Core Data")

        coreDataManager.removeCurrentFavorite(stationId: stationId, currentBin: currentBin)
        
        print("✅ REMOVE_FAVORITE: Successfully removed from Core Data (CloudKit will sync)")
        // Immediately update UI by removing from local array
        favorites.removeAll { $0.id == stationId && ($0.currentBin ?? 0) == currentBin }
        print("✅ REMOVE_FAVORITE: Updated local UI, station removed")
    }

    /// Remove favorite by index (for swipe actions)
    func removeFavorite(at offsets: IndexSet) {
        print("🗑️ REMOVE_FAVORITE: Removing favorites at offsets \(Array(offsets))")
        Task { @MainActor in
            for index in offsets {
                guard index < favorites.count else { continue }
                let station = favorites[index]
                print("🗑️ REMOVE_FAVORITE: Processing station \(station.id), bin \(station.currentBin ?? 0)")
                await removeFavorite(stationId: station.id, currentBin: station.currentBin ?? 0)
            }
        }
    }

    /// Initialize with services (for dependency injection from ServiceProvider)
    func initialize(locationService: LocationService) {
        print("🔧 INITIALIZE: Setting location service")
        self.locationService = locationService
        print("🔧 INITIALIZE: LocationService updated successfully")
    }

    /// Cleanup method (much simpler now)
    func cleanup() {
        print("🧹 CLEANUP: Core Data + CloudKit cleanup (minimal)")
        // No complex cleanup needed - no sync tasks or manual database operations
    }
}

// MARK: - Core Data + CloudKit Architecture Benefits:
/*
 
 🎉 WHAT WE ELIMINATED:
 
 ❌ Removed CurrentFavoritesCloudService dependency (Supabase)
 ❌ Removed complex async Result handling 
 ❌ Removed manual authentication checks
 ❌ Removed network error handling complexity
 ❌ Removed cloud-only storage with no offline support
 
 ✅ WHAT WE GAINED:
 
 ✅ Single source of truth (Core Data + CloudKit)
 ✅ Predictable behavior - automatic CloudKit sync
 ✅ Offline support with local Core Data storage
 ✅ Simple synchronous operations with automatic background sync
 ✅ Consistent architecture with other favorites modules
 ✅ Built-in conflict resolution via CloudKit
 ✅ No authentication complexity - handled by CloudKit
 
 */
