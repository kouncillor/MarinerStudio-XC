import Foundation
import CoreLocation

class GeocodingServiceImpl: GeocodingService {
    // MARK: - Properties
    private let geocoder = CLGeocoder()

    // MARK: - GeocodingService Methods

    /// Reverse geocodes coordinates to a place name
    /// - Parameters:
    ///   - latitude: The latitude coordinate
    ///   - longitude: The longitude coordinate
    /// - Returns: A GeocodingResponse containing location information
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> GeocodingResponse {
        // Create a CLLocation from the coordinates
        let location = CLLocation(latitude: latitude, longitude: longitude)

        do {
            // Use Apple's geocoder to reverse geocode the location
            let placemarks = try await geocoder.reverseGeocodeLocation(location)

            // Format the results
            var results: [GeocodingResponse.Result] = []

            for placemark in placemarks {
                // Get the locality (city/town) and administrative area (state/province)
                let name = placemark.locality ?? placemark.name ?? "Unknown Location"

                // Get the state abbreviation or full name
                let state = placemark.administrativeArea ?? ""

                // Create a result object
                let result = GeocodingResponse.Result(
                    name: name,
                    state: state
                )

                results.append(result)
            }

            // If no results were found, return a default "Unknown Location"
            if results.isEmpty {
                results.append(
                    GeocodingResponse.Result(
                        name: "Unknown Location",
                        state: ""
                    )
                )
            }

            return GeocodingResponse(results: results)
        } catch {
            print("🔍 Geocoding error: \(error.localizedDescription)")

            // In case of error, create a fallback response with coordinates
            let formattedLatitude = String(format: "%.4f", latitude)
            let formattedLongitude = String(format: "%.4f", longitude)

            let result = GeocodingResponse.Result(
                name: "Location \(formattedLatitude),\(formattedLongitude)",
                state: ""
            )

            return GeocodingResponse(results: [result])
        }
    }

    /// Forward geocodes a place name to coordinates
    /// - Parameter address: The address or place name to geocode
    /// - Returns: A GeocodingResponse containing location information
    func forwardGeocode(address: String) async throws -> GeocodingResponse {
        do {
            // Use Apple's geocoder to forward geocode the address
            let placemarks = try await geocoder.geocodeAddressString(address)

            // Format the results
            var results: [GeocodingResponse.Result] = []

            for placemark in placemarks {
                // Get the locality (city/town) and administrative area (state/province)
                let name = placemark.locality ?? placemark.name ?? "Unknown Location"

                // Get the state abbreviation or full name
                let state = placemark.administrativeArea ?? ""

                // Create a result object
                let result = GeocodingResponse.Result(
                    name: name,
                    state: state
                )

                results.append(result)
            }

            // If no results were found, return a default error result
            if results.isEmpty {
                results.append(
                    GeocodingResponse.Result(
                        name: "No results found for \(address)",
                        state: ""
                    )
                )
            }

            return GeocodingResponse(results: results)
        } catch {
            print("🔍 Forward geocoding error: \(error.localizedDescription)")

            // In case of error, create a fallback response
            let result = GeocodingResponse.Result(
                name: "Unable to geocode \(address)",
                state: ""
            )

            return GeocodingResponse(results: [result])
        }
    }
}
