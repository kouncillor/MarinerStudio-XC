//
//  CurrentFavoritesViewModel.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/14/25.
//


import Foundation
import SwiftUI
import Combine
import CoreLocation

class CurrentFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [TidalCurrentStation] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Private Properties
    private var currentStationService: CurrentStationDatabaseService?
    private var tidalCurrentService: TidalCurrentService?
    private var locationService: LocationService?
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    func initialize(
        currentStationService: CurrentStationDatabaseService?,
        tidalCurrentService: TidalCurrentService?,
        locationService: LocationService?
    ) {
        self.currentStationService = currentStationService
        self.tidalCurrentService = tidalCurrentService
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
                if let tidalCurrentService = tidalCurrentService, let currentStationService = currentStationService {
                    // First get all stations
                    let response = try await tidalCurrentService.getTidalCurrentStations()
                    let allStations = response.stations
                    
                    // Process each station individually without a mutable collected array
                    let favoriteStations = await processStationsForFavorites(
                        allStations: allStations,
                        currentStationService: currentStationService
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
        allStations: [TidalCurrentStation],
        currentStationService: CurrentStationDatabaseService
    ) async -> [TidalCurrentStation] {
        var result: [TidalCurrentStation] = []
        
        for var station in allStations {
            let isFavorite = await currentStationService.isCurrentStationFavorite(id: station.id)
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
                    
                    if let currentStationService = currentStationService {
                        // Toggle the favorite status (which will remove it since it's currently a favorite)
                        if let bin = favorite.currentBin {
                            _ = await currentStationService.toggleCurrentStationFavorite(id: favorite.id, bin: bin)
                        } else {
                            _ = await currentStationService.toggleCurrentStationFavorite(id: favorite.id)
                        }
                        
                        // Reload favorites to reflect the changes
                        loadFavorites()
                    }
                }
            }
        }
    }
    
    func toggleStationFavorite(stationId: String, bin: Int? = nil) async {
        if let currentStationService = currentStationService {
            if let bin = bin {
                _ = await currentStationService.toggleCurrentStationFavorite(id: stationId, bin: bin)
            } else {
                _ = await currentStationService.toggleCurrentStationFavorite(id: stationId)
            }
            loadFavorites()
        }
    }
    
    func cleanup() {
        loadTask?.cancel()
    }
}