import SwiftUI
import RevenueCat
import RevenueCatUI

struct RevenueCatGateView: View {
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    @State private var isCheckingStatus = true
    @State private var showPaywall = false

    var body: some View {
        Group {
            if isCheckingStatus {
                // Loading screen while checking subscription status
                ProgressView("Checking subscription status...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else {
                // Determine what to show based on subscription status
                switch subscriptionService.subscriptionStatus {
                case .subscribed:
                    // User has active subscription - allow access
                    MainView()
                        .onAppear {
                            DebugLogger.shared.log("🔍 RC_SUB: UI showing MainView (subscribed)", category: "SUBSCRIPTION")
                        }

                case .firstLaunch, .expired, .unknown:
                    // No valid access - show RevenueCat paywall
                    MainView()
                        .sheet(isPresented: $showPaywall) {
                            PaywallView()
                                .onRestoreCompleted { customerInfo in
                                    DebugLogger.shared.log("✅ RC_SUB: Restore completed", category: "SUBSCRIPTION")
                                }
                                .onPurchaseCompleted { customerInfo in
                                    DebugLogger.shared.log("✅ RC_SUB: Purchase completed", category: "SUBSCRIPTION")
                                    showPaywall = false
                                }
                                .onPurchaseFailure { error in
                                    DebugLogger.shared.log("❌ RC_SUB: Purchase failed: \(error)", category: "SUBSCRIPTION")
                                }
                        }
                        .onAppear {
                            DebugLogger.shared.log("🔍 RC_SUB: UI showing paywall", category: "SUBSCRIPTION")
                            showPaywall = true
                        }
                }
            }
        }
        .onAppear {
            DebugLogger.shared.log("🔍 RC_SUB: RevenueCatGateView appeared", category: "SUBSCRIPTION")
            Task {
                await subscriptionService.determineSubscriptionStatus()
                isCheckingStatus = false
            }
        }
    }
}

#Preview {
    RevenueCatGateView()
        .environmentObject(RevenueCatSubscription())
}
