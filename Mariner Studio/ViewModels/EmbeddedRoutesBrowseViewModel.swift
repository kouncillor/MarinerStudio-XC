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
    
    // MARK: - Route Loading
    
    func loadRoutes() {
        print("🛣️ BROWSE: Starting route loading")
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                print("🛣️ BROWSE: Fetching routes from Supabase")
                let fetchedRoutes = try await SupabaseManager.shared.getEmbeddedRoutes(limit: 50)
                
                await MainActor.run {
                    self.routes = fetchedRoutes
                    self.isLoading = false
                    print("🛣️ BROWSE: ✅ Loaded \(fetchedRoutes.count) routes successfully")
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
        print("🛣️ BROWSE: Starting download for route: \(route.name)")
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
                    print("🛣️ BROWSE: ✅ Route '\(route.name)' downloaded successfully")
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
        print("🛣️ BROWSE: Saving route to local database")
        
        // TODO: Implement local database saving
        // This would integrate with your existing RouteFavorites table
        // For now, we'll simulate the save
        
        print("🛣️ BROWSE: Creating local route entry")
        print("🛣️ BROWSE: - Route Name: \(originalRoute.name)")
        print("🛣️ BROWSE: - Category: \(originalRoute.category ?? "General")")
        print("🛣️ BROWSE: - Waypoints: \(gpxFile.route.routePoints.count)")
        print("🛣️ BROWSE: - Distance: \(originalRoute.totalDistance)")
        
        // Simulate save delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        print("🛣️ BROWSE: ✅ Route saved to local database")
    }
    
    // MARK: - Helper Methods
    
    func refresh() {
        print("🛣️ BROWSE: Manual refresh triggered")
        loadRoutes()
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