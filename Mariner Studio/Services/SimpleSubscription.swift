import Foundation
import StoreKit

@MainActor
class SimpleSubscription: ObservableObject {
    
    // MARK: - Published Properties
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var isLoading: Bool = false
    
    // MARK: - Constants
    private let monthlyProductID = "mariner_pro_monthly14"
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let localWeatherUsageKey = "localWeatherUsageDate"
    private let localTideUsageKey = "localTideUsageDate"
    private let localCurrentUsageKey = "localCurrentUsageDate"
    private let localNavUnitUsageKey = "localNavUnitUsageDate"
    private let localBuoyUsageKey = "localBuoyUsageDate"
    
    // MARK: - Debug Properties
    #if DEBUG
    private let debugOverrideSubscriptionKey = "debugOverrideSubscription"
    private var debugOverrideSubscription: Bool {
        get { userDefaults.bool(forKey: debugOverrideSubscriptionKey) }
        set { userDefaults.set(newValue, forKey: debugOverrideSubscriptionKey) }
    }
    #endif
    
    // MARK: - Computed Properties
    var hasAppAccess: Bool {
        return subscriptionStatus.hasAccess
    }
    
    var needsPaywall: Bool {
        return subscriptionStatus.needsPaywall
    }
    
    // MARK: - Initialization
    init() {
        DebugLogger.shared.log("💰 SIMPLE_SUB: Initializing simple subscription service", category: "SUBSCRIPTION")
        Task {
            await determineSubscriptionStatus()
        }
    }
    
    // MARK: - Subscription Status
    func determineSubscriptionStatus() async {
        DebugLogger.shared.log("💰 SIMPLE_SUB: Determining subscription status", category: "SUBSCRIPTION")
        
        #if DEBUG
        if debugOverrideSubscription {
            DebugLogger.shared.log("🧪 SIMPLE_SUB: Debug override enabled - ignoring StoreKit subscriptions", category: "SUBSCRIPTION")
            subscriptionStatus = .firstLaunch
            return
        }
        #endif
        
        // Check for active StoreKit subscriptions
        await checkActiveSubscriptions()
    }
    
    private func checkActiveSubscriptions() async {
        DebugLogger.shared.log("💰 SIMPLE_SUB: Checking for active subscriptions", category: "SUBSCRIPTION")
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                DebugLogger.shared.log("✅ SIMPLE_SUB: Active subscription found: \(transaction.productID)", category: "SUBSCRIPTION")
                
                if transaction.productID == monthlyProductID {
                    subscriptionStatus = .subscribed(expiryDate: transaction.expirationDate)
                    DebugLogger.shared.log("✅ SIMPLE_SUB: Active subscription found", category: "SUBSCRIPTION")
                    return
                }
            } catch {
                DebugLogger.shared.log("❌ SIMPLE_SUB: Transaction verification failed: \(error)", category: "SUBSCRIPTION")
            }
        }
        
        // No active subscription found - first time user
        DebugLogger.shared.log("🎉 SIMPLE_SUB: No active subscription - first time user", category: "SUBSCRIPTION")
        subscriptionStatus = .firstLaunch
    }
    
    func subscribe(to productID: String) async throws {
        DebugLogger.shared.log("💰 SIMPLE_SUB: Starting subscription purchase for \(productID)", category: "SUBSCRIPTION")
        isLoading = true
        
        do {
            let products = try await Product.products(for: [productID])
            DebugLogger.shared.log("💰 SIMPLE_SUB: Products loaded - count: \(products.count)", category: "SUBSCRIPTION")
            
            guard let product = products.first else {
                DebugLogger.shared.log("❌ SIMPLE_SUB: Product not found: \(productID)", category: "SUBSCRIPTION")
                throw SubscriptionError.productNotFound
            }
            
            DebugLogger.shared.log("💰 SIMPLE_SUB: Purchasing: \(product.displayName) - \(product.displayPrice)", category: "SUBSCRIPTION")
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                DebugLogger.shared.log("🎉 SIMPLE_SUB: Purchase successful", category: "SUBSCRIPTION")
                await processTransaction(verification.unsafePayloadValue)
            case .userCancelled:
                DebugLogger.shared.log("❌ SIMPLE_SUB: User cancelled purchase", category: "SUBSCRIPTION")
            case .pending:
                DebugLogger.shared.log("⏳ SIMPLE_SUB: Purchase pending", category: "SUBSCRIPTION")
            @unknown default:
                DebugLogger.shared.log("❓ SIMPLE_SUB: Unknown purchase result", category: "SUBSCRIPTION")
            }
            
        } catch {
            DebugLogger.shared.log("❌ SIMPLE_SUB: Purchase failed: \(error)", category: "SUBSCRIPTION")
            throw error
        }
        
        isLoading = false
    }
    
    func restorePurchases() async {
        DebugLogger.shared.log("🔄 SIMPLE_SUB: Restoring purchases", category: "SUBSCRIPTION")
        isLoading = true
        
        do {
            try await AppStore.sync()
            await determineSubscriptionStatus()
            DebugLogger.shared.log("✅ SIMPLE_SUB: Restore complete", category: "SUBSCRIPTION")
        } catch {
            DebugLogger.shared.log("❌ SIMPLE_SUB: Restore failed: \(error)", category: "SUBSCRIPTION")
        }
        
        isLoading = false
    }
    
    func getAvailableProducts() async throws -> [Product] {
        DebugLogger.shared.log("💰 SIMPLE_SUB: Loading available products", category: "SUBSCRIPTION")
        DebugLogger.shared.log("💰 SIMPLE_SUB: Using Product ID: \(monthlyProductID)", category: "SUBSCRIPTION")
        
        let productIDs = [monthlyProductID]
        let products = try await Product.products(for: productIDs)
        
        DebugLogger.shared.log("💰 SIMPLE_SUB: Loaded \(products.count) products", category: "SUBSCRIPTION")
        
        for product in products {
            DebugLogger.shared.log("💰 SIMPLE_SUB: Product found: \(product.id) - \(product.displayName) - \(product.displayPrice)", category: "SUBSCRIPTION")
        }
        
        return products
    }
    
    private func processTransaction(_ transaction: Transaction) async {
        if transaction.productID == monthlyProductID {
            subscriptionStatus = .subscribed(expiryDate: transaction.expirationDate)
            DebugLogger.shared.log("🎉 SIMPLE_SUB: Subscription activated", category: "SUBSCRIPTION")
        }
        
        await transaction.finish()
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
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
    
    // MARK: - Feature Access Control
    func canAccessLocalWeather() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: localWeatherUsageKey)
    }
    
    func recordLocalWeatherUsage() {
        recordDailyFeatureUsage(key: localWeatherUsageKey)
        DebugLogger.shared.log("📍 SIMPLE_SUB: Local weather usage recorded for today", category: "SUBSCRIPTION")
    }
    
    func canAccessLocalTides() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: localTideUsageKey)
    }
    
    func recordLocalTideUsage() {
        recordDailyFeatureUsage(key: localTideUsageKey)
        DebugLogger.shared.log("🌊 SIMPLE_SUB: Local tide usage recorded for today", category: "SUBSCRIPTION")
    }
    
    func canAccessLocalCurrents() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: localCurrentUsageKey)
    }
    
    func recordLocalCurrentUsage() {
        recordDailyFeatureUsage(key: localCurrentUsageKey)
        DebugLogger.shared.log("🌊 SIMPLE_SUB: Local current usage recorded for today", category: "SUBSCRIPTION")
    }
    
    func canAccessLocalNavUnits() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: localNavUnitUsageKey)
    }
    
    func recordLocalNavUnitUsage() {
        recordDailyFeatureUsage(key: localNavUnitUsageKey)
        DebugLogger.shared.log("⚓ SIMPLE_SUB: Local nav unit usage recorded for today", category: "SUBSCRIPTION")
    }
    
    func canAccessLocalBuoys() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: localBuoyUsageKey)
    }
    
    func recordLocalBuoyUsage() {
        recordDailyFeatureUsage(key: localBuoyUsageKey)
        DebugLogger.shared.log("🎯 SIMPLE_SUB: Local buoy usage recorded for today", category: "SUBSCRIPTION")
    }
    
    // MARK: - Daily Usage Tracking
    private func canUseDailyFeature(key: String) -> Bool {
        let today = getTodayString()
        let lastUsage = userDefaults.string(forKey: key)
        return lastUsage != today
    }
    
    private func recordDailyFeatureUsage(key: String) {
        let today = getTodayString()
        userDefaults.set(today, forKey: key)
    }
    
    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // MARK: - Debug Functions
    #if DEBUG
    func enableDebugSubscription() {
        debugOverrideSubscription = true
        Task {
            await determineSubscriptionStatus()
        }
    }
    
    func disableDebugSubscription() {
        debugOverrideSubscription = false
        Task {
            await determineSubscriptionStatus()
        }
    }
    
    func resetSubscriptionState() {
        // Clear all subscription-related UserDefaults
        userDefaults.removeObject(forKey: localWeatherUsageKey)
        userDefaults.removeObject(forKey: localTideUsageKey)
        userDefaults.removeObject(forKey: localCurrentUsageKey)
        userDefaults.removeObject(forKey: localNavUnitUsageKey)
        userDefaults.removeObject(forKey: localBuoyUsageKey)
        
        // ENABLE debug override to force first launch behavior
        debugOverrideSubscription = true
        
        DebugLogger.shared.log("🔄 SIMPLE_SUB: Subscription state reset - forcing first launch", category: "SUBSCRIPTION")
        
        Task {
            await determineSubscriptionStatus()
        }
    }
    #endif
}

// MARK: - Error Types
enum SubscriptionError: Error, LocalizedError {
    case productNotFound
    case failedVerification
    case networkError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription product not found"
        case .failedVerification:
            return "Failed to verify subscription"
        case .networkError:
            return "Network error occurred"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}