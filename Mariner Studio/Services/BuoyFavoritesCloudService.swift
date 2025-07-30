import Foundation
import UIKit
import Supabase

/// Cloud-only buoy favorites service - eliminates local storage and sync complexity
class BuoyFavoritesCloudService {

    // MARK: - Dependencies
    private let supabaseManager: SupabaseManager

    // MARK: - Initialization
    init(supabaseManager: SupabaseManager = SupabaseManager.shared) {
        self.supabaseManager = supabaseManager
    }

    // MARK: - Core Operations

    /// Add a buoy station to favorites (cloud-only)
    func addFavorite(stationId: String, stationName: String? = nil,
                     latitude: Double? = nil, longitude: Double? = nil,
                     stationType: String? = nil, meteorological: String? = nil,
                     currents: String? = nil) async -> Result<Void, Error> {

        guard let session = try? await supabaseManager.getSession() else {
            return .failure(BuoyFavoritesError.notAuthenticated)
        }

        let favorite = RemoteBuoyFavorite.fromLocal(
            userId: session.user.id,
            stationId: stationId,
            isFavorite: true,
            stationName: stationName,
            latitude: latitude,
            longitude: longitude,
            stationType: stationType,
            meteorological: meteorological,
            currents: currents
        )

        do {
            let _: PostgrestResponse<[RemoteBuoyFavorite]> = try await supabaseManager
                .from("user_buoy_favorites")
                .insert(favorite)
                .select()
                .execute()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Remove a buoy station from favorites (cloud-only)
    func removeFavorite(stationId: String) async -> Result<Void, Error> {

        guard let session = try? await supabaseManager.getSession() else {
            return .failure(BuoyFavoritesError.notAuthenticated)
        }

        do {
            _ = try await supabaseManager
                .from("user_buoy_favorites")
                .delete()
                .eq("user_id", value: session.user.id.uuidString)
                .eq("station_id", value: stationId)
                .execute()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Get all favorite buoy stations (cloud-only)
    func getFavorites() async -> Result<[BuoyStation], Error> {

        guard let session = try? await supabaseManager.getSession() else {
            return .failure(BuoyFavoritesError.notAuthenticated)
        }

        do {
            let response: PostgrestResponse<[RemoteBuoyFavorite]> = try await supabaseManager
                .from("user_buoy_favorites")
                .select("*")
                .eq("user_id", value: session.user.id.uuidString)
                .execute()

            // Convert to BuoyStation objects
            let stations = response.value
                .filter { $0.isFavorite } // Only true favorites
                .map { remote in
                    BuoyStation(
                        id: remote.stationId,
                        name: remote.stationName ?? "Unknown Station",
                        latitude: remote.latitude,
                        longitude: remote.longitude,
                        elevation: nil, // Not stored in favorites table
                        type: remote.stationType ?? "Unknown",
                        meteorological: remote.meteorological,
                        currents: remote.currents,
                        waterQuality: nil, // Not stored in favorites table
                        dart: nil, // Not stored in favorites table
                        isFavorite: true
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
            return .failure(BuoyFavoritesError.notAuthenticated)
        }

        do {
            let response: PostgrestResponse<[RemoteBuoyFavorite]> = try await supabaseManager
                .from("user_buoy_favorites")
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

    /// Get all favorite station IDs in a single batch call (optimized for bulk checking)
    func getFavoriteStationIds() async -> Result<Set<String>, Error> {

        guard let session = try? await supabaseManager.getSession() else {
            print("❌ BATCH_FAVORITES: No session available")
            return .failure(BuoyFavoritesError.notAuthenticated)
        }

        do {
            print("🔍 BATCH_FAVORITES: Querying user favorites")
            let response: PostgrestResponse<[RemoteBuoyFavorite]> = try await supabaseManager
                .from("user_buoy_favorites")
                .select("*")
                .eq("user_id", value: session.user.id.uuidString)
                .eq("is_favorite", value: true)
                .execute()

            print("🔍 BATCH_FAVORITES: Raw response count: \(response.value.count)")
            for favorite in response.value {
                print("🔍 BATCH_FAVORITES: Found favorite - Station: \(favorite.stationId), IsFavorite: \(favorite.isFavorite)")
            }

            let favoriteIds = Set(response.value.map { $0.stationId })
            print("🔍 BATCH_FAVORITES: Final favorite IDs: \(favoriteIds)")
            return .success(favoriteIds)
        } catch {
            print("❌ BATCH_FAVORITES: Error - \(error)")
            return .failure(error)
        }
    }

    /// Toggle favorite status (cloud-only)
    func toggleFavorite(stationId: String, stationName: String? = nil,
                       latitude: Double? = nil, longitude: Double? = nil,
                       stationType: String? = nil, meteorological: String? = nil,
                       currents: String? = nil) async -> Result<Bool, Error> {

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
                    longitude: longitude,
                    stationType: stationType,
                    meteorological: meteorological,
                    currents: currents
                )
                return result.map { true }
            }
        case .failure(let error):
            return .failure(error)
        }
    }
}

// MARK: - Error Types
enum BuoyFavoritesError: Error, LocalizedError {
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
            return "Invalid buoy station data"
        }
    }
}
