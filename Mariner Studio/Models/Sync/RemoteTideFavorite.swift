import Foundation
import UIKit

/// Remote tide favorite model matching Supabase user_tide_favorites table structure
struct RemoteTideFavorite: Codable, Identifiable {
    let id: UUID?
    let userId: UUID
    let stationId: String
    let isFavorite: Bool
    let lastModified: Date
    let deviceId: String

    // NEW: Station details for complete sync
    let stationName: String?
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case stationId = "station_id"
        case isFavorite = "is_favorite"
        case lastModified = "last_modified"
        case deviceId = "device_id"

        // NEW: Station details
        case stationName = "station_name"
        case latitude
        case longitude
    }

    init(userId: UUID, stationId: String, isFavorite: Bool, deviceId: String,
         stationName: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = nil  // Let Supabase generate the ID
        self.userId = userId
        self.stationId = stationId
        self.isFavorite = isFavorite
        self.lastModified = Date()
        self.deviceId = deviceId

        // NEW: Store station details
        self.stationName = stationName
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Create from local favorite data with station details
    static func fromLocal(userId: UUID, stationId: String, isFavorite: Bool,
                         stationName: String? = nil, latitude: Double? = nil, longitude: Double? = nil) -> RemoteTideFavorite {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        return RemoteTideFavorite(
            userId: userId,
            stationId: stationId,
            isFavorite: isFavorite,
            deviceId: deviceId,
            stationName: stationName,
            latitude: latitude,
            longitude: longitude
        )
    }
}
