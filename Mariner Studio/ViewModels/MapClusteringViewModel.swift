import SwiftUI
import MapKit
import Combine

class MapClusteringViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var navobjects: [NavObject] = []
    @Published var isLoadingNavUnits = false
    @Published var isLoadingTideStations = false
    @Published var isLoadingCurrentStations = false
    @Published var currentRegion: MKCoordinateRegion?
    
    // MARK: - Private Properties
    private let navUnitService: NavUnitDatabaseService
    private let tideStationService: TideStationDatabaseService
    private let currentStationService: CurrentStationDatabaseService
    private let tidalHeightService: TidalHeightService
    private let tidalCurrentService: TidalCurrentService
    private let locationService: LocationService
    
    // Queue for background processing
    private let processingQueue = DispatchQueue(label: "com.marinerstudio.mapprocessing", qos: .userInitiated, attributes: .concurrent)
    
    // Cache
    private var navUnitsCache: [NavUnit] = []
    private var tideStationsCache: [TidalHeightStation] = []
    private var currentStationsCache: [TidalCurrentStation] = []
    
    // Throttling region updates
    private var regionUpdateTimer: Timer?
    private var pendingRegionUpdate: MKCoordinateRegion?
    
    // Visible region for lazy loading
    private var visibleRegion: MKCoordinateRegion?
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Batch size for processing annotations
    private let annotationBatchSize = 200
    
    // MARK: - Initialization
    init(
        navUnitService: NavUnitDatabaseService,
        tideStationService: TideStationDatabaseService,
        currentStationService: CurrentStationDatabaseService,
        tidalHeightService: TidalHeightService,
        tidalCurrentService: TidalCurrentService,
        locationService: LocationService
    ) {
        self.navUnitService = navUnitService
        self.tideStationService = tideStationService
        self.currentStationService = currentStationService
        self.tidalHeightService = tidalHeightService
        self.tidalCurrentService = tidalCurrentService
        self.locationService = locationService
        
        // Initialize with user's location if available
        if let userLocation = locationService.currentLocation {
            self.currentRegion = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else {
            // Default region (San Francisco Bay Area)
            self.currentRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.8050315413548, longitude: -122.413632917219),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }
    
    // MARK: - Public Methods
    
    /// Load all data required for the map
    func loadData() {
        Task {
            await loadNavUnits()
            await loadTidalHeightStations()
            await loadTidalCurrentStations()
        }
    }
    
    /// Update the visible map region and refresh annotations if needed
    func updateMapRegion(_ region: MKCoordinateRegion) {
        // Cancel any pending updates
        regionUpdateTimer?.invalidate()
        
        // Store the new region for processing
        pendingRegionUpdate = region
        
        // Create a debounced region update to avoid excessive processing
        regionUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self, let pendingRegion = self.pendingRegionUpdate else { return }
            
            // Update the current region
            self.currentRegion = pendingRegion
            
            // Check if we need to load more annotations based on the new visible region
            self.refreshVisibleAnnotations(in: pendingRegion)
        }
    }
    
    // MARK: - Private Methods
    
    /// Refresh annotations visible in the current region
    private func refreshVisibleAnnotations(in region: MKCoordinateRegion) {
        // Save the visible region
        self.visibleRegion = region
        
        // Use expanded region for preloading
        let expandedRegion = expandRegion(region, byFactor: 1.5)
        
        // Process in background
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Process NavUnits, TidalHeightStations, and TidalCurrentStations
            // that are within the expanded visible region
            var visibleAnnotations: [NavObject] = []
            
            // Add NavUnits that are within the visible region
            let visibleNavUnits = self.navUnitsCache.filter { navUnit in
                guard let latitude = navUnit.latitude, let longitude = navUnit.longitude else { return false }
                return self.isCoordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                       inRegion: expandedRegion)
            }
            
            // Create NavObject annotations for visible NavUnits
            for navUnit in visibleNavUnits {
                guard let latitude = navUnit.latitude, let longitude = navUnit.longitude else { continue }
                let annotation = NavUnitAnnotation(navUnit: navUnit)
                visibleAnnotations.append(annotation)
            }
            
            // Add TidalHeightStations that are within the visible region
            let visibleTideStations = self.tideStationsCache.filter { station in
                guard let latitude = station.latitude, let longitude = station.longitude else { return false }
                return self.isCoordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                       inRegion: expandedRegion)
            }
            
            // Create NavObject annotations for visible TidalHeightStations
            for station in visibleTideStations {
                guard let latitude = station.latitude, let longitude = station.longitude else { continue }
                let annotation = TidalHeightStationAnnotation(station: station)
                visibleAnnotations.append(annotation)
            }
            
            // Add TidalCurrentStations that are within the visible region
            let visibleCurrentStations = self.currentStationsCache.filter { station in
                guard let latitude = station.latitude, let longitude = station.longitude else { return false }
                return self.isCoordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                       inRegion: expandedRegion)
            }
            
            // Create NavObject annotations for visible TidalCurrentStations
            for station in visibleCurrentStations {
                guard let latitude = station.latitude, let longitude = station.longitude else { continue }
                let annotation = TidalCurrentStationAnnotation(station: station)
                visibleAnnotations.append(annotation)
            }
            
            // Update annotations on the main thread
            DispatchQueue.main.async {
                self.navobjects = visibleAnnotations
            }
        }
    }
    
    /// Load navigation units from the database
    private func loadNavUnits() async {
        // Skip if already loading
        guard !isLoadingNavUnits else { return }
        
        await MainActor.run {
            isLoadingNavUnits = true
        }
        
        do {
            let navUnits = try await navUnitService.getNavUnitsAsync()
            
            // Cache the nav units
            navUnitsCache = navUnits
            
            // If we have a visible region, update annotations
            if let region = visibleRegion {
                refreshVisibleAnnotations(in: region)
            }
            
            await MainActor.run {
                isLoadingNavUnits = false
            }
        } catch {
            print("❌ Error loading NavUnits: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingNavUnits = false
            }
        }
    }
    
    /// Load tidal height stations from the API
    private func loadTidalHeightStations() async {
        // Skip if already loading
        guard !isLoadingTideStations else { return }
        
        await MainActor.run {
            isLoadingTideStations = true
        }
        
        do {
            let response = try await tidalHeightService.getTidalHeightStations()
            var stations = response.stations
            
            // Update favorite status
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
            
            // Cache the stations
            tideStationsCache = stations
            
            // If we have a visible region, update annotations
            if let region = visibleRegion {
                refreshVisibleAnnotations(in: region)
            }
            
            await MainActor.run {
                isLoadingTideStations = false
            }
        } catch {
            print("❌ Error loading TidalHeightStations: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingTideStations = false
            }
        }
    }
    
    /// Load tidal current stations from the API
    private func loadTidalCurrentStations() async {
        // Skip if already loading
        guard !isLoadingCurrentStations else { return }
        
        await MainActor.run {
            isLoadingCurrentStations = true
        }
        
        do {
            let response = try await tidalCurrentService.getTidalCurrentStations()
            var stations = response.stations
            
            // Update favorite status
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
            
            // Cache the stations
            currentStationsCache = stations
            
            // If we have a visible region, update annotations
            if let region = visibleRegion {
                refreshVisibleAnnotations(in: region)
            }
            
            await MainActor.run {
                isLoadingCurrentStations = false
            }
        } catch {
            print("❌ Error loading TidalCurrentStations: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingCurrentStations = false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if a coordinate is inside a region
    private func isCoordinate(_ coordinate: CLLocationCoordinate2D, inRegion region: MKCoordinateRegion) -> Bool {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        
        return coordinate.latitude >= minLat && coordinate.latitude <= maxLat &&
               coordinate.longitude >= minLon && coordinate.longitude <= maxLon
    }
    
    /// Expand a region by a factor for preloading
    private func expandRegion(_ region: MKCoordinateRegion, byFactor factor: Double) -> MKCoordinateRegion {
        let expandedSpan = MKCoordinateSpan(
            latitudeDelta: region.span.latitudeDelta * factor,
            longitudeDelta: region.span.longitudeDelta * factor
        )
        
        return MKCoordinateRegion(
            center: region.center,
            span: expandedSpan
        )
    }
}

// MARK: - Custom NavObject Subclasses

/// NavUnit Annotation - to improve type safety and performance
class NavUnitAnnotation: NavObject {
    let navUnit: NavUnit
    
    init(navUnit: NavUnit) {
        self.navUnit = navUnit
        super.init()
        self.type = .navunit
        if let lat = navUnit.latitude, let lon = navUnit.longitude {
            self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
    
    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}

/// TidalHeightStation Annotation
class TidalHeightStationAnnotation: NavObject {
    let station: TidalHeightStation
    
    init(station: TidalHeightStation) {
        self.station = station
        super.init()
        self.type = .tidalheightstation
        if let lat = station.latitude, let lon = station.longitude {
            self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
    
    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}

/// TidalCurrentStation Annotation
class TidalCurrentStationAnnotation: NavObject {
    let station: TidalCurrentStation
    
    init(station: TidalCurrentStation) {
        self.station = station
        super.init()
        self.type = .tidalcurrentstation
        if let lat = station.latitude, let lon = station.longitude {
            self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
    
    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}
