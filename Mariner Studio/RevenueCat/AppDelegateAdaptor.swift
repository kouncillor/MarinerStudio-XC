import SwiftUI
import RevenueCat

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        // Get secure configuration
        let config = AppConfiguration.shared

        // Validate configuration before proceeding
        let validation = config.validateConfiguration()
        if !validation.isValid {
            DebugLogger.shared.log("❌ RevenueCat: Missing configuration keys: \(validation.missingKeys.joined(separator: ", "))", category: "CONFIG_ERROR")
            fatalError("❌ RevenueCat configuration is invalid. Missing keys: \(validation.missingKeys.joined(separator: ", "))")
        }

        // Configure RevenueCat with environment-appropriate settings
        // Set log level directly to avoid type issues
        switch config.revenueCatLogLevel {
        case "debug":
            Purchases.logLevel = .debug
        case "info":
            Purchases.logLevel = .info
        case "error":
            Purchases.logLevel = .error
        default:
            Purchases.logLevel = .error
        }

        Purchases.configure(withAPIKey: config.revenueCatAPIKey)

        // Log configuration summary (only in debug)
        #if DEBUG
        DebugLogger.shared.log("🎫 RevenueCat Configuration:", category: "REVENUECAT_INIT")
        DebugLogger.shared.log("   Environment: \(config.currentEnvironment)", category: "REVENUECAT_INIT")
        DebugLogger.shared.log("   Log Level: \(config.revenueCatLogLevel)", category: "REVENUECAT_INIT")
        DebugLogger.shared.log("   API Key: \(config.revenueCatAPIKey.prefix(20))...", category: "REVENUECAT_INIT")
        #endif

        return true
    }
}
