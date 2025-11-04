import Foundation
import RevenueCat
import SwiftUI

@MainActor
class RevenueCatSubscription: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var isLoading: Bool = false
    @Published var customerInfo: CustomerInfo?

    // MARK: - Constants
    private let entitlementID = "Pro"  // Your RevenueCat entitlement

    // MARK: - Computed Properties
    var hasAppAccess: Bool {
        return subscriptionStatus.hasAccess
    }

    var needsPaywall: Bool {
        return subscriptionStatus.needsPaywall
    }

    // MARK: - Initialization
    override init() {
        super.init()

        DebugLogger.shared.log("🔍 RC_SUB: ========== REVENUECAT SUBSCRIPTION INIT ==========", category: "SUBSCRIPTION")

        // Configure RevenueCat
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "appl_owWBbZSrntrBRGfXiVahtAozFrk")

        // Set up delegate for updates
        Purchases.shared.delegate = self

        DebugLogger.shared.log("🔍 RC_SUB: RevenueCat configured", category: "SUBSCRIPTION")

        Task {
            await determineSubscriptionStatus()
        }
    }

    // MARK: - Subscription Status
    func determineSubscriptionStatus() async {
        DebugLogger.shared.log("🔍 RC_SUB: Starting subscription status determination", category: "SUBSCRIPTION")

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo

            DebugLogger.shared.log("🔍 RC_SUB: Customer info retrieved", category: "SUBSCRIPTION")
            DebugLogger.shared.log("🔍 RC_SUB: Active entitlements: \(customerInfo.entitlements.active.keys)", category: "SUBSCRIPTION")

            if customerInfo.entitlements[entitlementID]?.isActive == true {
                let expiryDate = customerInfo.entitlements[entitlementID]?.expirationDate
                subscriptionStatus = .subscribed(expiryDate: expiryDate)
                DebugLogger.shared.log("✅ RC_SUB: Active subscription found", category: "SUBSCRIPTION")
            } else {
                subscriptionStatus = .firstLaunch
                DebugLogger.shared.log("🔍 RC_SUB: No active subscription found", category: "SUBSCRIPTION")
            }

        } catch {
            DebugLogger.shared.log("❌ RC_SUB: Failed to get customer info: \(error)", category: "SUBSCRIPTION")
            subscriptionStatus = .unknown
        }
    }

    func restorePurchases() async {
        DebugLogger.shared.log("🔄 RC_SUB: Restoring purchases", category: "SUBSCRIPTION")
        isLoading = true

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            await determineSubscriptionStatus()
            DebugLogger.shared.log("✅ RC_SUB: Restore complete", category: "SUBSCRIPTION")
        } catch {
            DebugLogger.shared.log("❌ RC_SUB: Restore failed: \(error)", category: "SUBSCRIPTION")
        }

        isLoading = false
    }

    // MARK: - Subscription Status Display
    var subscriptionStatusMessage: String {
        switch subscriptionStatus {
        case .unknown:
            return "Checking subscription status..."
        case .firstLaunch:
            return "Subscribe for full access"
        case .subscribed:
            return "Subscribed"
        case .expired:
            return "Subscription expired"
        }
    }
}

// MARK: - PurchasesDelegate
extension RevenueCatSubscription: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            DebugLogger.shared.log("🔄 RC_SUB: Received updated customer info", category: "SUBSCRIPTION")
            self.customerInfo = customerInfo
            await determineSubscriptionStatus()
        }
    }
}
