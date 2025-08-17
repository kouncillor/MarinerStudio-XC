//
//  NavUnitFavoritesViewModel.swift
//  Mariner Studio
//
//  NavUnit Favorites ViewModel migrated to Core Data + CloudKit
//  Manages the display and interaction logic for favorite navigation units
//  Uses CoreDataManager for simple, synchronous operations with automatic CloudKit sync
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

    // MARK: - Properties
    private var coreDataManager: CoreDataManager
    private var navUnitService: NavUnitDatabaseService?
    private var locationService: LocationService?
    private var loadTask: Task<Void, Never>?

    // Performance tracking
    private var startTime: Date?

    // MARK: - Initialization
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        DebugLogger.shared.log("🎯 NAVUNIT_FAVORITES_VM: Initialized with CoreDataManager", category: "NAVUNIT_FAVORITES")
    }

    deinit {
        DebugLogger.shared.log("💀 NAVUNIT_FAVORITES_VM: Being deallocated", category: "NAVUNIT_FAVORITES")
        loadTask?.cancel()
    }

    // MARK: - Service Initialization

    /// Initialize with services using dependency injection
    func initialize(
        navUnitService: NavUnitDatabaseService,
        locationService: LocationService
    ) {
        DebugLogger.shared.log("🔧 NAVUNIT_FAVORITES_VM: Initializing services", category: "NAVUNIT_FAVORITES")
        
        self.navUnitService = navUnitService
        self.locationService = locationService
        
        DebugLogger.shared.log("✅ NAVUNIT_FAVORITES_VM: Services initialized", category: "NAVUNIT_FAVORITES")
    }

    // MARK: - Data Loading

    /// Load favorite navigation units from Core Data
    func loadFavorites() {
        DebugLogger.shared.log("📱 NAVUNIT_FAVORITES_VM: Starting favorites load", category: "NAVUNIT_FAVORITES")

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
        DebugLogger.shared.log("🔄 NAVUNIT_FAVORITES_VM: Refreshing favorites", category: "NAVUNIT_FAVORITES")
        do {
            try await performLoadFavorites()
        } catch {
            await handleLoadError("Failed to refresh favorites: \(error.localizedDescription)")
        }
    }

    /// Perform the actual loading of favorites
    private func performLoadFavorites() async throws {
        startTime = Date()
        DebugLogger.shared.log("⏰ NAVUNIT_FAVORITES_VM: Starting load operation", category: "NAVUNIT_FAVORITES")

        // Get Core Data favorites
        let coreDataFavorites = coreDataManager.getNavUnitFavorites()
        DebugLogger.shared.log("📥 NAVUNIT_FAVORITES_VM: Found \(coreDataFavorites.count) CoreData favorites", category: "NAVUNIT_FAVORITES")

        // Convert to NavUnit objects using the nav unit service
        guard let navUnitService = navUnitService else {
            throw NSError(domain: "NavUnitFavoritesViewModel", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "NavUnit service not available"])
        }

        var favoriteNavUnits: [NavUnit] = []
        
        for favorite in coreDataFavorites {
            do {
                let navUnit = try await navUnitService.getNavUnitByIdAsync(favorite.navUnitId)
                favoriteNavUnits.append(navUnit)
            } catch {
                DebugLogger.shared.log("⚠️ NAVUNIT_FAVORITES_VM: Could not load NavUnit \(favorite.navUnitId): \(error)", category: "NAVUNIT_FAVORITES")
                // Skip this favorite if we can't load the nav unit details
                continue
            }
        }

        DebugLogger.shared.log("📱 NAVUNIT_FAVORITES_VM: Loaded \(favoriteNavUnits.count) nav unit details", category: "NAVUNIT_FAVORITES")

        // Get current location for distance calculation
        let currentLocation = locationService?.currentLocation
        DebugLogger.shared.log("📍 NAVUNIT_FAVORITES_VM: Current location available: \(currentLocation != nil)", category: "NAVUNIT_FAVORITES")

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
            DebugLogger.shared.log("✅ NAVUNIT_FAVORITES_VM: Load completed in \(String(format: "%.3f", duration))s", category: "NAVUNIT_FAVORITES")
        }
    }

    // MARK: - Favorite Management

    /// Remove favorite at specified indices (used by swipe-to-delete)
    func removeFavorite(at offsets: IndexSet) async {
        DebugLogger.shared.log("🗑️ NAVUNIT_FAVORITES_VM: Removing favorites at offsets: \(Array(offsets))", category: "NAVUNIT_FAVORITES")

        for index in offsets {
            let navUnit = favorites[index].station
            DebugLogger.shared.log("🗑️ NAVUNIT_FAVORITES_VM: Removing favorite: \(navUnit.navUnitName)", category: "NAVUNIT_FAVORITES")

            // Remove from Core Data
            coreDataManager.removeNavUnitFavorite(navUnitId: navUnit.navUnitId)
            DebugLogger.shared.log("✅ NAVUNIT_FAVORITES_VM: Removed from CoreData: \(navUnit.navUnitName)", category: "NAVUNIT_FAVORITES")
        }

        // Refresh the list after removal
        await refreshFavorites()
    }

    // MARK: - Error Handling

    /// Handle load errors
    private func handleLoadError(_ message: String) async {
        DebugLogger.shared.log("❌ NAVUNIT_FAVORITES_VM: Load error - \(message)", category: "NAVUNIT_FAVORITES")
        errorMessage = message
        isLoading = false
    }

    // MARK: - Cleanup

    /// Cleanup resources (for SwiftUI calls)
    func cleanup() {
        DebugLogger.shared.log("🧹 NAVUNIT_FAVORITES_VM: Cleaning up resources", category: "NAVUNIT_FAVORITES")
        loadTask?.cancel()
    }
}
