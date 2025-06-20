import Foundation
import SwiftUI
import Combine
import CoreLocation
import Supabase

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
                    
                    // Only update published properties on main actor
                    await MainActor.run {
                        self.favorites = favoriteStations
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Service not available"
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load favorites: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func removeFavorite(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let station = favorites[index]
                await removeStationFromFavorites(station)
            }
            
            // Reload the favorites list
            loadFavorites()
        }
    }
    
    func cleanup() {
        loadTask?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Supabase Sync Methods
   
    // MARK: - Private Methods
    private func processStationsForFavorites(
        allStations: [TidalHeightStation],
        tideStationService: TideStationDatabaseService
    ) async -> [TidalHeightStation] {
        var favoriteStations: [TidalHeightStation] = []
        
        for station in allStations {
            let isFavorite = await tideStationService.isTideStationFavorite(id: station.id)
            if isFavorite {
                favoriteStations.append(station)
            }
        }
        
        return favoriteStations.sorted { $0.name < $1.name }
    }
    
    private func removeStationFromFavorites(_ station: TidalHeightStation) async {
        guard let tideStationService = tideStationService else { return }
        
        let success = await tideStationService.toggleTideStationFavorite(id: station.id)
        if !success {
            await MainActor.run {
                self.errorMessage = "Failed to remove station from favorites"
            }
        }
    }
    
    // MARK: - Private Sync Helper Methods
    
    private func getLocalFavorites() async -> [String] {
        guard let tideStationService = tideStationService,
              let tidalHeightService = tidalHeightService else {
            return []
        }
        
        do {
            let response = try await tidalHeightService.getTidalHeightStations()
            var localFavorites: [String] = []
            
            for station in response.stations {
                let isFavorite = await tideStationService.isTideStationFavorite(id: station.id)
                if isFavorite {
                    localFavorites.append(station.id)
                }
            }
            
            return localFavorites
        } catch {
            print("❌ Error getting local favorites: \(error)")
            return []
        }
    }
    
    
    
   
    
    private func getDeviceId() async -> String {
        // Get a unique device identifier
        if let deviceId = await UIDevice.current.identifierForVendor?.uuidString {
            return deviceId
        }
        return UUID().uuidString
    }
}

// MARK: - Supporting Types

struct RemoteFavorite: Codable {
    let stationId: String
    let isFavorite: Bool
    let lastModified: String
    
    enum CodingKeys: String, CodingKey {
        case stationId = "station_id"
        case isFavorite = "is_favorite"
        case lastModified = "last_modified"
    }
}

struct UploadFavorite: Codable {
    let userId: String
    let stationId: String
    let isFavorite: Bool
    let lastModified: String
    let deviceId: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case stationId = "station_id"
        case isFavorite = "is_favorite"
        case lastModified = "last_modified"
        case deviceId = "device_id"
    }
}

struct UpdateFavorite: Codable {
    let isFavorite: Bool
    let lastModified: String
    let deviceId: String
    
    enum CodingKeys: String, CodingKey {
        case isFavorite = "is_favorite"
        case lastModified = "last_modified"
        case deviceId = "device_id"
    }
}

enum SyncError: LocalizedError {
    case notAuthenticated
    case networkError
    case databaseError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to sync your favorites"
        case .networkError:
            return "Network connection failed"
        case .databaseError:
            return "Database error occurred"
        }
    }
}
