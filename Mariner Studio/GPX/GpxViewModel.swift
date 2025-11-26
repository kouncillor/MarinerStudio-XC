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
    @Published var averageSpeed = "10"
    @Published var hasRoute = false
    @Published var etasCalculated = false
    @Published var routePoints: [RoutePoint] = []
    @Published var isReversed = false
    @Published var directionButtonText = "Reverse Route"
    @Published var isPreLoaded = false // New property to track if route was pre-loaded
    @Published var selectedStartingWaypointIndex = 0 // Index of waypoint to start from (0 = first waypoint)

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
        guard canCalculateETAs, routePoints.count >= 2 else { return }
        guard let speed = Double(averageSpeed) else { return }

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

        // selectedStartingWaypointIndex is a direct index into routePoints array
        let actualStartingIndex = selectedStartingWaypointIndex
        print("📍 GpxViewModel: Starting from waypoint #\(actualStartingIndex + 1) at \(startDateTime)")

        // Set first waypoint ETA
        routePoints[actualStartingIndex].eta = startDateTime

        // Calculate rest of waypoints from the first waypoint's ETA
        routePoints = routeCalculationService.calculateDistanceAndBearing(
            routePoints: routePoints,
            averageSpeed: speed,
            startingIndex: actualStartingIndex
        )

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

        // Reset ETAs since they need to be recalculated
        etasCalculated = false

        // Notify listeners that the route has been reversed
        onRouteReversed?(routePoints)
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
