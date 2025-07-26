import Foundation
import UIKit
import Supabase

/// Cloud-only weather favorites service - eliminates local storage and sync complexity
class WeatherFavoritesCloudService {
    
    // MARK: - Dependencies
    private let supabaseManager: SupabaseManager
    
    // MARK: - Initialization
    init(supabaseManager: SupabaseManager = SupabaseManager.shared) {
        self.supabaseManager = supabaseManager
    }
    
    // MARK: - Core Operations
    
    /// Add a weather location to favorites (cloud-only)
    func addFavorite(latitude: Double, longitude: Double, locationName: String) async -> Result<Void, Error> {
        
        guard let session = try? await supabaseManager.getSession() else {
            return .failure(WeatherFavoritesError.notAuthenticated)
        }
        
        let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        let favorite = RemoteWeatherFavorite(
            id: nil,
            userId: session.user.id,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            isFavorite: true, // Always true since we only store favorites
            lastModified: Date(),
            deviceId: deviceId,
            createdAt: nil,
            updatedAt: nil
        )
        
        print("🗄️ WEATHER_FAVORITES_CLOUD: Adding favorite with user_id: \(session.user.id) (UUID), lat: \(latitude), lng: \(longitude)")
        
        do {
            let _: PostgrestResponse<[RemoteWeatherFavorite]> = try await supabaseManager
                .from("user_weather_favorites")
                .insert(favorite)
                .select()
                .execute()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    /// Remove a weather location from favorites by ID (cloud-only)
    func removeFavorite(id: String) async -> Result<Void, Error> {
        
        guard let session = try? await supabaseManager.getSession() else {
            return .failure(WeatherFavoritesError.notAuthenticated)
        }
        
        do {
            print("🗄️ WEATHER_FAVORITES_CLOUD: Attempting DELETE with id: \(id)")
            
            // First, let's check if the record exists
            let checkResponse: PostgrestResponse<[RemoteWeatherFavorite]> = try await supabaseManager
                .from("user_weather_favorites")
                .select("*")
                .eq("id", value: id)
                .execute()
            
            print("🗄️ WEATHER_FAVORITES_CLOUD: Found \(checkResponse.value.count) records with id: \(id)")
            if let record = checkResponse.value.first {
                print("🗄️ WEATHER_FAVORITES_CLOUD: Record found - name: \(record.locationName), user: \(record.userId)")
            }
            
            // Delete by primary key ID - most reliable and precise
            let response = try await supabaseManager
                .from("user_weather_favorites")
                .delete()
                .eq("id", value: id)
                .execute()
            
            print("🗄️ WEATHER_FAVORITES_CLOUD: DELETE response status: \(response.response.statusCode)")
            print("🗄️ WEATHER_FAVORITES_CLOUD: DELETE response data: \(String(data: response.data, encoding: .utf8) ?? "No data")")
            
            return .success(())
        } catch {
            print("❌ WEATHER_FAVORITES_CLOUD: DELETE failed with error: \(error)")
            return .failure(error)
        }
    }
    
    /// Get all weather location favorites (cloud-only)
    func getFavorites() async -> Result<[WeatherLocationFavorite], Error> {
        
        guard let session = try? await supabaseManager.getSession() else {
            return .failure(WeatherFavoritesError.notAuthenticated)
        }
        
        do {
            let response: PostgrestResponse<[RemoteWeatherFavorite]> = try await supabaseManager
                .from("user_weather_favorites")
                .select("*")
                .eq("user_id", value: session.user.id)
                .execute()
            
            let favorites = response.value.map { remoteFavorite in
                WeatherLocationFavorite(
                    id: Int64(remoteFavorite.id?.uuidString.hashValue ?? 0), // Convert UUID to Int64 for compatibility
                    latitude: remoteFavorite.latitude,
                    longitude: remoteFavorite.longitude,
                    locationName: remoteFavorite.locationName,
                    isFavorite: true, // Always true for existing records
                    createdAt: remoteFavorite.createdAt ?? Date(),
                    userId: remoteFavorite.userId.uuidString,
                    deviceId: remoteFavorite.deviceId,
                    lastModified: remoteFavorite.lastModified,
                    remoteId: remoteFavorite.id?.uuidString
                )
            }
            
            return .success(favorites)
        } catch {
            return .failure(error)
        }
    }
    
    /// Check if a weather location is favorited (cloud-only)
    func isFavorite(latitude: Double, longitude: Double) async -> Result<Bool, Error> {
        
        guard let session = try? await supabaseManager.getSession() else {
            return .failure(WeatherFavoritesError.notAuthenticated)
        }
        
        do {
            let response: PostgrestResponse<[RemoteWeatherFavorite]> = try await supabaseManager
                .from("user_weather_favorites")
                .select("*")
                .eq("user_id", value: session.user.id)
                .eq("latitude", value: latitude)
                .eq("longitude", value: longitude)
                .execute()
            
            return .success(!response.value.isEmpty)
        } catch {
            return .failure(error)
        }
    }
    
    /// Toggle favorite status for a weather location (cloud-only)
    func toggleFavorite(latitude: Double, longitude: Double, locationName: String) async -> Result<Bool, Error> {
        
        // First check current status
        let currentStatusResult = await isFavorite(latitude: latitude, longitude: longitude)
        
        switch currentStatusResult {
        case .success(let isCurrentlyFavorited):
            if isCurrentlyFavorited {
                // TODO: For now, toggleFavorite won't work for removal until we store IDs in weather views
                // This method should probably be deprecated in favor of direct add/remove with IDs
                return .failure(WeatherFavoritesError.invalidData)
            } else {
                // Add to favorites
                let result = await addFavorite(latitude: latitude, longitude: longitude, locationName: locationName)
                return result.map { true }
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Update location name for a weather favorite (cloud-only) - UNIQUE TO WEATHER FAVORITES
    func updateLocationName(latitude: Double, longitude: Double, newName: String) async -> Result<Void, Error> {
        
        guard let session = try? await supabaseManager.getSession() else {
            return .failure(WeatherFavoritesError.notAuthenticated)
        }
        
        do {
            let _: PostgrestResponse<[RemoteWeatherFavorite]> = try await supabaseManager
                .from("user_weather_favorites")
                .update([
                    "location_name": newName,
                    "last_modified": Date().toISOString()
                ])
                .eq("user_id", value: session.user.id)
                .eq("latitude", value: latitude)
                .eq("longitude", value: longitude)
                .select()
                .execute()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - Error Types

enum WeatherFavoritesError: LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidData:
            return "Invalid weather location data"
        case .networkError:
            return "Network error occurred"
        }
    }
}

