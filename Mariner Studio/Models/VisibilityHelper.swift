import Foundation
import SwiftUI

/// Helper utility for formatting visibility values
struct VisibilityHelper {

    /// Formats visibility from meters to a readable string with units
    /// - Parameter visibilityMeters: The visibility value in meters
    /// - Returns: A formatted string (e.g. "10.5 mi" or "15+ mi")
    static func formatVisibility(_ visibilityMeters: Double) -> String {
        let visibilityMiles = visibilityMeters / 1609.34
        return visibilityMiles >= 15.0 ? "15+ mi" : "\(String(format: "%.1f", visibilityMiles)) mi"
    }

    /// Formats visibility with appropriate units based on the value
    /// - Parameter visibilityMeters: The visibility value in meters
    /// - Returns: A formatted string with the most appropriate units
    static func formatVisibilityWithUnits(_ visibilityMeters: Double) -> String {
        // For very short visibility, use feet
        if visibilityMeters < 100 {
            let visibilityFeet = visibilityMeters * 3.28084
            return "\(String(format: "%.0f", visibilityFeet)) ft"
        }

        // For medium visibility, use miles with one decimal place
        let visibilityMiles = visibilityMeters / 1609.34
        if visibilityMiles < 15.0 {
            return "\(String(format: "%.1f", visibilityMiles)) mi"
        }

        // For high visibility, cap at "15+ mi"
        return "15+ mi"
    }

    /// Maps visibility to a descriptive term
    /// - Parameter visibilityMeters: The visibility value in meters
    /// - Returns: A descriptive term for the visibility
    static func getVisibilityDescription(_ visibilityMeters: Double) -> String {
        let visibilityMiles = visibilityMeters / 1609.34

        if visibilityMiles < 0.25 {
            return "Dense fog"
        } else if visibilityMiles < 0.5 {
            return "Thick fog"
        } else if visibilityMiles < 1.0 {
            return "Fog"
        } else if visibilityMiles < 2.0 {
            return "Mist"
        } else if visibilityMiles < 5.0 {
            return "Haze"
        } else if visibilityMiles < 10.0 {
            return "Good"
        } else {
            return "Excellent"
        }
    }

    /// Creates a gradient color representing visibility conditions
    /// - Parameter visibilityMeters: The visibility value in meters
    /// - Returns: A color for the visibility value (red for poor, green for good)
    static func getVisibilityColor(_ visibilityMeters: Double) -> Color {
        let visibilityMiles = visibilityMeters / 1609.34

        if visibilityMiles < 0.25 {
            return .red
        } else if visibilityMiles < 1.0 {
            return .orange
        } else if visibilityMiles < 3.0 {
            return .yellow
        } else if visibilityMiles < 7.0 {
            return .green.opacity(0.8)
        } else {
            return .green
        }
    }
}
