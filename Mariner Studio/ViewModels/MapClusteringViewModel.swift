import SwiftUI
import MapKit
import CoreLocation

class MapClusteringViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var navobjects: [NavObject] = []
    @Published var navUnits: [StationWithDistance<NavUnit>] = []
    @Published var tideStations: [StationWithDistance<TidalHeightStation>] = []
    @Published var currentStations: [StationWithDistance<TidalCurrentStation>] = []
    @Published var isLoadingNavUnits = false
    @Published var isLoadingTideStations = false
    @Published var isLoadingCurrentStations = false
    @Published var navUnitsError = ""
    @Published var tideStationsError = ""
    @Published var currentStationsError = ""
    
    // MARK: - Services
    private let navUnitService: NavUnitDatabaseService
    private let tideStationService: TideStationDatabaseService
    private let currentStationService: CurrentStationDatabaseService
    private let tidalHeightService: TidalHeightService
    private let tidalCurrentService: TidalCurrentService
    private let locationService: LocationService
    
    // MARK: - Initialization
    init(navUnitService: NavUnitDatabaseService,
         tideStationService: TideStationDatabaseService,
         currentStationService: CurrentStationDatabaseService,
         tidalHeightService: TidalHeightService,
         tidalCurrentService: TidalCurrentService,
         locationService: LocationService) {
        self.navUnitService = navUnitService
        self.tideStationService = tideStationService
        self.currentStationService = currentStationService
        self.tidalHeightService = tidalHeightService
        self.tidalCurrentService = tidalCurrentService
        self.locationService = locationService
    }
    
    // MARK: - Data Loading Methods
    func loadData() {
        // Load all three data types concurrently
        Task {
            await loadNavUnits()
            await loadTidalHeightStations()
            await loadTidalCurrentStations()
        }
        
        // Keep the existing sample data loading for backward compatibility
        guard let plistURL = Bundle.main.url(forResource: "Data", withExtension: "plist") else {
            print("Failed to resolve URL for Data.plist in bundle.")
            return
        }

        do {
            let plistData = try Data(contentsOf: plistURL)
            let decoder = PropertyListDecoder()
            let decodedData = try decoder.decode(MapData.self, from: plistData)
            
            // Set the cycles data
            self.navobjects = decodedData.cycles
        } catch {
            print("Failed to load provided data, error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load Nav Units from SQLite Database
    @MainActor
    func loadNavUnits() async {
        isLoadingNavUnits = true
        navUnitsError = ""
        
        do {
            let units = try await navUnitService.getNavUnitsAsync()
            let currentLocationForDistance = locationService.currentLocation
            let unitsWithDistance = units.map { unit in
                return StationWithDistance<NavUnit>.create(
                    station: unit,
                    userLocation: currentLocationForDistance
                )
            }

            navUnits = unitsWithDistance
            isLoadingNavUnits = false
            print("MapClusteringViewModel: Loaded \(navUnits.count) Nav Units")
        } catch {
            navUnitsError = "Failed to load navigation units: \(error.localizedDescription)"
            navUnits = []
            isLoadingNavUnits = false
            print("MapClusteringViewModel: Error loading Nav Units - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load Tidal Height Stations from API
    @MainActor
    func loadTidalHeightStations() async {
        isLoadingTideStations = true
        tideStationsError = ""
        
        do {
            let response = try await tidalHeightService.getTidalHeightStations()
            var stations = response.stations

            await withTaskGroup(of: (String, Bool).self) { group in
                for station in stations {
                    group.addTask {
                        let isFav = await self.tideStationService.isTideStationFavorite(id: station.id)
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

            let currentLocationForDistance = locationService.currentLocation
            let stationsWithDistance = stations.map { station in
                return StationWithDistance<TidalHeightStation>.create(
                    station: station,
                    userLocation: currentLocationForDistance
                )
            }

            tideStations = stationsWithDistance
            isLoadingTideStations = false
            print("MapClusteringViewModel: Loaded \(tideStations.count) Tide Stations")
        } catch {
            tideStationsError = "Failed to load tide stations: \(error.localizedDescription)"
            tideStations = []
            isLoadingTideStations = false
            print("MapClusteringViewModel: Error loading Tide Stations - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load Tidal Current Stations from API
    @MainActor
    func loadTidalCurrentStations() async {
        isLoadingCurrentStations = true
        currentStationsError = ""
        
        do {
            let response = try await tidalCurrentService.getTidalCurrentStations()
            var stations = response.stations

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

            let currentLocationForDistance = locationService.currentLocation
            let stationsWithDistance = stations.map { station in
                return StationWithDistance<TidalCurrentStation>.create(
                    station: station,
                    userLocation: currentLocationForDistance
                )
            }

            currentStations = stationsWithDistance
            isLoadingCurrentStations = false
            print("MapClusteringViewModel: Loaded \(currentStations.count) Current Stations")
        } catch {
            currentStationsError = "Failed to load current stations: \(error.localizedDescription)"
            currentStations = []
            isLoadingCurrentStations = false
            print("MapClusteringViewModel: Error loading Current Stations - \(error.localizedDescription)")
        }
    }
}
