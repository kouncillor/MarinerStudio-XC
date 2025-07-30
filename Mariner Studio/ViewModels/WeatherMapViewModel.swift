import Foundation
import SwiftUI
import Combine
import MapKit
import CoreLocation

class WeatherMapViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default coords
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var userTrackingMode: MapUserTrackingMode = .follow

    // MARK: - Private Properties
    private var locationService: LocationService?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(locationService: LocationService? = nil) {
        self.locationService = locationService
    }

    // MARK: - Public Methods
    func initialize(with locationService: LocationService) {
        self.locationService = locationService

        // Start observing location changes
        setupLocationObservation()

        // Check location permission status
        checkLocationPermission()
    }

    func centerOnUserLocation() {
        guard let currentLocation = locationService?.currentLocation else {
            // If no location is available, request permission
            requestLocationPermission()
            return
        }

        // Update the map region to center on user location
        withAnimation {
            region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }

        // Set tracking mode to follow
        userTrackingMode = .follow
    }

    // MARK: - Private Methods
    private func setupLocationObservation() {
        // Observe location changes if possible
        // This would need a Publisher from the LocationService
        // For now, we'll rely on direct access to currentLocation
    }

    private func checkLocationPermission() {
        guard let locationService = locationService else {
            errorMessage = "Location service not available"
            return
        }

        switch locationService.permissionStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // Location permission already granted
            locationService.startUpdatingLocation()
            centerOnUserLocation()
        case .notDetermined:
            // Need to request permission
            requestLocationPermission()
        case .denied, .restricted:
            errorMessage = "Location access is restricted. Please enable location services in Settings."
        case .unknown:
            errorMessage = "Unable to determine location permission status."
        }
    }

    private func requestLocationPermission() {
        guard let locationService = locationService else {
            errorMessage = "Location service not available"
            return
        }

        Task {
            let granted = await locationService.requestLocationPermission()

            await MainActor.run {
                if granted {
                    locationService.startUpdatingLocation()
                    // Wait a moment for location to update
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.centerOnUserLocation()
                    }
                } else {
                    errorMessage = "Location permission denied. Some features may be limited."
                }
            }
        }
    }
}
