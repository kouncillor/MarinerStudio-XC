
//
//  RemoteCurrentFavorite.swift
//  Mariner
//
//  Created by Swift Developer on 2025-06-27.
//

import Foundation

/// Remote current station favorite model matching the Supabase `user_current_favorites` table schema.
struct RemoteCurrentFavorite: Codable, Identifiable {
    var id: UUID?
    let userId: UUID
    let stationId: String
    let currentBin: Int
    let isFavorite: Bool
    let lastModified: Date
    let deviceId: String
    
    // Optional station metadata that can be synced
    let stationName: String?
    let latitude: Double?
    let longitude: Double?
    let depth: Double?
    let depthType: String?

    // Coding keys to map Swift properties to database column names
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case stationId = "station_id"
        case currentBin = "current_bin"
        case isFavorite = "is_favorite"
        case lastModified = "last_modified"
        case deviceId = "device_id"
        case stationName = "station_name"
        case latitude
        case longitude
        case depth
        // THIS IS THE FIX: Map 'depthType' to 'depth_type'
        case depthType = "depth_type"
    }
}
