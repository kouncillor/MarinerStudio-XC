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
    private let monthlyTrialProductID = "mariner_pro_monthly14"
    private let trialDurationDays = 3
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let trialStartDateKey = "trialStartDate"
    private let hasUsedTrialKey = "hasUsedTrial"
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
        DebugLogger.shared.log("💰 TRIAL_SUB: Initializing trial-enabled subscription service", category: "TRIAL_SUBSCRIPTION")
        Task {
            await determineSubscriptionStatus()
        }
    }
    
    // MARK: - Core Logic Methods
    
    func determineSubscriptionStatus() async {
        DebugLogger.shared.log("💰 TRIAL_SUB: Determining subscription status", category: "TRIAL_SUBSCRIPTION")
        isLoading = true
        
        // First check if user has an active subscription
        let subscriptionResult = await checkForActiveSubscription()
        if subscriptionResult.hasSubscription, let transaction = subscriptionResult.transaction {
            DebugLogger.shared.log("✅ TRIAL_SUB: Active subscription found", category: "TRIAL_SUBSCRIPTION")
            
            // Check if this subscription is currently in its free trial period
            if hasUsedTrialBefore() && !isTrialExpired() {
                let daysRemaining = calculateTrialDaysRemaining()
                DebugLogger.shared.log("⏰ TRIAL_SUB: Subscription in trial period - \(daysRemaining) days remaining", category: "TRIAL_SUBSCRIPTION")
                subscriptionStatus = .inTrial(daysRemaining: daysRemaining)
                trialDaysRemaining = daysRemaining
                updateTrialBannerVisibility()
            } else {
                // Full paid subscription (trial period over)
                subscriptionStatus = .subscribed(expiryDate: transaction.expirationDate)
            }
            
            isLoading = false
            return
        }
        
        // No active subscription - check local trial status
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
    
    func checkForActiveSubscription() async -> (hasSubscription: Bool, transaction: Transaction?) {
        DebugLogger.shared.log("💰 TRIAL_SUB: Checking for active subscriptions", category: "TRIAL_SUBSCRIPTION")
        
        #if DEBUG
        // Check for debug override first
        if debugOverrideSubscription {
            DebugLogger.shared.log("🧪 TRIAL_SUB: Debug override enabled - ignoring StoreKit subscriptions", category: "TRIAL_SUBSCRIPTION")
            return (false, nil)
        }
        #endif
        
        for await result in Transaction.all {
            if case .verified(let transaction) = result {
                if transaction.productID == monthlyTrialProductID {
                    DebugLogger.shared.log("✅ TRIAL_SUB: Active subscription found: \(transaction.productID)", category: "TRIAL_SUBSCRIPTION")
                    return (true, transaction)
                }
            }
        }
        
        DebugLogger.shared.log("❌ TRIAL_SUB: No active subscription found", category: "TRIAL_SUBSCRIPTION")
        return (false, nil)
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
        
        // Check if this is a subscription with free trial (first time user)
        if case .firstLaunch = subscriptionStatus {
            // Mark trial as used and set start date for proper tracking
            markTrialAsUsed()
            setTrialStartDate(Date())
            DebugLogger.shared.log("🎉 TRIAL_SUB: First subscription with trial - marked trial as used", category: "TRIAL_SUBSCRIPTION")
        }
        
        subscriptionStatus = .subscribed(expiryDate: transaction.expirationDate)
        showTrialBanner = false
        
        DebugLogger.shared.log("✅ TRIAL_SUB: Transaction processed - user now subscribed", category: "TRIAL_SUBSCRIPTION")
    }
    
    private func updateTrialBannerVisibility() {
        // Show banner on day 2 of 3-day trial (1 day remaining)
        showTrialBanner = trialDaysRemaining <= 1 && trialDaysRemaining > 0
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
    
    func skipTrial() {
        DebugLogger.shared.log("⏭️ TRIAL_SUB: User skipped trial - limited access mode", category: "TRIAL_SUBSCRIPTION")
        subscriptionStatus = .skippedTrial
    }
    
    // MARK: - Daily Usage Tracking
    
    var canUseLocalWeatherToday: Bool {
        // Subscribed and trial users have unlimited access
        if hasAppAccess {
            return true
        }
        
        // For free users, check if they've used it today
        return !hasUsedLocalWeatherToday()
    }
    
    private func hasUsedLocalWeatherToday() -> Bool {
        guard let lastUsageDate = userDefaults.object(forKey: localWeatherUsageKey) as? Date else {
            return false
        }
        
        let calendar = Calendar.current
        return calendar.isDate(lastUsageDate, inSameDayAs: Date())
    }
    
    func recordLocalWeatherUsage() {
        userDefaults.set(Date(), forKey: localWeatherUsageKey)
        DebugLogger.shared.log("📍 TRIAL_SUB: Local weather usage recorded for today", category: "TRIAL_SUBSCRIPTION")
        
        // Force a UI update by triggering objectWillChange
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Local Tides Usage Tracking
    
    var canUseLocalTidesToday: Bool {
        // Subscribed and trial users have unlimited access
        if hasAppAccess {
            return true
        }
        
        // For free users, check if they've used it today
        return !hasUsedLocalTidesToday()
    }
    
    private func hasUsedLocalTidesToday() -> Bool {
        guard let lastUsageDate = userDefaults.object(forKey: localTideUsageKey) as? Date else {
            return false
        }
        
        let calendar = Calendar.current
        return calendar.isDate(lastUsageDate, inSameDayAs: Date())
    }
    
    func recordLocalTideUsage() {
        userDefaults.set(Date(), forKey: localTideUsageKey)
        DebugLogger.shared.log("🌊 TRIAL_SUB: Local tide usage recorded for today", category: "TRIAL_SUBSCRIPTION")
        
        // Force a UI update by triggering objectWillChange
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Local Currents Usage Tracking
    
    var canUseLocalCurrentsToday: Bool {
        // Subscribed and trial users have unlimited access
        if hasAppAccess {
            return true
        }
        
        // For free users, check if they've used it today
        return !hasUsedLocalCurrentsToday()
    }
    
    private func hasUsedLocalCurrentsToday() -> Bool {
        guard let lastUsageDate = userDefaults.object(forKey: localCurrentUsageKey) as? Date else {
            return false
        }
        
        let calendar = Calendar.current
        return calendar.isDate(lastUsageDate, inSameDayAs: Date())
    }
    
    func recordLocalCurrentUsage() {
        userDefaults.set(Date(), forKey: localCurrentUsageKey)
        DebugLogger.shared.log("🌊 TRIAL_SUB: Local current usage recorded for today", category: "TRIAL_SUBSCRIPTION")
        
        // Force a UI update by triggering objectWillChange
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Local Nav Units Usage Tracking
    
    var canUseLocalNavUnitsToday: Bool {
        // Subscribed and trial users have unlimited access
        if hasAppAccess {
            return true
        }
        
        // For free users, check if they've used it today
        return !hasUsedLocalNavUnitsToday()
    }
    
    private func hasUsedLocalNavUnitsToday() -> Bool {
        guard let lastUsageDate = userDefaults.object(forKey: localNavUnitUsageKey) as? Date else {
            return false
        }
        
        let calendar = Calendar.current
        return calendar.isDate(lastUsageDate, inSameDayAs: Date())
    }
    
    func recordLocalNavUnitUsage() {
        userDefaults.set(Date(), forKey: localNavUnitUsageKey)
        DebugLogger.shared.log("🧭 TRIAL_SUB: Local nav unit usage recorded for today", category: "TRIAL_SUBSCRIPTION")
        
        // Force a UI update by triggering objectWillChange
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Local Buoys Usage Tracking
    
    var canUseLocalBuoysToday: Bool {
        // Subscribed and trial users have unlimited access
        if hasAppAccess {
            return true
        }
        
        // For free users, check if they've used it today
        return !hasUsedLocalBuoysToday()
    }
    
    private func hasUsedLocalBuoysToday() -> Bool {
        guard let lastUsageDate = userDefaults.object(forKey: localBuoyUsageKey) as? Date else {
            return false
        }
        
        let calendar = Calendar.current
        return calendar.isDate(lastUsageDate, inSameDayAs: Date())
    }
    
    func recordLocalBuoyUsage() {
        userDefaults.set(Date(), forKey: localBuoyUsageKey)
        DebugLogger.shared.log("⚓ TRIAL_SUB: Local buoy usage recorded for today", category: "TRIAL_SUBSCRIPTION")
        
        // Force a UI update by triggering objectWillChange
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Debug Methods
    #if DEBUG
    func enableDebugOverride(_ enabled: Bool) {
        DebugLogger.shared.log("🧪 TRIAL_SUB: Debug override \(enabled ? "enabled" : "disabled")", category: "TRIAL_SUBSCRIPTION")
        debugOverrideSubscription = enabled
        
        // If enabling override, also clear subscription-related data
        if enabled {
            userDefaults.removeObject(forKey: "subscriptionStatus")
            userDefaults.removeObject(forKey: "subscriptionProductId")
            userDefaults.removeObject(forKey: "subscriptionPurchaseDate")
            userDefaults.synchronize()
        }
        
        Task {
            await determineSubscriptionStatus()
        }
    }
    #endif
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