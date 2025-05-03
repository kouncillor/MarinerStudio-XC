import Foundation
import SwiftUI
import CoreLocation

class NavUnitsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var filteredNavUnits: [StationWithDistance<NavUnit>] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var totalNavUnits = 0
    @Published var searchText = ""
    @Published var showOnlyFavorites = false
    @Published var userLatitude: String = "Unknown"
    @Published var userLongitude: String = "Unknown"

    // MARK: - Computed Property for Location Status
    var isLocationEnabled: Bool {
        let status = locationService.permissionStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    // MARK: - Properties
    let navUnitService: NavUnitDatabaseService
    private let locationService: LocationService
    private var allNavUnits: [StationWithDistance<NavUnit>] = []

    // MARK: - Initialization
    init(navUnitService: NavUnitDatabaseService, locationService: LocationService) {
        self.navUnitService = navUnitService
        self.locationService = locationService
        print("✅ NavUnitsViewModel initialized. Will rely on ServiceProvider for location. Dynamic updates disabled.")
    }

    // MARK: - Public Methods
    func loadNavUnits() async {
        print("⏰ ViewModel (NavUnits): loadNavUnits() started at \(Date())")

        guard !isLoading else {
             print("⏰ ViewModel (NavUnits): loadNavUnits() exited early, already loading.")
             return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = ""
            print("⏰ ViewModel (NavUnits): Checking location in loadNavUnits (MainActor block) at \(Date()). Current value: \(locationService.currentLocation?.description ?? "nil")")
            updateUserCoordinates() // Update displayed coordinates based on current location
        }

        do {
            print("⏰ ViewModel (NavUnits): Starting Database call for NavUnits at \(Date())")
            let units = try await navUnitService.getNavUnitsAsync()
            print("⏰ ViewModel (NavUnits): Finished Database call. Count: \(units.count) at \(Date())")

            print("⏰ ViewModel (NavUnits): Checking location for distance calculation at \(Date()). Current value: \(locationService.currentLocation?.description ?? "nil")")
            let currentLocationForDistance = locationService.currentLocation
            let unitsWithDistance = units.map { unit in
                return StationWithDistance<NavUnit>.create(
                    station: unit,
                    userLocation: currentLocationForDistance
                )
            }

            // *** ADDED: Log Calculated Distances ***
            print("🔍 Distances Calculated (First 5):")
            for (index, unitDist) in unitsWithDistance.prefix(5).enumerated() {
                print("🔍 \(index): \(unitDist.station.navUnitName) - Dist: \(unitDist.distanceFromUser)")
            }
            // *************************************

            print("⏰ ViewModel (NavUnits): Updating UI state (allNavUnits, filterNavUnits, isLoading) at \(Date())")
            await MainActor.run {
                allNavUnits = unitsWithDistance // Store units with calculated distances
                filterNavUnits() // Apply initial filter/sort based on these distances
                isLoading = false
                print("⏰ ViewModel (NavUnits): UI state update complete at \(Date())")
            }
        } catch {
            print("❌ ViewModel (NavUnits): Error in loadNavUnits at \(Date()): \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to load navigation units: \(error.localizedDescription)"
                allNavUnits = []
                self.filteredNavUnits = []
                totalNavUnits = 0
                isLoading = false
            }
        }
        print("⏰ ViewModel (NavUnits): loadNavUnits() finished at \(Date())")
    }

    func refreshNavUnits() async {
         print("🔄 ViewModel (NavUnits): refreshNavUnits() called at \(Date())")
         // Reset state before reloading
         await MainActor.run {
              self.filteredNavUnits = []
              self.allNavUnits = []
              self.totalNavUnits = 0
         }
         // loadNavUnits will recalculate distances with the latest location
         await loadNavUnits()
    }

    // Filter/sort logic remains the same, uses distances stored in allNavUnits
    func filterNavUnits() {
        print("🔄 ViewModel (NavUnits): filterNavUnits() called at \(Date())")
        let currentSearchText = self.searchText
        let currentShowOnlyFavorites = self.showOnlyFavorites

        let filtered = self.allNavUnits.filter { unit in
             let matchesFavorite = !currentShowOnlyFavorites || unit.station.isFavorite
             let matchesSearch = currentSearchText.isEmpty ||
                 unit.station.navUnitName.localizedCaseInsensitiveContains(currentSearchText) ||
                 (unit.station.location?.localizedCaseInsensitiveContains(currentSearchText) ?? false) ||
                 (unit.station.cityOrTown?.localizedCaseInsensitiveContains(currentSearchText) ?? false) ||
                 (unit.station.statePostalCode?.localizedCaseInsensitiveContains(currentSearchText) ?? false) ||
                 unit.station.navUnitId.localizedCaseInsensitiveContains(currentSearchText)

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
                return first.station.navUnitName.localizedCompare(second.station.navUnitName) == .orderedAscending
            }
        }

        // *** ADDED: Log Sort Result ***
        print("🔍 Sort Result (First 5):")
        for (index, unitDist) in sorted.prefix(5).enumerated() {
            print("🔍 \(index): \(unitDist.station.navUnitName) - Dist: \(unitDist.distanceFromUser)")
        }
        // ****************************

        DispatchQueue.main.async {
            self.filteredNavUnits = sorted
            self.totalNavUnits = sorted.count
            print("🔄 ViewModel (NavUnits): filterNavUnits() updated self.filteredNavUnits on main thread at \(Date()). Count: \(sorted.count)")
        }
    }

    func searchTextChanged() {
         filterNavUnits()
     }

    func favoritesToggleChanged() {
         filterNavUnits()
     }

    func clearSearch() {
          searchText = ""
          filterNavUnits()
    }

    func toggleNavUnitFavorite(navUnitId: String) async {
        do {
            print("⭐ ViewModel (NavUnits): Toggling favorite for \(navUnitId) at \(Date())")
            let newFavoriteStatus = try await navUnitService.toggleFavoriteNavUnitAsync(navUnitId: navUnitId)
            print("⭐ ViewModel (NavUnits): Database returned new status \(newFavoriteStatus) for \(navUnitId) at \(Date())")

            await MainActor.run {
                 if let index = allNavUnits.firstIndex(where: { $0.station.navUnitId == navUnitId }) {
                      var updatedUnit = allNavUnits[index].station
                      updatedUnit.isFavorite = newFavoriteStatus
                      // We also need to update the distance from the existing object
                      let currentDistance = allNavUnits[index].distanceFromUser
                      allNavUnits[index] = StationWithDistance(
                          station: updatedUnit,
                          distanceFromUser: currentDistance // Preserve existing distance
                      )
                      print("⭐ ViewModel (NavUnits): Updated allNavUnits array for \(navUnitId) at \(Date())")
                      filterNavUnits() // Re-apply filter/sort
                 } else {
                     print("❌ ViewModel (NavUnits): Station \(navUnitId) not found in allNavUnits after toggle at \(Date())")
                 }
            }
        } catch {
             print("❌ ViewModel (NavUnits): Failed to update favorite status for \(navUnitId) at \(Date()): \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to update favorite status: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Private Methods
    private func updateUserCoordinates() {
         if let location = locationService.currentLocation {
              self.userLatitude = String(format: "%.6f", location.coordinate.latitude)
              self.userLongitude = String(format: "%.6f", location.coordinate.longitude)
          } else {
              self.userLatitude = "Unknown"
              self.userLongitude = "Unknown"
          }
    }

    deinit {
        print("🗑️ NavUnitsViewModel deinitialized.")
    }
}
