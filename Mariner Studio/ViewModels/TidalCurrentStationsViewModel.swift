
import Foundation
import CoreLocation
import SwiftUI

class TidalCurrentStationsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var stations: [StationWithDistance<TidalCurrentStation>] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var searchText = ""
    @Published var totalStations = 0
    @Published var userLatitude: String = "Unknown"
    @Published var userLongitude: String = "Unknown"
    @Published var showOnlyFavorites = false

    // MARK: - Computed Property for Location Status
    var isLocationEnabled: Bool {
        let status = locationService.permissionStatus
        print("🔍 VIEWMODEL: Checking location permission status: \(status)")
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    // MARK: - Properties
    let currentStationService: CurrentStationDatabaseService
    private let tidalCurrentService: TidalCurrentService
    private let locationService: LocationService
    private var allStations: [StationWithDistance<TidalCurrentStation>] = []

    // MARK: - Initialization
    init(
        tidalCurrentService: TidalCurrentService,
        locationService: LocationService,
        currentStationService: CurrentStationDatabaseService
    ) {
        self.tidalCurrentService = tidalCurrentService
        self.locationService = locationService
        self.currentStationService = currentStationService
        print("✅ VIEWMODEL: TidalCurrentStationsViewModel initialized successfully")
        print("📊 VIEWMODEL: Database service injected: \(type(of: currentStationService))")
        print("🌐 VIEWMODEL: Network service injected: \(type(of: tidalCurrentService))")
        print("📍 VIEWMODEL: Location service injected: \(type(of: locationService))")
    }

    // MARK: - Public Methods
    func loadStations() async {
        print("\n🚀 VIEWMODEL: ===== LOAD STATIONS START =====")
        print("⏰ VIEWMODEL: loadStations() started at \(Date())")
        print("🔄 VIEWMODEL: Current loading state: \(isLoading)")

        guard !isLoading else {
            print("⚠️ VIEWMODEL: loadStations() exited early - already loading")
            return
        }

        print("📱 VIEWMODEL: Setting loading state to true and clearing errors")
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            print("📍 VIEWMODEL: Checking location for UI update at \(Date())")
            if let location = locationService.currentLocation {
                 self.userLatitude = String(format: "%.6f", location.coordinate.latitude)
                 self.userLongitude = String(format: "%.6f", location.coordinate.longitude)
                 print("📍 VIEWMODEL: User location updated - Lat: \(self.userLatitude), Lng: \(self.userLongitude)")
             } else {
                 self.userLatitude = "Unknown"
                 self.userLongitude = "Unknown"
                 print("📍 VIEWMODEL: No user location available")
             }
        }

        do {
            print("🌐 VIEWMODEL: Starting NOAA API call for tidal current stations")
            print("⏰ VIEWMODEL: API call start time: \(Date())")
            
            let response = try await tidalCurrentService.getTidalCurrentStations()
            
            print("✅ VIEWMODEL: API call completed successfully")
            print("⏰ VIEWMODEL: API call end time: \(Date())")
            print("📊 VIEWMODEL: Received \(response.stations.count) stations from NOAA API")

            let stations = response.stations
            
            // ⭐ REMOVED: All favorite checking logic - NO DATABASE CALLS HERE! ⭐
            print("🚫 VIEWMODEL: SKIPPING favorite status checks - no database calls will be made")
            print("🚫 VIEWMODEL: No authentication calls will be made")
            print("🚫 VIEWMODEL: Favorites will be handled elsewhere in the app")
            
            print("📏 VIEWMODEL: Starting distance calculation for \(stations.count) stations")
            print("📍 VIEWMODEL: Using location for distance calc: \(locationService.currentLocation?.description ?? "nil")")
            
            let currentLocationForDistance = locationService.currentLocation
            let stationsWithDistance = stations.map { station in
                return StationWithDistance<TidalCurrentStation>.create(
                    station: station,
                    userLocation: currentLocationForDistance
                )
            }
            
            print("✅ VIEWMODEL: Distance calculation completed for \(stationsWithDistance.count) stations")

            print("📱 VIEWMODEL: Updating UI state on main thread")
            await MainActor.run {
                print("📱 VIEWMODEL: Setting allStations array with \(stationsWithDistance.count) items")
                allStations = stationsWithDistance
                
                print("🔍 VIEWMODEL: Calling filterStations() to apply search filters")
                filterStations()
                
                print("📱 VIEWMODEL: Setting loading state to false")
                isLoading = false
                
                print("✅ VIEWMODEL: UI state update complete - stations count: \(self.stations.count)")
            }
            
        } catch {
            print("❌ VIEWMODEL: Error in loadStations() at \(Date())")
            print("❌ VIEWMODEL: Error details: \(error.localizedDescription)")
            print("❌ VIEWMODEL: Error type: \(type(of: error))")
            
            await MainActor.run {
                errorMessage = "Failed to load stations: \(error.localizedDescription)"
                allStations = []
                self.stations = []
                totalStations = 0
                isLoading = false
                print("❌ VIEWMODEL: Error state set - UI updated with empty data")
            }
        }
        
        print("🏁 VIEWMODEL: loadStations() finished at \(Date())")
        print("🚀 VIEWMODEL: ===== LOAD STATIONS END =====\n")
    }

    func refreshStations() async {
        print("\n🔄 VIEWMODEL: ===== REFRESH STATIONS START =====")
        print("🔄 VIEWMODEL: refreshStations() called at \(Date())")
        
        await MainActor.run {
            print("🗑️ VIEWMODEL: Clearing existing station data")
            self.stations = []
            self.allStations = []
            self.totalStations = 0
        }
        
        print("🔄 VIEWMODEL: Calling loadStations() for refresh")
        await loadStations()
        print("🔄 VIEWMODEL: ===== REFRESH STATIONS END =====\n")
    }

    func filterStations() {
        print("\n🔍 VIEWMODEL: ===== FILTER STATIONS START =====")
        print("🔍 VIEWMODEL: filterStations() called at \(Date())")
        print("🔍 VIEWMODEL: Search text: '\(searchText)'")
        print("🔍 VIEWMODEL: Total stations to filter: \(allStations.count)")
        
        let filtered = allStations.filter { station in
            let matchesSearch = searchText.isEmpty ||
                station.station.name.localizedCaseInsensitiveContains(searchText) ||
                (station.station.state?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                station.station.id.localizedCaseInsensitiveContains(searchText)
            
            let matchesFavorites = !showOnlyFavorites || station.station.isFavorite
            
            return matchesSearch && matchesFavorites
        }
        
        print("✅ VIEWMODEL: Filtering complete")
        print("📊 VIEWMODEL: Filtered results: \(filtered.count) stations")
        
        // Sort strictly by distance (closest first)
        print("🔄 VIEWMODEL: Starting sort by distance (closest first)")
        let sorted = filtered.sorted { first, second in
            return first.distanceFromUser < second.distanceFromUser
        }
        
        print("✅ VIEWMODEL: Distance sorting complete")
        print("📊 VIEWMODEL: Filter efficiency: \(sorted.count)/\(allStations.count) stations shown")
        
        // Log first few stations to verify distance sorting
        print("🔍 VIEWMODEL: Top 5 closest stations:")
        for (index, station) in sorted.prefix(5).enumerated() {
            let distanceText = station.distanceFromUser == Double.greatestFiniteMagnitude ? "No location" : String(format: "%.1f mi", station.distanceFromUser * 0.621371)
            print("🔍 VIEWMODEL: \(index + 1). \(station.station.name) - \(distanceText)")
        }
        
        stations = sorted
        totalStations = sorted.count
        
        print("📱 VIEWMODEL: Published properties updated")
        print("🔍 VIEWMODEL: ===== FILTER STATIONS END =====\n")
    }

    func clearSearch() {
        print("\n🗑️ VIEWMODEL: ===== CLEAR SEARCH START =====")
        print("🗑️ VIEWMODEL: Clearing search text (was: '\(searchText)')")
        searchText = ""
        print("🔍 VIEWMODEL: Calling filterStations() after clearing search")
        filterStations()
        print("🗑️ VIEWMODEL: ===== CLEAR SEARCH END =====\n")
    }
    
    func toggleFavorites() {
        print("\n⭐ VIEWMODEL: ===== TOGGLE FAVORITES START =====")
        print("⭐ VIEWMODEL: Current showOnlyFavorites: \(showOnlyFavorites)")
        showOnlyFavorites.toggle()
        print("⭐ VIEWMODEL: New showOnlyFavorites: \(showOnlyFavorites)")
        print("🔍 VIEWMODEL: Calling filterStations() to apply favorites filter")
        filterStations()
        print("⭐ VIEWMODEL: ===== TOGGLE FAVORITES END =====\n")
    }
    
    func toggleStationFavorite(stationId: String) async {
        print("\n⭐ VIEWMODEL: ===== TOGGLE STATION FAVORITE START =====")
        print("⭐ VIEWMODEL: Toggling favorite for station: \(stationId)")
        
        // Find the station object first to get the metadata
        guard let stationWithDistance = allStations.first(where: { $0.station.id == stationId }) else {
            print("❌ VIEWMODEL: Could not find station \(stationId) in allStations")
            return
        }
        
        let currentStation = stationWithDistance.station
        
        let newFavoriteStatus = await currentStationService.toggleCurrentStationFavoriteWithMetadata(
            id: stationId,
            bin: currentStation.currentBin ?? 0,
            stationName: currentStation.name,
            latitude: currentStation.latitude,
            longitude: currentStation.longitude,
            depth: currentStation.depth,
            depthType: currentStation.depthType
        )
        
        print("⭐ VIEWMODEL: Toggle completed for station \(stationId), new status: \(newFavoriteStatus)")

        if let index = allStations.firstIndex(where: { $0.station.id == stationId }) {
            var updatedStation = allStations[index].station
            updatedStation.isFavorite = newFavoriteStatus
            allStations[index] = StationWithDistance(
                station: updatedStation,
                distanceFromUser: allStations[index].distanceFromUser
            )
            
            await MainActor.run {
                filterStations()
            }
            
            print("⭐ VIEWMODEL: Updated station \(stationId) in allStations array")
        }
        
        print("⭐ VIEWMODEL: ===== TOGGLE STATION FAVORITE END =====\n")
    }
}
