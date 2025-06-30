////
////  NavUnitFavoritesViewModel.swift
////  Mariner Studio
////
////  NavUnit Favorites ViewModel - Manages the display and interaction logic for favorite navigation units
////  Handles loading favorites from local database, distance calculations, and favorite status toggling
////
//
//import Foundation
//import SwiftUI
//import Combine
//import CoreLocation
//
//class NavUnitFavoritesViewModel: ObservableObject {
//    // MARK: - Published Properties
//    @Published var favorites: [StationWithDistance<NavUnit>] = []
//    @Published var isLoading = false
//    @Published var errorMessage = ""
//    
//    // MARK: - Properties
//    public var navUnitService: NavUnitDatabaseService?
//    public var locationService: LocationService?
//    public var loadTask: Task<Void, Never>?
//    public var cancellables = Set<AnyCancellable>()
//    
//    // Performance tracking
//    private var startTime: Date?
//    
//    // MARK: - Initialization
//    init() {
//        logDebug("🎯 INIT: NavUnitFavoritesViewModel created at \(Date())")
//        logDebug("🎯 INIT: Thread = \(Thread.current)")
//        logDebug("🎯 INIT: Memory address = \(Unmanaged.passUnretained(self).toOpaque())")
//    }
//    
//    deinit {
//        logDebug("💀 DEINIT: NavUnitFavoritesViewModel being deallocated")
//        loadTask?.cancel()
//        cancellables.removeAll()
//    }
//    
//    // Initialize with services using dependency injection
//    func initialize(
//        navUnitService: NavUnitDatabaseService,
//        locationService: LocationService
//    ) {
//        logDebug("🔧 INITIALIZE: Starting service initialization...")
//        logDebug("🔧 INITIALIZE: NavUnitService = \(type(of: navUnitService))")
//        logDebug("🔧 INITIALIZE: LocationService = \(type(of: locationService))")
//        
//        self.navUnitService = navUnitService
//        self.locationService = locationService
//        
//        logDebug("✅ INITIALIZE: All services assigned successfully")
//    }
//    
//    // MARK: - Data Loading
//    
//    /// Load favorite navigation units from local database
//    func loadFavorites() {
//        logDebug("📱 LOAD_FAVORITES: Starting load process")
//        
//        // Cancel any existing load task
//        loadTask?.cancel()
//        
//        // Reset error state
//        Task { @MainActor in
//            errorMessage = ""
//            isLoading = true
//        }
//        
//        loadTask = Task {
//            do {
//                try await performLoadFavorites()
//            } catch {
//                if !Task.isCancelled {
//                    await handleLoadError("Failed to load favorites: \(error.localizedDescription)")
//                }
//            }
//        }
//    }
//    
//    /// Perform the actual loading of favorites
//    private func performLoadFavorites() async throws {
//        startTime = Date()
//        logDebug("⏰ LOAD_START: Beginning favorite nav units load at \(Date())")
//        
//        guard let navUnitService = navUnitService else {
//            throw NSError(domain: "NavUnitFavoritesViewModel", code: 1,
//                         userInfo: [NSLocalizedDescriptionKey: "NavUnit service not available"])
//        }
//        
//        // Get all nav units (the service will filter for favorites)
//        logDebug("📱 DATABASE_CALL: Requesting nav units from database")
//        let allNavUnits = try await navUnitService.getNavUnitsAsync()
//        
//        // Filter for favorites only
//        let favoriteNavUnits = allNavUnits.filter { $0.isFavorite }
//        logDebug("📱 FILTER_RESULT: Found \(favoriteNavUnits.count) favorite nav units out of \(allNavUnits.count) total")
//        
//        // Get current location for distance calculation
//        let currentLocation = locationService?.currentLocation
//        logDebug("📍 LOCATION: Current location = \(currentLocation?.description ?? "nil")")
//        
//        // Calculate distances and create StationWithDistance objects
//        let favoritesWithDistance = favoriteNavUnits.map { navUnit in
//            return StationWithDistance<NavUnit>.create(
//                station: navUnit,
//                userLocation: currentLocation
//            )
//        }
//        
//        // Sort by distance (closest first)
//        // Break down the special distance value to help compiler
//        let noLocationDistance = Double.greatestFiniteMagnitude
//        
//        let sortedFavorites = favoritesWithDistance.sorted { first, second in
//            let firstDistance = first.distanceFromUser
//            let secondDistance = second.distanceFromUser
//            
//            // Both have no location - sort alphabetically
//            if firstDistance == noLocationDistance && secondDistance == noLocationDistance {
//                return first.station.navUnitName < second.station.navUnitName
//            }
//            
//            // First has no location - put at end
//            if firstDistance == noLocationDistance {
//                return false
//            }
//            
//            // Second has no location - put at end
//            if secondDistance == noLocationDistance {
//                return true
//            }
//            
//            // Both have distances - sort by distance
//            return firstDistance < secondDistance
//        }
//        
//        let totalDuration = startTime.map { Date().timeIntervalSince($0) } ?? 0
//        logDebug("✅ LOAD_COMPLETE: Loaded \(sortedFavorites.count) favorites in \(String(format: "%.3f", totalDuration))s")
//        
//        // Update UI on main thread
//        await MainActor.run {
//            self.favorites = sortedFavorites
//            self.isLoading = false
//            logDebug("✅ UI_UPDATE: Favorites list updated with \(sortedFavorites.count) items")
//        }
//    }
//    
//    // MARK: - Favorite Toggle Functionality
//    
//    /// Toggle favorite status for a navigation unit (called from swipe action)
//    func toggleFavorite(for navUnit: NavUnit) {
//        logDebug("⭐ TOGGLE_FAVORITE: Starting toggle for nav unit \(navUnit.navUnitId)")
//        
//        Task {
//            do {
//                guard let navUnitService = navUnitService else {
//                    throw NSError(domain: "NavUnitFavoritesViewModel", code: 1,
//                                 userInfo: [NSLocalizedDescriptionKey: "NavUnit service not available"])
//                }
//                
//                // Toggle the favorite status in the database
//                let newFavoriteStatus = try await navUnitService.toggleFavoriteNavUnitAsync(navUnitId: navUnit.navUnitId)
//                logDebug("⭐ TOGGLE_RESULT: New favorite status for \(navUnit.navUnitId) = \(newFavoriteStatus)")
//                
//                // Since we're on the favorites view, if status becomes false, remove from list
//                // If it somehow becomes true, we don't need to add it (it should already be there)
//                await MainActor.run {
//                    if !newFavoriteStatus {
//                        // Remove from favorites list
//                        favorites.removeAll { $0.station.navUnitId == navUnit.navUnitId }
//                        logDebug("🗑️ REMOVE_FROM_LIST: Removed \(navUnit.navUnitId) from favorites list")
//                    }
//                }
//                
//            } catch {
//                logDebug("❌ TOGGLE_ERROR: Failed to toggle favorite for \(navUnit.navUnitId): \(error.localizedDescription)")
//                await MainActor.run {
//                    errorMessage = "Failed to update favorite status: \(error.localizedDescription)"
//                }
//            }
//        }
//    }
//    
//    /// Remove favorite using IndexSet (for swipe-to-delete functionality)
//    func removeFavorite(at offsets: IndexSet) {
//        logDebug("🗑️ REMOVE_FAVORITE: Starting removal for offsets \(Array(offsets))")
//        
//        for index in offsets {
//            guard index < favorites.count else {
//                logDebug("❌ REMOVE_FAVORITE: Index \(index) out of bounds (\(favorites.count))")
//                continue
//            }
//            
//            let navUnit = favorites[index].station
//            logDebug("🗑️ REMOVE_FAVORITE: Toggling favorite off for \(navUnit.navUnitId) - \(navUnit.navUnitName)")
//            
//            toggleFavorite(for: navUnit)
//        }
//    }
//    
//    // MARK: - Error Handling
//    
//    @MainActor
//    private func handleLoadError(_ message: String) async {
//        let totalDuration = startTime.map { Date().timeIntervalSince($0) } ?? 0
//        
//        logDebug("❌ ERROR: \(message)")
//        logDebug("❌ ERROR: Total time before failure = \(String(format: "%.3f", totalDuration))s")
//        
//        errorMessage = message
//        isLoading = false
//        favorites = []
//    }
//    
//    // MARK: - Utility Methods
//    
//    /// Refresh favorites (can be called when returning to view or after changes)
//    func refreshFavorites() {
//        logDebug("🔄 REFRESH: Refreshing favorites list")
//        loadFavorites()
//    }
//    
//    /// Cleanup resources
//    func cleanup() {
//        logDebug("🧹 CLEANUP: Starting cleanup process")
//        
//        loadTask?.cancel()
//        cancellables.removeAll()
//        
//        logDebug("🧹 CLEANUP: Cleanup completed")
//    }
//    
//    // MARK: - Debug Helpers
//    
//    private func logDebug(_ message: String) {
//        print("🚢 NAV_UNIT_FAV_VM: \(message)")
//    }
//}




//
//  NavUnitFavoritesViewModel.swift
//  Mariner Studio
//
//  NavUnit Favorites ViewModel with comprehensive sync integration
//  Manages the display and interaction logic for favorite navigation units
//  Handles loading favorites from local database, distance calculations, sync operations, and favorite status toggling
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

@MainActor
class NavUnitFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [StationWithDistance<NavUnit>] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // NEW: Sync-related published properties
    @Published var isSyncing = false
    @Published var syncErrorMessage: String?
    @Published var syncSuccessMessage: String?
    @Published var lastSyncTime: Date?
    
    // MARK: - Properties
    private var navUnitService: NavUnitDatabaseService?
    private var locationService: LocationService?
    private var syncService: NavUnitSyncService?
    private var loadTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // Performance tracking
    private var startTime: Date?
    
    // MARK: - Initialization
    init() {
        logDebug("🎯 NavUnitFavoritesViewModel: Created at \(Date())")
        logDebug("🎯 NavUnitFavoritesViewModel: Thread = \(Thread.current)")
        logDebug("🎯 NavUnitFavoritesViewModel: Memory address = \(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    deinit {
        logDebug("💀 NavUnitFavoritesViewModel: Being deallocated")
        cleanup()
    }
    
    // MARK: - Service Initialization
    
    /// Initialize with services using dependency injection
    func initialize(
        navUnitService: NavUnitDatabaseService,
        locationService: LocationService,
        syncService: NavUnitSyncService
    ) {
        logDebug("🔧 NavUnitFavoritesViewModel: Starting service initialization...")
        logDebug("🔧 NavUnitFavoritesViewModel: NavUnitService = \(type(of: navUnitService))")
        logDebug("🔧 NavUnitFavoritesViewModel: LocationService = \(type(of: locationService))")
        logDebug("🔧 NavUnitFavoritesViewModel: SyncService = \(type(of: syncService))")
        
        self.navUnitService = navUnitService
        self.locationService = locationService
        self.syncService = syncService
        
        // Observe sync service state changes
        setupSyncObservation()
        
        logDebug("✅ NavUnitFavoritesViewModel: All services assigned successfully")
    }
    
    // MARK: - Sync Observation
    
    /// Set up observation of sync service state changes
    private func setupSyncObservation() {
        guard let syncService = syncService else { return }
        
        // Observe isSyncing state from the sync service
        syncService.$isSyncing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSyncing, on: self)
            .store(in: &cancellables)
        
        logDebug("🔗 NavUnitFavoritesViewModel: Sync observation configured")
    }
    
    // MARK: - Data Loading
    
    /// Load favorite navigation units from local database
    func loadFavorites() {
        logDebug("📱 NavUnitFavoritesViewModel: Starting load process")
        
        // Cancel any existing load task
        loadTask?.cancel()
        
        // Reset error state
        errorMessage = ""
        isLoading = true
        
        loadTask = Task {
            do {
                try await performLoadFavorites()
            } catch {
                if !Task.isCancelled {
                    await handleLoadError("Failed to load favorites: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Refresh favorites (used by pull-to-refresh and manual refresh)
    func refreshFavorites() async {
        logDebug("🔄 NavUnitFavoritesViewModel: Refreshing favorites")
        await performLoadFavorites()
    }
    
    /// Perform the actual loading of favorites
    private func performLoadFavorites() async throws {
        startTime = Date()
        logDebug("⏰ NavUnitFavoritesViewModel: Beginning favorite nav units load at \(Date())")
        
        guard let navUnitService = navUnitService else {
            throw NSError(domain: "NavUnitFavoritesViewModel", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "NavUnit service not available"])
        }
        
        // Get all favorite nav units from database
        logDebug("📱 NavUnitFavoritesViewModel: Requesting favorite nav units from database")
        let favoriteNavUnits = try await navUnitService.getFavoriteNavUnitsAsync()
        
        logDebug("📱 NavUnitFavoritesViewModel: Found \(favoriteNavUnits.count) favorite nav units")
        
        // Get current location for distance calculation
        let currentLocation = locationService?.currentLocation
        logDebug("📍 NavUnitFavoritesViewModel: Current location = \(currentLocation?.description ?? "unknown")")
        
        // Create StationWithDistance objects
        let favoritesWithDistance = favoriteNavUnits.map { navUnit in
            StationWithDistance<NavUnit>.create(
                station: navUnit,
                userLocation: currentLocation
            )
        }
        
        // Sort by distance (closest first)
        let sortedFavorites = favoritesWithDistance.sorted { first, second in
            let noLocationDistance = Double.greatestFiniteMagnitude
            
            // Handle cases where location is unknown
            if first.distanceFromUser == noLocationDistance && second.distanceFromUser == noLocationDistance {
                return first.station.navUnitName < second.station.navUnitName
            }
            if first.distanceFromUser == noLocationDistance {
                return false
            }
            if second.distanceFromUser == noLocationDistance {
                return true
            }
            
            return first.distanceFromUser < second.distanceFromUser
        }
        
        // Update UI on main thread
        favorites = sortedFavorites
        isLoading = false
        
        // Performance logging
        if let startTime = startTime {
            let duration = Date().timeIntervalSince(startTime)
            logDebug("✅ NavUnitFavoritesViewModel: Load completed in \(String(format: "%.3f", duration))s")
            logDebug("📊 NavUnitFavoritesViewModel: Performance - \(sortedFavorites.count) favorites processed")
        }
    }
    
    // MARK: - Sync Operations
    
    /// Perform manual sync triggered by user
    func performManualSync() async {
        logDebug("🔄 NavUnitFavoritesViewModel: Manual sync triggered")
        
        guard let syncService = syncService else {
            logDebug("❌ NavUnitFavoritesViewModel: Sync service not available")
            syncErrorMessage = "Sync service not available"
            return
        }
        
        // Clear previous sync messages
        clearSyncMessages()
        
        // Perform the sync
        let success = await syncService.performFullSync()
        
        if success {
            logDebug("✅ NavUnitFavoritesViewModel: Manual sync completed successfully")
            syncSuccessMessage = "Sync completed successfully"
            lastSyncTime = Date()
            
            // Reload favorites after successful sync
            await refreshFavorites()
        } else {
            logDebug("❌ NavUnitFavoritesViewModel: Manual sync failed")
            syncErrorMessage = "Sync failed. Please try again."
        }
    }
    
    /// Clear sync status messages
    func clearSyncMessages() {
        syncErrorMessage = nil
        syncSuccessMessage = nil
    }
    
    // MARK: - Favorite Management
    
    /// Remove favorite at specified indices (used by swipe-to-delete)
    func removeFavorite(at offsets: IndexSet) async {
        logDebug("🗑️ NavUnitFavoritesViewModel: Removing favorites at offsets: \(Array(offsets))")
        
        guard let navUnitService = navUnitService else {
            logDebug("❌ NavUnitFavoritesViewModel: NavUnit service not available for favorite removal")
            return
        }
        
        for index in offsets {
            let navUnit = favorites[index].station
            logDebug("🗑️ NavUnitFavoritesViewModel: Removing favorite: \(navUnit.navUnitName)")
            
            do {
                // Toggle favorite status in database (will set to false)
                _ = try await navUnitService.toggleFavoriteNavUnitAsync(navUnitId: navUnit.navUnitId)
                logDebug("✅ NavUnitFavoritesViewModel: Successfully removed favorite: \(navUnit.navUnitName)")
            } catch {
                logDebug("❌ NavUnitFavoritesViewModel: Error removing favorite \(navUnit.navUnitName): \(error.localizedDescription)")
                errorMessage = "Failed to remove favorite: \(error.localizedDescription)"
            }
        }
        
        // Refresh the list after removal
        await refreshFavorites()
    }
    
    // MARK: - Error Handling
    
    /// Handle load errors
    private func handleLoadError(_ message: String) async {
        logDebug("❌ NavUnitFavoritesViewModel: Load error - \(message)")
        errorMessage = message
        isLoading = false
    }
    
    // MARK: - Cleanup
    
    /// Cleanup resources
    func cleanup() {
        logDebug("🧹 NavUnitFavoritesViewModel: Cleaning up resources")
        loadTask?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Debug Logging
    
    /// Debug logging helper
    private func logDebug(_ message: String) {
        print(message)
    }
}
