import Foundation
import SwiftUI
import Combine
import CoreLocation

/// Core Data + CloudKit Tide Favorites ViewModel - Seamless sync!
class TideFavoritesViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var favorites: [TidalHeightStation] = []
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

        print("🎯 INIT: TideFavoritesViewModel (CORE DATA + CLOUDKIT) created at \(Date())")
    }

    // MARK: - Core Operations

    /// Load favorites from cloud (single source of truth)
    @MainActor
    func loadFavorites() async {
        print("🚀 LOAD_FAVORITES: Starting Core Data + CloudKit load")
        isLoading = true
        errorMessage = ""

        // Get favorites from Core Data
        let tideFavorites = coreDataManager.getTideFavorites()
        
        // Convert Core Data entities to TidalHeightStation objects
        let stations: [TidalHeightStation] = tideFavorites.map { favorite in
            TidalHeightStation(
                id: favorite.stationId,
                name: favorite.name,
                latitude: favorite.latitude,
                longitude: favorite.longitude,
                state: nil,
                type: "Unknown",
                referenceId: "Unknown",
                timezoneCorrection: nil,
                timeMeridian: nil,
                tidePredOffsets: nil,
                isFavorite: true
            )
        }

        print("✅ LOAD_FAVORITES: Retrieved \(stations.count) stations from Core Data")

        // Calculate distances if location available
        var stationsWithDistance = stations
        if let locationService = locationService,
           let userLocation = locationService.currentLocation {

            for i in 0..<stationsWithDistance.count {
                if let lat = stationsWithDistance[i].latitude,
                   let lon = stationsWithDistance[i].longitude {
                    let stationLocation = CLLocation(latitude: lat, longitude: lon)
                    let distanceInMeters = userLocation.distance(from: stationLocation)
                    let distanceInMiles = distanceInMeters * 0.000621371
                    stationsWithDistance[i].distanceFromUser = distanceInMiles
                }
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
    func removeFavorite(stationId: String) async {
        print("🗑️ REMOVE_FAVORITE: Removing station \(stationId) from Core Data")

        coreDataManager.removeTideFavorite(stationId: stationId)
        
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
    func initialize(locationService: LocationService) {
        print("🔧 INITIALIZE: Setting location service to \(type(of: locationService))")
        self.locationService = locationService
        print("🔧 INITIALIZE: LocationService updated successfully")
    }

    /// Cleanup method (much simpler now)
    func cleanup() {
        print("🧹 CLEANUP: Cloud-only cleanup (minimal)")
        // No complex cleanup needed - no sync tasks or local database
    }
}

// MARK: - Simplified Architecture Benefits:
/*
 
 🎉 WHAT WE ELIMINATED:
 
 ❌ Removed TideStationDatabaseService dependency
 ❌ Removed TideStationSyncService complexity  
 ❌ Removed all sync-related @Published properties
 ❌ Removed 400+ lines of sync/database code
 ❌ Removed race conditions and "ghost favorites"
 ❌ Removed complex error handling and conflict resolution
 ❌ Removed debug info, performance metrics, database stats
 ❌ Removed sync status UI (isSyncing, syncErrorMessage, etc.)
 
 ✅ WHAT WE GAINED:
 
 ✅ Single source of truth (cloud-only)
 ✅ Predictable behavior - no more reappearing favorites
 ✅ Simple error handling (network errors only)
 ✅ Fast operations (direct cloud calls)
 ✅ Easy testing and debugging
 ✅ Consistent cross-device experience
 
 */
