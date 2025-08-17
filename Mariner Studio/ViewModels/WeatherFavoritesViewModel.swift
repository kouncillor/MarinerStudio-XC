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
    private let coreDataManager: CoreDataManager
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?

    // MARK: - Initialization
    init(coreDataManager: CoreDataManager) {
        print("🏗️ WEATHER_FAVORITES_VM: Initializing WeatherFavoritesViewModel (CORE DATA + CLOUDKIT)")
        print("🏗️ WEATHER_FAVORITES_VM: Injecting CoreDataManager: \(type(of: coreDataManager))")

        self.coreDataManager = coreDataManager

        print("✅ WEATHER_FAVORITES_VM: WeatherFavoritesViewModel initialization complete (CORE DATA + CLOUDKIT)")
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

            let weatherFavorites = coreDataManager.getWeatherFavorites()
            
            // Convert Core Data entities to WeatherLocationFavorite objects
            let favoriteLocations = weatherFavorites.map { favorite in
                WeatherLocationFavorite(
                    id: Int64.random(in: 1...Int64.max),
                    latitude: favorite.latitude,
                    longitude: favorite.longitude,
                    locationName: favorite.locationName,
                    isFavorite: true,
                    createdAt: favorite.dateAdded ?? Date(),
                    userId: nil,
                    deviceId: nil,
                    lastModified: nil,
                    remoteId: nil
                )
            }

            if !Task.isCancelled {
                await MainActor.run {
                    print("✅ WEATHER_FAVORITES_VM: Loaded \(favoriteLocations.count) weather favorites from Core Data")
                    self.favorites = favoriteLocations
                    self.isLoading = false
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

                    print("🗑️ WEATHER_FAVORITES_VM: Removing favorite: \(favorite.locationName) (CORE DATA + CLOUDKIT)")

                    coreDataManager.removeWeatherFavorite(
                        latitude: favorite.latitude,
                        longitude: favorite.longitude
                    )

                    await MainActor.run {
                        operationInProgress.remove(operationKey)
                    }

                    print("✅ WEATHER_FAVORITES_VM: Successfully removed favorite from Core Data")
                    // Remove from local array immediately
                    await MainActor.run {
                        if let removeIndex = self.favorites.firstIndex(where: {
                            $0.latitude == favorite.latitude && $0.longitude == favorite.longitude
                        }) {
                            self.favorites.remove(at: removeIndex)
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

        // Update in Core Data by removing and re-adding with new name
        coreDataManager.removeWeatherFavorite(
            latitude: favorite.latitude,
            longitude: favorite.longitude
        )
        coreDataManager.addWeatherFavorite(
            latitude: favorite.latitude,
            longitude: favorite.longitude,
            locationName: newName
        )

        await MainActor.run {
            operationInProgress.remove(operationKey)
        }

        print("✅ WEATHER_FAVORITES_VM: Successfully updated location name in Core Data")
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
