//
//  BuoyStation.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//


import Foundation

struct BuoyStation: Identifiable, Codable {
    // MARK: - Properties
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let elevation: Double?
    let type: String
    let meteorological: String?
    let currents: String?
    let waterQuality: String?
    let dart: String?
    var isFavorite: Bool = false
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case latitude = "lat"
        case longitude = "lon"
        case elevation = "elev"
        case type
        case meteorological = "met"
        case currents
        case waterQuality = "waterquality"
        case dart
        // isFavorite is not included as it will be set locally, not decoded from API
    }
}

// MARK: - Response Container
struct BuoyStationResponse: Codable {
    let stations: [BuoyStation]
}

// MARK: - Extension for StationCoordinates
extension BuoyStation: StationCoordinates {
    // The protocol implementation is empty because
    // BuoyStation already has latitude and longitude properties
    // that satisfy the protocol requirements
}