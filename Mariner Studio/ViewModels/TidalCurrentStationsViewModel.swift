import Foundation
import CoreLocation
import SwiftUI

class TidalCurrentStationsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var stations: [StationWithDistance<TidalCurrentStation>] = []
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
        print("✅ TidalCurrentStationsViewModel initialized. Will rely on ServiceProvider for location permission/start.")
    }

    // MARK: - Public Methods
    func loadStations() async {
        print("⏰ ViewModel (Currents): loadStations() started at \(Date())")

        guard !isLoading else {
             print("⏰ ViewModel (Currents): loadStations() exited early, already loading.")
             return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = ""
            print("⏰ ViewModel (Currents): Checking location in loadStations (MainActor block) at \(Date()). Current value: \(locationService.currentLocation?.description ?? "nil")")
            if let location = locationService.currentLocation {
                 self.userLatitude = String(format: "%.6f", location.coordinate.latitude)
                 self.userLongitude = String(format: "%.6f", location.coordinate.longitude)
             } else {
                 self.userLatitude = "Unknown"
                 self.userLongitude = "Unknown"
             }
        }

        do {
            print("⏰ ViewModel (Currents): Starting API call for stations at \(Date())")
            let response = try await tidalCurrentService.getTidalCurrentStations()
            print("⏰ ViewModel (Currents): Finished API call for stations at \(Date()). Count: \(response.count)")

            var stations = response.stations

            print("⏰ ViewModel (Currents): Starting favorite checks at \(Date())")
            await withTaskGroup(of: (String, Int?, Bool).self) { group in
                 for station in stations {
                     group.addTask {
                         let isFav: Bool
                         if let bin = station.currentBin {
                             isFav = await self.currentStationService.isCurrentStationFavorite(id: station.id, bin: bin)
                         } else {
                             isFav = await self.currentStationService.isCurrentStationFavorite(id: station.id)
                         }
                         return (station.id, station.currentBin, isFav)
                     }
                 }
                 var favoriteStatuses: [String: (bin: Int?, isFav: Bool)] = [:]
                 for await (id, bin, isFav) in group {
                     favoriteStatuses[id] = (bin: bin, isFav: isFav)
                 }
                 for i in 0..<stations.count {
                     stations[i].isFavorite = favoriteStatuses[stations[i].id]?.isFav ?? false
                 }
            }
            print("⏰ ViewModel (Currents): Finished favorite checks at \(Date())")

            print("⏰ ViewModel (Currents): Checking location for distance calculation at \(Date()). Current value: \(locationService.currentLocation?.description ?? "nil")")
            let currentLocationForDistance = locationService.currentLocation
            let stationsWithDistance = stations.map { station in
                return StationWithDistance<TidalCurrentStation>.create(
                    station: station,
                    userLocation: currentLocationForDistance
                )
            }

            print("⏰ ViewModel (Currents): Updating UI state (allStations, filterStations, isLoading) at \(Date())")
            await MainActor.run {
                allStations = stationsWithDistance
                filterStations()
                isLoading = false
                print("⏰ ViewModel (Currents): UI state update complete at \(Date())")
            }
        } catch {
            print("❌ ViewModel (Currents): Error in loadStations at \(Date()): \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to load stations: \(error.localizedDescription)"
                allStations = []
                self.stations = []
                totalStations = 0
                isLoading = false
            }
        }
         print("⏰ ViewModel (Currents): loadStations() finished at \(Date())")
    }

    func refreshStations() async {
         print("🔄 ViewModel (Currents): refreshStations() called at \(Date())")
         await MainActor.run {
              self.stations = []
              self.allStations = []
              self.totalStations = 0
         }
         await loadStations()
    }

    func filterStations() {
        print("🔄 ViewModel (Currents): filterStations() called at \(Date())")
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
             self.stations = sorted
             print("🔄 ViewModel (Currents): filterStations() updated self.stations on main thread at \(Date()). Count: \(sorted.count)")
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
        guard let stationToToggle = allStations.first(where: { $0.station.id == stationId })?.station else {
            print("❌ ViewModel (Currents): Could not find station \(stationId) to toggle favorite.")
            return
        }

        let newFavoriteStatus: Bool
        if let bin = stationToToggle.currentBin {
            newFavoriteStatus = await currentStationService.toggleCurrentStationFavorite(id: stationId, bin: bin)
            print("⭐ ViewModel (Currents): Toggled favorite for \(stationId) (bin: \(bin)) to \(newFavoriteStatus) at \(Date())")
        } else {
            newFavoriteStatus = await currentStationService.toggleCurrentStationFavorite(id: stationId)
            print("⭐ ViewModel (Currents): Toggled favorite for \(stationId) (no bin) to \(newFavoriteStatus) at \(Date())")
        }

        await MainActor.run {
            if let index = allStations.firstIndex(where: { $0.station.id == stationId }) {
                var updatedStation = allStations[index].station
                updatedStation.isFavorite = newFavoriteStatus
                allStations[index] = StationWithDistance(
                    station: updatedStation,
                    distanceFromUser: allStations[index].distanceFromUser
                )
                print("⭐ ViewModel (Currents): Updated allStations array for \(stationId) at \(Date())")
            } else {
                 print("❌ ViewModel (Currents): Station \(stationId) not found in allStations after toggle at \(Date())")
            }

            filterStations()
        }
    }
}
