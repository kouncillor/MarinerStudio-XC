
// MARK: - Remote Navigation Unit Favorite Model
// File: Models/Sync/RemoteNavUnitFavorite.swift

import Foundation
import UIKit

/// Remote navigation unit favorite model matching Supabase user_nav_unit_favorites table structure
struct RemoteNavUnitFavorite: Codable, Identifiable {
    let id: UUID?
    let userId: String
    let navUnitId: String
    let isFavorite: Bool
    let lastModified: Date
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
    
    init(userId: String, navUnitId: String, isFavorite: Bool, deviceId: String,
         navUnitName: String? = nil, latitude: Double? = nil, longitude: Double? = nil,
         facilityType: String? = nil) {
        self.id = nil  // Let Supabase generate the ID
        self.userId = userId
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
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        return RemoteNavUnitFavorite(
            userId: userId.uuidString,
            navUnitId: navUnitId,
            isFavorite: isFavorite,
            deviceId: deviceId,
            navUnitName: navUnitName,
            latitude: latitude,
            longitude: longitude,
            facilityType: facilityType
        )
    }
    
    /// Create from NavUnitFavoriteRecord
    static func fromLocalRecord(_ record: NavUnitFavoriteRecord, userId: UUID) -> RemoteNavUnitFavorite {
        return RemoteNavUnitFavorite(
            userId: userId.uuidString,
            navUnitId: record.navUnitId,
            isFavorite: record.isFavorite,
            deviceId: record.deviceId,
            navUnitName: record.navUnitName,
            latitude: record.latitude,
            longitude: record.longitude,
            facilityType: record.facilityType
        )
    }
    
    // MARK: - Conversion Methods
    
    /// Convert to local NavUnitFavoriteRecord
    func toLocalRecord() -> NavUnitFavoriteRecord {
        return NavUnitFavoriteRecord(
            userId: userId,
            navUnitId: navUnitId,
            isFavorite: isFavorite,
            lastModified: lastModified,
            deviceId: deviceId,
            navUnitName: navUnitName,
            latitude: latitude,
            longitude: longitude,
            facilityType: facilityType
        )
    }
    
    /// Convert to display NavUnit
    func toNavUnit() -> NavUnit {
        return NavUnit(
            navUnitId: navUnitId,
            unloCode: nil,
            navUnitName: navUnitName ?? "Unknown Navigation Unit",
            locationDescription: nil,
            facilityType: facilityType,
            streetAddress: nil,
            cityOrTown: nil,
            statePostalCode: nil,
            zipCode: nil,
            countyName: nil,
            countyFipsCode: nil,
            congress: nil,
            congressFips: nil,
            waterwayName: nil,
            portName: nil,
            mile: nil,
            bank: nil,
            latitude: latitude ?? 0.0,
            longitude: longitude ?? 0.0,
            operators: nil,
            owners: nil,
            purpose: nil,
            highwayNote: nil,
            railwayNote: nil,
            location: nil,
            dock: nil,
            commodities: nil,
            construction: nil,
            mechanicalHandling: nil,
            remarks: nil,
            verticalDatum: nil,
            depthMin: nil,
            depthMax: nil,
            berthingLargest: nil,
            berthingTotal: nil,
            deckHeightMin: nil,
            deckHeightMax: nil,
            serviceInitiationDate: nil,
            serviceTerminationDate: nil,
            isFavorite: isFavorite
        )
    }
}

// MARK: - Extensions for Debugging

extension RemoteNavUnitFavorite: CustomStringConvertible {
    var description: String {
        return "RemoteNavUnitFavorite(id: \(id?.uuidString ?? "nil"), navUnitId: \(navUnitId), isFavorite: \(isFavorite), name: \(navUnitName ?? "nil"))"
    }
}
