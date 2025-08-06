import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var subscriptionService = SimpleSubscription()
    
    var body: some View {
        VStack {
            if subscriptionService.isPro {
                // User has subscription - show the app
                MainView()
                    .onAppear {
                        DebugLogger.shared.log("✅ SIMPLE SUB: User is Pro - showing full app", category: "SIMPLE_SUBSCRIPTION")
                    }
            } else {
                // User needs to subscribe - show paywall
                SimplePaywallView()
                    .onAppear {
                        DebugLogger.shared.log("💰 SIMPLE SUB: Showing paywall - no subscription", category: "SIMPLE_SUBSCRIPTION")
                    }
            }
        }
        .environmentObject(authViewModel)
        .environmentObject(subscriptionService)
        .sheet(isPresented: .constant(!authViewModel.isAuthenticated && shouldShowAuthPrompt())) {
            AuthenticationPromptView()
                .environmentObject(authViewModel)
        }
        .onAppear {
            DebugLogger.shared.log("💰 SIMPLE SUB: ContentView appeared - checking subscription", category: "SIMPLE_SUBSCRIPTION")
        }
    }
    
    
    // Helper function to determine when to show auth prompt
    private func shouldShowAuthPrompt() -> Bool {
        // Only show auth prompt if user tries to access features that require authentication
        // For now, we'll make this false to allow full app access without authentication
        return false
    }
}