//
//  RouteCalculationService.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//

import Foundation
import CoreLocation

/// Information about which leg of the route the user is on
struct LegInfo {
    let legStartIndex: Int      // Index of waypoint before user
    let legEndIndex: Int        // Index of waypoint after user
    let waypointBefore: RoutePoint
    let waypointAfter: RoutePoint
}

protocol RouteCalculationService {
    func calculateDistanceAndBearing(routePoints: [RoutePoint], averageSpeed: Double, startingIndex: Int) -> [RoutePoint]
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double
    func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double
    func formatDuration(_ duration: TimeInterval) -> String
    func calculateTotalDistance(from coordinates: [CLLocationCoordinate2D]) -> Double
    func calculateTotalDistance(from routePoints: [GpxRoutePoint]) -> Double
    func interpolatePosition(from: CLLocationCoordinate2D, bearing: Double, distance: Double) -> CLLocationCoordinate2D
    func findClosestLeg(userLocation: CLLocationCoordinate2D, routePoints: [RoutePoint]) -> LegInfo?
    func perpendicularDistanceToSegment(point: CLLocationCoordinate2D, segStart: CLLocationCoordinate2D, segEnd: CLLocationCoordinate2D) -> Double
}

class RouteCalculationServiceImpl: RouteCalculationService {
    private let earthRadius: Double = 3440.065 // Earth's radius in nautical miles

    func calculateDistanceAndBearing(routePoints: [RoutePoint], averageSpeed: Double, startingIndex: Int = 0) -> [RoutePoint] {
        guard routePoints.count >= 2 else { return routePoints }
        guard startingIndex >= 0 && startingIndex < routePoints.count else { return routePoints }

        var updatedPoints = routePoints
        var currentTime = updatedPoints[startingIndex].eta

        // Calculate from the starting index forward
        for i in startingIndex..<updatedPoints.count - 1 {
            let currentPoint = updatedPoints[i]
            let nextPoint = updatedPoints[i + 1]

            let fromCoord = CLLocationCoordinate2D(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
            let toCoord = CLLocationCoordinate2D(latitude: nextPoint.latitude, longitude: nextPoint.longitude)

            let distance = calculateDistance(from: fromCoord, to: toCoord)
            let bearing = calculateBearing(from: fromCoord, to: toCoord)

            updatedPoints[i].distanceToNext = distance
            updatedPoints[i].bearingToNext = bearing

            let timeToNext = TimeInterval(distance / averageSpeed * 3600) // Convert to seconds
            currentTime = currentTime.addingTimeInterval(timeToNext)

            if i < updatedPoints.count - 1 {
                updatedPoints[i + 1].eta = currentTime
            }
        }

        return updatedPoints
    }

    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLat = toRadians(from.latitude)
        let fromLon = toRadians(from.longitude)
        let toLat = toRadians(to.latitude)
        let toLon = toRadians(to.longitude)

        let dLat = toLat - fromLat
        let dLon = toLon - fromLon

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(fromLat) * cos(toLat) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLat = toRadians(from.latitude)
        let fromLon = toRadians(from.longitude)
        let toLat = toRadians(to.latitude)
        let toLon = toRadians(to.longitude)

        let dLon = toLon - fromLon

        let y = sin(dLon) * cos(toLat)
        let x = cos(fromLat) * sin(toLat) -
                sin(fromLat) * cos(toLat) * cos(dLon)

        var bearing = atan2(y, x)
        bearing = toDegrees(bearing)
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let days = Int(duration / 86400) // 86400 seconds in a day
        let hours = Int((duration.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)

        if days > 0 {
            return "\(days) Day\(days != 1 ? "s" : "") \(hours) hour\(hours != 1 ? "s" : "")"
        } else {
            return "\(hours) hour\(hours != 1 ? "s" : "") \(minutes) minute\(minutes != 1 ? "s" : "")"
        }
    }

    func calculateTotalDistance(from coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else { return 0.0 }

        var totalDistance = 0.0
        for i in 0..<(coordinates.count - 1) {
            let distance = calculateDistance(from: coordinates[i], to: coordinates[i + 1])
            totalDistance += distance
        }

        print("📐 RouteCalculationService: Total route distance calculated: \(String(format: "%.2f", totalDistance)) nm")
        return totalDistance
    }

    func calculateTotalDistance(from routePoints: [GpxRoutePoint]) -> Double {
        let coordinates = routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        return calculateTotalDistance(from: coordinates)
    }

    /// Interpolate a position given a starting point, bearing, and distance
    /// Uses the destination point formula for great circle navigation
    func interpolatePosition(from: CLLocationCoordinate2D, bearing: Double, distance: Double) -> CLLocationCoordinate2D {
        let lat1 = toRadians(from.latitude)
        let lon1 = toRadians(from.longitude)
        let bearingRad = toRadians(bearing)
        let angularDistance = distance / earthRadius

        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearingRad))
        let lon2 = lon1 + atan2(sin(bearingRad) * sin(angularDistance) * cos(lat1),
                                 cos(angularDistance) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(latitude: toDegrees(lat2), longitude: toDegrees(lon2))
    }

    /// Find the leg of the route that the user is closest to.
    /// Uses perpendicular distance from point to line segment.
    func findClosestLeg(userLocation: CLLocationCoordinate2D, routePoints: [RoutePoint]) -> LegInfo? {
        guard routePoints.count >= 2 else { return nil }

        var closestLegIndex = 0
        var minDistance = Double.greatestFiniteMagnitude

        // Check each leg (segment between consecutive waypoints)
        for i in 0..<(routePoints.count - 1) {
            let p1 = routePoints[i]
            let p2 = routePoints[i + 1]

            let segStart = CLLocationCoordinate2D(latitude: p1.latitude, longitude: p1.longitude)
            let segEnd = CLLocationCoordinate2D(latitude: p2.latitude, longitude: p2.longitude)

            let distance = perpendicularDistanceToSegment(
                point: userLocation,
                segStart: segStart,
                segEnd: segEnd
            )

            if distance < minDistance {
                minDistance = distance
                closestLegIndex = i
            }
        }

        return LegInfo(
            legStartIndex: closestLegIndex,
            legEndIndex: closestLegIndex + 1,
            waypointBefore: routePoints[closestLegIndex],
            waypointAfter: routePoints[closestLegIndex + 1]
        )
    }

    /// Calculate the perpendicular distance from a point to a line segment.
    /// Returns distance in nautical miles.
    func perpendicularDistanceToSegment(point: CLLocationCoordinate2D, segStart: CLLocationCoordinate2D, segEnd: CLLocationCoordinate2D) -> Double {
        // Convert to a simple projected coordinate system for distance calculation
        // This is an approximation but works well for short distances
        let avgLat = (segStart.latitude + segEnd.latitude) / 2.0
        let latScale = 60.0 // 1 degree latitude ≈ 60 nautical miles
        let lonScale = 60.0 * cos(toRadians(avgLat)) // Adjust for latitude

        // Convert to "flat" coordinates in nautical miles relative to segment start
        let px = (point.longitude - segStart.longitude) * lonScale
        let py = (point.latitude - segStart.latitude) * latScale
        let ax = 0.0
        let ay = 0.0
        let bx = (segEnd.longitude - segStart.longitude) * lonScale
        let by = (segEnd.latitude - segStart.latitude) * latScale

        // Vector from A to B
        let abx = bx - ax
        let aby = by - ay

        // Vector from A to P
        let apx = px - ax
        let apy = py - ay

        // Project P onto line AB, clamped to segment
        let abLengthSq = abx * abx + aby * aby
        if abLengthSq == 0.0 {
            // Segment is a point
            return sqrt(apx * apx + apy * apy)
        }

        var t = (apx * abx + apy * aby) / abLengthSq
        t = max(0.0, min(1.0, t)) // Clamp to segment [0, 1]

        // Closest point on segment
        let closestX = ax + t * abx
        let closestY = ay + t * aby

        // Distance from point to closest point on segment
        let dx = px - closestX
        let dy = py - closestY
        return sqrt(dx * dx + dy * dy)
    }

    private func toRadians(_ degrees: Double) -> Double {
        return degrees * .pi / 180
    }

    private func toDegrees(_ radians: Double) -> Double {
        return radians * 180 / .pi
    }
}
