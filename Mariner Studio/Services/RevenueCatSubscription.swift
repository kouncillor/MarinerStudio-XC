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

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let localWeatherUsageKey = "localWeatherUsageDate"
    private let localTideUsageKey = "localTideUsageDate"
    private let localCurrentUsageKey = "localCurrentUsageDate"
    private let localNavUnitUsageKey = "localNavUnitUsageDate"
    private let localBuoyUsageKey = "localBuoyUsageDate"

    // New daily-limited features
    private let weatherFavoritesUsageKey = "weatherFavoritesUsageDate"
    private let weatherMapUsageKey = "weatherMapUsageKey"
    private let weatherRadarUsageKey = "weatherRadarUsageDate"
    private let tideFavoritesUsageKey = "tideFavoritesUsageDate"
    private let currentFavoritesUsageKey = "currentFavoritesUsageDate"
    private let navUnitFavoritesUsageKey = "navUnitFavoritesUsageKey"
    private let buoyFavoritesUsageKey = "buoyFavoritesUsageDate"
    private let routesUsageKey = "routesUsageDate"

    // Main menu usage keys
    private let mapMenuUsageKey = "mapMenuUsageDate"
    private let weatherMenuUsageKey = "weatherMenuUsageDate"
    private let tideMenuUsageKey = "tideMenuUsageDate"
    private let currentMenuUsageKey = "currentMenuUsageDate"
    private let navUnitMenuUsageKey = "navUnitMenuUsageDate"
    private let buoyMenuUsageKey = "buoyMenuUsageDate"
    private let routeMenuUsageKey = "routeMenuUsageDate"

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

    // MARK: - Feature Access Control
    func canAccessLocalWeather() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: localWeatherUsageKey)
    }

    func recordLocalWeatherUsage() {
        recordDailyFeatureUsage(key: localWeatherUsageKey)
        DebugLogger.shared.log("📍 RC_SUB: Local weather usage recorded for today", category: "SUBSCRIPTION")
    }

    func canAccessLocalTides() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: localTideUsageKey)
    }

    func recordLocalTideUsage() {
        recordDailyFeatureUsage(key: localTideUsageKey)
        DebugLogger.shared.log("🌊 RC_SUB: Local tide usage recorded for today", category: "SUBSCRIPTION")
    }

    func canAccessLocalCurrents() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: localCurrentUsageKey)
    }

    func recordLocalCurrentUsage() {
        recordDailyFeatureUsage(key: localCurrentUsageKey)
        DebugLogger.shared.log("🌊 RC_SUB: Local current usage recorded for today", category: "SUBSCRIPTION")
    }

    func canAccessLocalNavUnits() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: localNavUnitUsageKey)
    }

    func recordLocalNavUnitUsage() {
        recordDailyFeatureUsage(key: localNavUnitUsageKey)
        DebugLogger.shared.log("⚓ RC_SUB: Local nav unit usage recorded for today", category: "SUBSCRIPTION")
    }

    func canAccessLocalBuoys() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: localBuoyUsageKey)
    }

    func recordLocalBuoyUsage() {
        recordDailyFeatureUsage(key: localBuoyUsageKey)
        DebugLogger.shared.log("🎯 RC_SUB: Local buoy usage recorded for today", category: "SUBSCRIPTION")
    }

    // MARK: - Weather Feature Access
    func canAccessWeatherFavorites() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: weatherFavoritesUsageKey)
    }

    func recordWeatherFavoritesUsage() {
        recordDailyFeatureUsage(key: weatherFavoritesUsageKey)
        DebugLogger.shared.log("⭐ RC_SUB: Weather favorites usage recorded for today", category: "SUBSCRIPTION")
    }

    func canAccessWeatherMap() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: weatherMapUsageKey)
    }

    func recordWeatherMapUsage() {
        recordDailyFeatureUsage(key: weatherMapUsageKey)
        DebugLogger.shared.log("🗺️ RC_SUB: Weather map usage recorded for today", category: "SUBSCRIPTION")
    }

    func canAccessWeatherRadar() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: weatherRadarUsageKey)
    }

    func recordWeatherRadarUsage() {
        recordDailyFeatureUsage(key: weatherRadarUsageKey)
        DebugLogger.shared.log("📡 RC_SUB: Weather radar usage recorded for today", category: "SUBSCRIPTION")
    }

    // MARK: - Tide Feature Access
    func canAccessTideFavorites() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: tideFavoritesUsageKey)
    }

    func recordTideFavoritesUsage() {
        recordDailyFeatureUsage(key: tideFavoritesUsageKey)
        DebugLogger.shared.log("⭐ RC_SUB: Tide favorites usage recorded for today", category: "SUBSCRIPTION")
    }

    // MARK: - Current Feature Access
    func canAccessCurrentFavorites() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: currentFavoritesUsageKey)
    }

    func recordCurrentFavoritesUsage() {
        recordDailyFeatureUsage(key: currentFavoritesUsageKey)
        DebugLogger.shared.log("⭐ RC_SUB: Current favorites usage recorded for today", category: "SUBSCRIPTION")
    }

    // MARK: - Nav Unit Feature Access
    func canAccessNavUnitFavorites() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: navUnitFavoritesUsageKey)
    }

    func recordNavUnitFavoritesUsage() {
        recordDailyFeatureUsage(key: navUnitFavoritesUsageKey)
        DebugLogger.shared.log("⚓ RC_SUB: Nav unit favorites usage recorded for today", category: "SUBSCRIPTION")
    }

    // MARK: - Buoy Feature Access
    func canAccessBuoyFavorites() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: buoyFavoritesUsageKey)
    }

    func recordBuoyFavoritesUsage() {
        recordDailyFeatureUsage(key: buoyFavoritesUsageKey)
        DebugLogger.shared.log("⭐ RC_SUB: Buoy favorites usage recorded for today", category: "SUBSCRIPTION")
    }

    // MARK: - Routes Feature Access
    func canAccessRoutes() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: routesUsageKey)
    }

    func recordRoutesUsage() {
        recordDailyFeatureUsage(key: routesUsageKey)
        DebugLogger.shared.log("🗺️ RC_SUB: Routes usage recorded for today", category: "SUBSCRIPTION")
    }

    // MARK: - Main Menu Access Control
    func canAccessMapMenu() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: mapMenuUsageKey, limit: 2)
    }

    func recordMapMenuUsage() {
        recordDailyFeatureUsage(key: mapMenuUsageKey)
        DebugLogger.shared.log("🗺️ RC_SUB: Map menu usage recorded for today", category: "SUBSCRIPTION")
    }

    func canAccessWeatherMenu() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: weatherMenuUsageKey, limit: 2)
    }

    func recordWeatherMenuUsage() {
        recordDailyFeatureUsage(key: weatherMenuUsageKey)
        DebugLogger.shared.log("☀️ RC_SUB: Weather menu usage recorded for today", category: "SUBSCRIPTION")
    }

    func canAccessTideMenu() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: tideMenuUsageKey, limit: 2)
    }

    func recordTideMenuUsage() {
        recordDailyFeatureUsage(key: tideMenuUsageKey)
        DebugLogger.shared.log("🌊 RC_SUB: Tide menu usage recorded for today", category: "SUBSCRIPTION")
    }

    func canAccessCurrentMenu() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: currentMenuUsageKey, limit: 2)
    }

    func recordCurrentMenuUsage() {
        recordDailyFeatureUsage(key: currentMenuUsageKey)
        DebugLogger.shared.log("💨 RC_SUB: Current menu usage recorded for today", category: "SUBSCRIPTION")
    }

    func canAccessNavUnitMenu() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: navUnitMenuUsageKey, limit: 2)
    }

    func recordNavUnitMenuUsage() {
        recordDailyFeatureUsage(key: navUnitMenuUsageKey)
        DebugLogger.shared.log("⚓ RC_SUB: Nav unit menu usage recorded for today", category: "SUBSCRIPTION")
    }

    func canAccessBuoyMenu() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: buoyMenuUsageKey, limit: 2)
    }

    func recordBuoyMenuUsage() {
        recordDailyFeatureUsage(key: buoyMenuUsageKey)
        DebugLogger.shared.log("🎯 RC_SUB: Buoy menu usage recorded for today", category: "SUBSCRIPTION")
    }

    func canAccessRouteMenu() -> Bool {
        if subscriptionStatus.hasAccess { return true }
        return canUseDailyFeature(key: routeMenuUsageKey, limit: 3)
    }

    func recordRouteMenuUsage() {
        recordDailyFeatureUsage(key: routeMenuUsageKey)
        DebugLogger.shared.log("🛤️ RC_SUB: Route menu usage recorded for today", category: "SUBSCRIPTION")
    }

    func getRemainingMapMenuUses() -> Int {
        return getRemainingUses(key: mapMenuUsageKey, limit: 2)
    }

    func getRemainingWeatherMenuUses() -> Int {
        return getRemainingUses(key: weatherMenuUsageKey, limit: 2)
    }

    func getRemainingTideMenuUses() -> Int {
        return getRemainingUses(key: tideMenuUsageKey, limit: 2)
    }

    func getRemainingCurrentMenuUses() -> Int {
        return getRemainingUses(key: currentMenuUsageKey, limit: 2)
    }

    func getRemainingNavUnitMenuUses() -> Int {
        return getRemainingUses(key: navUnitMenuUsageKey, limit: 2)
    }

    func getRemainingBuoyMenuUses() -> Int {
        return getRemainingUses(key: buoyMenuUsageKey, limit: 2)
    }

    func getRemainingRouteMenuUses() -> Int {
        return getRemainingUses(key: routeMenuUsageKey, limit: 3)
    }

    // MARK: - Daily Usage Tracking
    private func canUseDailyFeature(key: String, limit: Int = 1) -> Bool {
        let today = getTodayString()
        let dateKey = key
        let countKey = "\(key)Count"

        let storedDate = userDefaults.string(forKey: dateKey)
        let count = userDefaults.integer(forKey: countKey)

        // If it's a new day, reset count
        if storedDate != today {
            return true
        }

        // Check if we've reached the limit for today
        return count < limit
    }

    private func getRemainingUses(key: String, limit: Int) -> Int {
        let today = getTodayString()
        let dateKey = key
        let countKey = "\(key)Count"

        let storedDate = userDefaults.string(forKey: dateKey)
        let count = userDefaults.integer(forKey: countKey)

        // If it's a new day, return full limit
        if storedDate != today {
            return limit
        }

        // Return remaining uses
        return max(0, limit - count)
    }

    private func recordDailyFeatureUsage(key: String) {
        let today = getTodayString()
        let dateKey = key
        let countKey = "\(key)Count"

        let storedDate = userDefaults.string(forKey: dateKey)

        // If it's a new day, reset to 1
        if storedDate != today {
            userDefaults.set(today, forKey: dateKey)
            userDefaults.set(1, forKey: countKey)
        } else {
            // Increment the count
            let currentCount = userDefaults.integer(forKey: countKey)
            userDefaults.set(currentCount + 1, forKey: countKey)
        }
    }

    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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
