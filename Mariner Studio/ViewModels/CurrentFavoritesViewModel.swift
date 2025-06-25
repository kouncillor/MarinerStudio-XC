
import Foundation
import SwiftUI
import Combine
import CoreLocation

class CurrentFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [TidalCurrentStation] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var lastLoadTime: Date?
    @Published var loadDuration: Double = 0.0
    @Published var debugInfo = ""
    
    // MARK: - Private Properties
    private var currentStationService: CurrentStationDatabaseService?
    private var tidalCurrentService: TidalCurrentService?
    private var locationService: LocationService?
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
    // Performance tracking
    private var startTime: Date?
    private var phaseStartTime: Date?
    
    // MARK: - Initialization
    func initialize(
        currentStationService: CurrentStationDatabaseService?,
        tidalCurrentService: TidalCurrentService?,
        locationService: LocationService?
    ) {
        print("🚀 CURRENT_FAVORITES_VM: Initializing with services")
        print("🚀 CURRENT_FAVORITES_VM: currentStationService: \(currentStationService != nil ? "✅" : "❌")")
        print("🚀 CURRENT_FAVORITES_VM: tidalCurrentService: \(tidalCurrentService != nil ? "✅" : "❌")")
        print("🚀 CURRENT_FAVORITES_VM: locationService: \(locationService != nil ? "✅" : "❌")")
        
        self.currentStationService = currentStationService
        self.tidalCurrentService = tidalCurrentService
        self.locationService = locationService
        
       // updateDebugInfo("Services initialized ✅")
    }
    
    deinit {
        print("♻️ CURRENT_FAVORITES_VM: Deinitializing, canceling load task")
        loadTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func loadFavorites() {
        print("🚀 CURRENT_FAVORITES_VM: loadFavorites() called")
        print("🚀 CURRENT_FAVORITES_VM: Current thread = \(Thread.current)")
        print("🚀 CURRENT_FAVORITES_VM: Is main thread = \(Thread.isMainThread)")
        
        // Cancel any existing task
        if let existingTask = loadTask {
            print("🛑 CURRENT_FAVORITES_VM: Cancelling existing load task")
            existingTask.cancel()
        }
        
        // Start performance tracking
        startTime = Date()
        phaseStartTime = startTime
        
        loadTask = Task { @MainActor in
            await performLoadFavorites()
        }
    }
    
    @MainActor
    private func performLoadFavorites() async {
        print("📱 CURRENT_FAVORITES_VM: Starting main load operation on MainActor")
        print("📱 CURRENT_FAVORITES_VM: Current favorites count = \(favorites.count)")
        
        startTime = Date()
        
        guard let currentStationService = currentStationService else {
            await handleLoadError("CurrentStationDatabaseService not available", phase: "Service Check")
            return
        }
        
        print("✅ CURRENT_FAVORITES_VM: Services verified successfully")
        await updateDebugInfo("Services verified ✅")
        
        do {
            // PHASE 1: Set loading state
            await updateLoadingPhase("Loading favorites from database")
            isLoading = true
            errorMessage = ""
            
            // PHASE 2: Get favorites efficiently from database
            let phaseStart = Date()
            print("📋 CURRENT_FAVORITES_VM: PHASE 2 - Fetching favorites from database")
            
            let favoriteRecords = try await currentStationService.getCurrentStationFavoritesWithMetadata()
            
            let phase2Duration = Date().timeIntervalSince(phaseStart)
            print("⏱️ CURRENT_FAVORITES_VM: PHASE 2 completed in \(String(format: "%.3f", phase2Duration))s - Found \(favoriteRecords.count) records")
            
            // PHASE 3: Convert to TidalCurrentStation objects
            await updateLoadingPhase("Processing station data")
            let phase3Start = Date()
            print("🔄 CURRENT_FAVORITES_VM: PHASE 3 - Converting \(favoriteRecords.count) records to TidalCurrentStation objects")
            
            var favoriteStations: [TidalCurrentStation] = []
            for record in favoriteRecords {
                let station = record.toTidalCurrentStation()
                favoriteStations.append(station)
            }
            
            let phase3Duration = Date().timeIntervalSince(phase3Start)
            print("⏱️ CURRENT_FAVORITES_VM: PHASE 3 completed in \(String(format: "%.3f", phase3Duration))s")
            
            // PHASE 4: Calculate distances if location service available
            await updateLoadingPhase("Calculating distances")
            let phase4Start = Date()
            print("📍 CURRENT_FAVORITES_VM: PHASE 4 - Calculating distances")
            
            var processedStations = favoriteStations
            if let locationService = locationService {
                processedStations = await calculateDistances(for: favoriteStations, locationService: locationService)
            } else {
                print("⚠️ CURRENT_FAVORITES_VM: No location service available, skipping distance calculation")
            }
            
            let phase4Duration = Date().timeIntervalSince(phase4Start)
            print("⏱️ CURRENT_FAVORITES_VM: PHASE 4 completed in \(String(format: "%.3f", phase4Duration))s")
            
            // PHASE 5: Sort stations (by distance if available, otherwise by name)
            await updateLoadingPhase("Sorting stations")
            let phase5Start = Date()
            print("📊 CURRENT_FAVORITES_VM: PHASE 5 - Sorting stations")
            
            let sortedStations = processedStations.sorted { station1, station2 in
                // First sort by distance if available
                if let dist1 = station1.distanceFromUser, let dist2 = station2.distanceFromUser {
                    return dist1 < dist2
                }
                // If one has distance and other doesn't, prioritize the one with distance
                if station1.distanceFromUser != nil && station2.distanceFromUser == nil {
                    return true
                }
                if station1.distanceFromUser == nil && station2.distanceFromUser != nil {
                    return false
                }
                // If neither has distance, sort by name
                return station1.name < station2.name
            }
            
            let phase5Duration = Date().timeIntervalSince(phase5Start)
            print("⏱️ CURRENT_FAVORITES_VM: PHASE 5 completed in \(String(format: "%.3f", phase5Duration))s")
            
            // PHASE 6: Update UI
            let phase6Start = Date()
            print("🎨 CURRENT_FAVORITES_VM: PHASE 6 - Updating UI with \(sortedStations.count) stations")
            
            // Only update if task hasn't been cancelled
            if !Task.isCancelled {
                favorites = sortedStations
                isLoading = false
                lastLoadTime = Date()
                
                if let startTime = startTime {
                    loadDuration = Date().timeIntervalSince(startTime)
                    updateDebugInfo("✅ Loaded \(sortedStations.count) favorites in \(String(format: "%.3f", loadDuration))s")
                }
                
                let phase6Duration = Date().timeIntervalSince(phase6Start)
                print("⏱️ CURRENT_FAVORITES_VM: PHASE 6 completed in \(String(format: "%.3f", phase6Duration))s")
                
                let totalDuration = Date().timeIntervalSince(startTime!)
                print("🎉 CURRENT_FAVORITES_VM: Load operation completed successfully!")
                print("📊 CURRENT_FAVORITES_VM: Total duration: \(String(format: "%.3f", totalDuration))s")
                print("📊 CURRENT_FAVORITES_VM: Phase breakdown:")
                print("   📋 Database query: \(String(format: "%.3f", phase2Duration))s")
                print("   🔄 Data conversion: \(String(format: "%.3f", phase3Duration))s")
                print("   📍 Distance calc: \(String(format: "%.3f", phase4Duration))s")
                print("   📊 Sorting: \(String(format: "%.3f", phase5Duration))s")
                print("   🎨 UI update: \(String(format: "%.3f", phase6Duration))s")
                
                // Log sample stations for debugging
                if !sortedStations.isEmpty {
                    print("📄 CURRENT_FAVORITES_VM: Sample stations loaded:")
                    for (index, station) in sortedStations.prefix(3).enumerated() {
                        let distanceText = station.distanceFromUser.map { String(format: "%.1f mi", $0) } ?? "unknown distance"
                        print("   \(index + 1). \(station.name) - \(distanceText)")
                    }
                }
            } else {
                print("🛑 CURRENT_FAVORITES_VM: Task was cancelled, not updating UI")
            }
            
        } catch {
            print("❌ CURRENT_FAVORITES_VM: Load failed with error: \(error.localizedDescription)")
            await handleLoadError("Failed to load favorites: \(error.localizedDescription)", phase: "Load Operation")
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func updateLoadingPhase(_ phase: String) async {
        print("📝 CURRENT_FAVORITES_VM: Updating loading phase: \(phase)")
        updateDebugInfo("Loading: \(phase)")
    }
    
    @MainActor
    private func handleLoadError(_ message: String, phase: String) async {
        print("❌ CURRENT_FAVORITES_VM: Error in \(phase): \(message)")
        errorMessage = message
        isLoading = false
        updateDebugInfo("❌ Error in \(phase)")
        
        if let startTime = startTime {
            loadDuration = Date().timeIntervalSince(startTime)
        }
    }
    
    @MainActor
    private func updateDebugInfo(_ info: String) {
        debugInfo = info
        print("🐛 CURRENT_FAVORITES_VM: Debug info updated: \(info)")
    }
    
    private func calculateDistances(for stations: [TidalCurrentStation], locationService: LocationService) async -> [TidalCurrentStation] {
        print("📍 CURRENT_FAVORITES_VM: Starting distance calculation for \(stations.count) stations")
        let startTime = Date()
        
        guard let userLocation = await getUserLocation(locationService: locationService) else {
            print("⚠️ CURRENT_FAVORITES_VM: Could not get user location, returning stations without distances")
            return stations
        }
        
        print("📍 CURRENT_FAVORITES_VM: User location: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
        
        var stationsWithDistance: [TidalCurrentStation] = []
        var calculatedCount = 0
        
        for station in stations {
            if let stationLat = station.latitude, let stationLon = station.longitude {
                let stationLocation = CLLocation(latitude: stationLat, longitude: stationLon)
                let distance = userLocation.distance(from: stationLocation)
                let distanceInMiles = distance * 0.000621371 // Convert meters to miles
                
                let updatedStation = station.withDistance(distanceInMiles)
                stationsWithDistance.append(updatedStation)
                calculatedCount += 1
                
                if calculatedCount <= 3 { // Log first few for debugging
                    print("📍 CURRENT_FAVORITES_VM: Station '\(station.name)' distance: \(String(format: "%.1f", distanceInMiles)) mi")
                }
            } else {
                print("⚠️ CURRENT_FAVORITES_VM: Station '\(station.name)' missing coordinates")
                stationsWithDistance.append(station) // Add without distance
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ CURRENT_FAVORITES_VM: Distance calculation completed in \(String(format: "%.3f", duration))s")
        print("📊 CURRENT_FAVORITES_VM: Calculated distances for \(calculatedCount)/\(stations.count) stations")
        
        return stationsWithDistance
    }
    
    private func getUserLocation(locationService: LocationService) async -> CLLocation? {
        print("📍 CURRENT_FAVORITES_VM: Requesting user location")
        
        // Check if we already have a current location
        if let currentLocation = locationService.currentLocation {
            print("✅ CURRENT_FAVORITES_VM: Using existing location: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)")
            return currentLocation
        }
        
        // Request location permission if needed
        let hasPermission = await locationService.requestLocationPermission()
        guard hasPermission else {
            print("❌ CURRENT_FAVORITES_VM: Location permission denied")
            return nil
        }
        
        // Start location updates
        await MainActor.run {
            locationService.startUpdatingLocation()
        }
        
        // Wait a bit for location to be obtained and check again
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        if let location = locationService.currentLocation {
            print("✅ CURRENT_FAVORITES_VM: Location obtained after starting updates: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            return location
        } else {
            print("⚠️ CURRENT_FAVORITES_VM: No location available after starting updates")
            return nil
        }
    }
    
    // MARK: - User Actions
    
    func removeFavorite(at indexSet: IndexSet) {
        print("🗑️ CURRENT_FAVORITES_VM: Remove favorite called for indices: \(Array(indexSet))")
        
        Task {
            for index in indexSet {
                if index < favorites.count {
                    let favorite = favorites[index]
                    print("🗑️ CURRENT_FAVORITES_VM: Removing favorite: \(favorite.name) (ID: \(favorite.id))")
                    
                    if let currentStationService = currentStationService {
                        // Toggle the favorite status using the metadata-rich method
                        let newStatus = await currentStationService.toggleCurrentStationFavoriteWithMetadata(
                            id: favorite.id,
                            bin: favorite.currentBin ?? 0,
                            stationName: favorite.name,
                            latitude: favorite.latitude,
                            longitude: favorite.longitude,
                            depth: favorite.depth,
                            depthType: favorite.depthType
                        )
                        
                        print("🗑️ CURRENT_FAVORITES_VM: Toggle result for \(favorite.name): \(newStatus)")
                        
                        // Reload favorites to reflect the changes
                        await MainActor.run {
                            loadFavorites()
                        }
                    } else {
                        print("❌ CURRENT_FAVORITES_VM: No currentStationService available for removal")
                    }
                }
            }
        }
    }
    
    func cleanup() {
        print("🧹 CURRENT_FAVORITES_VM: Cleanup called")
        loadTask?.cancel()
        
    }
    
    // MARK: - Refresh Support
    
    func refreshFavorites() async {
        print("🔄 CURRENT_FAVORITES_VM: Manual refresh triggered")
        await MainActor.run {
            loadFavorites()
        }
        
    }
    
}
