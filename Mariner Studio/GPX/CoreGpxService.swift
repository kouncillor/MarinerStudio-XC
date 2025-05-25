//
//  CoreGpxService.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/24/25.
//

import Foundation
import CoreGPX

/// CoreGPX-powered implementation of the GPX service
class CoreGpxService: ExtendedGpxServiceProtocol {
    
    // MARK: - Properties
    
    var capabilities: GpxServiceCapabilities {
        return .coreGpxCapabilities
    }
    
    // MARK: - Initialization
    init() {
        print("📦 CoreGpxService: Initialized with full GPX 1.1 support")
    }
    
    // MARK: - GpxServiceProtocol Implementation
    
    func loadGpxFile(from url: URL) async throws -> GpxFile {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Ensure we have access to the URL
                    let shouldStopAccessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if shouldStopAccessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    // Read the GPX data
                    let gpxData = try Data(contentsOf: url)
                    
                    // Parse with CoreGPX
                    guard let coreGpxRoot = GPXRoot(data: gpxData) else {
                        continuation.resume(throwing: GpxServiceError.parsingFailed("Failed to parse GPX data"))
                        return
                    }
                    
                    // Convert CoreGPX to our model
                    let gpxFile = try self.convertCoreGpxToGpxFile(coreGpxRoot)
                    
                    continuation.resume(returning: gpxFile)
                } catch let error as GpxServiceError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: self.mapCoreGpxError(error))
                }
            }
        }
    }
    
    // MARK: - ExtendedGpxServiceProtocol Implementation
    
    func writeGpxFile(_ gpxFile: GpxFile, to url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Convert our model to CoreGPX
                    let coreGpxRoot = try self.convertGpxFileToCoreGpx(gpxFile)
                    
                    // Generate GPX XML
                    let gpxString = coreGpxRoot.gpx()
                    guard let gpxData = gpxString.data(using: .utf8) else {
                        continuation.resume(throwing: GpxServiceError.parsingFailed("Failed to generate GPX data"))
                        return
                    }
                    
                    // Write to file
                    try gpxData.write(to: url)
                    
                    print("✅ CoreGpxService: Successfully wrote GPX file to \(url.lastPathComponent)")
                    continuation.resume()
                } catch let error as GpxServiceError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: self.mapCoreGpxError(error))
                }
            }
        }
    }
    
    func validateGpxFile(at url: URL) async throws -> Bool {
        do {
            _ = try await loadGpxFile(from: url)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Private Conversion Methods
    
    private func convertCoreGpxToGpxFile(_ coreGpxRoot: GPXRoot) throws -> GpxFile {
        // Look for routes first, then tracks, then waypoints
        if let route = coreGpxRoot.routes?.first {
            return try convertRouteToGpxFile(route)
        } else if let track = coreGpxRoot.tracks?.first {
            return try convertTrackToGpxFile(track)
        } else if let waypoints = coreGpxRoot.waypoints, !waypoints.isEmpty {
            return try convertWaypointsToGpxFile(waypoints)
        } else {
            throw GpxServiceError.noRouteData
        }
    }
    
    private func convertRouteToGpxFile(_ coreRoute: GPXRoute) throws -> GpxFile {
        guard let routePoints = coreRoute.points, !routePoints.isEmpty else {
            throw GpxServiceError.noRouteData
        }
        
        let gpxRoutePoints = routePoints.map { corePoint in
            var gpxPoint = GpxRoutePoint(
                latitude: corePoint.latitude ?? 0.0,
                longitude: corePoint.longitude ?? 0.0,
                name: corePoint.name
            )
            
            // Set time if available
            if let time = corePoint.time {
                gpxPoint.eta = time
            }
            
            return gpxPoint
        }
        
        let gpxRoute = GpxRoute(
            name: coreRoute.name ?? "Imported Route",
            routePoints: gpxRoutePoints
        )
        
        return GpxFile(route: gpxRoute)
    }
    
    private func convertTrackToGpxFile(_ coreTrack: GPXTrack) throws -> GpxFile {
        guard let segments = coreTrack.segments, !segments.isEmpty else {
            throw GpxServiceError.noRouteData
        }
        
        // Combine all track points from all segments
        var allTrackPoints: [GPXTrackPoint] = []
        for segment in segments {
            if let points = segment.points {
                allTrackPoints.append(contentsOf: points)
            }
        }
        
        guard !allTrackPoints.isEmpty else {
            throw GpxServiceError.noRouteData
        }
        
        let gpxRoutePoints = allTrackPoints.enumerated().map { index, trackPoint in
            var gpxPoint = GpxRoutePoint(
                latitude: trackPoint.latitude ?? 0.0,
                longitude: trackPoint.longitude ?? 0.0,
                name: trackPoint.name ?? "Point \(index + 1)"
            )
            
            // Set time if available
            if let time = trackPoint.time {
                gpxPoint.eta = time
            }
            
            return gpxPoint
        }
        
        let gpxRoute = GpxRoute(
            name: coreTrack.name ?? "Imported Track",
            routePoints: gpxRoutePoints
        )
        
        return GpxFile(route: gpxRoute)
    }
    
    private func convertWaypointsToGpxFile(_ waypoints: [GPXWaypoint]) throws -> GpxFile {
        let gpxRoutePoints = waypoints.enumerated().map { index, waypoint in
            var gpxPoint = GpxRoutePoint(
                latitude: waypoint.latitude ?? 0.0,
                longitude: waypoint.longitude ?? 0.0,
                name: waypoint.name ?? "Waypoint \(index + 1)"
            )
            
            // Set time if available
            if let time = waypoint.time {
                gpxPoint.eta = time
            }
            
            return gpxPoint
        }
        
        let gpxRoute = GpxRoute(
            name: "Waypoint Route",
            routePoints: gpxRoutePoints
        )
        
        return GpxFile(route: gpxRoute)
    }
    
    private func convertGpxFileToCoreGpx(_ gpxFile: GpxFile) throws -> GPXRoot {
        let root = GPXRoot(creator: "Mariner Studio")
        
        // Create CoreGPX route
        let coreRoute = GPXRoute()
        coreRoute.name = gpxFile.route.name
        
        // Convert route points
        let coreRoutePoints = gpxFile.route.routePoints.map { gpxPoint in
            let corePoint = GPXRoutePoint(latitude: gpxPoint.latitude, longitude: gpxPoint.longitude)
            corePoint.name = gpxPoint.name
            corePoint.time = gpxPoint.eta
            return corePoint
        }
        
        coreRoute.add(routePoints: coreRoutePoints)
        root.add(route: coreRoute)
        
        return root
    }
    
    // MARK: - Error Handling
    
    private func mapCoreGpxError(_ error: Error) -> GpxServiceError {
        if let nsError = error as NSError? {
            switch nsError.code {
            case NSFileReadNoSuchFileError:
                return .fileNotFound
            case NSFileReadNoPermissionError:
                return .fileAccessDenied
            case NSFileWriteNoPermissionError:
                return .fileAccessDenied
            default:
                return .parsingFailed(nsError.localizedDescription)
            }
        }
        
        return .parsingFailed(error.localizedDescription)
    }
}