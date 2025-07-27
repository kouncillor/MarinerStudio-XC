import Foundation
import SwiftUI
import Combine

/// ViewModel for the Voyage Plan Menu
class VoyagePlanMenuViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Initialization
    init() {
        print("🎯 INIT: VoyagePlanMenuViewModel created at \(Date())")
    }
    
    // MARK: - Navigation Methods
    
    /// Handle navigation to Favorite Routes
    func navigateToFavoriteRoutes() {
        print("📍 NAVIGATION: Navigating to Favorite Routes")
        // TODO: Implement navigation to RouteFavoritesView
    }
    
    /// Handle navigation to All Routes
    func navigateToAllRoutes() {
        print("📍 NAVIGATION: Navigating to All Routes")
        // TODO: Implement navigation to AllRoutesView
    }
    
    // MARK: - Helper Methods
    
    /// Clear any error messages
    func clearError() {
        errorMessage = ""
    }
}