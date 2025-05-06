
import Foundation
import CoreLocation
import MapKit

class MapClusteringViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var navobjects: [NavObject] = []
    @Published var isLoadingNavUnits = false
    @Published var isLoadingTideStations = false
    @Published var isLoadingCurrentStations = false
    
    // MARK: - Map Properties
    private var allNavObjects: [NavObject] = []
    private(set) var currentRegion: MKCoordinateRegion?
    
    // MARK: - New Properties for Annotation Capping
    private let maxAnnotations = 100
    private var lastProcessedRegion: MKCoordinateRegion?
    private var regionChangeThrottleTime = 0.3 // seconds
    private var lastRegionChangeTime = Date()
    
    // MARK: - Spatial Indexing
    private var spatialGrid: [String: [NavObject]] = [:]
    private let gridCellSize: Double = 0.05 // degrees (roughly 5.5 km at equator)
    
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
        
        // Set initial region based on user location if available
        if let userLocation = locationService.currentLocation {
            currentRegion = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else {
            // Default to San Francisco as fallback
            currentRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }
    
    // MARK: - Public Methods
    func loadData() {
        Task {
            await loadNavUnits()
            await loadTidalHeightStations()
            await loadTidalCurrentStations()
        }
    }
    
    // Method to update map region and refresh visible annotations
    func updateMapRegion(_ newRegion: MKCoordinateRegion) {
        // Check if we should throttle this update
        let now = Date()
        if now.timeIntervalSince(lastRegionChangeTime) < regionChangeThrottleTime {
            return
        }
        
        // Skip if it's a very small change
        if let lastRegion = lastProcessedRegion,
           abs(lastRegion.center.latitude - newRegion.center.latitude) < 0.001 &&
           abs(lastRegion.center.longitude - newRegion.center.longitude) < 0.001 &&
           abs(lastRegion.span.latitudeDelta - newRegion.span.latitudeDelta) < 0.001 {
            return
        }
        
        lastRegionChangeTime = now
        currentRegion = newRegion
        lastProcessedRegion = newRegion
        
        // Get visible or nearby grid cells
        let nearbyGridCells = getNearbyCells(forRegion: newRegion)
        
        // Update visible annotations
        Task { @MainActor in
            self.updateVisibleAnnotations(forRegion: newRegion, fromCells: nearbyGridCells)
        }
    }
    
    // MARK: - Private Methods
    private func loadNavUnits() async {
        if isLoadingNavUnits { return }
        
        await MainActor.run {
            isLoadingNavUnits = true
        }
        
        do {
            let units = try await navUnitService.getNavUnitsAsync()
            
            // Convert to NavObject annotations
            let annotations = units.compactMap { unit -> NavObject? in
                // Skip entries without valid coordinates
                guard let latitude = unit.latitude, let longitude = unit.longitude,
                      latitude != 0 || longitude != 0 else {
                    return nil
                }
                
                let navObject = NavObject()
                navObject.type = .navunit
                navObject.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                return navObject
            }
            
            await MainActor.run {
                addToSpatialIndex(annotations)
                self.allNavObjects.append(contentsOf: annotations)
                
                // Update visible annotations if we have a current region
                if let region = self.currentRegion {
                    let nearbyCells = self.getNearbyCells(forRegion: region)
                    self.updateVisibleAnnotations(forRegion: region, fromCells: nearbyCells)
                }
                
                isLoadingNavUnits = false
            }
        } catch {
            print("Error loading navigation units: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingNavUnits = false
            }
        }
    }
    
    private func loadTidalHeightStations() async {
        if isLoadingTideStations { return }
        
        await MainActor.run {
            isLoadingTideStations = true
        }
        
        do {
            let response = try await tidalHeightService.getTidalHeightStations()
            
            // Convert to NavObject annotations
            let annotations = response.stations.compactMap { station -> NavObject? in
                // Skip entries without valid coordinates
                guard let latitude = station.latitude, let longitude = station.longitude else {
                    return nil
                }
                
                let navObject = NavObject()
                navObject.type = .tidalheightstation
                navObject.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                return navObject
            }
            
            await MainActor.run {
                addToSpatialIndex(annotations)
                self.allNavObjects.append(contentsOf: annotations)
                
                // Update visible annotations if we have a current region
                if let region = self.currentRegion {
                    let nearbyCells = self.getNearbyCells(forRegion: region)
                    self.updateVisibleAnnotations(forRegion: region, fromCells: nearbyCells)
                }
                
                isLoadingTideStations = false
            }
        } catch {
            print("Error loading tidal height stations: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingTideStations = false
            }
        }
    }
    
    private func loadTidalCurrentStations() async {
        if isLoadingCurrentStations { return }
        
        await MainActor.run {
            isLoadingCurrentStations = true
        }
        
        do {
            let response = try await tidalCurrentService.getTidalCurrentStations()
            
            // Convert to NavObject annotations
            let annotations = response.stations.compactMap { station -> NavObject? in
                // Skip entries without valid coordinates
                guard let latitude = station.latitude, let longitude = station.longitude else {
                    return nil
                }
                
                let navObject = NavObject()
                navObject.type = .tidalcurrentstation
                navObject.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                return navObject
            }
            
            await MainActor.run {
                addToSpatialIndex(annotations)
                self.allNavObjects.append(contentsOf: annotations)
                
                // Update visible annotations if we have a current region
                if let region = self.currentRegion {
                    let nearbyCells = self.getNearbyCells(forRegion: region)
                    self.updateVisibleAnnotations(forRegion: region, fromCells: nearbyCells)
                }
                
                isLoadingCurrentStations = false
            }
        } catch {
            print("Error loading tidal current stations: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingCurrentStations = false
            }
        }
    }
    
    // MARK: - Spatial Indexing Methods
    
    // Add annotations to spatial grid index
    private func addToSpatialIndex(_ annotations: [NavObject]) {
        for annotation in annotations {
            let gridKey = gridKeyForCoordinate(annotation.coordinate)
            if spatialGrid[gridKey] == nil {
                spatialGrid[gridKey] = [annotation]
            } else {
                spatialGrid[gridKey]?.append(annotation)
            }
        }
    }
    
    // Get grid cell key for a coordinate
    private func gridKeyForCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        let latCell = Int(coordinate.latitude / gridCellSize)
        let lonCell = Int(coordinate.longitude / gridCellSize)
        return "\(latCell):\(lonCell)"
    }
    
    // Get nearby grid cells for a region
    private func getNearbyCells(forRegion region: MKCoordinateRegion) -> [String] {
        // Calculate bounding box
        let minLat = region.center.latitude - region.span.latitudeDelta
        let maxLat = region.center.latitude + region.span.latitudeDelta
        let minLon = region.center.longitude - region.span.longitudeDelta
        let maxLon = region.center.longitude + region.span.longitudeDelta
        
        // Get grid cell ranges
        let minLatCell = Int(minLat / gridCellSize)
        let maxLatCell = Int(maxLat / gridCellSize)
        let minLonCell = Int(minLon / gridCellSize)
        let maxLonCell = Int(maxLon / gridCellSize)
        
        // Generate all cell keys in the range
        var cellKeys: [String] = []
        for latCell in minLatCell...maxLatCell {
            for lonCell in minLonCell...maxLonCell {
                cellKeys.append("\(latCell):\(lonCell)")
            }
        }
        
        return cellKeys
    }
    
    // MARK: - Annotation Filtering and Capping
    
    // Update visible annotations based on current region
    private func updateVisibleAnnotations(forRegion region: MKCoordinateRegion, fromCells cellKeys: [String]) {
        // Collect all annotations from the relevant grid cells
        var candidateAnnotations: [NavObject] = []
        for key in cellKeys {
            if let annotations = spatialGrid[key] {
                candidateAnnotations.append(contentsOf: annotations)
            }
        }
        
        // Sort by distance from center
        let centerCoordinate = region.center
        let sortedAnnotations = candidateAnnotations.sorted { (obj1, obj2) -> Bool in
            let distance1 = calculateDistance(from: centerCoordinate, to: obj1.coordinate)
            let distance2 = calculateDistance(from: centerCoordinate, to: obj2.coordinate)
            return distance1 < distance2
        }
        
        // Cap to maximum number
        let cappedAnnotations = Array(sortedAnnotations.prefix(maxAnnotations))
        self.navobjects = cappedAnnotations
    }
    
    // Calculate distance between coordinates
    private func calculateDistance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
        let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        return sourceLocation.distance(from: destinationLocation)
    }
}
