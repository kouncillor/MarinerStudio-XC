import Foundation
import SwiftUI
import Combine
import CoreLocation

/// Cloud-only Tide Favorites ViewModel - NO sync complexity!
class TideFavoritesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var favorites: [TidalHeightStation] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Dependencies  
    private let cloudService: TideFavoritesCloudService
    private var locationService: LocationService?
    
    // MARK: - Initialization
    init(cloudService: TideFavoritesCloudService = TideFavoritesCloudService(),
         locationService: LocationService? = nil) {
        self.cloudService = cloudService
        self.locationService = locationService
        
        print("🎯 INIT: TideFavoritesViewModel (CLOUD-ONLY) created at \(Date())")
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
            print("📍 LOAD_FAVORITES: Starting distance calculation process")
            print("📍 LOAD_FAVORITES: LocationService exists: \(locationService != nil)")
            
            var stationsWithDistance = stations
            if let locationService = locationService,
               let userLocation = locationService.currentLocation {
                
                print("📍 LOAD_FAVORITES: User location available - Lat: \(String(format: "%.6f", userLocation.coordinate.latitude)), Lng: \(String(format: "%.6f", userLocation.coordinate.longitude))")
                print("📍 LOAD_FAVORITES: Processing \(stationsWithDistance.count) stations for distance calculation")
                
                var stationsWithCoords = 0
                var stationsWithoutCoords = 0
                
                for i in 0..<stationsWithDistance.count {
                    if let lat = stationsWithDistance[i].latitude,
                       let lon = stationsWithDistance[i].longitude {
                        let stationLocation = CLLocation(latitude: lat, longitude: lon)
                        let distanceInMeters = userLocation.distance(from: stationLocation)
                        let distanceInMiles = distanceInMeters * 0.000621371
                        stationsWithDistance[i].distanceFromUser = distanceInMiles
                        stationsWithCoords += 1
                        
                        // Log first 3 stations for verification
                        if i < 3 {
                            print("📍 LOAD_FAVORITES: Station \(i+1) - \(stationsWithDistance[i].name): \(String(format: "%.1f", distanceInMiles)) miles")
                        }
                    } else {
                        stationsWithoutCoords += 1
                        if stationsWithoutCoords <= 3 {
                            print("⚠️ LOAD_FAVORITES: Station \(stationsWithDistance[i].name) has missing coordinates (lat: \(stationsWithDistance[i].latitude?.description ?? "nil"), lng: \(stationsWithDistance[i].longitude?.description ?? "nil"))")
                        }
                    }
                }
                
                print("📍 LOAD_FAVORITES: Distance calculation complete - \(stationsWithCoords) stations with coords, \(stationsWithoutCoords) without coords")
                
            } else {
                if locationService == nil {
                    print("❌ LOAD_FAVORITES: LocationService is nil - no distance calculations possible")
                } else {
                    print("❌ LOAD_FAVORITES: User location not available - no distance calculations possible")
                    print("📍 LOAD_FAVORITES: Location permission status: \(locationService!.permissionStatus)")
                }
            }
            
            // Sort by distance, then alphabetically
            print("🔄 LOAD_FAVORITES: Starting sort process")
            
            var distanceSorted = 0
            var alphabeticalSorted = 0
            
            favorites = stationsWithDistance.sorted { station1, station2 in
                if let distance1 = station1.distanceFromUser,
                   let distance2 = station2.distanceFromUser {
                    distanceSorted += 1
                    return distance1 < distance2
                } else if station1.distanceFromUser != nil {
                    return true
                } else if station2.distanceFromUser != nil {
                    return false
                } else {
                    alphabeticalSorted += 1
                    return station1.name < station2.name
                }
            }
            
            print("🔄 LOAD_FAVORITES: Sort complete - \(distanceSorted) distance comparisons, \(alphabeticalSorted) alphabetical comparisons")
            
            // Log first 5 stations with their sort criteria
            print("📊 LOAD_FAVORITES: Top 5 sorted stations:")
            for (index, station) in favorites.prefix(5).enumerated() {
                if let distance = station.distanceFromUser {
                    print("📊 LOAD_FAVORITES: \(index + 1). \(station.name) - \(String(format: "%.1f", distance)) miles")
                } else {
                    print("📊 LOAD_FAVORITES: \(index + 1). \(station.name) - No distance (alphabetical)")
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
    func removeFavorite(stationId: String) async {
        print("🗑️ REMOVE_FAVORITE: Removing station \(stationId) from cloud")
        
        let result = await cloudService.removeFavorite(stationId: stationId)
        
        switch result {
        case .success():
            print("✅ REMOVE_FAVORITE: Successfully removed from cloud")
            // Immediately update UI by removing from local array
            favorites.removeAll { $0.id == stationId }
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