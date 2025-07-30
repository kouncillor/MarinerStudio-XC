import Foundation
import UIKit

/// Remote weather favorite model matching Supabase user_weather_favorites table structure
struct RemoteWeatherFavorite: Codable, Identifiable {
    let id: UUID?
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let locationName: String
    let isFavorite: Bool
    let lastModified: Date
    let deviceId: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case latitude
        case longitude
        case locationName = "location_name"
        case isFavorite = "is_favorite"
        case lastModified = "last_modified"
        case deviceId = "device_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(userId: UUID, latitude: Double, longitude: Double, locationName: String,
         isFavorite: Bool, deviceId: String) {
        self.id = nil  // Let Supabase generate the ID
        self.userId = userId
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.isFavorite = isFavorite
        self.lastModified = Date()
        self.deviceId = deviceId
        self.createdAt = nil  // Let Supabase set these
        self.updatedAt = nil
    }

    /// Full initializer with all fields for sync operations
    init(id: UUID?, userId: UUID, latitude: Double, longitude: Double, locationName: String,
         isFavorite: Bool, lastModified: Date, deviceId: String, createdAt: Date?, updatedAt: Date?) {
        self.id = id
        self.userId = userId
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.isFavorite = isFavorite
        self.lastModified = lastModified
        self.deviceId = deviceId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Create from local favorite data with complete location details
    static func fromLocal(userId: UUID, latitude: Double, longitude: Double,
                         locationName: String, isFavorite: Bool) -> RemoteWeatherFavorite {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        return RemoteWeatherFavorite(
            userId: userId,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            isFavorite: isFavorite,
            deviceId: deviceId
        )
    }
}
