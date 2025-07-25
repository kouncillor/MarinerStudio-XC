import Foundation
import UIKit
import Supabase

/// Cloud-only current favorites service - eliminates local storage and sync complexity
class CurrentFavoritesCloudService {
    
    // MARK: - Dependencies
    private let supabaseManager: SupabaseManager
    
    // MARK: - Initialization
    init(supabaseManager: SupabaseManager = SupabaseManager.shared) {
        self.supabaseManager = supabaseManager
    }
    
    // MARK: - Core Operations
    
    /// Add a current station to favorites (cloud-only)
    func addFavorite(stationId: String, currentBin: Int, stationName: String? = nil, 
                     latitude: Double? = nil, longitude: Double? = nil,
                     depth: Double? = nil, depthType: String? = nil) async -> Result<Void, Error> {
        
        guard let session = try? await supabaseManager.getSession() else {
            return .failure(CurrentFavoritesError.notAuthenticated)
        }
        
        let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        let favorite = RemoteCurrentFavorite(
            id: nil,
            userId: session.user.id,
            stationId: stationId,
            currentBin: currentBin,
            isFavorite: true, // Always true since we only store favorites
            lastModified: Date(),
            deviceId: deviceId,
            stationName: stationName,
            latitude: latitude,
            longitude: longitude,
            depth: depth,
            depthType: depthType
        )
        
        do {
            let _: PostgrestResponse<[RemoteCurrentFavorite]> = try await supabaseManager
                .from("user_current_favorites")
                .insert(favorite)
                .select()
                .execute()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    /// Remove a current station from favorites (cloud-only)
    func removeFavorite(stationId: String, currentBin: Int) async -> Result<Void, Error> {
        
        guard let session = try? await supabaseManager.getSession() else {
            return .failure(CurrentFavoritesError.notAuthenticated)
        }
        
        do {
            let _ = try await supabaseManager
                .from("user_current_favorites")
                .delete()
                .eq("user_id", value: session.user.id.uuidString)
                .eq("station_id", value: stationId)
                .eq("current_bin", value: currentBin)
                .execute()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    /// Get all current station favorites (cloud-only)
    func getFavorites() async -> Result<[TidalCurrentStation], Error> {
        
        guard let session = try? await supabaseManager.getSession() else {
            return .failure(CurrentFavoritesError.notAuthenticated)
        }
        
        do {
            let response: PostgrestResponse<[RemoteCurrentFavorite]> = try await supabaseManager
                .from("user_current_favorites")
                .select("*")
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
            
            let favorites = response.value.map { remoteFavorite in
                TidalCurrentStation(
                    id: remoteFavorite.stationId,
                    name: remoteFavorite.stationName ?? "Unknown Station",
                    latitude: remoteFavorite.latitude,
                    longitude: remoteFavorite.longitude,
                    type: "current",
                    depth: remoteFavorite.depth,
                    depthType: remoteFavorite.depthType,
                    currentBin: remoteFavorite.currentBin,
                    isFavorite: true,
                    distanceFromUser: nil
                )
            }
            
            return .success(favorites)
        } catch {
            return .failure(error)
        }
    }
    
    /// Check if a specific current station is favorited (cloud-only)
    func isFavorite(stationId: String, currentBin: Int) async -> Result<Bool, Error> {
        
        guard let session = try? await supabaseManager.getSession() else {
            return .failure(CurrentFavoritesError.notAuthenticated)
        }
        
        do {
            let response: PostgrestResponse<[RemoteCurrentFavorite]> = try await supabaseManager
                .from("user_current_favorites")
                .select("*")
                .eq("user_id", value: session.user.id.uuidString)
                .eq("station_id", value: stationId)
                .eq("current_bin", value: currentBin)
                .execute()
            
            return .success(!response.value.isEmpty)
        } catch {
            return .failure(error)
        }
    }
    
    /// Toggle favorite status for a current station (cloud-only)
    func toggleFavorite(stationId: String, currentBin: Int, stationName: String? = nil,
                       latitude: Double? = nil, longitude: Double? = nil,
                       depth: Double? = nil, depthType: String? = nil) async -> Result<Bool, Error> {
        
        let isFavoriteResult = await isFavorite(stationId: stationId, currentBin: currentBin)
        
        switch isFavoriteResult {
        case .success(let currentlyFavorite):
            if currentlyFavorite {
                let removeResult = await removeFavorite(stationId: stationId, currentBin: currentBin)
                switch removeResult {
                case .success():
                    return .success(false) // Now not favorite
                case .failure(let error):
                    return .failure(error)
                }
            } else {
                let addResult = await addFavorite(
                    stationId: stationId, 
                    currentBin: currentBin,
                    stationName: stationName,
                    latitude: latitude,
                    longitude: longitude,
                    depth: depth,
                    depthType: depthType
                )
                switch addResult {
                case .success():
                    return .success(true) // Now favorite
                case .failure(let error):
                    return .failure(error)
                }
            }
        case .failure(let error):
            return .failure(error)
        }
    }
}

// MARK: - Error Types

enum CurrentFavoritesError: LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidData:
            return "Invalid current station data"
        case .networkError:
            return "Network error occurred"
        }
    }
}