import Foundation
import UIKit

#if canImport(Darwin)
import Darwin
#endif

/**
 * Helper for collecting device and app information
 * Used for feedback submissions to provide context for debugging and support
 * iOS equivalent of Android DeviceInfoHelper
 */
struct DeviceInfoHelper {

    // MARK: - App Information

    /**
     * Get app version from Info.plist
     * Example: "1.0.0"
     */
    static func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /**
     * Get app build number from Info.plist
     * Example: "123"
     */
    static func getBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    /**
     * Get complete app version with build number
     * Example: "1.0.0 (123)"
     */
    static func getFullAppVersion() -> String {
        let version = getAppVersion()
        let build = getBuildNumber()
        return "\(version) (\(build))"
    }

    // MARK: - Device Information

    /**
     * Get iOS version
     * Example: "17.0" for iOS 17
     */
    static func getIOSVersion() -> String {
        return UIDevice.current.systemVersion
    }

    /**
     * Get device model name
     * Example: "iPhone 15 Pro" or "iPad Air (5th generation)"
     */
    static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            let unicodeScalar = UnicodeScalar(UInt8(value))
            return identifier + String(unicodeScalar)
        }

        return mapDeviceIdentifier(identifier)
    }

    /**
     * Get device name set by user
     * Example: "John's iPhone"
     */
    static func getDeviceName() -> String {
        return UIDevice.current.name
    }

    // MARK: - System Information

    /**
     * Get device type (iPhone, iPad, etc.)
     */
    static func getDeviceType() -> String {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return "iPhone"
        case .pad:
            return "iPad"
        case .tv:
            return "Apple TV"
        case .carPlay:
            return "CarPlay"
        @unknown default:
            return "Unknown Device"
        }
    }

    // MARK: - Formatted Output

    /**
     * Get complete device info as formatted string
     * Useful for email templates and debugging
     */
    static func getDeviceInfoString() -> String {
        return """
        App Version: \(getFullAppVersion())
        iOS Version: \(getIOSVersion())
        Device: \(getDeviceModel())
        Device Name: \(getDeviceName())
        """
    }

    /**
     * Get email template with device info
     * Matches Android implementation format
     */
    static func getEmailTemplate(sourceView: String) -> String {
        return """
        ---
        Source View: \(sourceView)
        App Version: \(getFullAppVersion())
        iOS Version: \(getIOSVersion())
        Device: \(getDeviceModel())
        ---

        Please write your feedback above this line.
        """
    }

    // MARK: - Private Helper Methods

    /**
     * Map device identifier to human-readable name
     * Based on common iOS device identifiers
     */
    private static func mapDeviceIdentifier(_ identifier: String) -> String {
        switch identifier {
        // iPhone Models
        case "iPhone14,7": return "iPhone 13 mini"
        case "iPhone14,8": return "iPhone 13"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone15,4": return "iPhone 14"
        case "iPhone15,5": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone16,1": return "iPhone 15"
        case "iPhone16,2": return "iPhone 15 Plus"
        case "iPhone16,3": return "iPhone 15 Pro"
        case "iPhone16,4": return "iPhone 15 Pro Max"
        case "iPhone17,1": return "iPhone 16"
        case "iPhone17,2": return "iPhone 16 Plus"
        case "iPhone17,3": return "iPhone 16 Pro"
        case "iPhone17,4": return "iPhone 16 Pro Max"

        // iPad Models
        case "iPad13,1", "iPad13,2": return "iPad Air (5th generation)"
        case "iPad13,16", "iPad13,17": return "iPad Air (5th generation)"
        case "iPad14,1", "iPad14,2": return "iPad mini (6th generation)"
        case "iPad13,18", "iPad13,19": return "iPad (10th generation)"
        case "iPad14,3", "iPad14,4": return "iPad Pro 11-inch (4th generation)"
        case "iPad14,5", "iPad14,6": return "iPad Pro 12.9-inch (6th generation)"

        // Simulator
        case "i386", "x86_64":
            return "iOS Simulator"
        case "arm64":
            // Could be simulator on Apple Silicon Macs or actual device
            #if targetEnvironment(simulator)
            return "iOS Simulator"
            #else
            return identifier
            #endif

        default:
            // Return the identifier if we don't have a mapping
            return identifier
        }
    }
}