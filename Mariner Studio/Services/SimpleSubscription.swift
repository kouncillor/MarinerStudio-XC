import Foundation
import StoreKit

@MainActor
class SimpleSubscription: ObservableObject {
    
    // MARK: - Published Properties
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var trialDaysRemaining: Int = 0
    @Published var isLoading: Bool = false
    @Published var showTrialBanner: Bool = false
    
    // MARK: - Constants
    private let monthlyTrialProductID = "mariner_pro_monthly"
    private let trialDurationDays = 14
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let trialStartDateKey = "trialStartDate"
    private let hasUsedTrialKey = "hasUsedTrial"
    
    // MARK: - Computed Properties
    var hasAppAccess: Bool {
        return subscriptionStatus.hasAccess
    }
    
    var needsPaywall: Bool {
        return subscriptionStatus.needsPaywall
    }
    
    // MARK: - Initialization
    init() {
        DebugLogger.shared.log("💰 TRIAL_SUB: Initializing trial-enabled subscription service", category: "TRIAL_SUBSCRIPTION")
        Task {
            await determineSubscriptionStatus()
        }
    }
    
    // MARK: - Core Logic Methods
    
    func determineSubscriptionStatus() async {
        DebugLogger.shared.log("💰 TRIAL_SUB: Determining subscription status", category: "TRIAL_SUBSCRIPTION")
        isLoading = true
        
        // First check if user has an active paid subscription
        if await checkForActiveSubscription() {
            DebugLogger.shared.log("✅ TRIAL_SUB: Active subscription found", category: "TRIAL_SUBSCRIPTION")
            subscriptionStatus = .subscribed(expiryDate: nil)
            isLoading = false
            return
        }
        
        // Check trial status
        if hasUsedTrialBefore() {
            DebugLogger.shared.log("🔍 TRIAL_SUB: User has used trial before", category: "TRIAL_SUBSCRIPTION")
            if isTrialExpired() {
                DebugLogger.shared.log("❌ TRIAL_SUB: Trial expired", category: "TRIAL_SUBSCRIPTION")
                subscriptionStatus = .trialExpired
            } else {
                let daysRemaining = calculateTrialDaysRemaining()
                DebugLogger.shared.log("⏰ TRIAL_SUB: Trial active - \(daysRemaining) days remaining", category: "TRIAL_SUBSCRIPTION")
                subscriptionStatus = .inTrial(daysRemaining: daysRemaining)
                trialDaysRemaining = daysRemaining
                updateTrialBannerVisibility()
            }
        } else {
            DebugLogger.shared.log("🎉 TRIAL_SUB: First time user - ready for trial", category: "TRIAL_SUBSCRIPTION")
            subscriptionStatus = .firstLaunch
        }
        
        isLoading = false
    }
    
    func startTrial() async {
        DebugLogger.shared.log("🚀 TRIAL_SUB: Starting trial", category: "TRIAL_SUBSCRIPTION")
        
        let now = Date()
        setTrialStartDate(now)
        markTrialAsUsed()
        
        trialDaysRemaining = trialDurationDays
        subscriptionStatus = .inTrial(daysRemaining: trialDurationDays)
        
        DebugLogger.shared.log("✅ TRIAL_SUB: Trial started successfully", category: "TRIAL_SUBSCRIPTION")
    }
    
    func checkForActiveSubscription() async -> Bool {
        DebugLogger.shared.log("💰 TRIAL_SUB: Checking for active subscriptions", category: "TRIAL_SUBSCRIPTION")
        
        for await result in Transaction.all {
            if case .verified(let transaction) = result {
                if transaction.productID == monthlyTrialProductID {
                    DebugLogger.shared.log("✅ TRIAL_SUB: Active subscription found: \(transaction.productID)", category: "TRIAL_SUBSCRIPTION")
                    return true
                }
            }
        }
        
        DebugLogger.shared.log("❌ TRIAL_SUB: No active subscription found", category: "TRIAL_SUBSCRIPTION")
        return false
    }
    
    func calculateTrialDaysRemaining() -> Int {
        guard let startDate = getTrialStartDate() else {
            DebugLogger.shared.log("❌ TRIAL_SUB: No trial start date found", category: "TRIAL_SUBSCRIPTION")
            return 0
        }
        
        let calendar = Calendar.current
        let now = Date()
        let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: now).day ?? 0
        let remaining = max(0, trialDurationDays - daysSinceStart)
        
        DebugLogger.shared.log("🔢 TRIAL_SUB: Days since trial start: \(daysSinceStart), remaining: \(remaining)", category: "TRIAL_SUBSCRIPTION")
        return remaining
    }
    
    func subscribe(to productID: String) async throws {
        DebugLogger.shared.log("💰 TRIAL_SUB: Starting subscription purchase for \(productID)", category: "TRIAL_SUBSCRIPTION")
        isLoading = true
        
        do {
            let products = try await Product.products(for: [productID])
            DebugLogger.shared.log("💰 TRIAL_SUB: Products loaded - count: \(products.count)", category: "TRIAL_SUBSCRIPTION")
            
            guard let product = products.first else {
                DebugLogger.shared.log("❌ TRIAL_SUB: Product not found: \(productID)", category: "TRIAL_SUBSCRIPTION")
                throw SubscriptionError.productNotFound
            }
            
            DebugLogger.shared.log("💰 TRIAL_SUB: Purchasing: \(product.displayName) - \(product.displayPrice)", category: "TRIAL_SUBSCRIPTION")
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                DebugLogger.shared.log("🎉 TRIAL_SUB: Purchase successful", category: "TRIAL_SUBSCRIPTION")
                await processTransaction(verification.unsafePayloadValue)
            case .userCancelled:
                DebugLogger.shared.log("❌ TRIAL_SUB: User cancelled purchase", category: "TRIAL_SUBSCRIPTION")
            case .pending:
                DebugLogger.shared.log("⏳ TRIAL_SUB: Purchase pending", category: "TRIAL_SUBSCRIPTION")
            @unknown default:
                DebugLogger.shared.log("❓ TRIAL_SUB: Unknown purchase result", category: "TRIAL_SUBSCRIPTION")
            }
            
        } catch {
            DebugLogger.shared.log("❌ TRIAL_SUB: Purchase failed: \(error)", category: "TRIAL_SUBSCRIPTION")
            throw error
        }
        
        isLoading = false
    }
    
    func restorePurchases() async {
        DebugLogger.shared.log("🔄 TRIAL_SUB: Restoring purchases", category: "TRIAL_SUBSCRIPTION")
        isLoading = true
        
        do {
            try await AppStore.sync()
            await determineSubscriptionStatus()
            DebugLogger.shared.log("✅ TRIAL_SUB: Restore complete", category: "TRIAL_SUBSCRIPTION")
        } catch {
            DebugLogger.shared.log("❌ TRIAL_SUB: Restore failed: \(error)", category: "TRIAL_SUBSCRIPTION")
        }
        
        isLoading = false
    }
    
    func getAvailableProducts() async throws -> [Product] {
        DebugLogger.shared.log("💰 TRIAL_SUB: Loading available products", category: "TRIAL_SUBSCRIPTION")
        DebugLogger.shared.log("💰 TRIAL_SUB: Using Product ID: \(monthlyTrialProductID)", category: "TRIAL_SUBSCRIPTION")
        
        let productIDs = [monthlyTrialProductID]
        let products = try await Product.products(for: productIDs)
        
        DebugLogger.shared.log("💰 TRIAL_SUB: Loaded \(products.count) products", category: "TRIAL_SUBSCRIPTION")
        for product in products {
            DebugLogger.shared.log("💰 TRIAL_SUB: Product found: \(product.id) - \(product.displayName) - \(product.displayPrice)", category: "TRIAL_SUBSCRIPTION")
        }
        return products
    }
    
    // MARK: - Private Helper Methods
    
    private func hasUsedTrialBefore() -> Bool {
        return userDefaults.bool(forKey: hasUsedTrialKey)
    }
    
    private func getTrialStartDate() -> Date? {
        guard userDefaults.object(forKey: trialStartDateKey) != nil else { return nil }
        return userDefaults.object(forKey: trialStartDateKey) as? Date
    }
    
    private func setTrialStartDate(_ date: Date) {
        userDefaults.set(date, forKey: trialStartDateKey)
        DebugLogger.shared.log("📅 TRIAL_SUB: Trial start date set: \(date)", category: "TRIAL_SUBSCRIPTION")
    }
    
    private func markTrialAsUsed() {
        userDefaults.set(true, forKey: hasUsedTrialKey)
        DebugLogger.shared.log("✅ TRIAL_SUB: Trial marked as used", category: "TRIAL_SUBSCRIPTION")
    }
    
    private func isTrialExpired() -> Bool {
        let remaining = calculateTrialDaysRemaining()
        return remaining <= 0
    }
    
    private func processTransaction(_ transaction: Transaction) async {
        DebugLogger.shared.log("🔄 TRIAL_SUB: Processing transaction: \(transaction.productID)", category: "TRIAL_SUBSCRIPTION")
        
        subscriptionStatus = .subscribed(expiryDate: transaction.expirationDate)
        showTrialBanner = false
        
        DebugLogger.shared.log("✅ TRIAL_SUB: Transaction processed - user now subscribed", category: "TRIAL_SUBSCRIPTION")
    }
    
    private func updateTrialBannerVisibility() {
        // Show banner in last 5 days of trial
        showTrialBanner = trialDaysRemaining <= 5 && trialDaysRemaining > 0
        DebugLogger.shared.log("🎌 TRIAL_SUB: Trial banner visibility: \(showTrialBanner)", category: "TRIAL_SUBSCRIPTION")
    }
    
    // MARK: - Settings Management Methods
    
    func getSubscriptionStatusMessage() -> String {
        switch subscriptionStatus {
        case .subscribed(let expiryDate):
            if let expiry = expiryDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Renews on \(formatter.string(from: expiry))"
            } else {
                return "Active subscription"
            }
        case .inTrial(let days):
            return "\(days) days remaining in free trial"
        case .firstLaunch:
            return "Ready to start your free trial"
        case .trialExpired:
            return "Free trial has ended"
        case .expired:
            return "Subscription has expired"
        default:
            return "Checking status..."
        }
    }
    
    func hasTrialBeenUsed() -> Bool {
        return hasUsedTrialBefore()
    }
}

// MARK: - Error Types

enum SubscriptionError: Error, LocalizedError {
    case productNotFound
    case trialAlreadyUsed
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription product not found"
        case .trialAlreadyUsed:
            return "Trial has already been used"
        case .unknownError(let message):
            return message
        }
    }
}