// TidalCurrentStation.swift

import Foundation

struct TidalCurrentStation: Identifiable, Codable {
    // MARK: - Properties
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
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
        // isFavorite is not included as it will be set locally, not decoded from API
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
