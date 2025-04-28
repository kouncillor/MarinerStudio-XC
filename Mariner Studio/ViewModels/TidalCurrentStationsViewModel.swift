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

    // MARK: - Properties (Changed databaseService from private)
    private let tidalCurrentService: TidalCurrentService
    private let locationService: LocationService
    let databaseService: DatabaseService // <-- Removed 'private'
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
                    // Provide a default bin value if nil, e.g., 0 or handle appropriately
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
                isRefreshing = false // Ensure refreshing state is reset
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load stations: \(error.localizedDescription)"
                // Consider clearing stations array on error or keeping stale data
                // stations = []
                isLoading = false
                isRefreshing = false // Ensure refreshing state is reset
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
         // Using a background thread for potentially heavy filtering/sorting
        DispatchQueue.global(qos: .userInitiated).async {
            let filtered = self.allStations.filter { station in
                let matchesFavorite = !self.showOnlyFavorites || station.station.isFavorite
                let matchesSearch = self.searchText.isEmpty ||
                    station.station.name.localizedCaseInsensitiveContains(self.searchText) ||
                    (station.station.state?.localizedCaseInsensitiveContains(self.searchText) ?? false) ||
                    station.station.id.localizedCaseInsensitiveContains(self.searchText)

                return matchesFavorite && matchesSearch
            }

            // Sort stations by distance, then by favorite status, then by name
            let sorted = filtered.sorted { first, second in
                if first.distanceFromUser != second.distanceFromUser {
                    return first.distanceFromUser < second.distanceFromUser
                } else if first.station.isFavorite != second.station.isFavorite {
                    // If true (favorite) should come first, return true here
                    return first.station.isFavorite && !second.station.isFavorite
                } else {
                    return first.station.name.localizedCompare(second.station.name) == .orderedAscending
                }
            }

            // Update UI on the main thread
            DispatchQueue.main.async {
                self.stations = sorted
                self.totalStations = sorted.count
            }
        }
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
            await MainActor.run { // Ensure UI updates are on main thread
                 self.isLocationEnabled = authorized
                 if authorized {
                     self.locationService.startUpdatingLocation()
                      // Optionally update distances after location becomes available
                     self.updateDistances()
                 }
            }
        }
    }

     // New method to update distances when location changes or becomes available
     private func updateDistances() {
         guard locationService.currentLocation != nil else { return }
         // Create new StationWithDistance objects with updated distances
         let updatedStationsWithDistance = allStations.map { existingStationWithDistance in
             return StationWithDistance<TidalCurrentStation>.create(
                 station: existingStationWithDistance.station, // Keep existing station data
                 userLocation: locationService.currentLocation // Use new location
             )
         }
         self.allStations = updatedStationsWithDistance
         // Re-apply filter and sort which now uses updated distances
         filterStations()
     }
}

// Ensure StationWithDistance.create handles nil userLocation gracefully if needed
extension StationWithDistance where T: StationCoordinates {
    static func create(station: T, userLocation: CLLocation?) -> StationWithDistance<T> {
        let distance: Double
        if let userLoc = userLocation {
            let stationLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
            // Distance in kilometers
            distance = userLoc.distance(from: stationLocation) / 1000
        } else {
            // Assign a large value if user location is unknown
            distance = Double.greatestFiniteMagnitude
        }
        return StationWithDistance<T>(station: station, distanceFromUser: distance)
    }
}
