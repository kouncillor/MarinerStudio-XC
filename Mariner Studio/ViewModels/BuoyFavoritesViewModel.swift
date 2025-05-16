//
//  BuoyFavoritesViewModel.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/15/25.
//


import Foundation
import SwiftUI
import Combine
import CoreLocation

class BuoyFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [BuoyStation] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Private Properties
    private var buoyDatabaseService: BuoyDatabaseService?
    private var buoyService: BuoyService?
    private var locationService: LocationService?
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    func initialize(
        buoyDatabaseService: BuoyDatabaseService?,
        buoyService: BuoyService?,
        locationService: LocationService?
    ) {
        self.buoyDatabaseService = buoyDatabaseService
        self.buoyService = buoyService
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
                if let buoyService = buoyService, let buoyDatabaseService = buoyDatabaseService {
                    // First get all stations
                    let response = try await buoyService.getBuoyStations()
                    let allStations = response.stations
                    
                    // Process each station individually to find favorites
                    let favoriteStations = await processStationsForFavorites(
                        allStations: allStations,
                        buoyDatabaseService: buoyDatabaseService
                    )
                    
                    // Only update published property if task hasn't been cancelled
                    if !Task.isCancelled {
                        await MainActor.run {
                            favorites = favoriteStations
                            isLoading = false
                        }
                    }
                } else {
                    if !Task.isCancelled {
                        await MainActor.run {
                            errorMessage = "Services unavailable"
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
    
    // Helper method to process stations concurrently safe
    private func processStationsForFavorites(
        allStations: [BuoyStation],
        buoyDatabaseService: BuoyDatabaseService
    ) async -> [BuoyStation] {
        var result: [BuoyStation] = []
        
        for var station in allStations {
            let isFavorite = await buoyDatabaseService.isBuoyStationFavoriteAsync(stationId: station.id)
            if isFavorite {
                station.isFavorite = true
                result.append(station)
            }
        }
        
        return result
    }
    
    func removeFavorite(at indexSet: IndexSet) {
        Task {
            for index in indexSet {
                if index < favorites.count {
                    let favorite = favorites[index]
                    
                    if let buoyDatabaseService = buoyDatabaseService {
                        // Toggle the favorite status (which will remove it since it's currently a favorite)
                        _ = await buoyDatabaseService.toggleBuoyStationFavoriteAsync(stationId: favorite.id)
                        
                        // Reload favorites to reflect the changes
                        loadFavorites()
                    }
                }
            }
        }
    }
    
    func toggleStationFavorite(stationId: String) async {
        if let buoyDatabaseService = buoyDatabaseService {
            _ = await buoyDatabaseService.toggleBuoyStationFavoriteAsync(stationId: stationId)
            loadFavorites()
        }
    }
    
    func cleanup() {
        loadTask?.cancel()
    }
}