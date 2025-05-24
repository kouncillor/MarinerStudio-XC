// Create a new file or add to an existing one:
// Mariner Studio/Models/RoutePoint.swift

import Foundation

struct RoutePoint: Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var eta: Date = Date()
    var distanceToNext: Double = 0.0
    var bearingToNext: Double = 0.0
    
    // Implementation of Equatable
    static func == (lhs: RoutePoint, rhs: RoutePoint) -> Bool {
        return lhs.name == rhs.name &&
               lhs.latitude == rhs.latitude &&
               lhs.longitude == rhs.longitude &&
               lhs.eta == rhs.eta &&
               lhs.distanceToNext == rhs.distanceToNext &&
               lhs.bearingToNext == rhs.bearingToNext
    }
}
