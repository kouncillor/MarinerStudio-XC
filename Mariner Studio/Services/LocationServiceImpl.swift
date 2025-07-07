import Foundation
import CoreLocation


class LocationServiceImpl: NSObject, LocationService, CLLocationManagerDelegate {
    // MARK: - Properties
    private let locationManager = CLLocationManager()
    var locationUpdateHandler: ((CLLocation) -> Void)?

    private(set) var currentLocation: CLLocation? // Can be read publicly, but only set privately
    
    // Store the last known location, even if it's not the most accurate
    private var lastKnownLocation: CLLocation? {
        didSet {
            // If we don't have a better location yet, use this as current
            if currentLocation == nil {
                currentLocation = lastKnownLocation
            }
        }
    }

    var permissionStatus: LocationPermissionStatus {
        // Convert CoreLocation status to our custom enum
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedAlways:
            return .authorizedAlways
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        @unknown default:
            return .unknown
        }
    }

    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
        DebugLogger.shared.log("📍 LocationServiceImpl Initialized. Delegate set.", category: "LOCATION_INIT")
    }

    private func setupLocationManager() {
        locationManager.delegate = self // Essential: Make sure the delegate is self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update if device moves by 10 meters - changed from kCLDistanceFilterNone
    }

    
    
    func requestLocationPermission() async -> Bool {
        DebugLogger.shared.log("📍 LocationServiceImpl: requestLocationPermission called. Current status: \(permissionStatus.description)", category: "LOCATION_PERMISSION")

        return await withCheckedContinuation { [weak self] continuation in
            guard let self = self else {
                DebugLogger.shared.log("📍 LocationServiceImpl: Self is nil in request permission continuation.", category: "LOCATION_PERMISSION")
                continuation.resume(returning: false)
                return
            }
            
            // Move to the main thread if needed
            Task { @MainActor in
                switch self.locationManager.authorizationStatus {
                case .authorizedWhenInUse, .authorizedAlways:
                    DebugLogger.shared.log("📍 LocationServiceImpl: Permission already granted.", category: "LOCATION_PERMISSION")
                    continuation.resume(returning: true)
                case .notDetermined:
                    DebugLogger.shared.log("📍 LocationServiceImpl: Requesting 'When In Use' authorization...", category: "LOCATION_PERMISSION")
                    self.onAuthorizationStatusChanged = { status in
                        self.onAuthorizationStatusChanged = nil
                        let authorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
                        DebugLogger.shared.log("📍 LocationServiceImpl: Authorization status changed to \(status.rawValue). Authorized: \(authorized)", category: "LOCATION_PERMISSION")
                        continuation.resume(returning: authorized)
                    }
                    self.locationManager.requestWhenInUseAuthorization()
                case .denied, .restricted:
                    DebugLogger.shared.log("📍 LocationServiceImpl: Permission denied or restricted.", category: "LOCATION_PERMISSION")
                    continuation.resume(returning: false)
                @unknown default:
                    DebugLogger.shared.log("📍 LocationServiceImpl: Unknown authorization status.", category: "LOCATION_PERMISSION")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    
    
    
    
    
    
    func startUpdatingLocation() {
        DebugLogger.shared.log("📍 LocationServiceImpl: startUpdatingLocation() called.", category: "LOCATION_UPDATES")
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        DebugLogger.shared.log("📍 LocationServiceImpl: stopUpdatingLocation() called.", category: "LOCATION_UPDATES")
        locationManager.stopUpdatingLocation()
    }

    func calculateDistance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
        let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        return sourceLocation.distance(from: destinationLocation) / 1000 // Convert to kilometers
    }

    func distanceFromUser(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let userLocation = currentLocation else {
            return nil
        }
        let destinationLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return userLocation.distance(from: destinationLocation) / 1000 // Convert to kilometers
    }

    // MARK: - CLLocationManagerDelegate Methods

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            DebugLogger.shared.log("‼️ LocationServiceImpl (didUpdateLocations): Called but locations array was empty.", category: "LOCATION_UPDATES")
            return
        }

        // Print details of the received location
        DebugLogger.shared.log("📍 LocationServiceImpl (didUpdateLocations): Received location - Lat: \(location.coordinate.latitude), Lon: \(location.coordinate.longitude), Acc: \(location.horizontalAccuracy)m, Time: \(location.timestamp)", category: "LOCATION_UPDATES")

        // Always update lastKnownLocation with the latest reading
        lastKnownLocation = location
        
        // Apply a simpler filtering approach - negative accuracy is invalid
        guard location.horizontalAccuracy >= 0 else {
            DebugLogger.shared.log("📍 LocationServiceImpl (didUpdateLocations): Ignoring location with negative accuracy.", category: "LOCATION_UPDATES")
            return
        }

        // Prioritize recent locations with good accuracy
        let locationAge = -location.timestamp.timeIntervalSinceNow
        
        // If we don't have any location yet, use this one regardless of accuracy
        if currentLocation == nil {
            DebugLogger.shared.log("📍 LocationServiceImpl: First location received, using it.", category: "LOCATION_UPDATES")
            currentLocation = location
            locationUpdateHandler?(location)
            return
        }
        
        // If the location is recent and accurate, update our current location
        if locationAge < 60 && location.horizontalAccuracy <= 100 {
            // Check if this is better than our current location
            if let current = currentLocation,
               location.horizontalAccuracy < current.horizontalAccuracy ||
               current.horizontalAccuracy > 100 {
                DebugLogger.shared.log("📍 LocationServiceImpl: Better location received (more accurate), updating currentLocation.", category: "LOCATION_UPDATES")
                currentLocation = location
                locationUpdateHandler?(location)
            }
        } else if locationAge < 10 {
            // Even if accuracy isn't great, update if it's very recent and we have a poor current location
            if let current = currentLocation, current.horizontalAccuracy > 100 {
                DebugLogger.shared.log("📍 LocationServiceImpl: Recent location received, updating currentLocation.", category: "LOCATION_UPDATES")
                currentLocation = location
                locationUpdateHandler?(location)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Log errors
        DebugLogger.shared.log("‼️ LocationServiceImpl: locationManager failed with error: \(error.localizedDescription)", category: "LOCATION_ERROR")
        // You might want to set currentLocation to nil or handle specific errors (like kCLErrorDenied)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // This is the modern delegate method for authorization changes
        let status = manager.authorizationStatus
        DebugLogger.shared.log("📍 LocationServiceImpl: locationManagerDidChangeAuthorization delegate called. New status: \(status.rawValue) (\(permissionStatus.description))", category: "LOCATION_PERMISSION")
        // Call the temporary handler if it exists (used by requestLocationPermission)
        onAuthorizationStatusChanged?(status)
    }


    // MARK: - Callback Handlers (For requestLocationPermission continuation)
    private var onAuthorizationStatusChanged: ((CLAuthorizationStatus) -> Void)?
}
