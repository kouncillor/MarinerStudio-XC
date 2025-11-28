import Foundation
import CoreLocation
import Combine
import SwiftUI

class GpxViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var routeName = ""
    @Published var startDate = Date()
    @Published var startTime = Date()
    @Published var averageSpeed = VesselSettings.shared.averageSpeedString
    @Published var hasRoute = false
    @Published var etasCalculated = false
    @Published var routePoints: [RoutePoint] = []
    @Published var isReversed = false
    @Published var directionButtonText = "Reverse Route"
    @Published var isPreLoaded = false // New property to track if route was pre-loaded
    @Published var selectedStartingWaypointIndex = 0 // Index of waypoint to start from (0 = first waypoint)

    // MARK: - Current Location Feature Properties
    @Published var useCurrentLocation = false
    @Published var currentLocationLabel: String? = nil
    @Published var isLoadingLocation = false
    @Published var modifiedRoutePoints: [RoutePoint]? = nil
    private var currentLocationPoint: RoutePoint? = nil
    private var originalRoutePoints: [RoutePoint] = [] // Store original points before modification

    // MARK: - Services
    private let gpxService: GpxServiceProtocol
    private let routeCalculationService: RouteCalculationService

    // MARK: - Computed Properties
    var canCalculateETAs: Bool {
        return hasRoute && !averageSpeed.isEmpty && Double(averageSpeed) != nil
    }

    var waypointNames: [String] {
        return routePoints.enumerated().map { index, point in
            "\(index + 1). \(point.name)"
        }
    }

    // MARK: - Event handlers
    var onRouteReversed: (([RoutePoint]) -> Void)?

    // MARK: - Initialization
    init(gpxService: GpxServiceProtocol, routeCalculationService: RouteCalculationService) {
        self.gpxService = gpxService
        self.routeCalculationService = routeCalculationService
    }

    // MARK: - New Initialization with Pre-loaded Data
    convenience init(gpxService: GpxServiceProtocol, routeCalculationService: RouteCalculationService, preLoadedRoute: GpxFile) {
        self.init(gpxService: gpxService, routeCalculationService: routeCalculationService)
        self.loadPreExistingRoute(preLoadedRoute)
    }

    // MARK: - Public Methods

    /// Load a route that already exists (from favorites, etc.)
    func loadPreExistingRoute(_ gpxFile: GpxFile) {
        // Process route on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if !gpxFile.route.routePoints.isEmpty {
                let firstPoint = gpxFile.route.routePoints.first!
                let lastPoint = gpxFile.route.routePoints.last!

                self.routeName = gpxFile.route.name.isEmpty ? "\(firstPoint.name ?? "Start") - \(lastPoint.name ?? "End")" : gpxFile.route.name

                // Convert GPX route points to RoutePoints
                self.routePoints = gpxFile.route.routePoints.map { point in
                    RoutePoint(
                        name: point.name ?? "Waypoint",
                        latitude: point.latitude,
                        longitude: point.longitude
                    )
                }

                self.hasRoute = true
                self.isPreLoaded = true
                self.errorMessage = ""

                print("📍 GpxViewModel: Pre-loaded route '\(self.routeName)' with \(self.routePoints.count) waypoints")
            } else {
                self.errorMessage = "Invalid route data"
                self.isPreLoaded = false
            }
        }
    }

    func calculateETAs() {
        guard canCalculateETAs else { return }
        guard let speed = Double(averageSpeed) else { return }

        // Use modified route points if current location is selected
        var pointsToUse: [RoutePoint]
        let startIndex: Int

        if useCurrentLocation, let modified = modifiedRoutePoints {
            pointsToUse = modified
            startIndex = 0 // Always start from index 0 for modified route
        } else {
            pointsToUse = routePoints
            startIndex = selectedStartingWaypointIndex
        }

        guard pointsToUse.count >= 2 else { return }

        // Create start datetime
        let calendar = Calendar.current
        let startDateComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
        let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)

        var combinedComponents = DateComponents()
        combinedComponents.year = startDateComponents.year
        combinedComponents.month = startDateComponents.month
        combinedComponents.day = startDateComponents.day
        combinedComponents.hour = startTimeComponents.hour
        combinedComponents.minute = startTimeComponents.minute

        guard let startDateTime = calendar.date(from: combinedComponents) else { return }

        print("📍 GpxViewModel: Starting from waypoint #\(startIndex + 1) at \(startDateTime) (useCurrentLocation: \(useCurrentLocation))")

        // Set first waypoint ETA
        pointsToUse[startIndex].eta = startDateTime

        // Calculate rest of waypoints from the first waypoint's ETA
        pointsToUse = routeCalculationService.calculateDistanceAndBearing(
            routePoints: pointsToUse,
            averageSpeed: speed,
            startingIndex: startIndex
        )

        // Update the appropriate route points
        if useCurrentLocation {
            modifiedRoutePoints = pointsToUse
        } else {
            routePoints = pointsToUse
        }

        etasCalculated = true
    }

    func reverseRoute() {
        guard hasRoute else { return }

        isReversed.toggle()
        directionButtonText = isReversed ? "Original Direction" : "Reverse Route"

        // Create a new reversed list
        let reversedPoints = routePoints.reversed()

        // Clear and repopulate the observable collection
        routePoints = Array(reversedPoints)

        // Update route name to reflect direction
        if let firstPoint = routePoints.first, let lastPoint = routePoints.last {
            routeName = "\(firstPoint.name) - \(lastPoint.name)"
        }

        // Reset starting waypoint to first waypoint after reversal
        selectedStartingWaypointIndex = 0

        // Reset current location state since route changed
        resetCurrentLocationState()

        // Reset ETAs since they need to be recalculated
        etasCalculated = false

        // Notify listeners that the route has been reversed
        onRouteReversed?(routePoints)
    }

    // MARK: - Current Location Feature Methods

    /// Fetch the user's current location and update the route accordingly
    func fetchCurrentLocation() {
        isLoadingLocation = true
        etasCalculated = false

        // Store original route points if not already stored
        if originalRoutePoints.isEmpty {
            originalRoutePoints = routePoints
        }

        // Check location permission
        let status = CLLocationManager.authorizationStatus()

        switch status {
        case .notDetermined:
            LocationManager.shared.requestLocationPermission { [weak self] authorized in
                if authorized {
                    self?.processCurrentLocation()
                } else {
                    DispatchQueue.main.async {
                        self?.isLoadingLocation = false
                        self?.errorMessage = "Location permission denied"
                    }
                }
            }
        case .denied, .restricted:
            isLoadingLocation = false
            errorMessage = "Location permission denied. Please enable in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            processCurrentLocation()
        @unknown default:
            isLoadingLocation = false
        }
    }

    private func processCurrentLocation() {
        // Request a fresh location update
        LocationManager.shared.startUpdatingLocation()

        // Give it a moment to get the location, then process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            guard let location = LocationManager.shared.currentLocation else {
                print("📍 GpxViewModel: Could not get current location")
                self.isLoadingLocation = false
                self.errorMessage = "Could not get current location"
                return
            }

            print("📍 GpxViewModel: Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")

            // Find which leg of the route the user is on
            guard let legInfo = self.routeCalculationService.findClosestLeg(
                userLocation: location.coordinate,
                routePoints: self.routePoints
            ) else {
                print("📍 GpxViewModel: Could not determine user's position on route")
                self.isLoadingLocation = false
                self.errorMessage = "Could not determine position on route"
                return
            }

            let waypointBefore = legInfo.waypointBefore
            let waypointAfter = legInfo.waypointAfter

            print("📍 GpxViewModel: User is between waypoint \(legInfo.legStartIndex) (\(waypointBefore.name)) and \(legInfo.legEndIndex) (\(waypointAfter.name))")

            // Calculate distance and bearing from current location to next waypoint
            let userCoord = location.coordinate
            let nextCoord = CLLocationCoordinate2D(latitude: waypointAfter.latitude, longitude: waypointAfter.longitude)

            let distanceToNext = self.routeCalculationService.calculateDistance(from: userCoord, to: nextCoord)
            let bearingToNext = self.routeCalculationService.calculateBearing(from: userCoord, to: nextCoord)

            // Create a new waypoint at user's location
            let userWaypoint = RoutePoint(
                name: "Current Location",
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                eta: Date(),
                distanceToNext: distanceToNext,
                bearingToNext: bearingToNext
            )

            // Build new route: user location + remaining waypoints
            var newRoutePoints: [RoutePoint] = []
            newRoutePoints.append(userWaypoint)
            // Add waypoints from legEndIndex onwards (the ones not yet passed)
            newRoutePoints.append(contentsOf: Array(self.routePoints[legInfo.legEndIndex...]))

            // Update state
            self.modifiedRoutePoints = newRoutePoints
            self.currentLocationPoint = userWaypoint
            self.currentLocationLabel = "Current Location (between \(waypointBefore.name) & \(waypointAfter.name))"
            self.useCurrentLocation = true
            self.selectedStartingWaypointIndex = 0
            self.isLoadingLocation = false

            print("📍 GpxViewModel: Created modified route with \(newRoutePoints.count) waypoints")

            LocationManager.shared.stopUpdatingLocation()
        }
    }

    /// Called when user selects a regular waypoint instead of current location
    func selectRegularWaypoint(_ index: Int) {
        resetCurrentLocationState()
        selectedStartingWaypointIndex = index
        etasCalculated = false
    }

    /// Reset all current location state
    private func resetCurrentLocationState() {
        useCurrentLocation = false
        currentLocationLabel = nil
        currentLocationPoint = nil
        modifiedRoutePoints = nil
    }

    private func clearRoute() {
        routeName = ""
        hasRoute = false
        routePoints = []
        errorMessage = ""
        etasCalculated = false
        isReversed = false
        directionButtonText = "Reverse Route"
        isPreLoaded = false
        selectedStartingWaypointIndex = 0
    }
}
