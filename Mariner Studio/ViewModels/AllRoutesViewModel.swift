//
//  AllRoutesViewModel.swift
//  Mariner Studio
//
//  Created for managing all routes display and filtering.
//

import Foundation
import SwiftUI

@MainActor
class AllRoutesViewModel: ObservableObject {
    @Published var routes: [AllRoute] = []
    @Published var filteredRoutes: [AllRoute] = []
    @Published var isLoading = false
    @Published var errorMessage: String = ""
    @Published var selectedFilter: String = "all"
    
    // MARK: - Dependencies
    private let allRoutesService: AllRoutesDatabaseService
    
    init(allRoutesService: AllRoutesDatabaseService? = nil) {
        // Use provided service or create a new one with shared DatabaseCore
        if let service = allRoutesService {
            self.allRoutesService = service
            print("📋 ALL ROUTES: ✅ Using provided AllRoutesDatabaseService")
        } else {
            // Create new service with shared DatabaseCore for fallback
            let databaseCore = DatabaseCore()
            self.allRoutesService = AllRoutesDatabaseService(databaseCore: databaseCore)
            print("📋 ALL ROUTES: ⚠️ Creating fallback AllRoutesDatabaseService")
        }
    }
    
    // MARK: - Route Loading
    
    func loadRoutes() {
        print("📋 ALL ROUTES: Starting route loading")
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                print("📋 ALL ROUTES: Fetching routes from local database")
                let fetchedRoutes = try await allRoutesService.getAllRoutesAsync()
                
                await MainActor.run {
                    self.routes = fetchedRoutes
                    self.applyFilter()
                    self.isLoading = false
                    print("📋 ALL ROUTES: ✅ Loaded \(fetchedRoutes.count) routes successfully")
                    self.printRouteSummary()
                }
                
            } catch {
                print("📋 ALL ROUTES: ❌ Failed to load routes: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load routes: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Filtering
    
    func applyFilter() {
        switch selectedFilter {
        case "all":
            filteredRoutes = routes
        case "public":
            filteredRoutes = routes.filter { $0.sourceType == "public" }
        case "imported":
            filteredRoutes = routes.filter { $0.sourceType == "imported" }
        case "created":
            filteredRoutes = routes.filter { $0.sourceType == "created" }
        default:
            filteredRoutes = routes
        }
        
        print("📋 ALL ROUTES: 🔍 Applied filter '\(selectedFilter)': \(filteredRoutes.count)/\(routes.count) routes")
    }
    
    // MARK: - Route Actions
    
    func toggleFavorite(_ route: AllRoute) {
        print("📋 ALL ROUTES: Toggling favorite for route: \(route.name)")
        
        Task {
            do {
                try await allRoutesService.toggleFavoriteAsync(routeId: route.id)
                
                // Reload routes to reflect the change
                await loadRoutes()
                
                print("📋 ALL ROUTES: ✅ Successfully toggled favorite for '\(route.name)'")
                
            } catch {
                print("📋 ALL ROUTES: ❌ Failed to toggle favorite: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to update favorite status: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func deleteRoute(_ route: AllRoute) {
        print("📋 ALL ROUTES: Deleting route: \(route.name) (ID: \(route.id))")
        
        Task {
            do {
                let affectedRows = try await allRoutesService.deleteRouteAsync(routeId: route.id)
                
                if affectedRows > 0 {
                    // Remove from local arrays
                    await MainActor.run {
                        self.routes.removeAll { $0.id == route.id }
                        self.applyFilter()
                    }
                    
                    print("📋 ALL ROUTES: ✅ Successfully deleted route '\(route.name)'")
                } else {
                    print("📋 ALL ROUTES: ⚠️ No rows affected when deleting route '\(route.name)'")
                }
                
            } catch {
                print("📋 ALL ROUTES: ❌ Failed to delete route: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to delete route: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func refresh() {
        print("📋 ALL ROUTES: Manual refresh triggered")
        loadRoutes()
    }
    
    private func printRouteSummary() {
        let publicCount = routes.filter { $0.sourceType == "public" }.count
        let importedCount = routes.filter { $0.sourceType == "imported" }.count
        let createdCount = routes.filter { $0.sourceType == "created" }.count
        let favoriteCount = routes.filter { $0.isFavorite }.count
        
        print("📋 ALL ROUTES: 📊 Route Summary:")
        print("📋 ALL ROUTES: 📊 - Total: \(routes.count)")
        print("📋 ALL ROUTES: 📊 - Public: \(publicCount)")
        print("📋 ALL ROUTES: 📊 - Imported: \(importedCount)")
        print("📋 ALL ROUTES: 📊 - Created: \(createdCount)")
        print("📋 ALL ROUTES: 📊 - Favorites: \(favoriteCount)")
    }
}