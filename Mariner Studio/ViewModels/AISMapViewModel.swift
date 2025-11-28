//
//  AISMapViewModel.swift
//  Mariner Studio
//
//  Created by Claude on 11/28/25.
//

import Foundation
import CoreLocation
import MapKit
import Combine

class AISMapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published Properties

    @Published var vessels: [AISVessel] = []
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var errorMessage: String?
    @Published var vesselCount = 0

    // Initial map region - will be updated to user's location
    @Published var initialRegion: MKCoordinateRegion?

    // Trigger for programmatic map moves (e.g., NY Harbor button)
    @Published var programmaticMoveTarget: MKCoordinateRegion?

    // MARK: - Private Properties

    private var aisService: AISStreamServiceProtocol?
    private let apiKey: String
    private let locationManager = CLLocationManager()
    private var hasSetInitialLocation = false

    // Current bounding box for AIS subscription
    private var currentBoundingBox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)?

    // Throttle bounding box updates to prevent rapid reconnections
    private var lastBoundingBoxUpdate = Date.distantPast
    private let boundingBoxUpdateInterval: TimeInterval = 3.0 // Only update every 3 seconds

    // MARK: - Initialization

    override init() {
        self.apiKey = AISMapViewModel.getStoredAPIKey()

        super.init()

        setupLocationManager()
        setupService()
    }

    init(apiKey: String) {
        // Use provided API key or fall back to stored key
        self.apiKey = apiKey.isEmpty ? AISMapViewModel.getStoredAPIKey() : apiKey

        super.init()

        setupLocationManager()
        setupService()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // We don't need high accuracy for initial position
        locationManager.requestWhenInUseAuthorization()

        // Try to get current location
        if let location = locationManager.location {
            setInitialRegion(from: location)
        } else {
            locationManager.requestLocation()
        }
    }

    private func setInitialRegion(from location: CLLocation) {
        guard !hasSetInitialLocation else { return }
        hasSetInitialLocation = true

        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
        initialRegion = region

        // Also set initial bounding box
        currentBoundingBox = (
            minLat: region.center.latitude - region.span.latitudeDelta / 2,
            minLon: region.center.longitude - region.span.longitudeDelta / 2,
            maxLat: region.center.latitude + region.span.latitudeDelta / 2,
            maxLon: region.center.longitude + region.span.longitudeDelta / 2
        )
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            setInitialRegion(from: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Fall back to NY Harbor if location fails
        if !hasSetInitialLocation {
            hasSetInitialLocation = true
            initialRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.6501, longitude: -74.0500),
                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
            )
            currentBoundingBox = (minLat: 40.50, minLon: -74.25, maxLat: 40.80, maxLon: -73.85)
        }
    }

    // MARK: - Public Methods

    func connect() {
        guard !apiKey.isEmpty else {
            errorMessage = "No API key configured. Please add your AISStream API key."
            return
        }

        guard let boundingBox = currentBoundingBox else {
            errorMessage = "Location not available yet. Please try again."
            return
        }

        isConnecting = true
        errorMessage = nil

        aisService?.connect(boundingBox: boundingBox)
    }

    func disconnect() {
        aisService?.disconnect()
        isConnected = false
        isConnecting = false
    }

    func updateBoundingBoxFromRegion(_ region: MKCoordinateRegion) {
        // Throttle updates to prevent rapid subscription changes
        let now = Date()
        guard now.timeIntervalSince(lastBoundingBoxUpdate) >= boundingBoxUpdateInterval else { return }

        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        // Check if the region has changed significantly (more than 10% of the span)
        if let currentBox = currentBoundingBox {
            let latThreshold = region.span.latitudeDelta * 0.1
            let lonThreshold = region.span.longitudeDelta * 0.1

            let latChanged = abs(minLat - currentBox.minLat) > latThreshold ||
                             abs(maxLat - currentBox.maxLat) > latThreshold
            let lonChanged = abs(minLon - currentBox.minLon) > lonThreshold ||
                             abs(maxLon - currentBox.maxLon) > lonThreshold

            guard latChanged || lonChanged else { return }
        }

        lastBoundingBoxUpdate = now
        currentBoundingBox = (minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon)

        if isConnected, let boundingBox = currentBoundingBox {
            aisService?.updateBoundingBox(boundingBox)
        }
    }

    func centerOnNYHarbor() {
        // Set the programmatic move target - the map view will observe this
        programmaticMoveTarget = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.6501, longitude: -74.0500),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    }

    func centerOnUserLocation() {
        if let location = locationManager.location {
            programmaticMoveTarget = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
            )
        }
    }

    func clearProgrammaticMove() {
        programmaticMoveTarget = nil
    }

    // MARK: - Private Methods

    private func setupService() {
        guard !apiKey.isEmpty else {
            print("🚢 AISMapViewModel: No API key configured")
            return
        }

        let service = AISStreamService(apiKey: apiKey)

        service.onVesselsUpdated = { [weak self] vessels in
            DispatchQueue.main.async {
                self?.vessels = vessels
                self?.vesselCount = vessels.count
            }
        }

        service.onConnectionStateChanged = { [weak self] connected in
            DispatchQueue.main.async {
                self?.isConnected = connected
                self?.isConnecting = false
                if connected {
                    self?.errorMessage = nil
                }
            }
        }

        service.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.errorMessage = error
                self?.isConnecting = false
            }
        }

        self.aisService = service
    }

    // MARK: - API Key Management

    private static let defaultAPIKey = "f562294562e9a1417d56f25392f8988b8dea3224"

    private static func getStoredAPIKey() -> String {
        // Try to get from UserDefaults first
        if let key = UserDefaults.standard.string(forKey: "AISStreamAPIKey"), !key.isEmpty {
            return key
        }

        // Fall back to default key
        return defaultAPIKey
    }

    static func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "AISStreamAPIKey")
    }

    static func hasAPIKey() -> Bool {
        if let key = UserDefaults.standard.string(forKey: "AISStreamAPIKey"), !key.isEmpty {
            return true
        }
        return false
    }
}

// MARK: - Vessel Annotation for MapKit

class VesselAnnotation: NSObject, MKAnnotation {
    let vessel: AISVessel

    var coordinate: CLLocationCoordinate2D {
        vessel.coordinate
    }

    var title: String? {
        vessel.name
    }

    var subtitle: String? {
        var parts: [String] = []

        if let sog = vessel.speedOverGround {
            parts.append(String(format: "%.1f kts", sog))
        }

        if let cog = vessel.courseOverGround {
            parts.append(String(format: "COG: %.0f°", cog))
        }

        parts.append(vessel.shipTypeDescription)

        return parts.joined(separator: " | ")
    }

    init(vessel: AISVessel) {
        self.vessel = vessel
        super.init()
    }
}
