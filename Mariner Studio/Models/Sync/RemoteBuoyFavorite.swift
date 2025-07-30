import Foundation
import UIKit

/// Remote buoy favorite model matching Supabase user_buoy_favorites table structure
struct RemoteBuoyFavorite: Codable, Identifiable {
    let id: UUID?
    let userId: UUID
    let stationId: String
    let isFavorite: Bool
    let lastModified: Date
    let deviceId: String

    // Station details for complete sync
    let stationName: String?
    let latitude: Double?
    let longitude: Double?

    // Buoy-specific fields
    let stationType: String?
    let meteorological: String?
    let currents: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case stationId = "station_id"
        case isFavorite = "is_favorite"
        case lastModified = "last_modified"
        case deviceId = "device_id"

        // Station details
        case stationName = "station_name"
        case latitude
        case longitude

        // Buoy-specific fields
        case stationType = "station_type"
        case meteorological
        case currents
    }

    init(userId: UUID, stationId: String, isFavorite: Bool, deviceId: String,
         stationName: String? = nil, latitude: Double? = nil, longitude: Double? = nil,
         stationType: String? = nil, meteorological: String? = nil, currents: String? = nil) {
        self.id = nil  // Let Supabase generate the ID
        self.userId = userId
        self.stationId = stationId
        self.isFavorite = isFavorite
        self.lastModified = Date()
        self.deviceId = deviceId

        // Station details
        self.stationName = stationName
        self.latitude = latitude
        self.longitude = longitude

        // Buoy-specific fields
        self.stationType = stationType
        self.meteorological = meteorological
        self.currents = currents
    }

    /// Create from local favorite data with station details
    static func fromLocal(userId: UUID, stationId: String, isFavorite: Bool,
                         stationName: String? = nil, latitude: Double? = nil, longitude: Double? = nil,
                         stationType: String? = nil, meteorological: String? = nil, currents: String? = nil) -> RemoteBuoyFavorite {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        return RemoteBuoyFavorite(
            userId: userId,
            stationId: stationId,
            isFavorite: isFavorite,
            deviceId: deviceId,
            stationName: stationName,
            latitude: latitude,
            longitude: longitude,
            stationType: stationType,
            meteorological: meteorological,
            currents: currents
        )
    }
}
