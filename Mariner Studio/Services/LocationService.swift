import Foundation
import CoreLocation

enum LocationPermissionStatus {
    case notDetermined
    case restricted
    case denied
    case authorizedAlways
    case authorizedWhenInUse
    case unknown
    
    var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always Authorized"
        case .authorizedWhenInUse: return "Authorized When In Use"
        case .unknown: return "Unknown"
        }
    }
}

protocol LocationService {
    /// The current status of location permissions
    var permissionStatus: LocationPermissionStatus { get }
    
    /// The current user location, if available
    var currentLocation: CLLocation? { get }
    
    /// Request permission to use location services
    func requestLocationPermission() async -> Bool
    
    /// Start updating location
    func startUpdatingLocation()
    
    /// Stop updating location
    func stopUpdatingLocation()
    
    /// Calculate distance between two coordinates in kilometers
    func calculateDistance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double
    
    /// Calculate distance between a location and the current user location
    func distanceFromUser(to coordinate: CLLocationCoordinate2D) -> Double?
}
