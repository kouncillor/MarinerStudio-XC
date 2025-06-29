
//
//  RemoteNavUnitFavorite.swift
//  Mariner Studio
//
//  Remote navigation unit favorite model matching Supabase user_nav_unit_favorites table structure
//  FIXED: userId as UUID to match Supabase schema
//

import Foundation
import UIKit

/// Remote navigation unit favorite model matching Supabase user_nav_unit_favorites table structure
struct RemoteNavUnitFavorite: Codable, Identifiable {
    let id: UUID?
    let userId: UUID           // FIXED: UUID not String to match Supabase schema
    let navUnitId: String
    let isFavorite: Bool
    let lastModified: Date     // CRITICAL: For last-write-wins conflict resolution
    let deviceId: String
    let navUnitName: String?
    let latitude: Double?
    let longitude: Double?
    let facilityType: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case navUnitId = "nav_unit_id"
        case isFavorite = "is_favorite"
        case lastModified = "last_modified"
        case deviceId = "device_id"
        case navUnitName = "nav_unit_name"
        case latitude
        case longitude
        case facilityType = "facility_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Initializers
    
    init(userId: UUID, navUnitId: String, isFavorite: Bool, deviceId: String,
         navUnitName: String? = nil, latitude: Double? = nil, longitude: Double? = nil,
         facilityType: String? = nil) {
        self.id = nil  // Let Supabase generate the ID
        self.userId = userId  // FIXED: Now UUID
        self.navUnitId = navUnitId
        self.isFavorite = isFavorite
        self.lastModified = Date()
        self.deviceId = deviceId
        self.navUnitName = navUnitName
        self.latitude = latitude
        self.longitude = longitude
        self.facilityType = facilityType
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Factory Methods
    
    /// Create from local favorite data with navigation unit details
    static func fromLocal(
        userId: UUID,
        navUnitId: String,
        isFavorite: Bool,
        navUnitName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        facilityType: String? = nil
    ) -> RemoteNavUnitFavorite {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        return RemoteNavUnitFavorite(
            userId: userId,
            navUnitId: navUnitId,
            isFavorite: isFavorite,
            deviceId: deviceId,
            navUnitName: navUnitName,
            latitude: latitude,
            longitude: longitude,
            facilityType: facilityType
        )
    }
}
