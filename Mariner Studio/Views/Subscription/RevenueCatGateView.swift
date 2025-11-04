import SwiftUI
import RevenueCat
import RevenueCatUI

struct RevenueCatGateView: View {
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    @State private var isCheckingStatus = true
    @State private var testOffering: Offering?

    // MARK: - Debug bypass for simulator screenshots
    #if targetEnvironment(simulator)
    private let bypassPaywallInSimulator = true // Set to false to test paywall in simulator
    #else
    private let bypassPaywallInSimulator = false
    #endif

    var body: some View {
        Group {
            // Simulator bypass for screenshots
            if bypassPaywallInSimulator {
                MainView()
                    .onAppear {
                        DebugLogger.shared.log("🎬 RC_SUB: Simulator paywall bypass active for screenshots", category: "SUBSCRIPTION")
                    }
            } else if isCheckingStatus {
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
                    // HARD PAYWALL: Show only the paywall, no app access
                    paywallContent
                        .onAppear {
                            DebugLogger.shared.log("🔍 RC_SUB: HARD PAYWALL showing - no app access", category: "SUBSCRIPTION")
                        }
                }
            }
        }
        .onAppear {
            DebugLogger.shared.log("🔍 RC_SUB: RevenueCatGateView appeared", category: "SUBSCRIPTION")
            Task {
                // Load the new paywall offering
                do {
                    let offerings = try await Purchases.shared.offerings()
                    testOffering = offerings.offering(identifier: "rev_cat_template")
                    DebugLogger.shared.log("✅ RC_SUB: Loaded rev_cat_template offering", category: "SUBSCRIPTION")
                } catch {
                    DebugLogger.shared.log("❌ RC_SUB: Failed to load offering: \(error)", category: "SUBSCRIPTION")
                }

                await subscriptionService.determineSubscriptionStatus()
                isCheckingStatus = false
            }
        }
    }

    // MARK: - Paywall Content (Hard Paywall - Non-Dismissible)
    private var paywallContent: some View {
        Group {
            if let offering = testOffering {
                PaywallView(offering: offering)
                    .onRestoreCompleted { customerInfo in
                        DebugLogger.shared.log("✅ RC_SUB: Restore completed", category: "SUBSCRIPTION")
                        // Subscription status will update automatically via delegate
                    }
                    .onPurchaseCompleted { customerInfo in
                        DebugLogger.shared.log("✅ RC_SUB: Purchase/Trial started", category: "SUBSCRIPTION")
                        // Subscription status will update automatically via delegate
                        // View will switch to MainView when subscriptionStatus becomes .subscribed
                    }
                    .onPurchaseFailure { error in
                        DebugLogger.shared.log("❌ RC_SUB: Purchase failed: \(error)", category: "SUBSCRIPTION")
                    }
                    .interactiveDismissDisabled(true) // Prevent any dismiss gestures
            } else {
                ProgressView("Loading paywall...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
        }
    }
}

#Preview {
    RevenueCatGateView()
        .environmentObject(RevenueCatSubscription())
}
