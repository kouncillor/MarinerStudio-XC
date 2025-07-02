//
//  RemoteEmbeddedRoute.swift
//  Mariner Studio
//
//  Created for embedded route synchronization with Supabase.
//

import Foundation

struct RemoteEmbeddedRoute: Codable, Identifiable, Hashable {
    let id: UUID?
    let name: String
    let description: String?
    let gpxData: String
    let waypointCount: Int
    let totalDistance: Float
    let startLatitude: Float
    let startLongitude: Float
    let startName: String?
    let endLatitude: Float
    let endLongitude: Float
    let endName: String?
    let category: String?
    let difficulty: String?
    let region: String?
    let estimatedDurationHours: Float?
    let createdAt: Date?
    let updatedAt: Date?
    let isActive: Bool?
    let bboxNorth: Float?
    let bboxSouth: Float?
    let bboxEast: Float?
    let bboxWest: Float?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case gpxData = "gpx_data"
        case waypointCount = "waypoint_count"
        case totalDistance = "total_distance"
        case startLatitude = "start_latitude"
        case startLongitude = "start_longitude"
        case startName = "start_name"
        case endLatitude = "end_latitude"
        case endLongitude = "end_longitude"
        case endName = "end_name"
        case category
        case difficulty
        case region
        case estimatedDurationHours = "estimated_duration_hours"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isActive = "is_active"
        case bboxNorth = "bbox_north"
        case bboxSouth = "bbox_south"
        case bboxEast = "bbox_east"
        case bboxWest = "bbox_west"
    }
}