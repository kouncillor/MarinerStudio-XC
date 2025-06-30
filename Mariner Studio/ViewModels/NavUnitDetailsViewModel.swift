
import Foundation
import SwiftUI
import CoreLocation
import Combine
import MapKit

// Map-related models
struct MapRegion: Equatable {
    var center: CLLocationCoordinate2D
    var span: MKCoordinateSpan
    
    static func == (lhs: MapRegion, rhs: MapRegion) -> Bool {
        return lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
               lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}

struct NavUnitMapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String
}

class NavUnitDetailsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var unit: NavUnit?
    @Published var errorMessage: String = ""
    @Published var favoriteIcon: String = "favoriteoutlinesixseven"
    @Published var formattedCoordinates: String = ""
    @Published var depthRange: String = ""
    @Published var deckHeightRange: String = ""
    @Published var hasMultiplePhoneNumbers: Bool = false
    
    
    // Auto-sync state
    @Published var isAutoSyncing: Bool = false
    
    @Published var deletionStatusMessage: String = ""
    
    // MARK: - Chart Overlay Properties (NEW)
    @Published var chartOverlay: NOAAChartTileOverlay?
    private let defaultChartLayers: Set<Int> = [0, 1, 2, 6] // Same as MapClusteringView defaults
    
    // MARK: - Sync Throttling
    private var lastSyncTime: [String: Date] = [:] // Track last sync time per navUnitId
    private let syncThrottleInterval: TimeInterval = 10 // Minimum 10 seconds between syncs
    private var activeSyncTasks: Set<String> = Set() // Track active sync operations
    
    // MARK: - Map-related Properties
    @Published var mapRegion: MapRegion?
    @Published var mapAnnotation: NavUnitMapAnnotation?
    
    // MARK: - Services
    private let databaseService: NavUnitDatabaseService
    private let favoritesService: FavoritesService
    private let noaaChartService: NOAAChartService // NEW: Chart service
    
    // Used to manage and cancel any ongoing tasks
    private var cancellables = Set<AnyCancellable>()
    
    
    // MARK: - Computed Properties
    var hasCoordinates: Bool {
        return unit?.latitude != nil && unit?.longitude != nil
    }
    
    var hasPhoneNumbers: Bool {
        return unit?.hasPhoneNumbers ?? false
    }
    
    var hasAdditionalInfo: Bool {
        return !(unit?.construction?.isEmpty ?? true) ||
               !(unit?.mechanicalHandling?.isEmpty ?? true) ||
               !(unit?.remarks?.isEmpty ?? true) ||
               !(unit?.commodities?.isEmpty ?? true)
    }
    
    var hasWaterwayInfo: Bool {
        return !(unit?.waterwayName?.isEmpty ?? true) ||
               !(unit?.portName?.isEmpty ?? true) ||
               unit?.mile != nil ||
               !(unit?.bank?.isEmpty ?? true)
    }
    
    var hasTransportationInfo: Bool {
        return !(unit?.highwayNote?.isEmpty ?? true) ||
               !(unit?.railwayNote?.isEmpty ?? true)
    }
    
    // MARK: - Initialization
    init(
        databaseService: NavUnitDatabaseService,
        favoritesService: FavoritesService,
        noaaChartService: NOAAChartService // NEW: Chart service parameter
    ) {
        self.databaseService = databaseService
        self.favoritesService = favoritesService
        self.noaaChartService = noaaChartService
        createDefaultChartOverlay()
    }
    
    // New initializer that takes a NavUnit
    init(
        navUnit: NavUnit,
        databaseService: NavUnitDatabaseService,
        favoritesService: FavoritesService,
        noaaChartService: NOAAChartService // NEW: Chart service parameter
    ) {
        self.databaseService = databaseService
        self.favoritesService = favoritesService
        self.noaaChartService = noaaChartService // NEW: Store chart service
        createDefaultChartOverlay() // NEW: Create chart overlay
        
        // Set the nav unit and update display properties
        self.unit = navUnit
        updateDisplayProperties()
        updateFavoriteIcon()
        initializeMap()
        
    }
    
    // MARK: - Chart Overlay Methods (NEW)
    
    private func createDefaultChartOverlay() {
        chartOverlay = noaaChartService.createChartTileOverlay(
            selectedLayers: defaultChartLayers
        )
        print("📊 NavUnitDetailsViewModel: Created default chart overlay with layers: \(defaultChartLayers)")
    }
    
    
    
   
    
    // MARK: - Public Methods
    func loadUnit(_ navUnit: NavUnit) {
        self.unit = navUnit
        updateDisplayProperties()
        updateFavoriteIcon()
        initializeMap()
        
        
    }
    
     
  
    
     
    
    
    func toggleFavorite() async {
        guard let unit = unit else { return }
        
        do {
            let isFavorite = try await databaseService.toggleFavoriteNavUnitAsync(navUnitId: unit.navUnitId)
            
            await MainActor.run {
                self.unit?.isFavorite = isFavorite
                updateFavoriteIcon()
            }
            
            await favoritesService.syncFavoriteNavUnitAsync(unit.navUnitId, isFavorite)
        } catch {
            await MainActor.run {
                self.errorMessage = "Unable to update favorite status: \(error.localizedDescription)"
            }
        }
    }
    
    func openInMaps() {
        guard let unit = unit,
              let latitude = unit.latitude,
              let longitude = unit.longitude else { return }
        
        let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinates))
        mapItem.name = unit.navUnitName
        
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    func makePhoneCall() {
        guard let unit = unit, unit.hasPhoneNumbers else {
            errorMessage = "No phone number available."
            return
        }
        
        let phoneNumbers = unit.phoneNumbers
        
        if phoneNumbers.count > 1 {
            // In real implementation, display action sheet for number selection
            // For now, just use the first one
            dialPhoneNumber(phoneNumbers[0])
        } else if let firstNumber = phoneNumbers.first {
            dialPhoneNumber(firstNumber)
        }
    }
    
    private func dialPhoneNumber(_ number: String) {
        let formattedNumber = number.replacingOccurrences(of: "-", with: "")
                                    .replacingOccurrences(of: " ", with: "")
        
        guard let url = URL(string: "tel://\(formattedNumber)") else { return }
        
        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
    
    func shareUnit() {
        guard let unit = unit else { return }
        
        var shareText = "Navigation Unit Information\n\n"
        shareText += "Name: \(unit.navUnitName)\n"
        shareText += "ID: \(unit.navUnitId)\n"
        
        if let facilityType = unit.facilityType {
            shareText += "Type: \(facilityType)\n"
        }
        
        if let unloCode = unit.unloCode, !unloCode.isEmpty {
            shareText += "UNLOCODE: \(unloCode)\n"
        }
        
        // Location Information
        shareText += "\nLocation Information:\n"
        if hasCoordinates {
            shareText += "Coordinates: \(formattedCoordinates)\n"
        }
        
        if let streetAddress = unit.streetAddress, !streetAddress.isEmpty {
            shareText += "Street Address: \(streetAddress)\n"
        }
        
        // Additional information could be added here
        
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        // Get the root view controller to present the share sheet from
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
        #endif
    }

    
    
    // MARK: - Map Methods
    
    // Add this method to initialize the map when a unit is loaded
    private func initializeMap() {
        guard let unit = unit,
              let latitude = unit.latitude,
              let longitude = unit.longitude else {
            mapRegion = nil
            mapAnnotation = nil
            return
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        mapRegion = MapRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        mapAnnotation = NavUnitMapAnnotation(
            coordinate: coordinate,
            title: unit.navUnitName,
            subtitle: unit.facilityType ?? "Navigation Unit"
        )
    }
    
    // MARK: - Private Methods
    private func updateDisplayProperties() {
        guard let unit = unit else { return }
        
        // Format depth range
        if unit.depthMin != nil || unit.depthMax != nil {
            if unit.depthMin == unit.depthMax, let depth = unit.depthMin {
                depthRange = "\(depth) ft"
            } else if unit.depthMin == nil, let maxDepth = unit.depthMax {
                depthRange = "Up to \(maxDepth) ft"
            } else if unit.depthMax == nil, let minDepth = unit.depthMin {
                depthRange = "Minimum \(minDepth) ft"
            } else if let minDepth = unit.depthMin, let maxDepth = unit.depthMax {
                depthRange = "\(minDepth) - \(maxDepth) ft"
            }
        } else {
            depthRange = "Not specified"
        }
        
        // Format deck height range
        if unit.deckHeightMin != nil || unit.deckHeightMax != nil {
            if unit.deckHeightMin == unit.deckHeightMax, let height = unit.deckHeightMin {
                deckHeightRange = "\(height) ft"
            } else if unit.deckHeightMin == nil, let maxHeight = unit.deckHeightMax {
                deckHeightRange = "Up to \(maxHeight) ft"
            } else if unit.deckHeightMax == nil, let minHeight = unit.deckHeightMin {
                deckHeightRange = "Minimum \(minHeight) ft"
            } else if let minHeight = unit.deckHeightMin, let maxHeight = unit.deckHeightMax {
                deckHeightRange = "\(minHeight) - \(maxHeight) ft"
            }
        } else {
            deckHeightRange = "Not specified"
        }
        
        // Format coordinates - safely unwrapping optionals
        if let latitude = unit.latitude, let longitude = unit.longitude {
            formattedCoordinates = formatCoordinates(latitude: latitude, longitude: longitude)
        } else {
            formattedCoordinates = "Not available"
        }
        
        hasMultiplePhoneNumbers = unit.phoneNumbers.count > 1
    }
    
    private func formatCoordinates(latitude: Double, longitude: Double) -> String {
        let latDirection = latitude >= 0 ? "N" : "S"
        let lonDirection = longitude >= 0 ? "E" : "W"
        
        let absLat = abs(latitude)
        let absLon = abs(longitude)
        
        let latDegrees = floor(absLat)
        let latMinutes = (absLat - latDegrees) * 60
        
        let lonDegrees = floor(absLon)
        let lonMinutes = (absLon - lonDegrees) * 60
        
        return String(format: "%.0f°%.3f'%@, %.0f°%.3f'%@",
                      latDegrees, latMinutes, latDirection,
                      lonDegrees, lonMinutes, lonDirection)
    }
    
    private func updateFavoriteIcon() {
        favoriteIcon = unit?.isFavorite == true ? "favoritesixseven" : "favoriteoutlinesixseven"
    }
}
