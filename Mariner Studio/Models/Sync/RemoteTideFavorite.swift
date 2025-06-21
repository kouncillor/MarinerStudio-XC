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
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case stationId = "station_id"
        case isFavorite = "is_favorite"
        case lastModified = "last_modified"
        case deviceId = "device_id"
    }
    
    init(userId: UUID, stationId: String, isFavorite: Bool, deviceId: String) {
        self.id = nil  // Let Supabase generate the ID
        self.userId = userId
        self.stationId = stationId
        self.isFavorite = isFavorite
        self.lastModified = Date()
        self.deviceId = deviceId
    }
    
    /// Create from local favorite data
    static func fromLocal(userId: UUID, stationId: String, isFavorite: Bool) -> RemoteTideFavorite {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        return RemoteTideFavorite(
            userId: userId,
            stationId: stationId,
            isFavorite: isFavorite,
            deviceId: deviceId
        )
    }
}
