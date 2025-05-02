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
    @Published var userLatitude: String = "Unknown" // Added for consistency
    @Published var userLongitude: String = "Unknown" // Added for consistency

    // MARK: - Computed Property for Location Status
    var isLocationEnabled: Bool { // Changed from @Published var to computed var
        let status = locationService.permissionStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

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
        print("✅ TidalCurrentStationsViewModel initialized. Will rely on ServiceProvider for location permission/start.") // Added init log
        // Removed the call to the removed requestLocationAccess()
    }

    // MARK: - Public Methods
    func loadStations() async {
        // --- ADDED PRINT STATEMENT FOR TIMING PROOF ---
        print("⏰ ViewModel (Currents): loadStations() started at \(Date())")
        // ---------------------------------------------

        guard !isLoading else {
             print("⏰ ViewModel (Currents): loadStations() exited early, already loading.") // Added for clarity
             return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = ""
            // Print location check time within MainActor block as well
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
            print("⏰ ViewModel (Currents): Starting API call for stations at \(Date())") // Added API call timing
            let response = try await tidalCurrentService.getTidalCurrentStations()
            print("⏰ ViewModel (Currents): Finished API call for stations at \(Date()). Count: \(response.count)") // Added API call timing

            var stations = response.stations

            print("⏰ ViewModel (Currents): Starting favorite checks at \(Date())") // Added favorite check timing
            // Update favorite status (using task group for potential performance gain)
            await withTaskGroup(of: (String, Int?, Bool).self) { group in
                 for station in stations {
                     group.addTask {
                         let isFav: Bool
                         if let bin = station.currentBin {
                             isFav = await self.databaseService.isCurrentStationFavorite(id: station.id, bin: bin)
                         } else {
                             isFav = await self.databaseService.isCurrentStationFavorite(id: station.id)
                         }
                         return (station.id, station.currentBin, isFav) // Return bin as well
                     }
                 }
                 var favoriteStatuses: [String: (bin: Int?, isFav: Bool)] = [:]
                 for await (id, bin, isFav) in group {
                     favoriteStatuses[id] = (bin: bin, isFav: isFav)
                 }
                 // Apply favorite status back to the stations array
                 for i in 0..<stations.count {
                     stations[i].isFavorite = favoriteStatuses[stations[i].id]?.isFav ?? false
                 }
            }
            print("⏰ ViewModel (Currents): Finished favorite checks at \(Date())") // Added favorite check timing


            print("⏰ ViewModel (Currents): Checking location for distance calculation at \(Date()). Current value: \(locationService.currentLocation?.description ?? "nil")") // Added distance check timing
            let currentLocationForDistance = locationService.currentLocation
            // Create stations with distance
            let stationsWithDistance = stations.map { station in
                return StationWithDistance<TidalCurrentStation>.create(
                    station: station,
                    userLocation: currentLocationForDistance // Use the captured location
                )
            }

            print("⏰ ViewModel (Currents): Updating UI state (allStations, filterStations, isLoading) at \(Date())") // Added UI update timing
            await MainActor.run {
                allStations = stationsWithDistance
                filterStations() // Filter and sort with updated data
                // isLocationEnabled is now computed, no need to set it here
                isLoading = false
                print("⏰ ViewModel (Currents): UI state update complete at \(Date())") // Added UI update timing
            }
        } catch {
            print("❌ ViewModel (Currents): Error in loadStations at \(Date()): \(error.localizedDescription)") // Added error timing
            await MainActor.run {
                errorMessage = "Failed to load stations: \(error.localizedDescription)"
                allStations = [] // Clear all stations on error
                self.stations = [] // Clear filtered stations on error
                totalStations = 0
                isLoading = false
            }
        }
         print("⏰ ViewModel (Currents): loadStations() finished at \(Date())") // Added overall finish time
    }

    func refreshStations() async {
         // Added print for refresh action
         print("🔄 ViewModel (Currents): refreshStations() called at \(Date())")
         // Reset state before reloading
         await MainActor.run {
              self.stations = []
              self.allStations = []
              self.totalStations = 0
         }
         await loadStations()
    }

    func filterStations() {
        // This print helps see when sorting actually happens
        print("🔄 ViewModel (Currents): filterStations() called at \(Date())")
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
             // Prioritize stations with known distance
             if first.distanceFromUser != Double.greatestFiniteMagnitude && second.distanceFromUser == Double.greatestFiniteMagnitude {
                 return true // first comes before second
             } else if first.distanceFromUser == Double.greatestFiniteMagnitude && second.distanceFromUser != Double.greatestFiniteMagnitude {
                 return false // second comes before first
             } else if first.distanceFromUser != second.distanceFromUser {
                 // Both have valid distances, sort by distance
                 return first.distanceFromUser < second.distanceFromUser
             } else if first.station.isFavorite != second.station.isFavorite {
                 // Distances are equal (or both infinite), sort by favorite
                 return first.station.isFavorite && !second.station.isFavorite // Favorites first
             } else {
                 // Distances and favorite status are equal, sort by name
                 return first.station.name.localizedCompare(second.station.name) == .orderedAscending
             }
        }

         // Update the @Published property on the main thread
         DispatchQueue.main.async {
             // Avoid redundant updates if the list hasn't changed (optional optimization)
             // if self.stations.map({ $0.id }) != sorted.map({ $0.id }) {
                 self.stations = sorted
                 print("🔄 ViewModel (Currents): filterStations() updated self.stations on main thread at \(Date()). Count: \(sorted.count)")
             // }
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
        // Find the station first to determine if it has a bin
        guard let stationToToggle = allStations.first(where: { $0.station.id == stationId })?.station else {
            print("❌ ViewModel (Currents): Could not find station \(stationId) to toggle favorite.")
            return
        }

        // Call the appropriate database function based on whether a bin exists
        let newFavoriteStatus: Bool
        if let bin = stationToToggle.currentBin {
            newFavoriteStatus = await databaseService.toggleCurrentStationFavorite(id: stationId, bin: bin)
            print("⭐ ViewModel (Currents): Toggled favorite for \(stationId) (bin: \(bin)) to \(newFavoriteStatus) at \(Date())")
        } else {
            newFavoriteStatus = await databaseService.toggleCurrentStationFavorite(id: stationId)
            print("⭐ ViewModel (Currents): Toggled favorite for \(stationId) (no bin) to \(newFavoriteStatus) at \(Date())")
        }

        // Update local data on the main thread
        await MainActor.run {
            // Update in allStations first
            if let index = allStations.firstIndex(where: { $0.station.id == stationId }) {
                var updatedStation = allStations[index].station
                updatedStation.isFavorite = newFavoriteStatus
                // Create a new StationWithDistance to replace the old one
                allStations[index] = StationWithDistance(
                    station: updatedStation,
                    distanceFromUser: allStations[index].distanceFromUser
                )
                print("⭐ ViewModel (Currents): Updated allStations array for \(stationId) at \(Date())")
            } else {
                 print("❌ ViewModel (Currents): Station \(stationId) not found in allStations after toggle at \(Date())")
            }

            // Re-apply filters to update the filtered stations list
            filterStations()
        }
    }

    // MARK: - Private Methods
    // Removed requestLocationAccess() as it's handled by ServiceProvider
}
