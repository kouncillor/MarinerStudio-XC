import Foundation
import CoreLocation

protocol GeocodingService {
    /// Reverse geocodes coordinates to a place name
    /// - Parameters:
    ///   - latitude: The latitude coordinate
    ///   - longitude: The longitude coordinate
    /// - Returns: A GeocodingResponse containing location information
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> GeocodingResponse
    
    /// Forward geocodes a place name to coordinates
    /// - Parameter address: The address or place name to geocode
    /// - Returns: A GeocodingResponse containing location information
    func forwardGeocode(address: String) async throws -> GeocodingResponse
}

/// Response structure for geocoding operations
struct GeocodingResponse {
    struct Result {
        let name: String
        let state: String
    }
    
    let results: [Result]
}
