//
//
//// TidalCurrentStation.swift
//
//import Foundation
//
//struct TidalCurrentStation: Identifiable, Codable {
//    // MARK: - Properties
//    let id: String
//    let name: String
//    let latitude: Double?
//    let longitude: Double?
//    let state: String?
//    let type: String
//    let depth: Double?
//    let depthType: String?
//    let currentBin: Int?
//    let timezoneOffset: String?
//    let currentPredictionOffsets: CurrentPredictionOffsets?
//    let harmonicConstituents: HarmonicConstituents?
//    let selfUrl: String?
//    let expand: String?
//    var isFavorite: Bool = false
//    
//    // Add a computed property for a unique ID that combines station ID and bin
//    var uniqueId: String {
//        if let bin = currentBin {
//            return "\(id)_\(bin)"
//        } else {
//            return id
//        }
//    }
//    
//    // MARK: - Coding Keys
//    enum CodingKeys: String, CodingKey {
//        case id
//        case name
//        case latitude = "lat"
//        case longitude = "lng"
//        case state
//        case type
//        case depth
//        case depthType
//        case currentBin = "currbin"
//        case timezoneOffset = "timezone_offset"
//        case currentPredictionOffsets = "currentpredictionoffsets"
//        case harmonicConstituents = "harmonicConstituents"
//        case selfUrl = "self"
//        case expand
//        // isFavorite is not included as it will be set locally, not decoded from API
//    }
//}
//
//// MARK: - Supporting Types
//struct CurrentPredictionOffsets: Codable {
//    let selfUrl: String
//    
//    enum CodingKeys: String, CodingKey {
//        case selfUrl = "self"
//    }
//}
//
//struct HarmonicConstituents: Codable {
//    let selfUrl: String
//    
//    enum CodingKeys: String, CodingKey {
//        case selfUrl = "self"
//    }
//}
//
//// MARK: - Extensions
//extension TidalCurrentStation: StationCoordinates {
//    // The protocol implementation is empty because
//    // TidalCurrentStation already has latitude and longitude properties
//    // that satisfy the protocol requirements
//}






// TidalCurrentStation.swift

import Foundation

struct TidalCurrentStation: Identifiable, Codable {
    // MARK: - Properties
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let state: String?
    let type: String
    let depth: Double?
    let depthType: String?
    let currentBin: Int?
    let timezoneOffset: String?
    let currentPredictionOffsets: CurrentPredictionOffsets?
    let harmonicConstituents: HarmonicConstituents?
    let selfUrl: String?
    let expand: String?
    var isFavorite: Bool = false
    
    // Distance from user (calculated at runtime, not stored in API)
    var distanceFromUser: Double?
    
    // Add a computed property for a unique ID that combines station ID and bin
    var uniqueId: String {
        if let bin = currentBin {
            return "\(id)_\(bin)"
        } else {
            return id
        }
    }
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case latitude = "lat"
        case longitude = "lng"
        case state
        case type
        case depth
        case depthType
        case currentBin = "currbin"
        case timezoneOffset = "timezone_offset"
        case currentPredictionOffsets = "currentpredictionoffsets"
        case harmonicConstituents = "harmonicConstituents"
        case selfUrl = "self"
        case expand
        // isFavorite and distanceFromUser are not included as they are set locally, not decoded from API
    }
    
    // MARK: - Custom Initializers
    
    /// Initialize from API data (distance will be nil)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        type = try container.decode(String.self, forKey: .type)
        depth = try container.decodeIfPresent(Double.self, forKey: .depth)
        depthType = try container.decodeIfPresent(String.self, forKey: .depthType)
        currentBin = try container.decodeIfPresent(Int.self, forKey: .currentBin)
        timezoneOffset = try container.decodeIfPresent(String.self, forKey: .timezoneOffset)
        currentPredictionOffsets = try container.decodeIfPresent(CurrentPredictionOffsets.self, forKey: .currentPredictionOffsets)
        harmonicConstituents = try container.decodeIfPresent(HarmonicConstituents.self, forKey: .harmonicConstituents)
        selfUrl = try container.decodeIfPresent(String.self, forKey: .selfUrl)
        expand = try container.decodeIfPresent(String.self, forKey: .expand)
        
        // These are set locally, not from API
        isFavorite = false
        distanceFromUser = nil
    }
    
    /// Initialize with all parameters (useful for creating from database records)
    init(
        id: String,
        name: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        state: String? = nil,
        type: String,
        depth: Double? = nil,
        depthType: String? = nil,
        currentBin: Int? = nil,
        timezoneOffset: String? = nil,
        currentPredictionOffsets: CurrentPredictionOffsets? = nil,
        harmonicConstituents: HarmonicConstituents? = nil,
        selfUrl: String? = nil,
        expand: String? = nil,
        isFavorite: Bool = false,
        distanceFromUser: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.state = state
        self.type = type
        self.depth = depth
        self.depthType = depthType
        self.currentBin = currentBin
        self.timezoneOffset = timezoneOffset
        self.currentPredictionOffsets = currentPredictionOffsets
        self.harmonicConstituents = harmonicConstituents
        self.selfUrl = selfUrl
        self.expand = expand
        self.isFavorite = isFavorite
        self.distanceFromUser = distanceFromUser
    }
    
    // MARK: - Convenience Methods
    
    /// Create a copy with updated distance
    func withDistance(_ distance: Double?) -> TidalCurrentStation {
        var copy = self
        copy.distanceFromUser = distance
        return copy
    }
    
    /// Create a copy with updated favorite status
    func withFavoriteStatus(_ isFavorite: Bool) -> TidalCurrentStation {
        var copy = self
        copy.isFavorite = isFavorite
        return copy
    }
    
    /// Format distance for display
    var formattedDistance: String {
        if let distance = distanceFromUser {
            if distance < 1.0 {
                return String(format: "%.2f mi", distance)
            } else {
                return String(format: "%.1f mi", distance)
            }
        } else {
            return "Distance unknown"
        }
    }
    
    /// Check if station has valid coordinates
    var hasValidCoordinates: Bool {
        return latitude != nil && longitude != nil
    }
    
    /// Get formatted depth string
    var formattedDepth: String? {
        guard let depth = depth else { return nil }
        
        if let depthType = depthType, !depthType.isEmpty {
            return String(format: "%.1f ft (%@)", depth, depthType)
        } else {
            return String(format: "%.1f ft", depth)
        }
    }
}

// MARK: - Supporting Types
struct CurrentPredictionOffsets: Codable {
    let selfUrl: String
    
    enum CodingKeys: String, CodingKey {
        case selfUrl = "self"
    }
}

struct HarmonicConstituents: Codable {
    let selfUrl: String
    
    enum CodingKeys: String, CodingKey {
        case selfUrl = "self"
    }
}

// MARK: - Extensions
extension TidalCurrentStation: StationCoordinates {
    // The protocol implementation is empty because
    // TidalCurrentStation already has latitude and longitude properties
    // that satisfy the protocol requirements
}

// MARK: - Equatable Support
extension TidalCurrentStation: Equatable {
    static func == (lhs: TidalCurrentStation, rhs: TidalCurrentStation) -> Bool {
        return lhs.id == rhs.id && lhs.currentBin == rhs.currentBin
    }
}

// MARK: - Hashable Support
extension TidalCurrentStation: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(currentBin)
    }
}
