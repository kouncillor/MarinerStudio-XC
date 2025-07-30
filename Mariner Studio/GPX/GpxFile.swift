//
//  GpxFile.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//

import Foundation

/// Main GPX file container model
struct GpxFile: Codable {
    var route: GpxRoute

    enum CodingKeys: String, CodingKey {
        case route = "rte"
    }
}

/// GPX Route model
struct GpxRoute: Codable {
    var name: String
    var routePoints: [GpxRoutePoint]
    var totalDistance: Double = 0.0
    var averageSpeed: Double = 0.0

    enum CodingKeys: String, CodingKey {
        case name
        case routePoints = "rtept"
    }
}

/// GPX Route Point model
struct GpxRoutePoint: Codable, Identifiable {
    var id = UUID()
    var latitude: Double
    var longitude: Double
    var name: String?
    var eta: Date = Date()
    var distanceToNext: Double = 0.0
    var bearingToNext: Double = 0.0

    enum CodingKeys: String, CodingKey {
        case latitude = "lat"
        case longitude = "lon"
        case name
    }
}

extension GpxRoutePoint {
    var coordinates: String {
        return "\(String(format: "%.6f", latitude))°, \(String(format: "%.6f", longitude))°"
    }
}
