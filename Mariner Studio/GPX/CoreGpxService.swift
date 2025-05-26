
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
                    let parser = GPXParser(withData: gpxData)
                    guard let coreGpxRoot = parser.parsedData() else {
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
    
    func loadGpxFile(from xmlString: String) async throws -> GpxFile {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Convert string to data
                    guard let gpxData = xmlString.data(using: .utf8) else {
                        continuation.resume(throwing: GpxServiceError.parsingFailed("Invalid XML string encoding"))
                        return
                    }
                    
                    // Parse with CoreGPX
                    let parser = GPXParser(withData: gpxData)
                    guard let coreGpxRoot = parser.parsedData() else {
                        continuation.resume(throwing: GpxServiceError.parsingFailed("Failed to parse GPX data from string"))
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
    
    func serializeGpxFile(_ gpxFile: GpxFile) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Convert our model to CoreGPX
                    let coreGpxRoot = try self.convertGpxFileToCoreGpx(gpxFile)
                    
                    // Generate GPX XML string
                    let gpxString = coreGpxRoot.gpx()
                    
                    print("✅ CoreGpxService: Successfully serialized GPX file")
                    continuation.resume(returning: gpxString)
                } catch let error as GpxServiceError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: self.mapCoreGpxError(error))
                }
            }
        }
    }
    
    // MARK: - Private Conversion Methods
    
    private func convertCoreGpxToGpxFile(_ coreGpxRoot: GPXRoot) throws -> GpxFile {
        // Look for routes first, then tracks, then waypoints
        if !coreGpxRoot.routes.isEmpty {
            return try convertRouteToGpxFile(coreGpxRoot.routes.first!)
        } else if !coreGpxRoot.tracks.isEmpty {
            return try convertTrackToGpxFile(coreGpxRoot.tracks.first!)
        } else if !coreGpxRoot.waypoints.isEmpty {
            return try convertWaypointsToGpxFile(coreGpxRoot.waypoints)
        } else {
            throw GpxServiceError.noRouteData
        }
    }
    
    private func convertRouteToGpxFile(_ coreRoute: GPXRoute) throws -> GpxFile {
        guard !coreRoute.points.isEmpty else {
            throw GpxServiceError.noRouteData
        }
        
        let gpxRoutePoints = coreRoute.points.map { corePoint in
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
        guard !coreTrack.segments.isEmpty else {
            throw GpxServiceError.noRouteData
        }
        
        // Combine all track points from all segments
        var allTrackPoints: [GPXTrackPoint] = []
        for segment in coreTrack.segments {
            allTrackPoints.append(contentsOf: segment.points)
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
        
        // Initialize points array if needed
        if coreRoute.points == nil {
            coreRoute.points = []
        }
        
        // Convert route points using direct array manipulation
        for gpxPoint in gpxFile.route.routePoints {
            let corePoint = GPXRoutePoint(latitude: gpxPoint.latitude, longitude: gpxPoint.longitude)
            corePoint.name = gpxPoint.name
            corePoint.time = gpxPoint.eta
            coreRoute.points.append(corePoint)
        }
        
        // Add route to root using direct array manipulation
        if root.routes == nil {
            root.routes = []
        }
        root.routes.append(coreRoute)
        
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
