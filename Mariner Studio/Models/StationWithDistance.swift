import Foundation
import CoreLocation

struct StationWithDistance<T>: Identifiable where T: Identifiable {
    // MARK: - Properties
    let station: T
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
        
        if let userLocation = userLocation {
            let stationLocation = CLLocation(
                latitude: station.latitude,
                longitude: station.longitude
            )
            distance = stationLocation.distance(from: userLocation) / 1000 // Convert to km
        } else {
            distance = Double.greatestFiniteMagnitude
        }
        
        return StationWithDistance<S>(station: station, distanceFromUser: distance)
    }
}

// Protocol for any station type that has coordinates
protocol StationCoordinates {
    var latitude: Double { get }
    var longitude: Double { get }
}

// Make TidalHeightStation conform to StationCoordinates
extension TidalHeightStation: StationCoordinates {}
