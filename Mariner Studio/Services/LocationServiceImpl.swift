import Foundation
import CoreLocation

class LocationServiceImpl: NSObject, LocationService, CLLocationManagerDelegate {
    // MARK: - Properties
    private let locationManager = CLLocationManager()
    private var locationUpdateHandler: ((CLLocation) -> Void)?
    
    private(set) var currentLocation: CLLocation?
    
    var permissionStatus: LocationPermissionStatus {
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
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Update every 100 meters
    }
    
    // MARK: - LocationService Methods
    func requestLocationPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                switch self.locationManager.authorizationStatus {
                case .authorizedWhenInUse, .authorizedAlways:
                    continuation.resume(returning: true)
                case .notDetermined:
                    // Set up a temporary handler to listen for the authorization change
                    self.onAuthorizationStatusChanged = { status in
                        self.onAuthorizationStatusChanged = nil
                        continuation.resume(returning: status == .authorizedWhenInUse || status == .authorizedAlways)
                    }
                    self.locationManager.requestWhenInUseAuthorization()
                case .denied, .restricted:
                    continuation.resume(returning: false)
                @unknown default:
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
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
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out potentially cached or inaccurate readings
        let howRecent = location.timestamp.timeIntervalSinceNow
        guard abs(howRecent) < 15.0, location.horizontalAccuracy >= 0 else { return }
        
        currentLocation = location
        locationUpdateHandler?(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        onAuthorizationStatusChanged?(status)
    }
    
    // MARK: - Callback Handlers
    private var onAuthorizationStatusChanged: ((CLAuthorizationStatus) -> Void)?
}
