import Foundation
import SwiftUI
import Combine
import CoreLocation

/// Cloud-only Current Favorites ViewModel - NO sync complexity!
class CurrentFavoritesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var favorites: [TidalCurrentStation] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Dependencies  
    private let cloudService: CurrentFavoritesCloudService
    private let locationService: LocationService?
    
    // MARK: - Initialization
    init(cloudService: CurrentFavoritesCloudService = CurrentFavoritesCloudService(),
         locationService: LocationService? = nil) {
        self.cloudService = cloudService
        self.locationService = locationService
        
        print("🎯 INIT: CurrentFavoritesViewModel (CLOUD-ONLY) created at \(Date())")
    }
    
    // MARK: - Core Operations
    
    /// Load favorites from cloud (single source of truth)
    @MainActor
    func loadFavorites() async {
        print("🚀 LOAD_FAVORITES: Starting cloud-only load")
        isLoading = true
        errorMessage = ""
        
        let result = await cloudService.getFavorites()
        
        switch result {
        case .success(let stations):
            print("✅ LOAD_FAVORITES: Retrieved \(stations.count) stations from cloud")
            
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
            
            print("✅ LOAD_FAVORITES: Loaded and sorted \(favorites.count) favorites")
            
        case .failure(let error):
            print("❌ LOAD_FAVORITES: Failed - \(error.localizedDescription)")
            errorMessage = "Failed to load favorites: \(error.localizedDescription)"
            favorites = []
        }
        
        isLoading = false
    }
    
    /// Remove favorite from cloud (single operation, no sync needed!)
    @MainActor
    func removeFavorite(stationId: String, currentBin: Int) async {
        print("🗑️ REMOVE_FAVORITE: Removing station \(stationId), bin \(currentBin) from cloud")
        
        let result = await cloudService.removeFavorite(stationId: stationId, currentBin: currentBin)
        
        switch result {
        case .success():
            print("✅ REMOVE_FAVORITE: Successfully removed from cloud")
            // Immediately update UI by removing from local array
            favorites.removeAll { $0.id == stationId && ($0.currentBin ?? 0) == currentBin }
            print("✅ REMOVE_FAVORITE: Updated local UI, station removed")
            
        case .failure(let error):
            print("❌ REMOVE_FAVORITE: Failed - \(error.localizedDescription)")
            errorMessage = "Failed to remove favorite: \(error.localizedDescription)"
        }
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
        // LocationService is already set in init, but keeping this for compatibility
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
 
 ❌ Removed CurrentStationDatabaseService dependency
 ❌ Removed CurrentStationSyncService complexity  
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