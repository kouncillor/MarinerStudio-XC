import SwiftUI

struct ContentView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @StateObject private var subscriptionService = SimpleSubscription()
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    var body: some View {
        VStack {
            if subscriptionService.isPro {
                // User has subscription - show the app
                MainView()
                    .onAppear {
                        DebugLogger.shared.log("✅ SIMPLE SUB: User is Pro - showing full app", category: "SIMPLE_SUBSCRIPTION")
                        DebugLogger.shared.log("☁️ AUTH: Using seamless CloudKit authentication", category: "CLOUDKIT_AUTH")
                    }
            } else {
                // User needs to subscribe - show paywall
                SimplePaywallView()
                    .onAppear {
                        DebugLogger.shared.log("💰 SIMPLE SUB: Showing paywall - no subscription", category: "SIMPLE_SUBSCRIPTION")
                    }
            }
        }
        .environmentObject(subscriptionService)
        .environmentObject(cloudKitManager)
        .environmentObject(serviceProvider)
        .onAppear {
            DebugLogger.shared.log("💰 SIMPLE SUB: ContentView appeared - checking subscription", category: "SIMPLE_SUBSCRIPTION")
            DebugLogger.shared.log("☁️ AUTH: No authentication prompts needed - using iCloud account", category: "CLOUDKIT_AUTH")
        }
    }
}