import SwiftUI
import RevenueCat

struct ContentView: View {
    @StateObject private var authViewModel = AuthenticationViewModel()

    var body: some View {
        VStack {
            if authViewModel.isAuthenticated {
                // User is authenticated, show the MainView with the paywall modifier.
                MainView()
                    .presentPaywallIfNeeded(
                        requiredEntitlementIdentifier: "Pro"
                    ) { _ in
                        DebugLogger.shared.log("Purchase successful! User now has Pro access.", category: "PURCHASE")
                    }
            } else {
                // User is not authenticated, show the AuthenticationView.
                AuthenticationView()
            }
        }
        .environmentObject(authViewModel) // Make ViewModel available to child views
    }
}
