//
//  WeatherFavoritesViewModel.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/13/25.
//


import Foundation
import SwiftUI
import Combine

class WeatherFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [WeatherLocationFavorite] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Sync Properties
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncErrorMessage: String?
    @Published var syncSuccessMessage: String?
    
    // MARK: - Private Properties
    private var databaseService: WeatherDatabaseService?
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
    // MARK: - UI Helper Properties
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
    
    // MARK: - Initialization
    func initialize(databaseService: WeatherDatabaseService?) {
        self.databaseService = databaseService
    }
    
    deinit {
        loadTask?.cancel()
    }
    
    // MARK: - Public Methods
    func loadFavorites() {
        // Cancel any existing task
        loadTask?.cancel()
        
        // Create a new task
        loadTask = Task {
            await MainActor.run {
                isLoading = true
                errorMessage = ""
            }
            
            do {
                if let databaseService = databaseService {
                    let favoriteLocations = try await databaseService.getFavoriteWeatherLocationsAsync()
                    
                    if !Task.isCancelled {
                        await MainActor.run {
                            favorites = favoriteLocations
                            isLoading = false
                        }
                    }
                } else {
                    if !Task.isCancelled {
                        await MainActor.run {
                            errorMessage = "Database service unavailable"
                            isLoading = false
                        }
                    }
                }
            } catch {
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
        Task {
            for index in indexSet {
                if index < favorites.count {
                    let favorite = favorites[index]
                    
                    if let databaseService = databaseService {
                        _ = await databaseService.toggleWeatherLocationFavoriteAsync(
                            latitude: favorite.latitude,
                            longitude: favorite.longitude,
                            locationName: favorite.locationName
                        )
                        
                        // Reload favorites to reflect the changes
                        loadFavorites()
                        
                        // Sync after removal
                        await performSyncAfterChange()
                    }
                }
            }
        }
    }
    
    func cleanup() {
        loadTask?.cancel()
    }
    
    
    
    
    
    
    // Add these properties to WeatherFavoritesViewModel
    @Published var isEditingName = false
    @Published var favoriteToEdit: WeatherLocationFavorite?
    @Published var newLocationName = ""

    // Add this method to WeatherFavoritesViewModel
    func updateLocationName(favorite: WeatherLocationFavorite, newName: String) async {
        guard !newName.isEmpty else { return }
        
        if let databaseService = databaseService {
            let success = await databaseService.updateWeatherLocationNameAsync(
                latitude: favorite.latitude,
                longitude: favorite.longitude,
                newName: newName
            )
            
            if success {
                // Reload favorites to reflect the changes
                loadFavorites()
                
                // Sync after update
                await performSyncAfterChange()
            }
        }
    }

    // Add this method to prepare for editing
    func prepareForEditing(favorite: WeatherLocationFavorite) {
        favoriteToEdit = favorite
        newLocationName = favorite.locationName
        isEditingName = true
    }
}

// MARK: - Sync Integration Extension
extension WeatherFavoritesViewModel {
    /// Sync after user makes changes - always runs immediately
    func performSyncAfterChange() async {
        guard !isSyncing else { return }
        
        await MainActor.run {
            isSyncing = true
            syncErrorMessage = nil
            syncSuccessMessage = nil
        }
        
        print("🔄🌤️ WEATHER FAVORITES VIEWMODEL: Performing sync after favorite change")
        
        let result = await WeatherStationSyncService.shared.syncWeatherLocationFavorites()
        
        await MainActor.run {
            isSyncing = false
            
            switch result {
            case .success(let stats):
                lastSyncTime = Date()
                syncSuccessMessage = "Sync completed! \(stats.uploaded) uploaded, \(stats.downloaded) downloaded"
                syncErrorMessage = nil
                print("✅🌤️ WEATHER FAVORITES VIEWMODEL: Sync completed successfully")
                print("✅🌤️ SYNC STATS: \(stats.totalOperations) operations in \(String(format: "%.3f", stats.duration))s")
                
                // Auto-dismiss success message after 3 seconds
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run {
                        if syncSuccessMessage == "Sync completed! \(stats.uploaded) uploaded, \(stats.downloaded) downloaded" {
                            syncSuccessMessage = nil
                        }
                    }
                }
                
            case .failure(let error):
                syncErrorMessage = "Sync failed: \(error.localizedDescription)"
                syncSuccessMessage = nil
                print("❌🌤️ WEATHER FAVORITES VIEWMODEL: Sync failed - \(error.localizedDescription)")
                
                // Auto-dismiss error message after 5 seconds
                Task {
                    try? await Task.sleep(for: .seconds(5))
                    await MainActor.run {
                        if syncErrorMessage == "Sync failed: \(error.localizedDescription)" {
                            syncErrorMessage = nil
                        }
                    }
                }
                
            case .partialSuccess(let stats, let errors):
                lastSyncTime = Date()
                syncSuccessMessage = "Partial sync - \(stats.totalOperations) operations"
                syncErrorMessage = "Some operations failed (\(errors.count) errors)"
                print("⚠️🌤️ WEATHER FAVORITES VIEWMODEL: Partial sync - \(stats.totalOperations) operations, \(errors.count) errors")
                
                // Auto-dismiss messages after 4 seconds  
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    await MainActor.run {
                        if syncSuccessMessage == "Partial sync - \(stats.totalOperations) operations" {
                            syncSuccessMessage = nil
                        }
                        if syncErrorMessage == "Some operations failed (\(errors.count) errors)" {
                            syncErrorMessage = nil
                        }
                    }
                }
            }
        }
    }
    
    /// Perform manual sync (for refresh button)
    func performManualSync() async {
        print("🔄🌤️ WEATHER FAVORITES VIEWMODEL: Performing manual sync")
        await performSyncAfterChange()
        // Reload favorites after sync to show any new data
        loadFavorites()
    }
    
    /// Check if user can sync (authenticated)
    func canSync() async -> Bool {
        return await WeatherStationSyncService.shared.canSync()
    }
    
    /// Clear sync messages (for UI dismiss)
    func clearSyncMessages() {
        syncErrorMessage = nil
        syncSuccessMessage = nil
    }
}
