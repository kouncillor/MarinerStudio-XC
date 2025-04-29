import Foundation
import Combine
import SwiftUI

class NavUnitsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var navUnits: [NavUnit] = []
    @Published var filteredNavUnits: [NavUnit] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var totalNavUnits = 0
    
    // MARK: - Properties
    let databaseService: DatabaseService
    
    // MARK: - Initialization
    init(databaseService: DatabaseService) {
        self.databaseService = databaseService
    }
    
    // MARK: - Public Methods
    func loadNavUnits() async {
        if isLoading { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            // Get nav units from database
            let units = try await databaseService.getNavUnitsAsync()
            
            await MainActor.run {
                navUnits = units
                filteredNavUnits = units
                totalNavUnits = units.count
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load navigation units: \(error.localizedDescription)"
                navUnits = []
                filteredNavUnits = []
                isLoading = false
            }
        }
    }
    
    func filterNavUnits(searchText: String, showOnlyFavorites: Bool) {
        let filtered = navUnits.filter { navUnit in
            let matchesFavorite = !showOnlyFavorites || navUnit.isFavorite
            let matchesSearch = searchText.isEmpty ||
                navUnit.navUnitName.localizedCaseInsensitiveContains(searchText) ||
                (navUnit.location?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (navUnit.cityOrTown?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (navUnit.statePostalCode?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                navUnit.navUnitId.localizedCaseInsensitiveContains(searchText)
            
            return matchesFavorite && matchesSearch
        }
        
        filteredNavUnits = filtered
        totalNavUnits = filtered.count
    }
    
    func toggleNavUnitFavorite(navUnitId: String) async {
        do {
            // Call database service to toggle favorite
            let newFavoriteStatus = try await databaseService.toggleFavoriteNavUnitAsync(navUnitId: navUnitId)
            
            // Update our local data
            await MainActor.run {
                if let index = navUnits.firstIndex(where: { $0.navUnitId == navUnitId }) {
                    var updatedNavUnit = navUnits[index]
                    updatedNavUnit.isFavorite = newFavoriteStatus
                    navUnits[index] = updatedNavUnit
                }
                
                if let index = filteredNavUnits.firstIndex(where: { $0.navUnitId == navUnitId }) {
                    var updatedNavUnit = filteredNavUnits[index]
                    updatedNavUnit.isFavorite = newFavoriteStatus
                    filteredNavUnits[index] = updatedNavUnit
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update favorite status: \(error.localizedDescription)"
            }
        }
    }
}
