
//
//  NavUnitFavoritesViewModel.swift
//  Mariner Studio
//
//  Enhanced with NavUnitSyncService integration
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

class NavUnitFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [NavUnit] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Sync-related Published Properties
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncErrorMessage: String?
    @Published var syncSuccessMessage: String?
    
    // MARK: - Private Properties
    private var navUnitService: NavUnitDatabaseService?
    private var locationService: LocationService?
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    func initialize(
        navUnitService: NavUnitDatabaseService?,
        locationService: LocationService?
    ) {
        print("🔧 NAV_UNIT_FAVORITES_VM: Initializing with services")
        self.navUnitService = navUnitService
        self.locationService = locationService
        
        print("✅ NAV_UNIT_FAVORITES_VM: Services initialized successfully")
    }
    
    deinit {
        print("💀 NAV_UNIT_FAVORITES_VM: Cleaning up resources")
        loadTask?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Data Loading Methods
    
    func loadFavorites() {
        print("📱 NAV_UNIT_FAVORITES_VM: Starting loadFavorites")
        
        // Cancel any existing task
        loadTask?.cancel()
        
        // Create a new task
        loadTask = Task {
            await MainActor.run {
                isLoading = true
                errorMessage = ""
            }
            
            do {
                if let navUnitService = navUnitService {
                    print("📱 NAV_UNIT_FAVORITES_VM: Getting all nav units from database")
                    let allNavUnits = try await navUnitService.getNavUnitsAsync()
                    
                    // Filter to only include favorites
                    let favoriteNavUnits = allNavUnits.filter { $0.isFavorite }
                    print("📱 NAV_UNIT_FAVORITES_VM: Found \(favoriteNavUnits.count) favorite nav units")
                    
                    if !Task.isCancelled {
                        await MainActor.run {
                            favorites = favoriteNavUnits
                            isLoading = false
                        }
                    }
                } else {
                    print("❌ NAV_UNIT_FAVORITES_VM: NavUnitService not available")
                    if !Task.isCancelled {
                        await MainActor.run {
                            errorMessage = "Service unavailable"
                            isLoading = false
                        }
                    }
                }
            } catch {
                print("❌ NAV_UNIT_FAVORITES_VM: Error loading favorites: \(error.localizedDescription)")
                if !Task.isCancelled {
                    await MainActor.run {
                        errorMessage = "Failed to load favorites: \(error.localizedDescription)"
                        isLoading = false
                    }
                }
            }
        }
    }
    
    func removeFavorite(at indexSet: IndexSet) {
        print("🗑️ NAV_UNIT_FAVORITES_VM: Removing favorite(s)")
        
        Task {
            for index in indexSet {
                if index < favorites.count {
                    let favorite = favorites[index]
                    print("🗑️ NAV_UNIT_FAVORITES_VM: Removing \(favorite.navUnitId) - \(favorite.navUnitName)")
                    
                    if let navUnitService = navUnitService {
                        // Toggle favorite status (which will remove it since it's currently a favorite)
                        _ = try? await navUnitService.toggleFavoriteNavUnitAsync(navUnitId: favorite.navUnitId)
                        
                        print("🗑️ NAV_UNIT_FAVORITES_VM: Toggled favorite status for \(favorite.navUnitId)")
                    }
                }
            }
            
            // Reload favorites to reflect the changes
            print("🔄 NAV_UNIT_FAVORITES_VM: Reloading favorites after removal")
            loadFavorites()
            
            // Sync after removing favorites
            print("☁️ NAV_UNIT_FAVORITES_VM: Triggering sync after favorite removal")
            await performSyncAfterChange()
        }
    }
    
    func toggleNavUnitFavorite(navUnitId: String) async {
        print("⭐ NAV_UNIT_FAVORITES_VM: Toggling favorite for \(navUnitId)")
        
        if let navUnitService = navUnitService {
            _ = try? await navUnitService.toggleFavoriteNavUnitAsync(navUnitId: navUnitId)
            print("⭐ NAV_UNIT_FAVORITES_VM: Toggle completed for \(navUnitId)")
            
            loadFavorites()
            
            // Sync after toggle
            await performSyncAfterChange()
        }
    }
    
    func cleanup() {
        print("🧹 NAV_UNIT_FAVORITES_VM: Starting cleanup")
        loadTask?.cancel()
        cancellables.removeAll()
        print("🧹 NAV_UNIT_FAVORITES_VM: Cleanup completed")
    }
    
    // MARK: - Sync Methods
    
    /// Perform sync on app launch/view appear - always runs
    func performAppLaunchSync() async {
        guard !isSyncing else {
            print("🔄 NAV_UNIT_APP_LAUNCH_SYNC: Skipping - sync already in progress")
            return
        }
        
        print("🚀 NAV_UNIT_APP_LAUNCH_SYNC: Starting app launch sync")
        await syncWithCloud()
    }
    
    /// Sync after user makes changes - always runs
    func performSyncAfterChange() async {
        guard !isSyncing else {
            print("🔄 NAV_UNIT_CHANGE_SYNC: Skipping - sync already in progress")
            return
        }
        
        print("🔄 NAV_UNIT_CHANGE_SYNC: Starting sync after user changes")
        await syncWithCloud()
    }
    
    /// Perform full bidirectional sync with Supabase
    func syncWithCloud() async {
        guard !isSyncing else {
            print("🔄 NAV_UNIT_CLOUD_SYNC: Sync already in progress, skipping")
            return
        }
        
        await MainActor.run {
            isSyncing = true
            syncErrorMessage = nil
            syncSuccessMessage = nil
        }
        
        print("🔄 NAV_UNIT_CLOUD_SYNC: Starting nav unit sync from NavUnitFavoritesViewModel")
        
        let result = await NavUnitSyncService.shared.syncNavUnitFavorites()
        
        await MainActor.run {
            isSyncing = false
            
            switch result {
            case .success(let stats):
                lastSyncTime = Date()
                syncSuccessMessage = "Sync completed! \(stats.uploaded) uploaded, \(stats.downloaded) downloaded"
                syncErrorMessage = nil
                
                print("✅ NAV_UNIT_CLOUD_SYNC: Sync completed successfully")
                print("✅ NAV_UNIT_CLOUD_SYNC: Stats - \(stats.totalOperations) operations in \(String(format: "%.3f", stats.duration))s")
                
                // Reload favorites after successful sync to show any new items
                loadFavorites()
                
            case .failure(let error):
                syncErrorMessage = "Sync failed: \(error.localizedDescription)"
                syncSuccessMessage = nil
                
                print("❌ NAV_UNIT_CLOUD_SYNC: Sync failed - \(error.localizedDescription)")
                
            case .partialSuccess(let stats, let errors):
                lastSyncTime = Date()
                syncSuccessMessage = "Partial sync - \(stats.totalOperations) operations"
                syncErrorMessage = "Some operations failed (\(errors.count) errors)"
                
                print("⚠️ NAV_UNIT_CLOUD_SYNC: Partial sync - \(stats.totalOperations) operations, \(errors.count) errors")
                
                // Still reload favorites after partial sync
                loadFavorites()
            }
        }
    }
    
    // MARK: - Sync Status Properties
    
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
    
    var syncStatusText: String {
        if isSyncing {
            return "Syncing..."
        } else if let errorMessage = syncErrorMessage {
            return "Error: \(errorMessage)"
        } else if let lastSync = lastSyncTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Last sync: \(formatter.string(from: lastSync))"
        } else {
            return "Never synced"
        }
    }
    
    var canSync: Bool {
        return !isSyncing
    }
    
    // MARK: - Utility Methods
    
    /// Format sync success message for auto-dismiss
    var formattedSyncSuccessMessage: String? {
        guard let message = syncSuccessMessage else { return nil }
        return message
    }
    
    /// Clear sync messages (useful for UI)
    func clearSyncMessages() {
        Task { @MainActor in
            syncSuccessMessage = nil
            syncErrorMessage = nil
        }
    }
    
    /// Manual sync trigger (for UI buttons)
    func manualSync() async {
        print("👆 NAV_UNIT_MANUAL_SYNC: Manual sync triggered by user")
        await syncWithCloud()
    }
    
    /// Check if sync service is available
    func checkSyncAvailability() async -> Bool {
        let canSync = await NavUnitSyncService.shared.canSync()
        print("🔍 NAV_UNIT_SYNC_CHECK: Sync availability = \(canSync)")
        return canSync
    }
}
