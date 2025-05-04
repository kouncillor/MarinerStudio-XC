import Foundation
import CoreLocation

/// Represents the current state of location accuracy
enum LocationAccuracyState: Equatable {
    /// No location available yet
    case unavailable
    
    /// Using a cached location (might be old)
    case cached(location: CLLocation, age: TimeInterval)
    
    /// Using a low accuracy location (> 100m accuracy)
    case lowAccuracy(location: CLLocation, accuracy: Double)
    
    /// Using a medium accuracy location (between 100m and 50m accuracy)
    case mediumAccuracy(location: CLLocation, accuracy: Double)
    
    /// Using a high accuracy location (< 50m accuracy)
    case highAccuracy(location: CLLocation, accuracy: Double)
    
    /// Location services are disabled or denied
    case disabled
    
    /// Human-readable description of the current state
    var description: String {
        switch self {
        case .unavailable:
            return "Determining your location..."
        case .cached(_, let age):
            let minutes = Int(age / 60)
            return "Using cached location from \(minutes) minutes ago"
        case .lowAccuracy(_, let accuracy):
            return "Low accuracy location (±\(Int(accuracy))m)"
        case .mediumAccuracy(_, let accuracy):
            return "Medium accuracy location (±\(Int(accuracy))m)"
        case .highAccuracy(_, let accuracy):
            return "High accuracy location (±\(Int(accuracy))m)"
        case .disabled:
            return "Location services unavailable"
        }
    }
    
    /// Returns the location associated with this state, if available
    var location: CLLocation? {
        switch self {
        case .unavailable, .disabled:
            return nil
        case .cached(let location, _),
             .lowAccuracy(let location, _),
             .mediumAccuracy(let location, _),
             .highAccuracy(let location, _):
            return location
        }
    }
    
    /// Returns true if this state has a usable location
    var hasLocation: Bool {
        return location != nil
    }
    
    /// Returns true if this state is the best possible accuracy
    var isBestPossible: Bool {
        if case .highAccuracy = self {
            return true
        }
        return false
    }
}
