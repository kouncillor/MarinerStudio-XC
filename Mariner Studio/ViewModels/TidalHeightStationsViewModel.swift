
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
    let tideStationService: TideStationDatabaseService
    private let tidalHeightService: TidalHeightService
    private let locationService: LocationService
    private var allStations: [StationWithDistance<TidalHeightStation>] = []

    // MARK: - Initialization
    init(
        tidalHeightService: TidalHeightService,
        locationService: LocationService,
        tideStationService: TideStationDatabaseService
    ) {
        self.tidalHeightService = tidalHeightService
        self.locationService = locationService
        self.tideStationService = tideStationService
        print("✅ TidalHeightStationsViewModel initialized. Will rely on ServiceProvider for location permission/start.")
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

        var stationsWithDistance: [StationWithDistance<TidalHeightStation>] = []

        for station in stations {
            let distance: Double
            if let userLoc = userLocation,
               let stationLat = station.latitude,
               let stationLon = station.longitude {
                let stationLocation = CLLocation(latitude: stationLat, longitude: stationLon)
                distance = userLoc.distance(from: stationLocation)
            } else {
                distance = Double.greatestFiniteMagnitude
            }

            let isFavorite = await tideStationService.isTideStationFavorite(id: station.id)
            var updatedStation = station
            updatedStation.isFavorite = isFavorite

            stationsWithDistance.append(StationWithDistance(
                station: updatedStation,
                distanceFromUser: distance
            ))
        }

        return stationsWithDistance
    }

     func filterStations() {
          let filtered = allStations.filter { station in
              let matchesFavorite = !showOnlyFavorites || (station.station.isFavorite ?? false)
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
         
         let newFavoriteStatus = await tideStationService.toggleTideStationFavorite(id: stationId)
         
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
         
         // Sync after favorite toggle (no delay, no throttling)
         Task {
             await performSyncAfterFavoriteToggle()
         }
     }
}

// MARK: - Sync Integration Extension
extension TidalHeightStationsViewModel {
    
    /// Sync after user toggles a favorite - always runs immediately
    func performSyncAfterFavoriteToggle() async {
        print("🔄 STATIONS VIEWMODEL: Performing sync after favorite toggle")
        
        let result = await TideStationSyncService.shared.syncTideStationFavorites()
        
        switch result {
        case .success(let stats):
            print("✅ STATIONS VIEWMODEL: Sync completed successfully")
            print("✅ SYNC STATS: \(stats.totalOperations) operations in \(String(format: "%.3f", stats.duration))s")
            
        case .failure(let error):
            print("❌ STATIONS VIEWMODEL: Sync failed - \(error.localizedDescription)")
            
        case .partialSuccess(let stats, let errors):
            print("⚠️ STATIONS VIEWMODEL: Partial sync - \(stats.totalOperations) operations, \(errors.count) errors")
        }
    }
}



