import Foundation
import Combine
import SwiftUI
import CoreLocation

class NavUnitsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var navUnits: [StationWithDistance<NavUnit>] = []
    @Published var filteredNavUnits: [StationWithDistance<NavUnit>] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var totalNavUnits = 0
    @Published var isLocationEnabled = false
    
    // MARK: - Properties
    let databaseService: DatabaseService
    private let locationService: LocationService
    private var allNavUnits: [StationWithDistance<NavUnit>] = []
    private var locationUpdateHandler: ((CLLocation) -> Void)?
    
    // MARK: - Initialization
    init(databaseService: DatabaseService, locationService: LocationService) {
        self.databaseService = databaseService
        self.locationService = locationService
        
        // Start listening for location updates
        setupLocationUpdates()
        requestLocationAccess()
    }
    
    // MARK: - Public Methods
    func loadNavUnits() async {
        if isLoading { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            // Get nav units from database
            let units = try await databaseService.getNavUnitsAsync()
            
            // Create units with distance
            let unitsWithDistance = units.map { unit in
                return StationWithDistance<NavUnit>.create(
                    station: unit,
                    userLocation: locationService.currentLocation
                )
            }
            
            await MainActor.run {
                allNavUnits = unitsWithDistance
                filterNavUnits(searchText: "", showOnlyFavorites: false)
                isLocationEnabled = locationService.currentLocation != nil
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load navigation units: \(error.localizedDescription)"
                navUnits = []
                filteredNavUnits = []
                isLoading = false
            }
        }
    }
    
    func filterNavUnits(searchText: String, showOnlyFavorites: Bool) {
        // Using a background thread for potentially heavy filtering/sorting
        DispatchQueue.global(qos: .userInitiated).async {
            let filtered = self.allNavUnits.filter { unit in
                let matchesFavorite = !showOnlyFavorites || unit.station.isFavorite
                let matchesSearch = searchText.isEmpty ||
                    unit.station.navUnitName.localizedCaseInsensitiveContains(searchText) ||
                    (unit.station.location?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                    (unit.station.cityOrTown?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                    (unit.station.statePostalCode?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                    unit.station.navUnitId.localizedCaseInsensitiveContains(searchText)
                
                return matchesFavorite && matchesSearch
            }
            
            // Sort nav units by distance, then by favorite status, then by name
            let sorted = filtered.sorted { first, second in
                if first.distanceFromUser != second.distanceFromUser {
                    return first.distanceFromUser < second.distanceFromUser
                } else if first.station.isFavorite != second.station.isFavorite {
                    return first.station.isFavorite && !second.station.isFavorite
                } else {
                    return first.station.navUnitName.localizedCompare(second.station.navUnitName) == .orderedAscending
                }
            }
            
            // Update UI on the main thread
            DispatchQueue.main.async {
                self.filteredNavUnits = sorted
                self.totalNavUnits = sorted.count
                
                // Debug: Print the first few stations with their distances
                print("🌎 Sorted stations by distance:")
                for (index, station) in sorted.prefix(3).enumerated() {
                    print("🌎 \(index + 1): \(station.station.navUnitName) - \(station.distanceDisplay) (raw: \(station.distanceFromUser))")
                }
                
                if let location = self.locationService.currentLocation {
                    print("🌎 Current location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                } else {
                    print("❌ Current location is nil")
                }
            }
        }
    }
    
    func toggleNavUnitFavorite(navUnitId: String) async {
        do {
            // Call database service to toggle favorite
            let newFavoriteStatus = try await databaseService.toggleFavoriteNavUnitAsync(navUnitId: navUnitId)
            
            await MainActor.run {
                // Update all nav units
                allNavUnits = allNavUnits.map { unitWithDistance in
                    if unitWithDistance.station.navUnitId == navUnitId {
                        var updatedUnit = unitWithDistance.station
                        updatedUnit.isFavorite = newFavoriteStatus
                        return StationWithDistance(
                            station: updatedUnit,
                            distanceFromUser: unitWithDistance.distanceFromUser
                        )
                    }
                    return unitWithDistance
                }
                
                // Re-apply filter to update the displayed list
                // Use the current filter values from NavUnitsView instead of hardcoded values
                filterNavUnits(searchText: "", showOnlyFavorites: false)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update favorite status: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupLocationUpdates() {
        locationUpdateHandler = { [weak self] location in
            guard let self = self else { return }
            print("🌎 Location update received: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            self.updateDistances()
        }
    }
    
    private func requestLocationAccess() {
        Task {
            let authorized = await locationService.requestLocationPermission()
            if authorized {
                locationService.startUpdatingLocation()
                print("🌎 Location permission granted, started updates")
            } else {
                print("❌ Location permission denied")
            }
            
            await MainActor.run {
                isLocationEnabled = authorized
            }
        }
    }
    
    private func updateDistances() {
        guard let userLocation = locationService.currentLocation else {
            print("❌ updateDistances: Current location is nil")
            return
        }
        
        print("🌎 Updating distances with location: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
        
        // Create new StationWithDistance objects with updated distances
        let updatedUnitsWithDistance = allNavUnits.map { existingUnitWithDistance in
            return StationWithDistance<NavUnit>.create(
                station: existingUnitWithDistance.station,
                userLocation: userLocation
            )
        }
        
        DispatchQueue.main.async {
            self.allNavUnits = updatedUnitsWithDistance
            
            // Re-apply filter and sort with updated distances
            self.filterNavUnits(searchText: "", showOnlyFavorites: false)
        }
    }
    
    deinit {
        // Clean up any observers
        locationUpdateHandler = nil
    }
}
