// TidalCurrentStationsViewModel.swift

import Foundation
import CoreLocation
import SwiftUI

class TidalCurrentStationsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var stations: [StationWithDistance<TidalCurrentStation>] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage = ""
    @Published var searchText = ""
    @Published var showOnlyFavorites = false
    @Published var totalStations = 0
    @Published var isLocationEnabled = false
    @Published var favoritesFilterIcon = "star"
    
    // MARK: - Private Properties
    private let tidalCurrentService: TidalCurrentService
    private let locationService: LocationService
    private let databaseService: DatabaseService
    private var allStations: [StationWithDistance<TidalCurrentStation>] = []
    
    // MARK: - Initialization
    init(
        tidalCurrentService: TidalCurrentService,
        locationService: LocationService,
        databaseService: DatabaseService
    ) {
        self.tidalCurrentService = tidalCurrentService
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
            let response = try await tidalCurrentService.getTidalCurrentStations()
            
            var stations = response.stations
            
            // Update favorite status
            for i in 0..<stations.count {
                if let bin = stations[i].currentBin {
                    stations[i].isFavorite = await databaseService.isCurrentStationFavorite(id: stations[i].id, bin: bin)
                } else {
                    stations[i].isFavorite = await databaseService.isCurrentStationFavorite(id: stations[i].id, bin: 0)
                }
            }
            
            // Create stations with distance
            let stationsWithDistance = stations.map { station in
                return StationWithDistance<TidalCurrentStation>.create(
                    station: station,
                    userLocation: locationService.currentLocation
                )
            }
            
            await MainActor.run {
                allStations = stationsWithDistance
                filterStations()
                isLocationEnabled = locationService.currentLocation != nil
                isLoading = false
                isRefreshing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load stations: \(error.localizedDescription)"
                stations = []
                isLoading = false
                isRefreshing = false
            }
        }
    }
    
    func refreshStations() async {
        await MainActor.run {
            isRefreshing = true
        }
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
        favoritesFilterIcon = showOnlyFavorites ? "star.fill" : "star"
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
