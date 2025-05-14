//
//  NavUnitFavoritesViewModel.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/14/25.
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
        self.navUnitService = navUnitService
        self.locationService = locationService
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
                if let navUnitService = navUnitService {
                    // Get all nav units
                    let allNavUnits = try await navUnitService.getNavUnitsAsync()
                    
                    // Filter to only include favorites
                    let favoriteNavUnits = allNavUnits.filter { $0.isFavorite }
                    
                    if !Task.isCancelled {
                        await MainActor.run {
                            favorites = favoriteNavUnits
                            isLoading = false
                        }
                    }
                } else {
                    if !Task.isCancelled {
                        await MainActor.run {
                            errorMessage = "Service unavailable"
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
                    
                    if let navUnitService = navUnitService {
                        // Toggle favorite status (which will remove it since it's currently a favorite)
                        _ = try? await navUnitService.toggleFavoriteNavUnitAsync(navUnitId: favorite.navUnitId)
                        
                        // Reload favorites to reflect the changes
                        loadFavorites()
                    }
                }
            }
        }
    }
    
    func toggleNavUnitFavorite(navUnitId: String) async {
        if let navUnitService = navUnitService {
            _ = try? await navUnitService.toggleFavoriteNavUnitAsync(navUnitId: navUnitId)
            loadFavorites()
        }
    }
    
    func cleanup() {
        loadTask?.cancel()
    }
}