
//
//  NavUnitFavoritesViewModel.swift
//  Mariner Studio
//
//  Complete implementation with real NavUnitSyncService integration
//

import Foundation
import SwiftUI
import Combine

class NavUnitFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [NavUnitFavoriteRecord] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Sync-related Published Properties
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncErrorMessage: String?
    @Published var syncSuccessMessage: String?
    
    // MARK: - Private Properties
    private var navUnitService: NavUnitDatabaseService?
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    func initialize(
        navUnitService: NavUnitDatabaseService?,
        locationService: LocationService? // Keep for compatibility but don't use
    ) {
        print("🔧 NAV_UNIT_FAVORITES_VM: Initializing with services")
        self.navUnitService = navUnitService
        print("✅ NAV_UNIT_FAVORITES_VM: Services initialized successfully")
    }
    
    deinit {
        print("💀 NAV_UNIT_FAVORITES_VM: Cleaning up resources")
        loadTask?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Data Loading Methods
    
    func loadFavorites() {
        print("📱 NAV_UNIT_FAVORITES_VM: Starting simple loadFavorites")
        
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
                    print("📱 NAV_UNIT_FAVORITES_VM: Getting simple favorites from NavUnitFavorites table")
                    let favoriteRecords = try await navUnitService.getSimpleFavoritesForDisplay()
                    
                    print("📱 NAV_UNIT_FAVORITES_VM: Found \(favoriteRecords.count) favorite records")
                    
                    if !Task.isCancelled {
                        await MainActor.run {
                            favorites = favoriteRecords
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
                    print("🗑️ NAV_UNIT_FAVORITES_VM: Removing \(favorite.navUnitId) - \(favorite.navUnitName ?? "Unknown")")
                    
                    if let navUnitService = navUnitService {
                        // Set favorite to false (which will remove it from our display)
                        _ = try? await navUnitService.setNavUnitFavorite(
                            navUnitId: favorite.navUnitId,
                            isFavorite: false,
                            navUnitName: favorite.navUnitName,
                            latitude: favorite.latitude,
                            longitude: favorite.longitude,
                            facilityType: favorite.facilityType
                        )
                        
                        // Reload the list
                        await MainActor.run {
                            loadFavorites()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Sync Methods (REAL IMPLEMENTATION)
    
    /// Manual sync triggered by user tapping sync button
    func manualSync() async {
        guard !isSyncing else {
            print("🔄 NAV_UNIT_FAVORITES_VM: Manual sync already in progress, skipping")
            return
        }
        
        print("🔄 NAV_UNIT_FAVORITES_VM: Manual sync triggered")
        
        await MainActor.run {
            isSyncing = true
            syncErrorMessage = nil
            syncSuccessMessage = nil
        }
        
        let result = await NavUnitSyncService.shared.syncNavUnitFavorites()
        
        await MainActor.run {
            isSyncing = false
            
            switch result {
            case .success(let stats):
                lastSyncTime = Date()
                syncSuccessMessage = "Sync completed! \(stats.uploaded) uploaded, \(stats.downloaded) downloaded"
                syncErrorMessage = nil
                
                print("✅ NAV_UNIT_FAVORITES_VM: Sync completed successfully")
                print("✅ NAV_UNIT_SYNC_STATS: \(stats.totalOperations) operations in \(String(format: "%.3f", stats.duration))s")
                print("✅ NAV_UNIT_SYNC_STATS: Uploaded: \(stats.uploaded), Downloaded: \(stats.downloaded), Conflicts: \(stats.conflictsResolved)")
                
            case .failure(let error):
                syncErrorMessage = "Sync failed: \(error.localizedDescription)"
                syncSuccessMessage = nil
                
                print("❌ NAV_UNIT_FAVORITES_VM: Sync failed - \(error.localizedDescription)")
                
            case .partialSuccess(let stats, let errors):
                lastSyncTime = Date()
                syncSuccessMessage = "Partial sync - \(stats.totalOperations) operations"
                syncErrorMessage = "Some operations failed (\(errors.count) errors)"
                
                print("⚠️ NAV_UNIT_FAVORITES_VM: Partial sync - \(stats.totalOperations) operations, \(errors.count) errors")
                for (index, error) in errors.enumerated() {
                    print("⚠️ NAV_UNIT_FAVORITES_VM: Sync error [\(index)]: \(error.localizedDescription)")
                }
            }
            
            // Reload favorites after sync to show any changes
            loadFavorites()
        }
    }
    
    /// Perform sync on app launch
    func performAppLaunchSync() async {
        guard !isSyncing else {
            print("🔄 NAV_UNIT_FAVORITES_VM: App launch sync skipped - sync already in progress")
            return
        }
        
        print("🚀 NAV_UNIT_FAVORITES_VM: App launch sync started")
        
        let result = await NavUnitSyncService.shared.syncNavUnitFavorites()
        
        switch result {
        case .success(let stats):
            await MainActor.run {
                lastSyncTime = Date()
                print("✅ NAV_UNIT_FAVORITES_VM: App launch sync completed - \(stats.totalOperations) operations")
                loadFavorites() // Reload to show synced data
            }
            
        case .failure(let error):
            print("❌ NAV_UNIT_FAVORITES_VM: App launch sync failed - \(error.localizedDescription)")
            
        case .partialSuccess(let stats, let errors):
            await MainActor.run {
                lastSyncTime = Date()
                print("⚠️ NAV_UNIT_FAVORITES_VM: App launch sync partial - \(stats.totalOperations) operations, \(errors.count) errors")
                loadFavorites() // Reload to show synced data
            }
        }
    }
    
    /// Cloud sync (same as manual sync)
    func syncWithCloud() async {
        print("☁️ NAV_UNIT_FAVORITES_VM: Cloud sync triggered")
        await manualSync()
    }
    
    /// Check if sync is available
    func canSyncWithCloud() async -> Bool {
        return await NavUnitSyncService.shared.canSync()
    }
    
    /// Clear sync status messages
    func clearSyncMessages() {
        syncErrorMessage = nil
        syncSuccessMessage = nil
    }
    
    func cleanup() {
        print("🧹 NAV_UNIT_FAVORITES_VM: Cleanup called")
        loadTask?.cancel()
    }
    
    // MARK: - Computed Properties for UI (matches TideFavoritesViewModel)
    
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
    
    var canSync: Bool {
        return !isSyncing
    }
    
    /// Format last sync time for display
    var lastSyncTimeFormatted: String {
        guard let lastSyncTime = lastSyncTime else {
            return "Never synced"
        }
        
        let formatter = DateFormatter()
        let now = Date()
        let timeSince = now.timeIntervalSince(lastSyncTime)
        
        if timeSince < 60 {
            return "Just now"
        } else if timeSince < 3600 {
            let minutes = Int(timeSince / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if timeSince < 86400 {
            let hours = Int(timeSince / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: lastSyncTime)
        }
    }
}
