
//
//  NavUnitFavoritesViewModel.swift
//  Mariner Studio
//
//  Simplified to only work with NavUnitFavorites table
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
    
    // MARK: - Sync Methods (Simplified)
    
    func manualSync() async {
        print("🔄 NAV_UNIT_FAVORITES_VM: Manual sync triggered")
        await MainActor.run {
            isSyncing = true
            syncErrorMessage = nil
            syncSuccessMessage = nil
        }
        
        // Just reload the favorites - sync logic can be added later if needed
        loadFavorites()
        
        await MainActor.run {
            isSyncing = false
            lastSyncTime = Date()
            syncSuccessMessage = "Favorites refreshed"
        }
    }
    
    func performAppLaunchSync() async {
        print("🚀 NAV_UNIT_FAVORITES_VM: App launch sync")
        // Just load favorites on app launch
        loadFavorites()
    }
    
    func syncWithCloud() async {
        print("☁️ NAV_UNIT_FAVORITES_VM: Cloud sync")
        // For now, just reload favorites
        loadFavorites()
    }
    
    func cleanup() {
        print("🧹 NAV_UNIT_FAVORITES_VM: Cleanup called")
        loadTask?.cancel()
    }
    
    func clearSyncMessages() {
        syncErrorMessage = nil
        syncSuccessMessage = nil
    }
    
    // MARK: - Computed Properties for UI
    
    var syncStatusIcon: String {
        if isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if syncErrorMessage != nil {
            return "exclamationmark.triangle"
        } else {
            return "checkmark.circle"
        }
    }
    
    var syncStatusColor: Color {
        if isSyncing {
            return .blue
        } else if syncErrorMessage != nil {
            return .red
        } else {
            return .green
        }
    }
    
    var canSync: Bool {
        return !isSyncing
    }
}
