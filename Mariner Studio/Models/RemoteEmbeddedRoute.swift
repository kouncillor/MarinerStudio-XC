import Foundation

/// Model for remote embedded routes from Supabase
/// Used only for public route downloads - no authentication required
struct RemoteEmbeddedRoute: Codable, Identifiable {
    let id: UUID?
    let name: String
    let description: String?
    let category: String?
    let region: String?
    let difficulty: String?
    let gpx_data: String?
    let is_active: Bool
    let created_at: Date
    let updated_at: Date?
    let total_distance: Double?
    let waypoint_count: Int?
    let estimated_duration_hours: Double?
    
    // Computed properties for compatibility
    var gpxData: String {
        return gpx_data ?? ""
    }
    
    var totalDistance: Double {
        return total_distance ?? 0.0
    }
    
    var waypointCount: Int {
        return waypoint_count ?? 0
    }
    
    var estimatedDurationHours: Double? {
        return estimated_duration_hours
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case category
        case region
        case difficulty
        case gpx_data
        case is_active
        case created_at
        case updated_at
        case total_distance
        case waypoint_count
        case estimated_duration_hours
    }
}