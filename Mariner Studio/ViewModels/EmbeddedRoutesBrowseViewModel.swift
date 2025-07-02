//
//  EmbeddedRoutesBrowseViewModel.swift
//  Mariner Studio
//
//  Created for browsing and downloading embedded routes from Supabase.
//

import Foundation
import SwiftUI

@MainActor
class EmbeddedRoutesBrowseViewModel: ObservableObject {
    @Published var routes: [RemoteEmbeddedRoute] = []
    @Published var isLoading = false
    @Published var errorMessage: String = ""
    @Published var isDownloading = false
    @Published var downloadingRouteId: UUID? = nil
    @Published var downloadedRouteIds: Set<UUID> = []
    
    // MARK: - Dependencies
    private let allRoutesService: AllRoutesDatabaseService
    
    init(allRoutesService: AllRoutesDatabaseService? = nil) {
        // Use provided service or create a new one with shared DatabaseCore
        if let service = allRoutesService {
            self.allRoutesService = service
            print("🛣️ BROWSE: ✅ Using provided AllRoutesDatabaseService")
        } else {
            // Create new service with shared DatabaseCore for fallback
            let databaseCore = DatabaseCore()
            self.allRoutesService = AllRoutesDatabaseService(databaseCore: databaseCore)
            print("🛣️ BROWSE: ⚠️ Creating fallback AllRoutesDatabaseService")
        }
    }
    
    // MARK: - Route Loading
    
    func loadRoutes() {
        print("🛣️ BROWSE: Starting route loading")
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                print("🛣️ BROWSE: Fetching routes from Supabase")
                let fetchedRoutes = try await SupabaseManager.shared.getEmbeddedRoutes(limit: 50)
                
                // Check which routes are already downloaded
                print("🛣️ BROWSE: Checking download status for \(fetchedRoutes.count) routes")
                await checkDownloadedStatus(for: fetchedRoutes)
                
                await MainActor.run {
                    self.routes = fetchedRoutes
                    self.isLoading = false
                    print("🛣️ BROWSE: ✅ Loaded \(fetchedRoutes.count) routes successfully")
                    print("🛣️ BROWSE: 📊 Downloaded routes: \(self.downloadedRouteIds.count)/\(fetchedRoutes.count)")
                }
                
            } catch {
                print("🛣️ BROWSE: ❌ Failed to load routes: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load routes: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Route Downloading
    
    func downloadRoute(_ route: RemoteEmbeddedRoute) {
        // Check if route has a valid ID
        guard let routeId = route.id else {
            print("🛣️ BROWSE: ❌ Route '\(route.name)' has no valid ID, skipping")
            errorMessage = "Route '\(route.name)' has no valid ID"
            return
        }
        
        // Check if already downloaded
        if downloadedRouteIds.contains(routeId) {
            print("🛣️ BROWSE: ⚠️ Route '\(route.name)' is already downloaded, skipping")
            errorMessage = "Route '\(route.name)' is already downloaded"
            return
        }
        
        print("🛣️ BROWSE: Starting download for route: \(route.name)")
        print("🛣️ BROWSE: 🔍 Route ID: \(routeId)")
        isDownloading = true
        downloadingRouteId = route.id
        errorMessage = ""
        
        Task {
            do {
                print("🛣️ BROWSE: Converting route to local format")
                
                // Parse the GPX data using existing service
                let gpxService = GpxServiceFactory.shared.createServiceForReading()
                let gpxFile = try await gpxService.loadGpxFile(from: route.gpxData)
                
                print("🛣️ BROWSE: GPX parsed successfully, points: \(gpxFile.route.routePoints.count)")
                
                // Save to local database (using existing route saving logic)
                try await saveRouteToLocalDatabase(gpxFile: gpxFile, originalRoute: route)
                
                await MainActor.run {
                    self.isDownloading = false
                    self.downloadingRouteId = nil
                    if let routeId = route.id {
                        self.downloadedRouteIds.insert(routeId)
                    }
                    print("🛣️ BROWSE: ✅ Route '\(route.name)' downloaded successfully")
                    print("🛣️ BROWSE: 📊 Total downloaded routes: \(self.downloadedRouteIds.count)")
                }
                
            } catch {
                print("🛣️ BROWSE: ❌ Failed to download route: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to download '\(route.name)': \(error.localizedDescription)"
                    self.isDownloading = false
                    self.downloadingRouteId = nil
                }
            }
        }
    }
    
    // MARK: - Local Database Integration
    
    private func saveRouteToLocalDatabase(gpxFile: GpxFile, originalRoute: RemoteEmbeddedRoute) async throws {
        print("🛣️ BROWSE: Saving route to AllRoutes database")
        
        // Create AllRoute object from the remote route and GPX data
        let allRoute = AllRoute(
            name: originalRoute.name,
            gpxData: originalRoute.gpxData,
            waypointCount: gpxFile.route.routePoints.count,
            totalDistance: Double(originalRoute.totalDistance),
            sourceType: "public",
            isFavorite: false,
            createdAt: Date(),
            lastAccessedAt: Date(),
            tags: originalRoute.category,
            notes: originalRoute.description
        )
        
        print("🛣️ BROWSE: Creating local route entry")
        print("🛣️ BROWSE: - Route Name: \(originalRoute.name)")
        print("🛣️ BROWSE: - Category: \(originalRoute.category ?? "Public Route")")
        print("🛣️ BROWSE: - Source Type: public")
        print("🛣️ BROWSE: - Waypoints: \(gpxFile.route.routePoints.count)")
        print("🛣️ BROWSE: - Distance: \(originalRoute.totalDistance)")
        print("🛣️ BROWSE: - GPX Data Size: \(originalRoute.gpxData.count) characters")
        
        // Save to AllRoutes database
        let savedId = try await allRoutesService.addRouteAsync(route: allRoute)
        print("🛣️ BROWSE: ✅ Route saved to AllRoutes database with ID: \(savedId)")
    }
    
    // MARK: - Helper Methods
    
    func refresh() {
        print("🛣️ BROWSE: Manual refresh triggered")
        loadRoutes()
    }
    
    // MARK: - Download Status Checking
    
    private func checkDownloadedStatus(for routes: [RemoteEmbeddedRoute]) async {
        print("🛣️ BROWSE: 🔍 Checking download status for routes...")
        
        var newDownloadedIds: Set<UUID> = []
        
        for route in routes {
            let isDownloaded = await allRoutesService.routeExistsAsync(
                name: route.name,
                waypointCount: route.waypointCount
            )
            
            if isDownloaded, let routeId = route.id {
                newDownloadedIds.insert(routeId)
                print("🛣️ BROWSE: ✅ Route '\(route.name)' is already downloaded")
            } else {
                print("🛣️ BROWSE: 📥 Route '\(route.name)' is available for download")
            }
        }
        
        await MainActor.run {
            self.downloadedRouteIds = newDownloadedIds
            print("🛣️ BROWSE: 📊 Download status check complete: \(newDownloadedIds.count)/\(routes.count) already downloaded")
        }
    }
    
    func isRouteDownloaded(_ route: RemoteEmbeddedRoute) -> Bool {
        guard let routeId = route.id else { return false }
        return downloadedRouteIds.contains(routeId)
    }
    
    func formatDistance(_ distance: Float) -> String {
        if distance < 1.0 {
            return String(format: "%.1f m", distance * 1000)
        } else {
            return String(format: "%.1f km", distance)
        }
    }
    
    func formatCoordinate(_ coordinate: Float) -> String {
        return String(format: "%.6f°", coordinate)
    }
}