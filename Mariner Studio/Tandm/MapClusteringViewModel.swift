//
//import Foundation
//import CoreLocation
//import MapKit
//
//class MapClusteringViewModel: ObservableObject {
//   // MARK: - Published Properties
//   @Published var navobjects: [NavObject] = []
//   @Published var isLoadingNavUnits = false
//   @Published var isLoadingTideStations = false
//   @Published var isLoadingCurrentStations = false
//   @Published var isLoadingBuoyStations = false
//   
//   // MARK: - Chart Overlay Properties
//   @Published var isChartOverlayVisible = false
//   @Published var chartOverlay: NOAAChartTileOverlay?
//   @Published var selectedChartLayers: Set<Int> = [0, 1, 2, 6] // Start with basic layers
//   
//   // MARK: - Map Properties
//   private var allNavObjects: [NavObject] = []
//   private(set) var currentRegion: MKCoordinateRegion?
//   
//   // MARK: - New Properties for Annotation Capping
//   private let maxAnnotations = 100
//   private var lastProcessedRegion: MKCoordinateRegion?
//   private var regionChangeThrottleTime = 0.3 // seconds
//   private var lastRegionChangeTime = Date()
//   
//   // MARK: - Spatial Indexing
//   private var spatialGrid: [String: [NavObject]] = [:]
//   private let gridCellSize: Double = 0.05 // degrees (roughly 5.5 km at equator)
//   
//   // MARK: - NavUnit Storage
//   private var navUnits: [NavUnit] = []
//   
//   // MARK: - Services
//   let navUnitService: NavUnitDatabaseService
//   private let tideStationService: TideStationDatabaseService
//   private let currentStationService: CurrentStationDatabaseService
//   private let tidalHeightService: TidalHeightService
//   private let tidalCurrentService: TidalCurrentService
//   private let buoyService: BuoyApiService
//   private let buoyDatabaseService: BuoyDatabaseService
//   let locationService: LocationService
//   private let noaaChartService: NOAAChartService
//   
//   // MARK: - Initialization
//   init(navUnitService: NavUnitDatabaseService,
//        tideStationService: TideStationDatabaseService,
//        currentStationService: CurrentStationDatabaseService,
//        tidalHeightService: TidalHeightService,
//        tidalCurrentService: TidalCurrentService,
//        buoyService: BuoyApiService,
//        buoyDatabaseService: BuoyDatabaseService,
//        locationService: LocationService,
//        noaaChartService: NOAAChartService) {
//       self.navUnitService = navUnitService
//       self.tideStationService = tideStationService
//       self.currentStationService = currentStationService
//       self.tidalHeightService = tidalHeightService
//       self.tidalCurrentService = tidalCurrentService
//       self.buoyService = buoyService
//       self.buoyDatabaseService = buoyDatabaseService
//       self.locationService = locationService
//       self.noaaChartService = noaaChartService
//       
//       // Set initial region based on user location if available
//       if let userLocation = locationService.currentLocation {
//           currentRegion = MKCoordinateRegion(
//               center: userLocation.coordinate,
//               span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//           )
//       } else {
//           // Default to San Francisco as fallback
//           currentRegion = MKCoordinateRegion(
//               center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
//               span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//           )
//       }
//       
//       print("🗺️ MapClusteringViewModel: Initialized with NOAA Chart Service support")
//   }
//   
//   // MARK: - Public Methods
//   func loadData() {
//       Task {
//           await loadNavUnits()
//           await loadTidalHeightStations()
//           await loadTidalCurrentStations()
//           await loadBuoyStations()
//       }
//   }
//   
//   // Method to update map region and refresh visible annotations
//   func updateMapRegion(_ newRegion: MKCoordinateRegion) {
//       // Check if we should throttle this update
//       let now = Date()
//       if now.timeIntervalSince(lastRegionChangeTime) < regionChangeThrottleTime {
//           return
//       }
//       
//       // Skip if it's a very small change
//       if let lastRegion = lastProcessedRegion,
//          abs(lastRegion.center.latitude - newRegion.center.latitude) < 0.001 &&
//          abs(lastRegion.center.longitude - newRegion.center.longitude) < 0.001 &&
//          abs(lastRegion.span.latitudeDelta - newRegion.span.latitudeDelta) < 0.001 {
//           return
//       }
//       
//       lastRegionChangeTime = now
//       currentRegion = newRegion
//       lastProcessedRegion = newRegion
//       
//       // Get visible or nearby grid cells
//       let nearbyGridCells = getNearbyCells(forRegion: newRegion)
//       
//       // Update visible annotations
//       Task { @MainActor in
//           self.updateVisibleAnnotations(forRegion: newRegion, fromCells: nearbyGridCells)
//       }
//   }
//   
//   // Find a NavUnit by its ID
//   func findNavUnitById(_ navUnitId: String) -> NavUnit? {
//       return navUnits.first { $0.navUnitId == navUnitId }
//   }
//   
//   // MARK: - Chart Overlay Methods
//   
//   func toggleChartOverlay() {
//       isChartOverlayVisible.toggle()
//       
//       if isChartOverlayVisible {
//           createChartOverlay()
//           print("🗺️ MapClusteringViewModel: Chart overlay enabled")
//       } else {
//           chartOverlay = nil
//           print("🗺️ MapClusteringViewModel: Chart overlay disabled")
//       }
//   }
//   
//   func addChartLayer(_ layerId: Int) {
//       selectedChartLayers.insert(layerId)
//       updateChartOverlay()
//       print("➕ MapClusteringViewModel: Added chart layer \(layerId)")
//   }
//   
//   func removeChartLayer(_ layerId: Int) {
//       selectedChartLayers.remove(layerId)
//       updateChartOverlay()
//       print("➖ MapClusteringViewModel: Removed chart layer \(layerId)")
//   }
//   
//   private func createChartOverlay() {
//       chartOverlay = noaaChartService.createChartTileOverlay(
//           selectedLayers: selectedChartLayers
//       )
//   }
//   
//   private func updateChartOverlay() {
//       guard isChartOverlayVisible else { return }
//       createChartOverlay()
//   }
//   
//   // MARK: - Private Methods
//   private func loadNavUnits() async {
//       if isLoadingNavUnits { return }
//       
//       await MainActor.run {
//           isLoadingNavUnits = true
//       }
//       
//       do {
//           let units = try await navUnitService.getNavUnitsAsync()
//           self.navUnits = units // Store the full NavUnit objects
//           
//           // Convert to NavObject annotations
//           let annotations = units.compactMap { unit -> NavObject? in
//               // Skip entries without valid coordinates
//               guard let latitude = unit.latitude, let longitude = unit.longitude,
//                     latitude != 0 || longitude != 0 else {
//                   return nil
//               }
//               
//               let navObject = NavObject()
//               navObject.type = .navunit
//               navObject.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
//               navObject.name = unit.navUnitName
//               navObject.objectId = unit.navUnitId // Store the ID for later lookup
//               return navObject
//           }
//           
//           await MainActor.run {
//               addToSpatialIndex(annotations)
//               self.allNavObjects.append(contentsOf: annotations)
//               
//               // Update visible annotations if we have a current region
//               if let region = self.currentRegion {
//                   let nearbyCells = self.getNearbyCells(forRegion: region)
//                   self.updateVisibleAnnotations(forRegion: region, fromCells: nearbyCells)
//               }
//               
//               isLoadingNavUnits = false
//           }
//       } catch {
//           print("Error loading navigation units: \(error.localizedDescription)")
//           await MainActor.run {
//               isLoadingNavUnits = false
//           }
//       }
//   }
//   
//   private func loadTidalHeightStations() async {
//       if isLoadingTideStations { return }
//       
//       await MainActor.run {
//           isLoadingTideStations = true
//       }
//       
//       do {
//           let response = try await tidalHeightService.getTidalHeightStations()
//           
//           // Convert to NavObject annotations
//           let annotations = response.stations.compactMap { station -> NavObject? in
//               // Skip entries without valid coordinates
//               guard let latitude = station.latitude, let longitude = station.longitude else {
//                   return nil
//               }
//               
//               let navObject = NavObject()
//               navObject.type = .tidalheightstation
//               navObject.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
//               navObject.name = station.name
//               navObject.objectId = station.id // Store the ID for later lookup
//               return navObject
//           }
//           
//           await MainActor.run {
//               addToSpatialIndex(annotations)
//               self.allNavObjects.append(contentsOf: annotations)
//               
//               // Update visible annotations if we have a current region
//               if let region = self.currentRegion {
//                   let nearbyCells = self.getNearbyCells(forRegion: region)
//                   self.updateVisibleAnnotations(forRegion: region, fromCells: nearbyCells)
//               }
//               
//               isLoadingTideStations = false
//           }
//       } catch {
//           print("Error loading tidal height stations: \(error.localizedDescription)")
//           await MainActor.run {
//               isLoadingTideStations = false
//           }
//       }
//   }
//   
//   private func loadTidalCurrentStations() async {
//       if isLoadingCurrentStations { return }
//       
//       await MainActor.run {
//           isLoadingCurrentStations = true
//       }
//       
//       do {
//           let response = try await tidalCurrentService.getTidalCurrentStations()
//           
//           // Convert to NavObject annotations
//           let annotations = response.stations.compactMap { station -> NavObject? in
//               // Skip entries without valid coordinates
//               guard let latitude = station.latitude, let longitude = station.longitude else {
//                   return nil
//               }
//               
//               let navObject = NavObject()
//               navObject.type = .tidalcurrentstation
//               navObject.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
//               navObject.name = station.name
//               navObject.objectId = station.id // Store the ID for later lookup
//               navObject.currentBin = station.currentBin  // Store the bin value
//               return navObject
//           }
//           
//           await MainActor.run {
//               addToSpatialIndex(annotations)
//               self.allNavObjects.append(contentsOf: annotations)
//               
//               // Update visible annotations if we have a current region
//               if let region = self.currentRegion {
//                   let nearbyCells = self.getNearbyCells(forRegion: region)
//                   self.updateVisibleAnnotations(forRegion: region, fromCells: nearbyCells)
//               }
//               
//               isLoadingCurrentStations = false
//           }
//       } catch {
//           print("Error loading tidal current stations: \(error.localizedDescription)")
//           await MainActor.run {
//               isLoadingCurrentStations = false
//           }
//       }
//   }
//   
//   // New method to load buoy stations
//   private func loadBuoyStations() async {
//       if isLoadingBuoyStations { return }
//       
//       await MainActor.run {
//           isLoadingBuoyStations = true
//       }
//       
//       do {
//           let response = try await buoyService.getBuoyStations()
//           
//           // Convert to NavObject annotations
//           let annotations = response.stations.compactMap { station -> NavObject? in
//               // Skip entries without valid coordinates
//               guard let latitude = station.latitude, let longitude = station.longitude else {
//                   return nil
//               }
//               
//               let navObject = NavObject()
//               navObject.type = .buoystation
//               navObject.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
//               navObject.name = station.name
//               navObject.objectId = station.id // Store the ID for later lookup
//               return navObject
//           }
//           
//           await MainActor.run {
//               addToSpatialIndex(annotations)
//               self.allNavObjects.append(contentsOf: annotations)
//               
//               // Update visible annotations if we have a current region
//               if let region = self.currentRegion {
//                   let nearbyCells = self.getNearbyCells(forRegion: region)
//                   self.updateVisibleAnnotations(forRegion: region, fromCells: nearbyCells)
//               }
//               
//               isLoadingBuoyStations = false
//           }
//       } catch {
//           print("Error loading buoy stations: \(error.localizedDescription)")
//           await MainActor.run {
//               isLoadingBuoyStations = false
//           }
//       }
//   }
//   
//   // MARK: - Spatial Indexing Methods
//   
//   // Add annotations to spatial grid index
//   private func addToSpatialIndex(_ annotations: [NavObject]) {
//       for annotation in annotations {
//           let gridKey = gridKeyForCoordinate(annotation.coordinate)
//           if spatialGrid[gridKey] == nil {
//               spatialGrid[gridKey] = [annotation]
//           } else {
//               spatialGrid[gridKey]?.append(annotation)
//           }
//       }
//   }
//   
//   // Get grid cell key for a coordinate
//   private func gridKeyForCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
//       let latCell = Int(coordinate.latitude / gridCellSize)
//       let lonCell = Int(coordinate.longitude / gridCellSize)
//       return "\(latCell):\(lonCell)"
//   }
//   
//   // Get nearby grid cells for a region
//   private func getNearbyCells(forRegion region: MKCoordinateRegion) -> [String] {
//       // Calculate bounding box
//       let minLat = region.center.latitude - region.span.latitudeDelta
//       let maxLat = region.center.latitude + region.span.latitudeDelta
//       let minLon = region.center.longitude - region.span.longitudeDelta
//       let maxLon = region.center.longitude + region.span.longitudeDelta
//       
//       // Get grid cell ranges
//       let minLatCell = Int(minLat / gridCellSize)
//       let maxLatCell = Int(maxLat / gridCellSize)
//       let minLonCell = Int(minLon / gridCellSize)
//       let maxLonCell = Int(maxLon / gridCellSize)
//       
//       // Generate all cell keys in the range
//       var cellKeys: [String] = []
//       for latCell in minLatCell...maxLatCell {
//           for lonCell in minLonCell...maxLonCell {
//               cellKeys.append("\(latCell):\(lonCell)")
//           }
//       }
//       
//       return cellKeys
//   }
//   
//   // MARK: - Annotation Filtering and Capping
//   
//   // Update visible annotations based on current region
//   private func updateVisibleAnnotations(forRegion region: MKCoordinateRegion, fromCells cellKeys: [String]) {
//       // Collect all annotations from the relevant grid cells
//       var candidateAnnotations: [NavObject] = []
//       for key in cellKeys {
//           if let annotations = spatialGrid[key] {
//               candidateAnnotations.append(contentsOf: annotations)
//           }
//       }
//       
//       // Sort by distance from center
//       let centerCoordinate = region.center
//       let sortedAnnotations = candidateAnnotations.sorted { (obj1, obj2) -> Bool in
//           let distance1 = calculateDistance(from: centerCoordinate, to: obj1.coordinate)
//           let distance2 = calculateDistance(from: centerCoordinate, to: obj2.coordinate)
//           return distance1 < distance2
//       }
//       
//       // Cap to maximum number
//       let cappedAnnotations = Array(sortedAnnotations.prefix(maxAnnotations))
//       self.navobjects = cappedAnnotations
//   }
//   
//   // Calculate distance between coordinates
//   private func calculateDistance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
//       let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
//       let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
//       return sourceLocation.distance(from: destinationLocation)
//   }
//}









import Foundation
import CoreLocation
import MapKit

class MapClusteringViewModel: ObservableObject {
   // MARK: - Published Properties
   @Published var navobjects: [NavObject] = []
   @Published var isLoadingNavUnits = false
   @Published var isLoadingTideStations = false
   @Published var isLoadingCurrentStations = false
   @Published var isLoadingBuoyStations = false
   
   // MARK: - Chart Overlay Properties (updated to always be on)
   @Published var isChartOverlayVisible = true // Always true now
   @Published var chartOverlay: NOAAChartTileOverlay?
   @Published var selectedChartLayers: Set<Int> = [0, 1, 2, 6] // Layer 0 always included
   
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
   
   // MARK: - NavUnit Storage
   private var navUnits: [NavUnit] = []
   
   // MARK: - Services
   let navUnitService: NavUnitDatabaseService
   private let tideStationService: TideStationDatabaseService
   private let currentStationService: CurrentStationDatabaseService
   private let tidalHeightService: TidalHeightService
   private let tidalCurrentService: TidalCurrentService
   private let buoyService: BuoyApiService
   private let buoyDatabaseService: BuoyDatabaseService
   let locationService: LocationService
   private let noaaChartService: NOAAChartService
   
   // MARK: - Initialization
   init(navUnitService: NavUnitDatabaseService,
        tideStationService: TideStationDatabaseService,
        currentStationService: CurrentStationDatabaseService,
        tidalHeightService: TidalHeightService,
        tidalCurrentService: TidalCurrentService,
        buoyService: BuoyApiService,
        buoyDatabaseService: BuoyDatabaseService,
        locationService: LocationService,
        noaaChartService: NOAAChartService) {
       self.navUnitService = navUnitService
       self.tideStationService = tideStationService
       self.currentStationService = currentStationService
       self.tidalHeightService = tidalHeightService
       self.tidalCurrentService = tidalCurrentService
       self.buoyService = buoyService
       self.buoyDatabaseService = buoyDatabaseService
       self.locationService = locationService
       self.noaaChartService = noaaChartService
       
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
       
       // Initialize chart overlay immediately since it's always on
       createChartOverlay()
       
       print("🗺️ MapClusteringViewModel: Initialized with NOAA Chart Service support (always on)")
   }
   
   // MARK: - Public Methods
   func loadData() {
       Task {
           await loadNavUnits()
           await loadTidalHeightStations()
           await loadTidalCurrentStations()
           await loadBuoyStations()
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
   
   // Find a NavUnit by its ID
   func findNavUnitById(_ navUnitId: String) -> NavUnit? {
       return navUnits.first { $0.navUnitId == navUnitId }
   }
   
   // MARK: - Chart Overlay Methods (simplified)
   
   func addChartLayer(_ layerId: Int) {
       selectedChartLayers.insert(layerId)
       // Always ensure Layer 0 is included
       selectedChartLayers.insert(0)
       updateChartOverlay()
       print("➕ MapClusteringViewModel: Added chart layer \(layerId)")
   }
   
   func removeChartLayer(_ layerId: Int) {
       // Prevent removing Layer 0
       if layerId == 0 {
           print("🚫 MapClusteringViewModel: Cannot remove Layer 0 (always required)")
           return
       }
       
       selectedChartLayers.remove(layerId)
       // Always ensure Layer 0 remains
       selectedChartLayers.insert(0)
       updateChartOverlay()
       print("➖ MapClusteringViewModel: Removed chart layer \(layerId)")
   }
   
   private func createChartOverlay() {
       chartOverlay = noaaChartService.createChartTileOverlay(
           selectedLayers: selectedChartLayers
       )
   }
   
   private func updateChartOverlay() {
       createChartOverlay()
   }
   
   // MARK: - Private Methods
   private func loadNavUnits() async {
       if isLoadingNavUnits { return }
       
       await MainActor.run {
           isLoadingNavUnits = true
       }
       
       do {
           let units = try await navUnitService.getNavUnitsAsync()
           self.navUnits = units // Store the full NavUnit objects
           
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
               navObject.name = unit.navUnitName
               navObject.objectId = unit.navUnitId // Store the ID for later lookup
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
               navObject.name = station.name
               navObject.objectId = station.id // Store the ID for later lookup
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
               navObject.name = station.name
               navObject.objectId = station.id // Store the ID for later lookup
               navObject.currentBin = station.currentBin  // Store the bin value
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
   
   // New method to load buoy stations
   private func loadBuoyStations() async {
       if isLoadingBuoyStations { return }
       
       await MainActor.run {
           isLoadingBuoyStations = true
       }
       
       do {
           let response = try await buoyService.getBuoyStations()
           
           // Convert to NavObject annotations
           let annotations = response.stations.compactMap { station -> NavObject? in
               // Skip entries without valid coordinates
               guard let latitude = station.latitude, let longitude = station.longitude else {
                   return nil
               }
               
               let navObject = NavObject()
               navObject.type = .buoystation
               navObject.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
               navObject.name = station.name
               navObject.objectId = station.id // Store the ID for later lookup
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
               
               isLoadingBuoyStations = false
           }
       } catch {
           print("Error loading buoy stations: \(error.localizedDescription)")
           await MainActor.run {
               isLoadingBuoyStations = false
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
