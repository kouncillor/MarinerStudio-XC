//
//  RouteCalculationService.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//

import Foundation
import CoreLocation

protocol RouteCalculationService {
    func calculateDistanceAndBearing(routePoints: [RoutePoint], averageSpeed: Double) -> [RoutePoint]
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double
    func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double
    func formatDuration(_ duration: TimeInterval) -> String
    func calculateTotalDistance(from coordinates: [CLLocationCoordinate2D]) -> Double
    func calculateTotalDistance(from routePoints: [GpxRoutePoint]) -> Double
}

class RouteCalculationServiceImpl: RouteCalculationService {
    private let earthRadius: Double = 3440.065 // Earth's radius in nautical miles

    func calculateDistanceAndBearing(routePoints: [RoutePoint], averageSpeed: Double) -> [RoutePoint] {
        guard routePoints.count >= 2 else { return routePoints }

        var updatedPoints = routePoints
        var currentTime = updatedPoints[0].eta

        for i in 0..<updatedPoints.count - 1 {
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

    private func toRadians(_ degrees: Double) -> Double {
        return degrees * .pi / 180
    }

    private func toDegrees(_ radians: Double) -> Double {
        return radians * 180 / .pi
    }
}
