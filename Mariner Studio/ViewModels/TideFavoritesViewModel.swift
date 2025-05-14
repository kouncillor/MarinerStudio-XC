


import Foundation
import SwiftUI
import Combine
import CoreLocation

class TideFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [TidalHeightStation] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Private Properties
    private var tideStationService: TideStationDatabaseService?
    private var tidalHeightService: TidalHeightService?
    private var locationService: LocationService?
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    func initialize(
        tideStationService: TideStationDatabaseService?,
        tidalHeightService: TidalHeightService?,
        locationService: LocationService?
    ) {
        self.tideStationService = tideStationService
        self.tidalHeightService = tidalHeightService
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
                if let tidalHeightService = tidalHeightService, let tideStationService = tideStationService {
                    // First get all stations
                    let response = try await tidalHeightService.getTidalHeightStations()
                    let allStations = response.stations
                    
                    // Process each station individually without a mutable collected array
                    let favoriteStations = await processStationsForFavorites(
                        allStations: allStations,
                        tideStationService: tideStationService
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
        allStations: [TidalHeightStation],
        tideStationService: TideStationDatabaseService
    ) async -> [TidalHeightStation] {
        var result: [TidalHeightStation] = []
        
        for var station in allStations {
            let isFavorite = await tideStationService.isTideStationFavorite(id: station.id)
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
                    
                    if let tideStationService = tideStationService {
                        // Toggle the favorite status (which will remove it since it's currently a favorite)
                        _ = await tideStationService.toggleTideStationFavorite(id: favorite.id)
                        
                        // Reload favorites to reflect the changes
                        loadFavorites()
                    }
                }
            }
        }
    }
    
    func toggleStationFavorite(stationId: String) async {
        if let tideStationService = tideStationService {
            _ = await tideStationService.toggleTideStationFavorite(id: stationId)
            loadFavorites()
        }
    }
    
    func cleanup() {
        loadTask?.cancel()
    }
}
