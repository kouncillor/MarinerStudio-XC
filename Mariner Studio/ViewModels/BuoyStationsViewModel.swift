//
//  BuoyStationsViewModel.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//


import Foundation
import CoreLocation
import SwiftUI

class BuoyStationsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var stations: [StationWithDistance<BuoyStation>] = []
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
    let buoyDatabaseService: BuoyDatabaseService
    private let buoyService: BuoyApiService
    private let locationService: LocationService
    private var allStations: [StationWithDistance<BuoyStation>] = []

    // MARK: - Initialization
    init(
        buoyService: BuoyApiService,
        locationService: LocationService,
        buoyDatabaseService: BuoyDatabaseService
    ) {
        self.buoyService = buoyService
        self.locationService = locationService
        self.buoyDatabaseService = buoyDatabaseService
        print("✅ BuoyStationsViewModel initialized. Will rely on ServiceProvider for location permission/start.")
    }

    // MARK: - Public Methods
    func loadStations() async {
        print("⏰ ViewModel (Buoys): loadStations() started at \(Date())")

        guard !isLoading else {
             print("⏰ ViewModel (Buoys): loadStations() exited early, already loading.")
             return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = ""
            print("⏰ ViewModel (Buoys): Checking location in loadStations (MainActor block) at \(Date()). Current value: \(locationService.currentLocation?.description ?? "nil")")
            if let location = locationService.currentLocation {
                 self.userLatitude = String(format: "%.6f", location.coordinate.latitude)
                 self.userLongitude = String(format: "%.6f", location.coordinate.longitude)
             } else {
                 self.userLatitude = "Unknown"
                 self.userLongitude = "Unknown"
             }
        }

        do {
            print("⏰ ViewModel (Buoys): Starting API call for stations at \(Date())")
            let response = try await buoyService.getBuoyStations()
            print("⏰ ViewModel (Buoys): Finished API call for stations at \(Date()). Count: \(response.stations.count)")

            var stations = response.stations

            print("⏰ ViewModel (Buoys): Starting favorite checks at \(Date())")
            await withTaskGroup(of: (String, Bool).self) { group in
                for station in stations {
                    group.addTask {
                        let isFav = await self.buoyDatabaseService.isBuoyStationFavoriteAsync(stationId: station.id)
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
            print("⏰ ViewModel (Buoys): Finished favorite checks at \(Date())")

            print("⏰ ViewModel (Buoys): Checking location for distance calculation at \(Date()). Current value: \(locationService.currentLocation?.description ?? "nil")")
            let currentLocationForDistance = locationService.currentLocation
            let stationsWithDistance = stations.map { station in
                return StationWithDistance<BuoyStation>.create(
                    station: station,
                    userLocation: currentLocationForDistance
                )
            }

            print("⏰ ViewModel (Buoys): Updating UI state (allStations, filterStations, isLoading) at \(Date())")
            await MainActor.run {
                allStations = stationsWithDistance
                filterStations()
                isLoading = false
                print("⏰ ViewModel (Buoys): UI state update complete at \(Date())")
            }
        } catch {
            print("❌ ViewModel (Buoys): Error in loadStations at \(Date()): \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to load stations: \(error.localizedDescription)"
                allStations = []
                self.stations = []
                totalStations = 0
                isLoading = false
            }
        }
         print("⏰ ViewModel (Buoys): loadStations() finished at \(Date())")
    }

    func refreshStations() async {
         print("🔄 ViewModel (Buoys): refreshStations() called at \(Date())")
         await MainActor.run {
              self.stations = []
              self.allStations = []
              self.totalStations = 0
         }
         await loadStations()
    }

    func filterStations() {
        print("🔄 ViewModel (Buoys): filterStations() called at \(Date())")
        let filtered = allStations.filter { station in
            let matchesFavorite = !showOnlyFavorites || station.station.isFavorite
            let matchesSearch = searchText.isEmpty ||
                station.station.name.localizedCaseInsensitiveContains(searchText) ||
                station.station.type.localizedCaseInsensitiveContains(searchText) ||
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
             print("🔄 ViewModel (Buoys): filterStations() updated self.stations on main thread at \(Date()). Count: \(sorted.count)")
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
        let newFavoriteStatus = await buoyDatabaseService.toggleBuoyStationFavoriteAsync(stationId: stationId)
        
        await MainActor.run {
            if let index = allStations.firstIndex(where: { $0.station.id == stationId }) {
                var updatedStation = allStations[index].station
                updatedStation.isFavorite = newFavoriteStatus
                allStations[index] = StationWithDistance(
                    station: updatedStation,
                    distanceFromUser: allStations[index].distanceFromUser
                )
                print("⭐ ViewModel (Buoys): Updated allStations array for \(stationId) at \(Date())")
            } else {
                 print("❌ ViewModel (Buoys): Station \(stationId) not found in allStations after toggle at \(Date())")
            }

            filterStations()
        }
    }
}
