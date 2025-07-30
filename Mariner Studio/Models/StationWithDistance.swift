import Foundation
import CoreLocation

struct StationWithDistance<T>: Identifiable where T: Identifiable {
    // MARK: - Properties
    let station: T  // This is a 'let' constant, so we can't modify its properties directly
    let distanceFromUser: Double

    // MARK: - Computed Properties
    var id: T.ID {
        return station.id
    }

    var distanceDisplay: String {
        if distanceFromUser == Double.greatestFiniteMagnitude {
            return ""
        }

        let miles = distanceFromUser * 0.621371 // Convert km to miles
        return String(format: "%.1f mi", miles)
    }

    // MARK: - Initialization
    init(station: T, distanceFromUser: Double) {
        self.station = station
        self.distanceFromUser = distanceFromUser
    }

    // MARK: - Factory Method for Creating from Coordinates
    // In StationWithDistance.swift - Fix the create method to safely unwrap optionals
    static func create<S>(station: S, userLocation: CLLocation?) -> StationWithDistance<S> where S: Identifiable, S: StationCoordinates {
        let distance: Double

        // First, unwrap the user's location
        if let userLocation = userLocation {
            // Now, safely unwrap the station's coordinates
            if let stationLatitude = station.latitude, let stationLongitude = station.longitude {
                // If both coordinates exist, create the station location
                let stationLocation = CLLocation(
                    latitude: stationLatitude,
                    longitude: stationLongitude
                )
                distance = stationLocation.distance(from: userLocation) / 1000 // Convert to km
            } else {
                // Handle the case where station coordinates are missing
                distance = Double.greatestFiniteMagnitude
            }
        } else {
            // User location is missing, cannot calculate distance
            distance = Double.greatestFiniteMagnitude
        }

        return StationWithDistance<S>(station: station, distanceFromUser: distance)
    }

}
