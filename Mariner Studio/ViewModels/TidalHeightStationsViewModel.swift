import Foundation
import CoreLocation
import SwiftUI

class TidalHeightStationsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var stations: [StationWithDistance<TidalHeightStation>] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var searchText = ""
    @Published var showOnlyFavorites = false
    @Published var totalStations = 0
    @Published var isLocationEnabled = false
    
    // MARK: - Private Properties
    private let tidalHeightService: TidalHeightService
    private let locationService: LocationService
    private let databaseService: DatabaseService
    private var allStations: [StationWithDistance<TidalHeightStation>] = []
    
    // MARK: - Initialization
    init(
        tidalHeightService: TidalHeightService,
        locationService: LocationService,
        databaseService: DatabaseService
    ) {
        self.tidalHeightService = tidalHeightService
        self.locationService = locationService
        self.databaseService = databaseService
        
        // Start listening for location updates
        requestLocationAccess()
    }
    
    // MARK: - Public Methods
    func loadStations() async {
        if isLoading { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            // Get stations from API
            let response = try await tidalHeightService.getTidalHeightStations()
            
            var stations = response.stations
            
            // Update favorite status
            for i in 0..<stations.count {
                stations[i].isFavorite = await databaseService.isTideStationFavorite(id: stations[i].id)
            }
            
            // Create stations with distance
            let stationsWithDistance = stations.map { station in
                return StationWithDistance<TidalHeightStation>.create(
                    station: station,
                    userLocation: locationService.currentLocation
                )
            }
            
            
            await MainActor.run {
                allStations = stationsWithDistance
                filterStations()
                isLocationEnabled = locationService.currentLocation != nil
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load stations: \(error.localizedDescription)"
                stations = []
                isLoading = false
            }
        }
    }
    
    func refreshStations() async {
        await loadStations()
    }
    
    func filterStations() {
        let filtered = allStations.filter { station in
            let matchesFavorite = !showOnlyFavorites || station.station.isFavorite
            let matchesSearch = searchText.isEmpty ||
                station.station.name.localizedCaseInsensitiveContains(searchText) ||
                (station.station.state?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                station.station.id.localizedCaseInsensitiveContains(searchText)
            
            return matchesFavorite && matchesSearch
        }
        
        // Sort stations by distance, then by favorite status, then by name
        let sorted = filtered.sorted { first, second in
            if first.distanceFromUser != second.distanceFromUser {
                return first.distanceFromUser < second.distanceFromUser
            } else if first.station.isFavorite != second.station.isFavorite {
                return first.station.isFavorite
            } else {
                return first.station.name < second.station.name
            }
        }
        
        stations = sorted
        totalStations = sorted.count
    }
    
    func toggleFavorites() {
        showOnlyFavorites.toggle()
        filterStations()
    }
    
    func clearSearch() {
        searchText = ""
        filterStations()
    }
    
    // MARK: - Private Methods
    private func requestLocationAccess() {
        Task {
            let authorized = await locationService.requestLocationPermission()
            if authorized {
                locationService.startUpdatingLocation()
            }
            
            await MainActor.run {
                isLocationEnabled = authorized
            }
        }
    }
}
