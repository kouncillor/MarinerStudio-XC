import SwiftUI
import MapKit
import CoreLocation

class MapClusteringViewModel: ObservableObject {
    // MARK: - Constants
    private let MAX_ANNOTATIONS = 100  // Maximum number of annotations to display on map
    
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
    @Published var currentMapRegion: MKCoordinateRegion?
    
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
    
    // MARK: - Load Data Method
    func loadData() {
        // Load all three data types concurrently
        Task {
            // Start all three loading tasks
            await loadNavUnits()
            await loadTidalHeightStations()
            await loadTidalCurrentStations()
            
            // After all data is loaded, update the navobjects array
            await MainActor.run {
                updateNavObjects()
            }
        }
    }
    
    // MARK: - Update NavObjects Method
    /// Converts all loaded maritime data into NavObject instances and updates the navobjects array
    @MainActor
    private func updateNavObjects() {
        // Clear existing array
        navobjects.removeAll()
        
        // Convert all maritime objects to NavObjects
        let navUnitObjects = convertNavUnitsToNavObjects()
        let tideStationObjects = convertTideStationsToNavObjects()
        let currentStationObjects = convertCurrentStationsToNavObjects()
        
        print("MapClusteringViewModel: Converted objects - NavUnits: \(navUnitObjects.count), TideStations: \(tideStationObjects.count), CurrentStations: \(currentStationObjects.count)")
        
        // Limit and prioritize annotations based on map region
        let limitedObjects = limitAndPrioritizeAnnotations(
            navUnitObjects: navUnitObjects,
            tideStationObjects: tideStationObjects,
            currentStationObjects: currentStationObjects
        )
        
        // Update navobjects array with limited objects
        navobjects = limitedObjects
        
        print("MapClusteringViewModel: Limited to \(navobjects.count) objects for map display")
    }
    
    /// Limits the number of annotations to MAX_ANNOTATIONS and prioritizes by proximity to current map region
    private func limitAndPrioritizeAnnotations(
        navUnitObjects: [NavObject],
        tideStationObjects: [NavObject],
        currentStationObjects: [NavObject]
    ) -> [NavObject] {
        // Combine all objects
        var allObjects = navUnitObjects + tideStationObjects + currentStationObjects
        
        // If we're under the limit, return all objects
        if allObjects.count <= MAX_ANNOTATIONS {
            return allObjects
        }
        
        // If we have current map region, prioritize objects within or closest to it
        if let region = self.currentMapRegion {
            let regionCenter = CLLocation(
                latitude: region.center.latitude,
                longitude: region.center.longitude
            )
            
            // Calculate a score for each object based on whether it's in the visible region
            // and how close it is to the center
            allObjects.sort { objA, objB in
                let coordA = objA.coordinate
                let coordB = objB.coordinate
                
                // Check if objects are within the visible region
                let isAVisible = isCoordinateInRegion(coordA, region: region)
                let isBVisible = isCoordinateInRegion(coordB, region: region)
                
                // If one is visible and the other isn't, prioritize the visible one
                if isAVisible && !isBVisible {
                    return true
                }
                if !isAVisible && isBVisible {
                    return false
                }
                
                // If both are visible or both are not visible, prioritize by distance to center
                let locationA = CLLocation(latitude: coordA.latitude, longitude: coordA.longitude)
                let locationB = CLLocation(latitude: coordB.latitude, longitude: coordB.longitude)
                
                let distanceA = locationA.distance(from: regionCenter)
                let distanceB = locationB.distance(from: regionCenter)
                
                return distanceA < distanceB
            }
            
            // Take only the first MAX_ANNOTATIONS
            return Array(allObjects.prefix(MAX_ANNOTATIONS))
        }
        
        // If no map region is set, take a balanced sample from each type
        let totalObjects = allObjects.count
        let navUnitRatio = Double(navUnitObjects.count) / Double(totalObjects)
        let tideStationRatio = Double(tideStationObjects.count) / Double(totalObjects)
        let currentStationRatio = Double(currentStationObjects.count) / Double(totalObjects)
        
        // Calculate how many of each type to include based on original distribution
        let navUnitCount = min(navUnitObjects.count, Int(Double(MAX_ANNOTATIONS) * navUnitRatio))
        let tideStationCount = min(tideStationObjects.count, Int(Double(MAX_ANNOTATIONS) * tideStationRatio))
        let currentStationCount = min(currentStationObjects.count, Int(Double(MAX_ANNOTATIONS) * currentStationRatio))
        
        // If our counts don't add up to MAX_ANNOTATIONS due to rounding, adjust the largest group
        var totalCount = navUnitCount + tideStationCount + currentStationCount
        let remaining = MAX_ANNOTATIONS - totalCount
        
        var adjustedNavUnitCount = navUnitCount
        var adjustedTideStationCount = tideStationCount
        var adjustedCurrentStationCount = currentStationCount
        
        if remaining > 0 {
            if navUnitCount >= tideStationCount && navUnitCount >= currentStationCount && navUnitCount < navUnitObjects.count {
                adjustedNavUnitCount += remaining
            } else if tideStationCount >= navUnitCount && tideStationCount >= currentStationCount && tideStationCount < tideStationObjects.count {
                adjustedTideStationCount += remaining
            } else if currentStationCount < currentStationObjects.count {
                adjustedCurrentStationCount += remaining
            }
        }
        
        // Take a sample from each group
        var result: [NavObject] = []
        result.append(contentsOf: navUnitObjects.prefix(adjustedNavUnitCount))
        result.append(contentsOf: tideStationObjects.prefix(adjustedTideStationCount))
        result.append(contentsOf: currentStationObjects.prefix(adjustedCurrentStationCount))
        
        return result
    }
    
    /// Checks if a coordinate is within the visible map region
    private func isCoordinateInRegion(_ coordinate: CLLocationCoordinate2D, region: MKCoordinateRegion) -> Bool {
        let halfLatDelta = region.span.latitudeDelta / 2.0
        let halfLngDelta = region.span.longitudeDelta / 2.0
        
        let minLat = region.center.latitude - halfLatDelta
        let maxLat = region.center.latitude + halfLatDelta
        let minLng = region.center.longitude - halfLngDelta
        let maxLng = region.center.longitude + halfLngDelta
        
        return coordinate.latitude >= minLat &&
               coordinate.latitude <= maxLat &&
               coordinate.longitude >= minLng &&
               coordinate.longitude <= maxLng
    }
    
    // MARK: - Conversion Methods
    
    /// Converts NavUnit objects to NavObject instances for map display
    private func convertNavUnitsToNavObjects() -> [NavObject] {
        return navUnits.compactMap { stationWithDistance in
            let station = stationWithDistance.station
            
            // Skip if coordinates are invalid
            guard let latitude = station.latitude,
                  let longitude = station.longitude,
                  abs(latitude) > 0.0001 || abs(longitude) > 0.0001 else {
                return nil
            }
            
            // Create new NavObject
            let navObject = NavObject()
            navObject.type = .navunit
            navObject.coordinate = CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            )
            
            return navObject
        }
    }
    
    /// Converts TidalHeightStation objects to NavObject instances for map display
    private func convertTideStationsToNavObjects() -> [NavObject] {
        return tideStations.compactMap { stationWithDistance in
            let station = stationWithDistance.station
            
            // Skip if coordinates are invalid
            guard let latitude = station.latitude,
                  let longitude = station.longitude,
                  abs(latitude) > 0.0001 || abs(longitude) > 0.0001 else {
                return nil
            }
            
            // Create new NavObject
            let navObject = NavObject()
            navObject.type = .tidalheightstation
            navObject.coordinate = CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            )
            
            return navObject
        }
    }
    
    /// Converts TidalCurrentStation objects to NavObject instances for map display
    private func convertCurrentStationsToNavObjects() -> [NavObject] {
        return currentStations.compactMap { stationWithDistance in
            let station = stationWithDistance.station
            
            // Skip if coordinates are invalid
            guard let latitude = station.latitude,
                  let longitude = station.longitude,
                  abs(latitude) > 0.0001 || abs(longitude) > 0.0001 else {
                return nil
            }
            
            // Create new NavObject
            let navObject = NavObject()
            navObject.type = .tidalcurrentstation
            navObject.coordinate = CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            )
            
            return navObject
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
    
    // MARK: - Public Methods
    
    /// Updates the current map region
    func updateMapRegion(_ region: MKCoordinateRegion) {
        self.currentMapRegion = region
        
        // If we have data loaded, update the annotations based on the new region
        if !navUnits.isEmpty || !tideStations.isEmpty || !currentStations.isEmpty {
            Task { @MainActor in
                updateNavObjects()
            }
        }
    }
    
    /// Refreshes all maritime data
    func refreshData() {
        Task {
            // Clear current data
            await MainActor.run {
                navUnits = []
                tideStations = []
                currentStations = []
                navobjects = []
            }
            
            // Reload everything
            await loadNavUnits()
            await loadTidalHeightStations()
            await loadTidalCurrentStations()
            
            // Update navobjects array
            await MainActor.run {
                updateNavObjects()
            }
        }
    }
}
