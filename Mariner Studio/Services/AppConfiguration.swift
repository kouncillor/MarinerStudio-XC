//
//  AppConfiguration.swift
//  Mariner Studio
//
//  Secure API key and environment configuration management
//

import Foundation

/// Centralized configuration manager for API keys and environment-specific settings
class AppConfiguration {

    // MARK: - Singleton
    static let shared = AppConfiguration()
    private init() {}

    // MARK: - Environment Detection

    /// Current app environment
    enum Environment {
        case debug
        case testFlight
        case production
    }

    /// Detect current environment
    var currentEnvironment: Environment {
        if isTestFlightBuild {
            return .testFlight
        } else {
            return .production
        }
    }

    /// Detects if app is running from TestFlight
    private var isTestFlightBuild: Bool {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return appStoreReceiptURL.lastPathComponent == "sandboxReceipt"
    }

    // MARK: - RevenueCat Configuration

    /// Get RevenueCat API key (same key for all environments - RevenueCat handles sandbox/production automatically)
    var revenueCatAPIKey: String {
        // Use obfuscated key from SecureKeys instead of Info.plist
        return SecureKeys.getRevenueCatKey()
    }

    /// Get RevenueCat log level for current environment
    var revenueCatLogLevel: String {
        switch currentEnvironment {
        case .debug:
            return "debug"
        case .testFlight:
            return "info"
        case .production:
            return "error"
        }
    }

    // MARK: - Supabase Configuration

    /// Get Supabase URL for current environment
    var supabaseURL: String {
        // For now, we'll use the same Supabase for all environments
        // You can create separate Supabase projects later if needed
        return getConfigurationValue(for: "SUPABASE_URL") ?? ""
    }

    /// Get Supabase anonymous key for current environment
    var supabaseAnonKey: String {
        // Use obfuscated key from SecureKeys instead of Info.plist
        return SecureKeys.getSupabaseKey()
    }

    // MARK: - Logging Configuration

    /// Should enable verbose logging
    var enableVerboseLogging: Bool {
        switch currentEnvironment {
        case .debug:
            return true
        case .testFlight, .production:
            return false
        }
    }

    /// Should log authentication token information
    var enableAuthTokenLogging: Bool {
        switch currentEnvironment {
        case .debug:
            return true
        case .testFlight, .production:
            return false
        }
    }

    // MARK: - Private Helper Methods

    /// Safely retrieve configuration value from environment or Info.plist
    private func getConfigurationValue(for key: String) -> String? {
        // First try Info.plist (production builds)
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty {
            return value
        }

        // Then try process environment (development)
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }

        // Log missing configuration (only in debug)
        DebugLogger.shared.log("⚠️ AppConfiguration: Missing configuration '\(key)' for \(currentEnvironment)", category: "CONFIG_ERROR")

        return nil
    }

    // MARK: - Validation

    /// Validate all required configuration is present
    func validateConfiguration() -> (isValid: Bool, missingKeys: [String]) {
        var missingKeys: [String] = []

        // Check RevenueCat key (now from SecureKeys)
        if revenueCatAPIKey.isEmpty {
            missingKeys.append("REVENUECAT_API_KEY (SecureKeys)")
        }

        // Check Supabase configuration
        if supabaseURL.isEmpty {
            missingKeys.append("SUPABASE_URL")
        }

        // Check Supabase key (now from SecureKeys)
        if supabaseAnonKey.isEmpty {
            missingKeys.append("SUPABASE_ANON_KEY (SecureKeys)")
        }

        return (missingKeys.isEmpty, missingKeys)
    }

    // MARK: - Debug Information

    /// Get configuration summary for debugging
    func getConfigurationSummary() -> String {
        let validation = validateConfiguration()

        return """
        🔧 App Configuration Summary:
        Environment: \(currentEnvironment)
        TestFlight Build: \(isTestFlightBuild)
        RevenueCat Log Level: \(revenueCatLogLevel)
        Verbose Logging: \(enableVerboseLogging)
        Auth Token Logging: \(enableAuthTokenLogging)
        Configuration Valid: \(validation.isValid)
        Missing Keys: \(validation.missingKeys.joined(separator: ", "))
        """
    }
}

// MARK: - Environment Extensions

extension AppConfiguration.Environment: CustomStringConvertible {
    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .testFlight: return "TESTFLIGHT"
        case .production: return "PRODUCTION"
        }
    }
}
