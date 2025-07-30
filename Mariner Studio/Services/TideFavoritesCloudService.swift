import Foundation
import UIKit
import Supabase

/// Cloud-only tide favorites service - eliminates local storage and sync complexity
class TideFavoritesCloudService {

    // MARK: - Dependencies
    private let supabaseManager: SupabaseManager

    // MARK: - Initialization
    init(supabaseManager: SupabaseManager = SupabaseManager.shared) {
        self.supabaseManager = supabaseManager
    }

    // MARK: - Core Operations

    /// Add a tide station to favorites (cloud-only)
    func addFavorite(stationId: String, stationName: String? = nil,
                     latitude: Double? = nil, longitude: Double? = nil) async -> Result<Void, Error> {

        guard let session = try? await supabaseManager.getSession() else {
            return .failure(TideFavoritesError.notAuthenticated)
        }

        let favorite = RemoteTideFavorite.fromLocal(
            userId: session.user.id,
            stationId: stationId,
            isFavorite: true,
            stationName: stationName,
            latitude: latitude,
            longitude: longitude
        )

        do {
            let _: PostgrestResponse<[RemoteTideFavorite]> = try await supabaseManager
                .from("user_tide_favorites")
                .insert(favorite)
                .select()
                .execute()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Remove a tide station from favorites (cloud-only)
    func removeFavorite(stationId: String) async -> Result<Void, Error> {

        guard let session = try? await supabaseManager.getSession() else {
            return .failure(TideFavoritesError.notAuthenticated)
        }

        do {
            _ = try await supabaseManager
                .from("user_tide_favorites")
                .delete()
                .eq("user_id", value: session.user.id.uuidString)
                .eq("station_id", value: stationId)
                .execute()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Get all favorite tide stations (cloud-only)
    func getFavorites() async -> Result<[TidalHeightStation], Error> {

        guard let session = try? await supabaseManager.getSession() else {
            return .failure(TideFavoritesError.notAuthenticated)
        }

        do {
            let response: PostgrestResponse<[RemoteTideFavorite]> = try await supabaseManager
                .from("user_tide_favorites")
                .select("*")
                .eq("user_id", value: session.user.id.uuidString)
                .execute()

            // Convert to TidalHeightStation objects
            let stations = response.value
                .filter { $0.isFavorite } // Only true favorites
                .map { remote in
                    TidalHeightStation(
                        id: remote.stationId,
                        name: remote.stationName ?? "Unknown Station",
                        latitude: remote.latitude,
                        longitude: remote.longitude,
                        state: nil, // Not stored in favorites
                        type: "H", // Default for tide height stations
                        referenceId: remote.stationId,
                        timezoneCorrection: nil,
                        timeMeridian: nil,
                        tidePredOffsets: nil
                    )
                }

            return .success(stations)
        } catch {
            return .failure(error)
        }
    }

    /// Check if a station is favorited (cloud-only)
    func isFavorite(stationId: String) async -> Result<Bool, Error> {

        guard let session = try? await supabaseManager.getSession() else {
            return .failure(TideFavoritesError.notAuthenticated)
        }

        do {
            let response: PostgrestResponse<[RemoteTideFavorite]> = try await supabaseManager
                .from("user_tide_favorites")
                .select("*")
                .eq("user_id", value: session.user.id.uuidString)
                .eq("station_id", value: stationId)
                .execute()

            let isFavorited = response.value.first?.isFavorite ?? false
            return .success(isFavorited)
        } catch {
            return .failure(error)
        }
    }

    /// Toggle favorite status (cloud-only)
    func toggleFavorite(stationId: String, stationName: String? = nil,
                       latitude: Double? = nil, longitude: Double? = nil) async -> Result<Bool, Error> {

        // First check current status
        let currentStatusResult = await isFavorite(stationId: stationId)

        switch currentStatusResult {
        case .success(let isCurrentlyFavorited):
            if isCurrentlyFavorited {
                // Remove from favorites
                let result = await removeFavorite(stationId: stationId)
                return result.map { false }
            } else {
                // Add to favorites
                let result = await addFavorite(
                    stationId: stationId,
                    stationName: stationName,
                    latitude: latitude,
                    longitude: longitude
                )
                return result.map { true }
            }
        case .failure(let error):
            return .failure(error)
        }
    }
}

// MARK: - Error Types
enum TideFavoritesError: Error, LocalizedError {
    case notAuthenticated
    case networkError
    case invalidData

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .networkError:
            return "Network connection error"
        case .invalidData:
            return "Invalid tide station data"
        }
    }
}
