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
    
    // MARK: - Supabase Client
    private let supabaseClient = GLOBAL_SUPABASE_CLIENT
    
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
    func syncWithSupabase() async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            // Check if user is authenticated
            let session = try await supabaseClient.auth.session
            let userId = session.user.id.uuidString
            print("🔄 Starting Supabase sync for user: \(userId)")
            
            // Step 1: Get all local favorites
            let localFavorites = await getLocalFavorites()
            print("📱 Found \(localFavorites.count) local favorites")
            
            // Step 2: Get all remote favorites from Supabase
            let remoteFavorites = try await getRemoteFavorites()
            print("☁️ Found \(remoteFavorites.count) remote favorites")
            
            // Step 3: Upload local favorites that don't exist remotely
            let localOnly = localFavorites.filter { local in
                !remoteFavorites.contains { remote in remote.stationId == local }
            }
            if !localOnly.isEmpty {
                print("⬆️ Uploading \(localOnly.count) local-only favorites")
                try await uploadFavorites(localOnly, userId: userId)
            }
            
            // Step 4: Download remote favorites that don't exist locally
            let remoteOnly = remoteFavorites.filter { remote in
                remote.isFavorite && !localFavorites.contains(remote.stationId)
            }
            if !remoteOnly.isEmpty {
                print("⬇️ Downloading \(remoteOnly.count) remote-only favorites")
                await downloadFavorites(remoteOnly)
            }
            
            // Step 5: Handle conflicts (station exists both locally and remotely)
            let conflicts = remoteFavorites.filter { remote in
                localFavorites.contains(remote.stationId)
            }
            if !conflicts.isEmpty {
                print("🔄 Resolving \(conflicts.count) potential conflicts")
                await resolveConflicts(conflicts, userId: userId)
            }
            
            await MainActor.run {
                self.isLoading = false
            }
            
            print("✅ Supabase sync completed successfully")
            
            // Reload favorites to reflect changes
            loadFavorites()
            
        } catch let error as SyncError {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Sync failed: \(error.localizedDescription)")
        } catch {
            await MainActor.run {
                self.errorMessage = "Sync failed: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("❌ Sync failed with error: \(error)")
        }
    }
    
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
    
    private func getRemoteFavorites() async throws -> [RemoteFavorite] {
        let response: [RemoteFavorite] = try await supabaseClient
            .from("user_tide_favorites")
            .select("station_id, is_favorite, last_modified")
            .execute()
            .value
        
        return response
    }
    
    private func uploadFavorites(_ stationIds: [String], userId: String) async throws {
        let deviceId = await getDeviceId()
        let now = ISO8601DateFormatter().string(from: Date())
        
        let favorites = stationIds.map { stationId in
            return UploadFavorite(
                userId: userId,
                stationId: stationId,
                isFavorite: true,
                lastModified: now,
                deviceId: deviceId
            )
        }
        
        try await supabaseClient
            .from("user_tide_favorites")
            .upsert(favorites)
            .execute()
    }
    
    private func downloadFavorites(_ remoteFavorites: [RemoteFavorite]) async {
        guard let tideStationService = tideStationService else { return }
        
        for favorite in remoteFavorites {
            if favorite.isFavorite {
                // Add to local database
                _ = await tideStationService.toggleTideStationFavorite(id: favorite.stationId)
            }
        }
    }
    
    private func resolveConflicts(_ conflicts: [RemoteFavorite], userId: String) async {
        // For conflicts, we'll take the "favorite = true" preference
        // If either local or remote says it's a favorite, keep it as favorite
        
        for conflict in conflicts {
            if conflict.isFavorite {
                // Remote says it's a favorite, ensure local is also favorite
                guard let tideStationService = tideStationService else { continue }
                let isLocalFavorite = await tideStationService.isTideStationFavorite(id: conflict.stationId)
                
                if !isLocalFavorite {
                    // Local says not favorite, but remote says favorite - update local to favorite
                    _ = await tideStationService.toggleTideStationFavorite(id: conflict.stationId)
                    print("🔄 Resolved conflict for \(conflict.stationId): Updated local to favorite")
                }
            } else {
                // Remote says it's not a favorite, but we know local has it (otherwise no conflict)
                // Update remote to match local (favorite = true)
                do {
                    let deviceId = await getDeviceId()
                    let updateData = UpdateFavorite(
                        isFavorite: true,
                        lastModified: ISO8601DateFormatter().string(from: Date()),
                        deviceId: deviceId
                    )
                    
                    try await supabaseClient
                        .from("user_tide_favorites")
                        .update(updateData)
                        .eq("user_id", value: userId)
                        .eq("station_id", value: conflict.stationId)
                        .execute()
                    
                    print("🔄 Resolved conflict for \(conflict.stationId): Updated remote to favorite")
                } catch {
                    print("❌ Failed to resolve conflict for \(conflict.stationId): \(error)")
                }
            }
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
