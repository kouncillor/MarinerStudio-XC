import SwiftUI

struct ContentView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    var body: some View {
        SubscriptionGateView()
            .environmentObject(subscriptionService)
            .environmentObject(cloudKitManager)
            .environmentObject(serviceProvider)
            .onAppear {
                DebugLogger.shared.log("💰 TRIAL_SUB: ContentView appeared", category: "TRIAL_SUBSCRIPTION")
                DebugLogger.shared.log("☁️ CLOUDKIT: Using iCloud for sync", category: "CLOUDKIT")
            }
    }
}