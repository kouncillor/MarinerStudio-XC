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
    
    // MARK: - Editing Properties
    @Published var isEditingName = false
    @Published var favoriteToEdit: WeatherLocationFavorite?
    @Published var newLocationName = ""
    
    // MARK: - Operation State
    @Published var operationInProgress: Set<String> = []
    
    // MARK: - Private Properties
    private let weatherFavoritesCloudService: WeatherFavoritesCloudService
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init(weatherFavoritesCloudService: WeatherFavoritesCloudService) {
        print("🏗️ WEATHER_FAVORITES_VM: Initializing WeatherFavoritesViewModel (CLOUD-ONLY)")
        print("🏗️ WEATHER_FAVORITES_VM: Injecting WeatherFavoritesCloudService: \(type(of: weatherFavoritesCloudService))")
        
        self.weatherFavoritesCloudService = weatherFavoritesCloudService
        
        print("✅ WEATHER_FAVORITES_VM: WeatherFavoritesViewModel initialization complete (CLOUD-ONLY)")
    }
    
    deinit {
        loadTask?.cancel()
    }
    
    // MARK: - Public Methods
    func loadFavorites() async {
        print("🔄 WEATHER_FAVORITES_VM: Starting loadFavorites (CLOUD-ONLY)")
        
        // Cancel any existing task
        loadTask?.cancel()
        
        // Create a new task
        loadTask = Task {
            await MainActor.run {
                isLoading = true
                errorMessage = ""
            }
            
            let result = await weatherFavoritesCloudService.getFavorites()
            
            if !Task.isCancelled {
                await MainActor.run {
                    switch result {
                    case .success(let favoriteLocations):
                        print("✅ WEATHER_FAVORITES_VM: Loaded \(favoriteLocations.count) weather favorites from cloud")
                        self.favorites = favoriteLocations
                        self.isLoading = false
                    case .failure(let error):
                        print("❌ WEATHER_FAVORITES_VM: Failed to load favorites: \(error.localizedDescription)")
                        self.errorMessage = "Failed to load favorites: \(error.localizedDescription)"
                        self.isLoading = false
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
                    let operationKey = "\(favorite.latitude),\(favorite.longitude)"
                    
                    // Prevent duplicate operations
                    await MainActor.run {
                        if operationInProgress.contains(operationKey) {
                            print("⚠️ WEATHER_FAVORITES_VM: Operation already in progress for \(favorite.locationName), ignoring")
                            return
                        }
                        operationInProgress.insert(operationKey)
                    }
                    
                    print("🗑️ WEATHER_FAVORITES_VM: Removing favorite: \(favorite.locationName) (CLOUD-ONLY)")
                    
                    guard let remoteId = favorite.remoteId else {
                        print("❌ WEATHER_FAVORITES_VM: Cannot remove favorite - no remote ID")
                        return
                    }
                    
                    let result = await weatherFavoritesCloudService.removeFavorite(
                        id: remoteId
                    )
                    
                    await MainActor.run {
                        operationInProgress.remove(operationKey)
                    }
                    
                    switch result {
                    case .success():
                        print("✅ WEATHER_FAVORITES_VM: Successfully removed favorite")
                        // Optimistically remove from local array immediately
                        await MainActor.run {
                            if let removeIndex = self.favorites.firstIndex(where: { 
                                $0.latitude == favorite.latitude && $0.longitude == favorite.longitude 
                            }) {
                                self.favorites.remove(at: removeIndex)
                            }
                        }
                    case .failure(let error):
                        print("❌ WEATHER_FAVORITES_VM: Failed to remove favorite: \(error.localizedDescription)")
                        await MainActor.run {
                            self.errorMessage = "Failed to remove favorite: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Rename Functionality (UNIQUE TO WEATHER FAVORITES)
    func updateLocationName(favorite: WeatherLocationFavorite, newName: String) async {
        guard !newName.isEmpty else { return }
        
        let operationKey = "\(favorite.latitude),\(favorite.longitude)"
        
        // Prevent duplicate operations
        await MainActor.run {
            if operationInProgress.contains(operationKey) {
                print("⚠️ WEATHER_FAVORITES_VM: Rename operation already in progress for \(favorite.locationName), ignoring")
                return
            }
            operationInProgress.insert(operationKey)
        }
        
        print("✏️ WEATHER_FAVORITES_VM: Updating location name from '\(favorite.locationName)' to '\(newName)' (CLOUD-ONLY)")
        
        // Optimistic UI update
        await MainActor.run {
            if let index = self.favorites.firstIndex(where: { 
                $0.latitude == favorite.latitude && $0.longitude == favorite.longitude 
            }) {
                var updatedFavorite = self.favorites[index]
                updatedFavorite = WeatherLocationFavorite(
                    id: updatedFavorite.id,
                    latitude: updatedFavorite.latitude,
                    longitude: updatedFavorite.longitude,
                    locationName: newName,
                    isFavorite: updatedFavorite.isFavorite,
                    createdAt: updatedFavorite.createdAt,
                    userId: updatedFavorite.userId,
                    deviceId: updatedFavorite.deviceId,
                    lastModified: updatedFavorite.lastModified,
                    remoteId: updatedFavorite.remoteId
                )
                self.favorites[index] = updatedFavorite
            }
        }
        
        let result = await weatherFavoritesCloudService.updateLocationName(
            latitude: favorite.latitude,
            longitude: favorite.longitude,
            newName: newName
        )
        
        await MainActor.run {
            operationInProgress.remove(operationKey)
        }
        
        switch result {
        case .success():
            print("✅ WEATHER_FAVORITES_VM: Successfully updated location name")
            // Optimistic update was successful, no need to reload
        case .failure(let error):
            print("❌ WEATHER_FAVORITES_VM: Failed to update location name: \(error.localizedDescription)")
            // Revert optimistic update
            await MainActor.run {
                if let index = self.favorites.firstIndex(where: { 
                    $0.latitude == favorite.latitude && $0.longitude == favorite.longitude 
                }) {
                    var revertedFavorite = self.favorites[index]
                    revertedFavorite = WeatherLocationFavorite(
                        id: revertedFavorite.id,
                        latitude: revertedFavorite.latitude,
                        longitude: revertedFavorite.longitude,
                        locationName: favorite.locationName, // Revert to original name
                        isFavorite: revertedFavorite.isFavorite,
                        createdAt: revertedFavorite.createdAt,
                        userId: revertedFavorite.userId,
                        deviceId: revertedFavorite.deviceId,
                        lastModified: revertedFavorite.lastModified,
                        remoteId: revertedFavorite.remoteId
                    )
                    self.favorites[index] = revertedFavorite
                }
                self.errorMessage = "Failed to update location name: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - UI Helper Methods
    func prepareForEditing(favorite: WeatherLocationFavorite) {
        favoriteToEdit = favorite
        newLocationName = favorite.locationName
        isEditingName = true
    }
    
    func cleanup() {
        loadTask?.cancel()
    }
}
