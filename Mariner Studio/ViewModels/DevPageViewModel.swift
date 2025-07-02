//
//  DevPageViewModel.swift
//  Mariner Studio
//
//  Created for development tools and utilities.
//

import Foundation
import SwiftUI
import UIKit

#if DEBUG
@MainActor
class DevPageViewModel: ObservableObject {
    @Published var statusMessage: String = ""
    @Published var isUploading: Bool = false
    @Published var showingFilePicker: Bool = false
    
    // MARK: - GPX Upload to Supabase
    
    func uploadGPXToSupabase() {
        print("🔧 DEV: Starting GPX upload process to Supabase")
        statusMessage = "Opening file picker for GPX selection..."
        showingFilePicker = true
    }
    
    func processGPXForSupabase(from url: URL) {
        print("🔧 DEV: Processing GPX file for Supabase upload: \(url.lastPathComponent)")
        isUploading = true
        statusMessage = "Processing GPX file: \(url.lastPathComponent)"
        
        Task {
            do {
                // Start accessing the security-scoped resource
                print("🔧 DEV: Starting security-scoped resource access")
                let _ = url.startAccessingSecurityScopedResource()
                defer { 
                    print("🔧 DEV: Stopping security-scoped resource access")
                    url.stopAccessingSecurityScopedResource() 
                }
                
                // Parse GPX file
                print("🔧 DEV: Beginning GPX parsing process")
                let parsedData = try await parseGPXForSupabase(from: url)
                print("🔧 DEV: GPX parsing completed successfully")
                
                // Upload to Supabase
                print("🔧 DEV: Starting Supabase upload")
                try await uploadToSupabase(parsedData)
                print("🔧 DEV: Supabase upload completed successfully")
                
                await MainActor.run {
                    self.statusMessage = "✅ Successfully uploaded '\(parsedData.name)' to Supabase!"
                    self.isUploading = false
                }
                print("🔧 DEV: Upload process completed for: \(parsedData.name)")
                
            } catch {
                print("🔧 DEV: ❌ Error during GPX upload process: \(error)")
                await MainActor.run {
                    self.statusMessage = "❌ Failed to upload \(url.lastPathComponent): \(error.localizedDescription)"
                    self.isUploading = false
                }
            }
        }
    }
    
    // MARK: - GPX Parsing for Supabase
    
    private func parseGPXForSupabase(from url: URL) async throws -> SupabaseRouteData {
        print("🔧 DEV: Reading GPX file content from: \(url.path)")
        
        // 1. Read GPX file content
        let gpxData = try String(contentsOf: url, encoding: .utf8)
        let fileName = url.deletingPathExtension().lastPathComponent
        print("🔧 DEV: GPX file read successfully, size: \(gpxData.count) characters")
        print("🔧 DEV: Extracted file name: \(fileName)")
        
        // 2. Parse GPX using existing service
        print("🔧 DEV: Creating GPX service for parsing")
        let gpxService = GpxServiceFactory.shared.createServiceForReading()
        print("🔧 DEV: GPX service created: \(type(of: gpxService))")
        
        print("🔧 DEV: Parsing GPX data with service")
        let gpxFile = try await gpxService.loadGpxFile(from: gpxData)
        print("🔧 DEV: GPX file parsed successfully")
        print("🔧 DEV: Route name from GPX: \(gpxFile.route.name)")
        print("🔧 DEV: Route points count: \(gpxFile.route.routePoints.count)")
        print("🔧 DEV: Total distance: \(gpxFile.route.totalDistance)")
        
        // 3. Extract start and end coordinates
        guard let startPoint = gpxFile.route.routePoints.first else {
            print("🔧 DEV: ❌ No route points found in GPX file")
            throw NSError(domain: "DevPageViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No route points found in GPX file"])
        }
        
        guard let endPoint = gpxFile.route.routePoints.last else {
            print("🔧 DEV: ❌ No end point found in GPX file")
            throw NSError(domain: "DevPageViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "No end point found in GPX file"])
        }
        
        print("🔧 DEV: Start point - Lat: \(startPoint.latitude), Lon: \(startPoint.longitude), Name: \(startPoint.name ?? "N/A")")
        print("🔧 DEV: End point - Lat: \(endPoint.latitude), Lon: \(endPoint.longitude), Name: \(endPoint.name ?? "N/A")")
        
        // 4. Calculate bounding box
        let latitudes = gpxFile.route.routePoints.map { $0.latitude }
        let longitudes = gpxFile.route.routePoints.map { $0.longitude }
        
        let bboxNorth = latitudes.max() ?? startPoint.latitude
        let bboxSouth = latitudes.min() ?? startPoint.latitude  
        let bboxEast = longitudes.max() ?? startPoint.longitude
        let bboxWest = longitudes.min() ?? startPoint.longitude
        
        print("🔧 DEV: Calculated bounding box - North: \(bboxNorth), South: \(bboxSouth), East: \(bboxEast), West: \(bboxWest)")
        
        // 5. Create route data for Supabase
        let routeData = SupabaseRouteData(
            name: gpxFile.route.name.isEmpty ? fileName : gpxFile.route.name,
            description: "Imported from \(fileName)",
            gpxData: gpxData,
            waypointCount: gpxFile.route.routePoints.count,
            totalDistance: gpxFile.route.totalDistance,
            startLatitude: startPoint.latitude,
            startLongitude: startPoint.longitude,
            startName: startPoint.name,
            endLatitude: endPoint.latitude,
            endLongitude: endPoint.longitude,
            endName: endPoint.name,
            category: "Imported Routes",
            bboxNorth: bboxNorth,
            bboxSouth: bboxSouth,
            bboxEast: bboxEast,
            bboxWest: bboxWest
        )
        
        print("🔧 DEV: Created SupabaseRouteData successfully")
        print("🔧 DEV: Final route name: \(routeData.name)")
        print("🔧 DEV: Final route category: \(routeData.category)")
        
        return routeData
    }
    
    // MARK: - Supabase Upload
    
    private func uploadToSupabase(_ routeData: SupabaseRouteData) async throws {
        print("🔧 DEV: Starting Supabase upload for route: \(routeData.name)")
        
        // Get authenticated user session (needed for RLS policy)
        print("🔧 DEV: Getting user session for RLS authentication")
        let session = try await SupabaseManager.shared.getSession()
        print("🔧 DEV: User session obtained: \(session.user.id)")
        
        // Create RemoteEmbeddedRoute from parsed data
        print("🔧 DEV: Creating RemoteEmbeddedRoute object for RLS-protected table")
        let embeddedRoute = RemoteEmbeddedRoute(
            id: nil,
            name: routeData.name,
            description: routeData.description.isEmpty ? nil : routeData.description,
            gpxData: routeData.gpxData,
            waypointCount: routeData.waypointCount,
            totalDistance: Float(routeData.totalDistance),
            startLatitude: Float(routeData.startLatitude),
            startLongitude: Float(routeData.startLongitude),
            startName: routeData.startName,
            endLatitude: Float(routeData.endLatitude),
            endLongitude: Float(routeData.endLongitude),
            endName: routeData.endName,
            category: routeData.category,
            difficulty: nil, // Could be set based on route analysis
            region: nil, // Could be derived from location
            estimatedDurationHours: nil, // Could be calculated
            createdAt: nil, // Let Supabase set this with default
            updatedAt: nil, // Let Supabase set this with default
            isActive: true, // Default to active
            bboxNorth: Float(routeData.bboxNorth),
            bboxSouth: Float(routeData.bboxSouth),
            bboxEast: Float(routeData.bboxEast),
            bboxWest: Float(routeData.bboxWest)
        )
        
        print("🔧 DEV: RemoteEmbeddedRoute created successfully")
        print("🔧 DEV: - Route Name: \(embeddedRoute.name)")
        print("🔧 DEV: - Category: \(embeddedRoute.category ?? "nil")")
        print("🔧 DEV: - Waypoint Count: \(embeddedRoute.waypointCount)")
        print("🔧 DEV: - Total Distance: \(embeddedRoute.totalDistance)")
        print("🔧 DEV: - Is Active: \(embeddedRoute.isActive ?? false)")
        
        // Upload to Supabase using existing manager
        print("🔧 DEV: Uploading to Supabase using SupabaseManager")
        try await SupabaseManager.shared.upsertEmbeddedRoute(embeddedRoute)
        print("🔧 DEV: ✅ Upload to Supabase completed successfully")
    }
}

// MARK: - Data Structures

struct SupabaseRouteData {
    let name: String
    let description: String
    let gpxData: String
    let waypointCount: Int
    let totalDistance: Double
    let startLatitude: Double
    let startLongitude: Double
    let startName: String?
    let endLatitude: Double
    let endLongitude: Double
    let endName: String?
    let category: String
    let bboxNorth: Double
    let bboxSouth: Double
    let bboxEast: Double
    let bboxWest: Double
}

#endif