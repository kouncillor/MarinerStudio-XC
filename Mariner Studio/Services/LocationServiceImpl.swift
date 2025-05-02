import Foundation
import CoreLocation


class LocationServiceImpl: NSObject, LocationService, CLLocationManagerDelegate {
    // MARK: - Properties
    private let locationManager = CLLocationManager()
    var locationUpdateHandler: ((CLLocation) -> Void)? // Note: Currently not used by TidalHeightStationsViewModel

    private(set) var currentLocation: CLLocation? // Can be read publicly, but only set privately

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
        locationManager.distanceFilter = kCLDistanceFilterNone
    }

    // MARK: - LocationService Methods
    func requestLocationPermission() async -> Bool {
        // (Code for requestLocationPermission remains the same as before)
        // ... it checks status, requests if .notDetermined, returns true/false ...
   //     let currentStatus = locationManager.authorizationStatus // Check status directly here for logging
        print("📍 LocationServiceImpl: requestLocationPermission called. Current status: \(permissionStatus.description)")

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                 guard let self = self else {
                     print("📍 LocationServiceImpl: Self is nil in request permission continuation.")
                     continuation.resume(returning: false)
                     return
                 }

                 switch self.locationManager.authorizationStatus {
                 case .authorizedWhenInUse, .authorizedAlways:
                      print("📍 LocationServiceImpl: Permission already granted.")
                      continuation.resume(returning: true)
                 case .notDetermined:
                      print("📍 LocationServiceImpl: Requesting 'When In Use' authorization...")
                      // Set up a temporary handler (safer than instance property if called multiple times)
                      // NOTE: This simple handler only works for the *first* status change.
                      // A more robust solution might involve Combine or NotificationCenter.
                      self.onAuthorizationStatusChanged = { status in
                          self.onAuthorizationStatusChanged = nil // Clear handler
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
        // --- THIS IS THE PROOF POINT ---
        guard let location = locations.last else {
            print("‼️ PROOF POINT (didUpdateLocations): Called but locations array was empty.")
            return
        }

        // Print details of the received location *before* filtering
         print("‼️ PROOF POINT (didUpdateLocations): Received location - Lat: \(location.coordinate.latitude), Lon: \(location.coordinate.longitude), Acc: \(location.horizontalAccuracy)m, Time: \(location.timestamp)")

        // Existing filtering logic
        guard location.horizontalAccuracy >= 0 else {
             print("‼️ PROOF POINT (didUpdateLocations): Ignoring location with negative accuracy.")
             return
        }
        // Relaxed accuracy check for debugging - accept up to 100m initially
        guard location.horizontalAccuracy <= 100 else { // Relaxed from 20 to 100 for testing
            print("‼️ PROOF POINT (didUpdateLocations): Ignoring inaccurate location (\(location.horizontalAccuracy)m > 100m).")
            return
        }
        let howRecent = location.timestamp.timeIntervalSinceNow
        guard abs(howRecent) < 15.0 else {
            print("‼️ PROOF POINT (didUpdateLocations): Ignoring old location (\(howRecent)s).")
            return
        }

        // If it passes filters, update currentLocation
        print("✅ PROOF POINT (didUpdateLocations): Location PASSED filters. Updating currentLocation.")
        currentLocation = location
        locationUpdateHandler?(location) // Call handler if set (still not used by TidalHeight VM)
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

    // Deprecated delegate method (kept for compatibility reference if needed, but locationManagerDidChangeAuthorization is preferred)
    // func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    //    print("📍 LocationServiceImpl: locationManager didChangeAuthorization delegate called (DEPRECATED). Status: \(status.rawValue)")
    //    onAuthorizationStatusChanged?(status)
    // }
}
