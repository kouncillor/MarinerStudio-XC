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
    @Published var userLatitude: String = "Unknown"
    @Published var userLongitude: String = "Unknown"

    // MARK: - Computed Property for Location Status
    var isLocationEnabled: Bool {
        let status = locationService.permissionStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    // MARK: - Properties
    let tideFavoritesCloudService: TideFavoritesCloudService
    private let tidalHeightService: TidalHeightService
    private let locationService: LocationService
    private var allStations: [StationWithDistance<TidalHeightStation>] = []

    // MARK: - Initialization
    init(
        tidalHeightService: TidalHeightService,
        locationService: LocationService,
        tideFavoritesCloudService: TideFavoritesCloudService
    ) {
        self.tidalHeightService = tidalHeightService
        self.locationService = locationService
        self.tideFavoritesCloudService = tideFavoritesCloudService
        print("✅ TidalHeightStationsViewModel initialized with CLOUD-ONLY favorites service.")
    }

    // MARK: - Public Methods
    func loadStations() async {
        print("⏰ ViewModel: loadStations() started at \(Date())")

        guard !isLoading else {
             print("⏰ ViewModel: loadStations() exited early, already loading.")
             return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = ""
            print("⏰ ViewModel: Checking location in loadStations (MainActor block) at \(Date()). Current value: \(locationService.currentLocation?.description ?? "nil")")
        }

        do {
            let response = try await tidalHeightService.getTidalHeightStations()
            print("🌐 ViewModel: API returned \(response.stations.count) stations at \(Date())")

            let stationsWithDistance = await processStationsWithDistance(response.stations)
            print("📍 ViewModel: Processed stations with distance and favorites at \(Date())")

            await MainActor.run {
                self.allStations = stationsWithDistance
                self.isLoading = false
                print("🏁 ViewModel: Updated allStations and set isLoading=false on main thread at \(Date())")
            }

            filterStations()
        } catch {
            print("❌ ViewModel: Error loading stations at \(Date()): \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to load stations: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    // MARK: - Private Helper Methods
    private func processStationsWithDistance(_ stations: [TidalHeightStation]) async -> [StationWithDistance<TidalHeightStation>] {
        let userLocation = locationService.currentLocation

        await MainActor.run {
            if let location = userLocation {
                self.userLatitude = String(format: "%.6f", location.coordinate.latitude)
                self.userLongitude = String(format: "%.6f", location.coordinate.longitude)
            }
        }

        // Get all favorites at once (much more efficient than individual calls)
        let favoritesResult = await tideFavoritesCloudService.getFavorites()
        let favoriteStations = (try? favoritesResult.get()) ?? []
        let favoriteStationIds = Set(favoriteStations.map { $0.id })
        print("📍 ViewModel: Retrieved \(favoriteStationIds.count) favorite station IDs for checking")

        var stationsWithDistance: [StationWithDistance<TidalHeightStation>] = []

        for station in stations {
            let distance: Double
            if let userLoc = userLocation,
               let stationLat = station.latitude,
               let stationLon = station.longitude {
                let stationLocation = CLLocation(latitude: stationLat, longitude: stationLon)
                distance = userLoc.distance(from: stationLocation) / 1000 // Convert meters to km
            } else {
                distance = Double.greatestFiniteMagnitude
            }

            // Check if station is favorite using the Set lookup (O(1) instead of O(n) network calls)
            var updatedStation = station
            updatedStation.isFavorite = favoriteStationIds.contains(station.id)

            stationsWithDistance.append(StationWithDistance(
                station: updatedStation,
                distanceFromUser: distance
            ))
        }

        return stationsWithDistance
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

          let sorted = filtered.sorted { first, second in
               if first.distanceFromUser != Double.greatestFiniteMagnitude && second.distanceFromUser == Double.greatestFiniteMagnitude {
                   return true
               } else if first.distanceFromUser == Double.greatestFiniteMagnitude && second.distanceFromUser != Double.greatestFiniteMagnitude {
                   return false
               } else if first.distanceFromUser != second.distanceFromUser {
                   return first.distanceFromUser < second.distanceFromUser
               } else if first.station.isFavorite != second.station.isFavorite {
                   return first.station.isFavorite && !second.station.isFavorite
               } else {
                   return first.station.name.localizedCompare(second.station.name) == .orderedAscending
               }
          }

          DispatchQueue.main.async {
              if self.stations.map({ $0.id }) != sorted.map({ $0.id }) {
                  self.stations = sorted
                  print("🔄 ViewModel: filterStations() updated self.stations on main thread at \(Date()). Count: \(sorted.count)")
              }
              self.totalStations = sorted.count
          }
     }

     func toggleFavorites() {
         showOnlyFavorites.toggle()
         filterStations()
     }

     func clearSearch() {
         searchText = ""
         filterStations()
     }

    func toggleStationFavorite(stationId: String) async {
        print("⭐ ViewModel: Starting toggle for station \(stationId)")

        // Find the station object first to get the name and coordinates
        guard let stationWithDistance = allStations.first(where: { $0.station.id == stationId }) else {
            print("❌ ViewModel: Could not find station \(stationId) in allStations")
            return
        }

        let currentStation = stationWithDistance.station

        let toggleResult = await tideFavoritesCloudService.toggleFavorite(
            stationId: stationId,
            stationName: currentStation.name,
            latitude: currentStation.latitude,
            longitude: currentStation.longitude
        )

        let newFavoriteStatus: Bool
        switch toggleResult {
        case .success(let status):
            newFavoriteStatus = status
        case .failure(let error):
            print("❌ ViewModel: Failed to toggle favorite for station \(stationId): \(error)")
            return // Exit early if toggle failed
        }

        print("⭐ ViewModel: Toggle completed for station \(stationId), new status: \(newFavoriteStatus)")

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

            print("⭐ ViewModel: Updated station \(stationId) in allStations array")
        }

        // No sync needed - cloud service is the single source of truth
    }

}

// MARK: - Cloud-Only Implementation
// No sync extension needed - cloud service is the single source of truth
