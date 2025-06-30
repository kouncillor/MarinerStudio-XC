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
    
    // NEW: Async loading properties
    @Published var isLoadingNavUnit: Bool = false
    @Published var navUnitLoadError: String = ""
    
    // Auto-sync state
    @Published var isAutoSyncing: Bool = false
    @Published var deletionStatusMessage: String = ""
    
    // MARK: - Chart Overlay Properties
    @Published var chartOverlay: NOAAChartTileOverlay?
    private let defaultChartLayers: Set<Int> = [0, 1, 2, 6]
    
    // MARK: - Sync Throttling
    private var lastSyncTime: [String: Date] = [:]
    private let syncThrottleInterval: TimeInterval = 10
    private var activeSyncTasks: Set<String> = Set()
    
    // MARK: - Map-related Properties
    @Published var mapRegion: MapRegion?
    @Published var mapAnnotation: NavUnitMapAnnotation?
    
    // MARK: - Properties
    private let navUnitId: String?  // NEW: Store the ID for async loading
    private let databaseService: NavUnitDatabaseService
    private let favoritesService: FavoritesService
    private let noaaChartService: NOAAChartService
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initializers
    
    // NEW: Initializer for async loading by ID
    init(
        navUnitId: String,
        databaseService: NavUnitDatabaseService,
        favoritesService: FavoritesService,
        noaaChartService: NOAAChartService
    ) {
        print("🎯 NavUnitDetailsViewModel: Initializing with navUnitId: \(navUnitId)")
        
        self.navUnitId = navUnitId
        self.databaseService = databaseService
        self.favoritesService = favoritesService
        self.noaaChartService = noaaChartService
        
        // Initialize empty state - will load async
        self.unit = nil
        
        print("✅ NavUnitDetailsViewModel: Initialized for async loading")
    }
    
    // EXISTING: Initializer for direct model injection
    init(
        navUnit: NavUnit,
        databaseService: NavUnitDatabaseService,
        favoritesService: FavoritesService,
        noaaChartService: NOAAChartService
    ) {
        print("🎯 NavUnitDetailsViewModel: Initializing with direct navUnit: \(navUnit.navUnitName)")
        
        self.navUnitId = nil  // No async loading needed
        self.databaseService = databaseService
        self.favoritesService = favoritesService
        self.noaaChartService = noaaChartService
        
        // Set the unit immediately
        self.unit = navUnit
        
        // Initialize dependent properties
        initializeDependentProperties()
        
        print("✅ NavUnitDetailsViewModel: Initialized with direct model")
    }
    
    // MARK: - Async Loading Methods
    
    /// Load nav unit if needed (called from view onAppear)
    func loadNavUnitIfNeeded() async {
        guard let navUnitId = navUnitId else {
            // Already have a unit from direct initialization
            return
        }
        
        guard unit == nil else {
            // Already loaded
            return
        }
        
        await loadNavUnitById(navUnitId)
    }
    
    /// Load nav unit by ID from database
    private func loadNavUnitById(_ id: String) async {
        print("🔄 NavUnitDetailsViewModel: Starting async load for navUnitId: \(id)")
        
        await MainActor.run {
            isLoadingNavUnit = true
            navUnitLoadError = ""
        }
        
        do {
            // Fetch the full nav unit from database
            print("📱 NavUnitDetailsViewModel: Fetching nav unit from database...")
            let fetchedUnit = try await databaseService.getNavUnitByIdAsync(id)
            
            await MainActor.run {
                self.unit = fetchedUnit
                self.isLoadingNavUnit = false
                print("✅ NavUnitDetailsViewModel: Successfully loaded nav unit: \(fetchedUnit.navUnitName)")
                
                // Initialize dependent properties
                self.initializeDependentProperties()
            }
            
        } catch {
            print("❌ NavUnitDetailsViewModel: Error loading nav unit: \(error.localizedDescription)")
            
            await MainActor.run {
                self.isLoadingNavUnit = false
                self.navUnitLoadError = "Failed to load navigation unit: \(error.localizedDescription)"
            }
        }
    }
    
    /// Retry loading nav unit (called from error state button)
    func retryLoadNavUnit() async {
        guard let navUnitId = navUnitId else { return }
        await loadNavUnitById(navUnitId)
    }
    
    // MARK: - Initialization Helpers
    
    /// Initialize properties that depend on the nav unit being loaded
    private func initializeDependentProperties() {
        guard let unit = unit else { return }
        
        print("🔧 NavUnitDetailsViewModel: Initializing dependent properties for: \(unit.navUnitName)")
        
        // Update favorite icon
        updateFavoriteIcon()
        
        // Format coordinates
        formatCoordinates()
        
        // Calculate depth and deck height ranges
        calculateDepthRange()
        calculateDeckHeightRange()
        
        // Set up map region and annotation
        setupMapData()
        
        // Set up chart overlay
        setupChartOverlay()
        
        print("✅ NavUnitDetailsViewModel: Dependent properties initialized")
    }
    
    private func updateFavoriteIcon() {
        favoriteIcon = unit?.isFavorite == true ? "favoritesixseven" : "favoriteoutlinesixseven"
    }
    
    private func formatCoordinates() {
        guard let lat = unit?.latitude, let lon = unit?.longitude else {
            formattedCoordinates = ""
            return
        }
        
        formattedCoordinates = String(format: "%.6f°, %.6f°", lat, lon)
    }
    
    private func calculateDepthRange() {
        guard let unit = unit else {
            depthRange = ""
            return
        }
        
        if let minDepth = unit.depthMin, let maxDepth = unit.depthMax {
            if minDepth == maxDepth {
                depthRange = String(format: "%.1f ft", minDepth)
            } else {
                depthRange = String(format: "%.1f - %.1f ft", minDepth, maxDepth)
            }
        } else if let minDepth = unit.depthMin {
            depthRange = String(format: "%.1f ft (min)", minDepth)
        } else if let maxDepth = unit.depthMax {
            depthRange = String(format: "%.1f ft (max)", maxDepth)
        } else {
            depthRange = ""
        }
    }
    
    private func calculateDeckHeightRange() {
        guard let unit = unit else {
            deckHeightRange = ""
            return
        }
        
        if let minHeight = unit.deckHeightMin, let maxHeight = unit.deckHeightMax {
            if minHeight == maxHeight {
                deckHeightRange = String(format: "%.1f ft", minHeight)
            } else {
                deckHeightRange = String(format: "%.1f - %.1f ft", minHeight, maxHeight)
            }
        } else if let minHeight = unit.deckHeightMin {
            deckHeightRange = String(format: "%.1f ft (min)", minHeight)
        } else if let maxHeight = unit.deckHeightMax {
            deckHeightRange = String(format: "%.1f ft (max)", maxHeight)
        } else {
            deckHeightRange = ""
        }
    }
    
    private func setupMapData() {
        guard let lat = unit?.latitude, let lon = unit?.longitude else {
            mapRegion = nil
            mapAnnotation = nil
            return
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        
        mapRegion = MapRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        mapAnnotation = NavUnitMapAnnotation(
            coordinate: coordinate,
            title: unit?.navUnitName ?? "Navigation Unit",
            subtitle: formattedCoordinates
        )
    }
    
    private func setupChartOverlay() {
        chartOverlay = NOAAChartTileOverlay(selectedLayers: defaultChartLayers)
    }
    
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
    
    // MARK: - User Actions
    
    /// Toggle favorite status
    func toggleFavorite() async {
        guard let unit = unit else {
            print("⚠️ NavUnitDetailsViewModel: Cannot toggle favorite - no nav unit loaded")
            return
        }
        
        print("⭐ NavUnitDetailsViewModel: Toggling favorite for: \(unit.navUnitName)")
        
        do {
            // Toggle favorite in database
            let newFavoriteStatus = try await databaseService.toggleFavoriteNavUnitAsync(navUnitId: unit.navUnitId)
            
            await MainActor.run {
                // Update the local unit
                var updatedUnit = unit
                updatedUnit.isFavorite = newFavoriteStatus
                self.unit = updatedUnit
                
                // Update the favorite icon
                self.updateFavoriteIcon()
                
                print("✅ NavUnitDetailsViewModel: Favorite status updated to: \(newFavoriteStatus)")
            }
            
            // Trigger auto-sync if needed
            await performAutoSyncIfNeeded()
            
        } catch {
            print("❌ NavUnitDetailsViewModel: Error toggling favorite: \(error.localizedDescription)")
            
            await MainActor.run {
                self.errorMessage = "Failed to update favorite status: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Auto-Sync Methods
    
    /// Perform auto-sync if conditions are met
    private func performAutoSyncIfNeeded() async {
        guard let unit = unit else { return }
        
        let navUnitId = unit.navUnitId
        let currentTime = Date()
        
        // Check if we should throttle this sync
        if let lastSync = lastSyncTime[navUnitId],
           currentTime.timeIntervalSince(lastSync) < syncThrottleInterval {
            print("🔄 NavUnitDetailsViewModel: Skipping sync for \(navUnitId) - throttled")
            return
        }
        
        // Check if sync is already in progress
        guard !activeSyncTasks.contains(navUnitId) else {
            print("🔄 NavUnitDetailsViewModel: Skipping sync for \(navUnitId) - already in progress")
            return
        }
        
        // Mark sync as active
        activeSyncTasks.insert(navUnitId)
        lastSyncTime[navUnitId] = currentTime
        
        await MainActor.run {
            isAutoSyncing = true
        }
        
        do {
            // Perform sync using the favorites service
            print("☁️ NavUnitDetailsViewModel: Starting auto-sync for nav unit: \(navUnitId)")
            
            // Note: This would need to be implemented in the favorites service
            // For now, we'll just simulate the sync
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            print("✅ NavUnitDetailsViewModel: Auto-sync completed for: \(navUnitId)")
            
        } catch {
            print("❌ NavUnitDetailsViewModel: Auto-sync failed: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isAutoSyncing = false
        }
        
        // Remove from active sync tasks
        activeSyncTasks.remove(navUnitId)
    }
    
    // MARK: - Cleanup
    
    deinit {
        print("💀 NavUnitDetailsViewModel: Deallocating")
        cancellables.removeAll()
    }
}
