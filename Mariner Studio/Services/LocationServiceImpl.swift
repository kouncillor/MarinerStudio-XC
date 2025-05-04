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
        print("📍 LocationServiceImpl Initialized. Delegate set.") // Log init
    }

    private func setupLocationManager() {
        locationManager.delegate = self // Essential: Make sure the delegate is self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update if device moves by 10 meters - changed from kCLDistanceFilterNone
    }

    
    
    func requestLocationPermission() async -> Bool {
        print("📍 LocationServiceImpl: requestLocationPermission called. Current status: \(permissionStatus.description)")

        return await withCheckedContinuation { [weak self] continuation in
            guard let self = self else {
                print("📍 LocationServiceImpl: Self is nil in request permission continuation.")
                continuation.resume(returning: false)
                return
            }
            
            // Move to the main thread if needed
            Task { @MainActor in
                switch self.locationManager.authorizationStatus {
                case .authorizedWhenInUse, .authorizedAlways:
                    print("📍 LocationServiceImpl: Permission already granted.")
                    continuation.resume(returning: true)
                case .notDetermined:
                    print("📍 LocationServiceImpl: Requesting 'When In Use' authorization...")
                    self.onAuthorizationStatusChanged = { status in
                        self.onAuthorizationStatusChanged = nil
                        let authorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
                        print("📍 LocationServiceImpl: Authorization status changed to \(status.rawValue). Authorized: \(authorized)")
                        continuation.resume(returning: authorized)
                    }
                    self.locationManager.requestWhenInUseAuthorization()
                case .denied, .restricted:
                    print("📍 LocationServiceImpl: Permission denied or restricted.")
                    continuation.resume(returning: false)
                @unknown default:
                    print("📍 LocationServiceImpl: Unknown authorization status.")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    
    
    
    
    
    
    func startUpdatingLocation() {
        print("📍 LocationServiceImpl: startUpdatingLocation() called.")
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        print("📍 LocationServiceImpl: stopUpdatingLocation() called.")
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
            print("‼️ LocationServiceImpl (didUpdateLocations): Called but locations array was empty.")
            return
        }

        // Print details of the received location
        print("📍 LocationServiceImpl (didUpdateLocations): Received location - Lat: \(location.coordinate.latitude), Lon: \(location.coordinate.longitude), Acc: \(location.horizontalAccuracy)m, Time: \(location.timestamp)")

        // Always update lastKnownLocation with the latest reading
        lastKnownLocation = location
        
        // Apply a simpler filtering approach - negative accuracy is invalid
        guard location.horizontalAccuracy >= 0 else {
            print("📍 LocationServiceImpl (didUpdateLocations): Ignoring location with negative accuracy.")
            return
        }

        // Prioritize recent locations with good accuracy
        let locationAge = -location.timestamp.timeIntervalSinceNow
        
        // If we don't have any location yet, use this one regardless of accuracy
        if currentLocation == nil {
            print("📍 LocationServiceImpl: First location received, using it.")
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
                print("📍 LocationServiceImpl: Better location received (more accurate), updating currentLocation.")
                currentLocation = location
                locationUpdateHandler?(location)
            }
        } else if locationAge < 10 {
            // Even if accuracy isn't great, update if it's very recent and we have a poor current location
            if let current = currentLocation, current.horizontalAccuracy > 100 {
                print("📍 LocationServiceImpl: Recent location received, updating currentLocation.")
                currentLocation = location
                locationUpdateHandler?(location)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Log errors
        print("‼️ LocationServiceImpl: locationManager failed with error: \(error.localizedDescription)")
        // You might want to set currentLocation to nil or handle specific errors (like kCLErrorDenied)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // This is the modern delegate method for authorization changes
        let status = manager.authorizationStatus
        print("📍 LocationServiceImpl: locationManagerDidChangeAuthorization delegate called. New status: \(status.rawValue) (\(permissionStatus.description))")
        // Call the temporary handler if it exists (used by requestLocationPermission)
        onAuthorizationStatusChanged?(status)
    }


    // MARK: - Callback Handlers (For requestLocationPermission continuation)
    private var onAuthorizationStatusChanged: ((CLAuthorizationStatus) -> Void)?
}
