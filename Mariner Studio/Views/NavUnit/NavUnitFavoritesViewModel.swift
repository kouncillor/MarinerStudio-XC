//
//  NavUnitFavoritesViewModel.swift
//  Mariner Studio
//
//  NavUnit Favorites ViewModel - Manages the display and interaction logic for favorite navigation units
//  Handles loading favorites from local database, distance calculations, and favorite status toggling
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

class NavUnitFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [StationWithDistance<NavUnit>] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Properties
    public var navUnitService: NavUnitDatabaseService?
    public var locationService: LocationService?
    public var loadTask: Task<Void, Never>?
    public var cancellables = Set<AnyCancellable>()
    
    // Performance tracking
    private var startTime: Date?
    
    // MARK: - Initialization
    init() {
        logDebug("🎯 INIT: NavUnitFavoritesViewModel created at \(Date())")
        logDebug("🎯 INIT: Thread = \(Thread.current)")
        logDebug("🎯 INIT: Memory address = \(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    deinit {
        logDebug("💀 DEINIT: NavUnitFavoritesViewModel being deallocated")
        loadTask?.cancel()
        cancellables.removeAll()
    }
    
    // Initialize with services using dependency injection
    func initialize(
        navUnitService: NavUnitDatabaseService,
        locationService: LocationService
    ) {
        logDebug("🔧 INITIALIZE: Starting service initialization...")
        logDebug("🔧 INITIALIZE: NavUnitService = \(type(of: navUnitService))")
        logDebug("🔧 INITIALIZE: LocationService = \(type(of: locationService))")
        
        self.navUnitService = navUnitService
        self.locationService = locationService
        
        logDebug("✅ INITIALIZE: All services assigned successfully")
    }
    
    // MARK: - Data Loading
    
    /// Load favorite navigation units from local database
    func loadFavorites() {
        logDebug("📱 LOAD_FAVORITES: Starting load process")
        
        // Cancel any existing load task
        loadTask?.cancel()
        
        // Reset error state
        Task { @MainActor in
            errorMessage = ""
            isLoading = true
        }
        
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
    
    /// Perform the actual loading of favorites
    private func performLoadFavorites() async throws {
        startTime = Date()
        logDebug("⏰ LOAD_START: Beginning favorite nav units load at \(Date())")
        
        guard let navUnitService = navUnitService else {
            throw NSError(domain: "NavUnitFavoritesViewModel", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "NavUnit service not available"])
        }
        
        // Get all nav units (the service will filter for favorites)
        logDebug("📱 DATABASE_CALL: Requesting nav units from database")
        let allNavUnits = try await navUnitService.getNavUnitsAsync()
        
        // Filter for favorites only
        let favoriteNavUnits = allNavUnits.filter { $0.isFavorite }
        logDebug("📱 FILTER_RESULT: Found \(favoriteNavUnits.count) favorite nav units out of \(allNavUnits.count) total")
        
        // Get current location for distance calculation
        let currentLocation = locationService?.currentLocation
        logDebug("📍 LOCATION: Current location = \(currentLocation?.description ?? "nil")")
        
        // Calculate distances and create StationWithDistance objects
        let favoritesWithDistance = favoriteNavUnits.map { navUnit in
            return StationWithDistance<NavUnit>.create(
                station: navUnit,
                userLocation: currentLocation
            )
        }
        
        // Sort by distance (closest first)
        // Break down the special distance value to help compiler
        let noLocationDistance = Double.greatestFiniteMagnitude
        
        let sortedFavorites = favoritesWithDistance.sorted { first, second in
            let firstDistance = first.distanceFromUser
            let secondDistance = second.distanceFromUser
            
            // Both have no location - sort alphabetically
            if firstDistance == noLocationDistance && secondDistance == noLocationDistance {
                return first.station.navUnitName < second.station.navUnitName
            }
            
            // First has no location - put at end
            if firstDistance == noLocationDistance {
                return false
            }
            
            // Second has no location - put at end
            if secondDistance == noLocationDistance {
                return true
            }
            
            // Both have distances - sort by distance
            return firstDistance < secondDistance
        }
        
        let totalDuration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        logDebug("✅ LOAD_COMPLETE: Loaded \(sortedFavorites.count) favorites in \(String(format: "%.3f", totalDuration))s")
        
        // Update UI on main thread
        await MainActor.run {
            self.favorites = sortedFavorites
            self.isLoading = false
            logDebug("✅ UI_UPDATE: Favorites list updated with \(sortedFavorites.count) items")
        }
    }
    
    // MARK: - Favorite Toggle Functionality
    
    /// Toggle favorite status for a navigation unit (called from swipe action)
    func toggleFavorite(for navUnit: NavUnit) {
        logDebug("⭐ TOGGLE_FAVORITE: Starting toggle for nav unit \(navUnit.navUnitId)")
        
        Task {
            do {
                guard let navUnitService = navUnitService else {
                    throw NSError(domain: "NavUnitFavoritesViewModel", code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "NavUnit service not available"])
                }
                
                // Toggle the favorite status in the database
                let newFavoriteStatus = try await navUnitService.toggleFavoriteNavUnitAsync(navUnitId: navUnit.navUnitId)
                logDebug("⭐ TOGGLE_RESULT: New favorite status for \(navUnit.navUnitId) = \(newFavoriteStatus)")
                
                // Since we're on the favorites view, if status becomes false, remove from list
                // If it somehow becomes true, we don't need to add it (it should already be there)
                await MainActor.run {
                    if !newFavoriteStatus {
                        // Remove from favorites list
                        favorites.removeAll { $0.station.navUnitId == navUnit.navUnitId }
                        logDebug("🗑️ REMOVE_FROM_LIST: Removed \(navUnit.navUnitId) from favorites list")
                    }
                }
                
            } catch {
                logDebug("❌ TOGGLE_ERROR: Failed to toggle favorite for \(navUnit.navUnitId): \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Failed to update favorite status: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Remove favorite using IndexSet (for swipe-to-delete functionality)
    func removeFavorite(at offsets: IndexSet) {
        logDebug("🗑️ REMOVE_FAVORITE: Starting removal for offsets \(Array(offsets))")
        
        for index in offsets {
            guard index < favorites.count else {
                logDebug("❌ REMOVE_FAVORITE: Index \(index) out of bounds (\(favorites.count))")
                continue
            }
            
            let navUnit = favorites[index].station
            logDebug("🗑️ REMOVE_FAVORITE: Toggling favorite off for \(navUnit.navUnitId) - \(navUnit.navUnitName)")
            
            toggleFavorite(for: navUnit)
        }
    }
    
    // MARK: - Error Handling
    
    @MainActor
    private func handleLoadError(_ message: String) async {
        let totalDuration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        logDebug("❌ ERROR: \(message)")
        logDebug("❌ ERROR: Total time before failure = \(String(format: "%.3f", totalDuration))s")
        
        errorMessage = message
        isLoading = false
        favorites = []
    }
    
    // MARK: - Utility Methods
    
    /// Refresh favorites (can be called when returning to view or after changes)
    func refreshFavorites() {
        logDebug("🔄 REFRESH: Refreshing favorites list")
        loadFavorites()
    }
    
    /// Cleanup resources
    func cleanup() {
        logDebug("🧹 CLEANUP: Starting cleanup process")
        
        loadTask?.cancel()
        cancellables.removeAll()
        
        logDebug("🧹 CLEANUP: Cleanup completed")
    }
    
    // MARK: - Debug Helpers
    
    private func logDebug(_ message: String) {
        print("🚢 NAV_UNIT_FAV_VM: \(message)")
    }
}
