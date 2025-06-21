
import Foundation
import SwiftUI
import Combine
import CoreLocation

class TideFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [TidalHeightStation] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // Sync-related published properties
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncErrorMessage: String?
    @Published var syncSuccessMessage: String?
    
    // DEBUG: Published properties for debugging display
    @Published var debugInfo: [String] = []
    @Published var performanceMetrics: [String] = []
    @Published var databaseStats: [String] = []
    @Published var loadingPhase = "Idle"
    
    // MARK: - Properties
    public var tideStationService: TideStationDatabaseService?
    public var tidalHeightService: TidalHeightService?
    public var locationService: LocationService?
    public var loadTask: Task<Void, Never>?
    public var cancellables = Set<AnyCancellable>()
    
    // Performance tracking
    private var startTime: Date?
    private var phaseStartTime: Date?
    
    // MARK: - Initialization
    init() {
        logDebug("🎯 INIT: TideFavoritesViewModel created at \(Date())")
        logDebug("🎯 INIT: Thread = \(Thread.current)")
        logDebug("🎯 INIT: Memory address = \(Unmanaged.passUnretained(self).toOpaque())")
        
        // Use Task to call MainActor methods from init
        Task { @MainActor in
            updateDebugInfo("ViewModel initialized")
        }
    }
    
    deinit {
        logDebug("💀 DEINIT: TideFavoritesViewModel being deallocated")
        loadTask?.cancel()
        cancellables.removeAll()
    }
    
    // Initialize with services
    func initialize(
        tideStationService: TideStationDatabaseService,
        tidalHeightService: TidalHeightService,
        locationService: LocationService
    ) {
        logDebug("🔧 INITIALIZE: Starting service initialization...")
        logDebug("🔧 INITIALIZE: TideStationService = \(type(of: tideStationService))")
        logDebug("🔧 INITIALIZE: TidalHeightService = \(type(of: tidalHeightService))")
        logDebug("🔧 INITIALIZE: LocationService = \(type(of: locationService))")
        
        self.tideStationService = tideStationService
        self.tidalHeightService = tidalHeightService
        self.locationService = locationService
        
        logDebug("✅ INITIALIZE: All services assigned successfully")
        
        // Use Task to call MainActor methods
        Task { @MainActor in
            updateDebugInfo("Services initialized: TideStation✅ TidalHeight✅ Location✅")
            updatePerformanceMetric("Services initialized at \(Date())")
        }
    }
    
    // MARK: - Public Methods
    
    func loadFavorites() {
        logDebug("🚀 LOAD_FAVORITES: Entry point called")
        logDebug("🚀 LOAD_FAVORITES: Current thread = \(Thread.current)")
        logDebug("🚀 LOAD_FAVORITES: Is main thread = \(Thread.isMainThread)")
        
        // Cancel any existing task
        if let existingTask = loadTask {
            logDebug("🛑 LOAD_FAVORITES: Cancelling existing load task")
            existingTask.cancel()
        }
        
        // Start performance tracking
        startTime = Date()
        phaseStartTime = startTime
        
        loadTask = Task { @MainActor in
            await performLoadFavorites()
        }
    }
    
    @MainActor
    private func performLoadFavorites() async {
        logDebug("📱 PERFORM_LOAD: Starting main load operation on MainActor")
        logDebug("📱 PERFORM_LOAD: Current favorites count = \(favorites.count)")
        
        // Reset state
        isLoading = true
        errorMessage = ""
        loadingPhase = "Initializing"
        debugInfo.removeAll()
        performanceMetrics.removeAll()
        databaseStats.removeAll()
        
        updateDebugInfo("Load operation started")
        updatePerformanceMetric("Load started at \(Date())")
        
        // Check services
        guard let tideStationService = tideStationService else {
            await handleLoadError("TideStationDatabaseService not available", phase: "Service Check")
            return
        }
        
        guard let tidalHeightService = tidalHeightService else {
            await handleLoadError("TidalHeightService not available", phase: "Service Check")
            return
        }
        
        logDebug("✅ PERFORM_LOAD: Services verified successfully")
        updateDebugInfo("Services verified ✅")
        
        do {
            // PHASE 1: Get favorite station IDs from local database
            await updateLoadingPhase("Loading from local database")
            
            let phaseStart = Date()
            logDebug("📊 PHASE_1: Starting local database query...")
            logDebug("📊 PHASE_1: Calling getAllFavoriteStationIds()")
            
            let favoriteIds = await tideStationService.getAllFavoriteStationIds()
            let phase1Duration = Date().timeIntervalSince(phaseStart)
            
            logDebug("📊 PHASE_1: Database query completed")
            logDebug("📊 PHASE_1: Duration = \(String(format: "%.3f", phase1Duration))s")
            logDebug("📊 PHASE_1: Favorite IDs count = \(favoriteIds.count)")
            logDebug("📊 PHASE_1: Favorite IDs = \(Array(favoriteIds).sorted())")
            
            updateDebugInfo("Local DB query: \(favoriteIds.count) favorites in \(String(format: "%.3f", phase1Duration))s")
            updatePerformanceMetric("DB Query: \(String(format: "%.3f", phase1Duration))s for \(favoriteIds.count) records")
            updateDatabaseStat("Favorite station IDs: \(favoriteIds.count)")
            updateDatabaseStat("Station IDs: \(Array(favoriteIds).prefix(10).joined(separator: ", "))\(favoriteIds.count > 10 ? "..." : "")")
            
            if favoriteIds.isEmpty {
                logDebug("📊 PHASE_1: No favorites found - setting empty state")
                await updateLoadingPhase("No favorites found")
                
                favorites = []
                isLoading = false
                updateDebugInfo("No favorites in local database")
                updatePerformanceMetric("Total load time: \(String(format: "%.3f", Date().timeIntervalSince(startTime!)))s")
                
                logDebug("✅ PHASE_1: Load completed with empty result")
                return
            }
            
            // PHASE 2: Create station objects with local data only
            await updateLoadingPhase("Creating station objects")
            
            let phase2Start = Date()
            logDebug("🏗️ PHASE_2: Creating station objects from local data...")
            logDebug("🏗️ PHASE_2: Will create \(favoriteIds.count) station objects")
            
            var createdStations: [TidalHeightStation] = []
            var creationErrors: [String] = []
            
            for (index, stationId) in favoriteIds.enumerated() {
                logDebug("🏗️ PHASE_2: Creating station \(index + 1)/\(favoriteIds.count) - ID: \(stationId)")
                
                do {
                    // Get basic station info from database if available
                    let isFavorite = await tideStationService.isTideStationFavorite(id: stationId)
                    logDebug("🏗️ PHASE_2: Station \(stationId) favorite status confirmed: \(isFavorite)")
                    
                    // Try to get additional station details if possible
                    var stationName = "Station \(stationId)"
                    var state = "Unknown"
                    
                    // TODO: In the future, we could cache station details locally
                    // For now, use basic info to avoid API calls
                    
                    let station = TidalHeightStation(
                        id: stationId,
                        name: stationName,
                        latitude: nil,
                        longitude: nil,
                        state: state,
                        type: "tidepredictions",
                        referenceId: stationId,
                        timezoneCorrection: nil,
                        timeMeridian: nil,
                        tidePredOffsets: nil,
                        isFavorite: true // We know this is true since we got it from favorites
                    )
                    
                    createdStations.append(station)
                    logDebug("✅ PHASE_2: Successfully created station object for \(stationId)")
                    
                } catch {
                    let errorMsg = "Failed to create station \(stationId): \(error.localizedDescription)"
                    logDebug("❌ PHASE_2: \(errorMsg)")
                    creationErrors.append(errorMsg)
                }
            }
            
            let phase2Duration = Date().timeIntervalSince(phase2Start)
            logDebug("🏗️ PHASE_2: Station creation completed")
            logDebug("🏗️ PHASE_2: Duration = \(String(format: "%.3f", phase2Duration))s")
            logDebug("🏗️ PHASE_2: Created stations = \(createdStations.count)")
            logDebug("🏗️ PHASE_2: Creation errors = \(creationErrors.count)")
            
            updateDebugInfo("Created \(createdStations.count) stations in \(String(format: "%.3f", phase2Duration))s")
            updatePerformanceMetric("Station Creation: \(String(format: "%.3f", phase2Duration))s for \(createdStations.count) objects")
            updateDatabaseStat("Successfully created: \(createdStations.count)")
            updateDatabaseStat("Creation errors: \(creationErrors.count)")
            
            if !creationErrors.isEmpty {
                for error in creationErrors {
                    updateDebugInfo("Creation error: \(error)")
                }
            }
            
            // PHASE 3: Sort and finalize
            await updateLoadingPhase("Finalizing results")
            
            let phase3Start = Date()
            logDebug("🔄 PHASE_3: Sorting and finalizing stations...")
            
            let sortedStations = createdStations.sorted { $0.name < $1.name }
            let phase3Duration = Date().timeIntervalSince(phase3Start)
            
            logDebug("🔄 PHASE_3: Sorting completed")
            logDebug("🔄 PHASE_3: Duration = \(String(format: "%.3f", phase3Duration))s")
            logDebug("🔄 PHASE_3: Final count = \(sortedStations.count)")
            
            // PHASE 4: Update UI
            await updateLoadingPhase("Updating UI")
            
            let phase4Start = Date()
            logDebug("🎨 PHASE_4: Updating UI with final results...")
            
            favorites = sortedStations
            isLoading = false
            loadingPhase = "Complete"
            
            let phase4Duration = Date().timeIntervalSince(phase4Start)
            let totalDuration = Date().timeIntervalSince(startTime!)
            
            logDebug("🎨 PHASE_4: UI update completed")
            logDebug("🎨 PHASE_4: Duration = \(String(format: "%.3f", phase4Duration))s")
            logDebug("🎨 PHASE_4: Total operation duration = \(String(format: "%.3f", totalDuration))s")
            
            updateDebugInfo("✅ Load completed successfully")
            updatePerformanceMetric("UI Update: \(String(format: "%.3f", phase4Duration))s")
            updatePerformanceMetric("🏁 TOTAL TIME: \(String(format: "%.3f", totalDuration))s")
            
            logDebug("✅ LOAD_FAVORITES: Operation completed successfully")
            logDebug("✅ LOAD_FAVORITES: Final favorites count = \(favorites.count)")
            
        } catch {
            await handleLoadError("Unexpected error during load: \(error.localizedDescription)", phase: "Load Operation")
        }
    }
    
    // MARK: - Error Handling
    
    @MainActor
    private func handleLoadError(_ message: String, phase: String) async {
        let totalDuration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        logDebug("❌ ERROR in \(phase): \(message)")
        logDebug("❌ ERROR: Total time before failure = \(String(format: "%.3f", totalDuration))s")
        
        errorMessage = message
        isLoading = false
        loadingPhase = "Error"
        favorites = []
        
        updateDebugInfo("❌ ERROR in \(phase): \(message)")
        updatePerformanceMetric("Failed after \(String(format: "%.3f", totalDuration))s")
    }
    
    // MARK: - Loading Phase Management
    
    @MainActor
    private func updateLoadingPhase(_ phase: String) async {
        let now = Date()
        let phaseDuration = phaseStartTime.map { now.timeIntervalSince($0) } ?? 0
        
        if loadingPhase != "Initializing" {
            logDebug("⏱️ PHASE_COMPLETE: '\(loadingPhase)' took \(String(format: "%.3f", phaseDuration))s")
            updatePerformanceMetric("'\(loadingPhase)': \(String(format: "%.3f", phaseDuration))s")
        }
        
        loadingPhase = phase
        phaseStartTime = now
        
        logDebug("🔄 PHASE_START: '\(phase)' starting at \(now)")
        updateDebugInfo("Phase: \(phase)")
    }
    
    // MARK: - Debug Helpers
    
    private func logDebug(_ message: String) {
        print("🌊 TIDE_FAV_VM: \(message)")
    }
    
    @MainActor
    private func updateDebugInfo(_ info: String) {
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "HH:mm:ss.SSS"
        }.string(from: Date())
        debugInfo.append("[\(timestamp)] \(info)")
        
        // Keep only last 50 debug entries
        if debugInfo.count > 50 {
            debugInfo.removeFirst(debugInfo.count - 50)
        }
    }
    
    @MainActor
    private func updatePerformanceMetric(_ metric: String) {
        performanceMetrics.append(metric)
        
        // Keep only last 20 performance metrics
        if performanceMetrics.count > 20 {
            performanceMetrics.removeFirst(performanceMetrics.count - 20)
        }
    }
    
    @MainActor
    private func updateDatabaseStat(_ stat: String) {
        databaseStats.append(stat)
        
        // Keep only last 15 database stats
        if databaseStats.count > 15 {
            databaseStats.removeFirst(databaseStats.count - 15)
        }
    }
    
    // MARK: - Favorites Management
    
    func removeFavorite(at offsets: IndexSet) {
        logDebug("🗑️ REMOVE_FAVORITE: Starting removal for offsets \(Array(offsets))")
        
        Task {
            for index in offsets {
                guard index < favorites.count else {
                    logDebug("❌ REMOVE_FAVORITE: Index \(index) out of bounds (\(favorites.count))")
                    continue
                }
                
                let station = favorites[index]
                logDebug("🗑️ REMOVE_FAVORITE: Removing station \(station.id) - \(station.name)")
                
                await removeStationFromFavorites(station)
            }
            
            // Reload the favorites list
            logDebug("🔄 REMOVE_FAVORITE: Reloading favorites after removal")
            loadFavorites()
            
            // Sync after removing favorites
            logDebug("☁️ REMOVE_FAVORITE: Triggering sync after removal")
            await performSyncAfterChange()
        }
    }
    
    private func removeStationFromFavorites(_ station: TidalHeightStation) async {
        guard let tideStationService = tideStationService else {
            logDebug("❌ REMOVE_STATION: TideStationService not available")
            return
        }
        
        logDebug("🗑️ REMOVE_STATION: Setting favorite=false for station \(station.id)")
        
        let success = await tideStationService.setTideStationFavorite(id: station.id, isFavorite: false)
        
        if success {
            logDebug("✅ REMOVE_STATION: Successfully removed station \(station.id) from favorites")
        } else {
            logDebug("❌ REMOVE_STATION: Failed to remove station \(station.id) from favorites")
        }
    }
    
    func cleanup() {
        logDebug("🧹 CLEANUP: Starting cleanup process")
        
        loadTask?.cancel()
        cancellables.removeAll()
        
        logDebug("🧹 CLEANUP: Cleanup completed")
    }
    
    // MARK: - Sync Methods
    
    var syncStatusIcon: String {
        if isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if syncErrorMessage != nil {
            return "exclamationmark.triangle"
        } else if lastSyncTime != nil {
            return "checkmark.circle"
        } else {
            return "cloud"
        }
    }
    
    var syncStatusColor: Color {
        if isSyncing {
            return .blue
        } else if syncErrorMessage != nil {
            return .red
        } else if lastSyncTime != nil {
            return .green
        } else {
            return .gray
        }
    }
    
    /// Perform sync on app launch - always runs
    func performAppLaunchSync() async {
        guard !isSyncing else {
            logDebug("🔄 APP_LAUNCH_SYNC: Skipping - sync already in progress")
            return
        }
        
        logDebug("🚀 APP_LAUNCH_SYNC: Starting app launch sync")
        await syncWithCloud()
    }
    
    /// Sync after user makes changes - always runs
    func performSyncAfterChange() async {
        guard !isSyncing else {
            logDebug("🔄 CHANGE_SYNC: Skipping - sync already in progress")
            return
        }
        
        logDebug("🔄 CHANGE_SYNC: Starting sync after user changes")
        await syncWithCloud()
    }
    
    /// Perform full bidirectional sync with Supabase
    func syncWithCloud() async {
        guard !isSyncing else {
            logDebug("🔄 CLOUD_SYNC: Sync already in progress, skipping")
            return
        }
        
        await MainActor.run {
            isSyncing = true
            syncErrorMessage = nil
            syncSuccessMessage = nil
        }
        
        logDebug("🔄 CLOUD_SYNC: Starting tide station sync from TideFavoritesViewModel")
        
        // Use Task to call MainActor methods from async context
        Task { @MainActor in
            updateDebugInfo("Cloud sync started")
        }
        
        let result = await TideStationSyncService.shared.syncTideStationFavorites()
        
        await MainActor.run {
            isSyncing = false
            
            switch result {
            case .success(let stats):
                lastSyncTime = Date()
                syncSuccessMessage = "Sync completed! \(stats.uploaded) uploaded, \(stats.downloaded) downloaded"
                syncErrorMessage = nil
                
                logDebug("✅ CLOUD_SYNC: Sync completed successfully")
                logDebug("✅ CLOUD_SYNC: Stats - \(stats.totalOperations) operations in \(String(format: "%.3f", stats.duration))s")
                
                updateDebugInfo("✅ Sync success: \(stats.uploaded)↑ \(stats.downloaded)↓")
                updatePerformanceMetric("Sync: \(String(format: "%.3f", stats.duration))s")
                
            case .failure(let error):
                syncErrorMessage = "Sync failed: \(error.localizedDescription)"
                syncSuccessMessage = nil
                
                logDebug("❌ CLOUD_SYNC: Sync failed - \(error.localizedDescription)")
                updateDebugInfo("❌ Sync failed: \(error.localizedDescription)")
                
            case .partialSuccess(let stats, let errors):
                lastSyncTime = Date()
                syncSuccessMessage = "Partial sync - \(stats.totalOperations) operations"
                syncErrorMessage = "Some operations failed (\(errors.count) errors)"
                
                logDebug("⚠️ CLOUD_SYNC: Partial sync - \(stats.totalOperations) operations, \(errors.count) errors")
                updateDebugInfo("⚠️ Partial sync: \(errors.count) errors")
            }
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    func apply(_ block: (DateFormatter) -> Void) -> DateFormatter {
        block(self)
        return self
    }
}






