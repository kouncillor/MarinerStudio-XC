import Foundation
import SwiftUI
import Combine

/// ViewModel for Voyage Plan Routes - simple route selection for voyage planning
@MainActor
class VoyagePlanRoutesViewModel: ObservableObject {
    @Published var routes: [AllRoute] = []
    @Published var filteredRoutes: [AllRoute] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String = ""
    
    // MARK: - Dependencies
    private let allRoutesService: AllRoutesDatabaseService
    
    init(allRoutesService: AllRoutesDatabaseService? = nil) {
        // Use provided service or create a new one with shared DatabaseCore
        if let service = allRoutesService {
            self.allRoutesService = service
            print("🗺️ VOYAGE_PLAN_ROUTES: ✅ Using provided AllRoutesDatabaseService")
        } else {
            // Create new service with shared DatabaseCore for fallback
            let databaseCore = DatabaseCore()
            self.allRoutesService = AllRoutesDatabaseService(databaseCore: databaseCore)
            print("🗺️ VOYAGE_PLAN_ROUTES: ⚠️ Creating fallback AllRoutesDatabaseService")
        }
        
        // Monitor search text changes to trigger filtering
        $searchText
            .sink { [weak self] _ in
                self?.applyFilter()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Route Loading
    
    func loadRoutes() {
        print("🗺️ VOYAGE_PLAN_ROUTES: Starting route loading")
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let loadedRoutes = try await allRoutesService.getAllRoutesAsync()
                
                await MainActor.run {
                    routes = loadedRoutes
                    applyFilter()
                    isLoading = false
                    print("🗺️ VOYAGE_PLAN_ROUTES: ✅ Loaded \(loadedRoutes.count) routes")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load routes: \(error.localizedDescription)"
                    isLoading = false
                    print("🗺️ VOYAGE_PLAN_ROUTES: ❌ Error loading routes: \(error)")
                }
            }
        }
    }
    
    // MARK: - Filtering
    
    func applyFilter() {
        if searchText.isEmpty {
            filteredRoutes = routes
        } else {
            filteredRoutes = routes.filter { route in
                route.name.localizedCaseInsensitiveContains(searchText) ||
                route.sourceType.localizedCaseInsensitiveContains(searchText) ||
                (route.tags?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        print("🗺️ VOYAGE_PLAN_ROUTES: Filtered to \(filteredRoutes.count) routes")
    }
    
    // MARK: - Route Actions
    
    func refresh() {
        print("🗺️ VOYAGE_PLAN_ROUTES: Refreshing routes")
        loadRoutes()
    }
    
    // MARK: - Helper Methods
    
    /// Clear any error messages
    func clearError() {
        errorMessage = ""
    }
}