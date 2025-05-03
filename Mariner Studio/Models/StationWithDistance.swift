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
    static func create<S>(station: S, userLocation: CLLocation?) -> StationWithDistance<S> where S: Identifiable, S: StationCoordinates {
        let distance: Double

        // First, unwrap the user's location
        if let userLocation = userLocation {
            // Now, safely unwrap the station's coordinates
            // This is the new part to fix the error
            if let stationLatitude = station.latitude, let stationLongitude = station.longitude {
                // If both coordinates exist, create the station location
                let stationLocation = CLLocation(
                    latitude: stationLatitude, // Use the unwrapped latitude
                    longitude: stationLongitude // Use the unwrapped longitude
                )
                distance = stationLocation.distance(from: userLocation) / 1000 // Convert to km
            } else {
                // Handle the case where station coordinates are missing (e.g., set distance to infinite)
                print("Station \(station.id) is missing coordinates, cannot calculate distance.")
                distance = Double.greatestFiniteMagnitude // Cannot calculate distance if station has no coordinates
            }
        } else {
            // User location is missing, cannot calculate distance
            print("User location is nil, cannot calculate distance.")
            distance = Double.greatestFiniteMagnitude
        }

        return StationWithDistance<S>(station: station, distanceFromUser: distance)
    }
    
    
    
    
    
    
    
    
}
