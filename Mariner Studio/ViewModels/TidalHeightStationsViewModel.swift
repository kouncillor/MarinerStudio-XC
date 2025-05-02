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
        print("✅ TidalHeightStationsViewModel initialized. Will rely on ServiceProvider for location permission/start.")
    }

    // MARK: - Public Methods
    func loadStations() async {
        // --- ADDED PRINT STATEMENT FOR TIMING PROOF ---
        print("⏰ ViewModel: loadStations() started at \(Date())")
        // ---------------------------------------------

        guard !isLoading else {
             print("⏰ ViewModel: loadStations() exited early, already loading.") // Added for clarity
             return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = ""
            // Print location check time within MainActor block as well
            print("⏰ ViewModel: Checking location in loadStations (MainActor block) at \(Date()). Current value: \(locationService.currentLocation?.description ?? "nil")")
            if let location = locationService.currentLocation {
                 self.userLatitude = String(format: "%.6f", location.coordinate.latitude)
                 self.userLongitude = String(format: "%.6f", location.coordinate.longitude)
             } else {
                 self.userLatitude = "Unknown"
                 self.userLongitude = "Unknown"
             }
        }

        do {
            print("⏰ ViewModel: Starting API call for stations at \(Date())") // Added API call timing
            let response = try await tidalHeightService.getTidalHeightStations()
            print("⏰ ViewModel: Finished API call for stations at \(Date())") // Added API call timing

            var stations = response.stations

            print("⏰ ViewModel: Starting favorite checks at \(Date())") // Added favorite check timing
            await withTaskGroup(of: (String, Bool).self) { group in
                for station in stations {
                    group.addTask {
                        let isFav = await self.databaseService.isTideStationFavorite(id: station.id)
                        return (station.id, isFav)
                    }
                }
                var favoriteStatuses: [String: Bool] = [:]
                for await (id, isFav) in group {
                    favoriteStatuses[id] = isFav
                }
                for i in 0..<stations.count {
                    stations[i].isFavorite = favoriteStatuses[stations[i].id] ?? false
                }
            }
             print("⏰ ViewModel: Finished favorite checks at \(Date())") // Added favorite check timing


            print("⏰ ViewModel: Checking location for distance calculation at \(Date()). Current value: \(locationService.currentLocation?.description ?? "nil")") // Added distance check timing
            let currentLocationForDistance = locationService.currentLocation
            let stationsWithDistance = stations.map { station in
                return StationWithDistance<TidalHeightStation>.create(
                    station: station,
                    userLocation: currentLocationForDistance
                )
            }

            print("⏰ ViewModel: Updating UI state (allStations, filterStations, isLoading) at \(Date())") // Added UI update timing
            await MainActor.run {
                allStations = stationsWithDistance
                filterStations()
                isLoading = false
                 print("⏰ ViewModel: UI state update complete at \(Date())") // Added UI update timing
            }
        } catch {
             print("❌ ViewModel: Error in loadStations at \(Date()): \(error.localizedDescription)") // Added error timing
            await MainActor.run {
                errorMessage = "Failed to load stations: \(error.localizedDescription)"
                allStations = []
                self.stations = []
                totalStations = 0
                isLoading = false
            }
        }
        print("⏰ ViewModel: loadStations() finished at \(Date())") // Added overall finish time
    }

    // ... (rest of the ViewModel code: refreshStations, filterStations, toggleFavorites, toggleStationFavorite remains the same) ...
     func refreshStations() async {
         await MainActor.run {
              self.stations = []
              self.allStations = []
              self.totalStations = 0
         }
         await loadStations()
     }

     func filterStations() {
          // This print helps see when sorting actually happens
          print("🔄 ViewModel: filterStations() called at \(Date())")
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

          // Update the @Published property on the main thread
          DispatchQueue.main.async {
              // Avoid redundant updates if the list hasn't changed
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
         let newFavoriteStatus = await databaseService.toggleTideStationFavorite(id: stationId)

         if let index = allStations.firstIndex(where: { $0.station.id == stationId }) {
             var updatedStation = allStations[index].station
             updatedStation.isFavorite = newFavoriteStatus
             allStations[index] = StationWithDistance(
                 station: updatedStation,
                 distanceFromUser: allStations[index].distanceFromUser
             )
             filterStations()
         }
     }
}
