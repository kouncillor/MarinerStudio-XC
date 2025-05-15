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
    
    // MARK: - Private Properties
    private var databaseService: WeatherDatabaseService?
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
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
