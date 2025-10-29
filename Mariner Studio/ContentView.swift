import SwiftUI

struct ContentView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    @StateObject private var cloudKitManager = CloudKitManager.shared

    var body: some View {
        RevenueCatGateView()
            .environmentObject(subscriptionService)
            .environmentObject(cloudKitManager)
            .environmentObject(serviceProvider)
            .onAppear {
                DebugLogger.shared.log("💰 RC_SUB: ContentView appeared", category: "SUBSCRIPTION")
                DebugLogger.shared.log("☁️ CLOUDKIT: Using iCloud for sync", category: "CLOUDKIT")
            }
    }
}