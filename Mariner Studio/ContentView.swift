import SwiftUI
import RevenueCat

struct ContentView: View {
    @StateObject private var authViewModel = AuthenticationViewModel()

    var body: some View {
        VStack {
            // Show MainView with paywall regardless of authentication state
            // This allows subscription purchase without requiring authentication first
            MainView()
                .presentPaywallIfNeeded(
                    requiredEntitlementIdentifier: "Pro"
                ) { _ in
                    DebugLogger.shared.log("Purchase successful! User now has Pro access.", category: "PURCHASE")
                }
                .sheet(isPresented: .constant(!authViewModel.isAuthenticated && shouldShowAuthPrompt())) {
                    // Show authentication as an optional sheet, not a requirement
                    AuthenticationPromptView()
                        .environmentObject(authViewModel)
                }
        }
        .environmentObject(authViewModel) // Make ViewModel available to child views
    }
    
    // Helper function to determine when to show auth prompt
    private func shouldShowAuthPrompt() -> Bool {
        // Only show auth prompt if user tries to access features that require authentication
        // For now, we'll make this false to allow full app access without authentication
        return false
    }
}
