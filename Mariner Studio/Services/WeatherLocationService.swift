import Foundation
import CoreLocation
import Combine

/// Protocol defining the location manager interface for weather services
protocol WeatherLocationService {
    /// The current location of the user, if available
    var currentLocation: CLLocation? { get }
    
    /// Get the current location of the user
    /// - Parameter completion: A closure that will be called with the result
    func getCurrentLocation(completion: @escaping (Result<CLLocation, Error>) -> Void)
    
    /// Start updating location
    func startLocationUpdates()
    
    /// Stop updating location
    func stopLocationUpdates()
    
    /// Calculate distance between two coordinates in kilometers
    func calculateDistance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double
}

/// Implementation of the location manager for weather services
class WeatherLocationManager: NSObject, WeatherLocationService, CLLocationManagerDelegate {
    // MARK: - Properties
    private let locationManager = CLLocationManager()
    private var locationCompletion: ((Result<CLLocation, Error>) -> Void)?
    
    /// The current location of the user, if available
    private(set) var currentLocation: CLLocation?
    
    /// Publisher for location updates
    let locationPublisher = PassthroughSubject<CLLocation, Never>()
    
    /// Publisher for location errors
    let locationErrorPublisher = PassthroughSubject<Error, Never>()
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update if device moves by 100 meters
    }
    
    // MARK: - WeatherLocationService Methods
    
    /// Request the current location from the device
    /// - Parameter completion: A closure that will be called with the result
    func getCurrentLocation(completion: @escaping (Result<CLLocation, Error>) -> Void) {
        // If we already have a location, return it immediately
        if let currentLocation = currentLocation {
            let locationAge = -currentLocation.timestamp.timeIntervalSinceNow
            if locationAge < 300 { // Less than 5 minutes old
                completion(.success(currentLocation))
                return
            }
        }
        
        // Check authorization status
        let status = locationManager.authorizationStatus
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // Store the completion handler to be called when we get a location
            locationCompletion = completion
            
            // Start updating location
            locationManager.requestLocation()
            
        case .notDetermined:
            // Request permission first
            locationCompletion = completion
            locationManager.requestWhenInUseAuthorization()
            
        case .denied, .restricted:
            // Permission denied, return error
            let error = NSError(
                domain: "WeatherLocationManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Location permission denied or restricted"]
            )
            completion(.failure(error))
            
        @unknown default:
            // Unknown status, return error
            let error = NSError(
                domain: "WeatherLocationManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unknown location authorization status"]
            )
            completion(.failure(error))
        }
    }
    
    /// Start continuous location updates
    func startLocationUpdates() {
        // Check authorization status
        let status = locationManager.authorizationStatus
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    /// Stop continuous location updates
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    /// Calculate distance between two coordinates in kilometers
    /// - Parameters:
    ///   - source: The source coordinate
    ///   - destination: The destination coordinate
    /// - Returns: The distance in kilometers
    func calculateDistance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
        let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        
        let distanceInMeters = sourceLocation.distance(from: destinationLocation)
        return distanceInMeters / 1000 // Convert to kilometers
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out old or inaccurate locations
        let howRecent = location.timestamp.timeIntervalSinceNow
        guard abs(howRecent) < 15.0 else { return }
        
        guard location.horizontalAccuracy >= 0 else { return }
        guard location.horizontalAccuracy < 100 else { return }
        
        // Store the location
        currentLocation = location
        
        // Publish the location update
        locationPublisher.send(location)
        
        // If we have a completion handler, call it
        if let completion = locationCompletion {
            completion(.success(location))
            locationCompletion = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location error: \(error.localizedDescription)")
        
        // Publish the error
        locationErrorPublisher.send(error)
        
        // If we have a completion handler, call it with the error
        if let completion = locationCompletion {
            completion(.failure(error))
            locationCompletion = nil
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            
        case .denied, .restricted:
            // Publish an error
            let error = NSError(
                domain: "WeatherLocationManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Location permission denied or restricted"]
            )
            locationErrorPublisher.send(error)
            
            // If we have a completion handler, call it with the error
            if let completion = locationCompletion {
                completion(.failure(error))
                locationCompletion = nil
            }
            
        case .notDetermined:
            // Wait for user's decision
            break
            
        @unknown default:
            break
        }
    }
}
