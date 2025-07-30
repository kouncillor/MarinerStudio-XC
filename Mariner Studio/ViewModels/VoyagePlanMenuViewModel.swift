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
        // Navigation handled by SwiftUI NavigationLink in VoyagePlanMenuView
    }

    /// Handle navigation to All Routes
    func navigateToAllRoutes() {
        print("📍 NAVIGATION: Navigating to All Routes")
        // Navigation handled by SwiftUI NavigationLink in VoyagePlanMenuView
    }

    // MARK: - Helper Methods

    /// Clear any error messages
    func clearError() {
        errorMessage = ""
    }
}
