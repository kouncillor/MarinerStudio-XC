
import SwiftUI

// Extensions to make it easier to work with services
extension View {
    /// Injects all services into this view
    func withInjectedServices(_ serviceProvider: ServiceProvider = ServiceProvider()) -> some View {
        self.environmentObject(serviceProvider)
    }
}

// Convenience extensions to access specific database services from SwiftUI views
extension EnvironmentObject where ObjectType == ServiceProvider {
    var databaseCore: DatabaseCore {
        wrappedValue.databaseCore
    }
    
    var tideFavoritesCloudService: TideFavoritesCloudService {
        wrappedValue.tideFavoritesCloudService
    }
    
    var currentStationService: CurrentStationDatabaseService {
        wrappedValue.currentStationService
    }
    
    var navUnitService: NavUnitDatabaseService {
        wrappedValue.navUnitService
    }
    
    var vesselService: VesselDatabaseService {
        wrappedValue.vesselService
    }
    
    var buoyDatabaseService: BuoyDatabaseService {
        wrappedValue.buoyDatabaseService
    }
    
    var weatherService: WeatherDatabaseService {
        wrappedValue.weatherService
    }
    
    var locationService: LocationService {
        wrappedValue.locationService
    }
    
    var openMeteoService: WeatherService {
        wrappedValue.openMeteoService
    }
    
    var geocodingService: GeocodingService {
        wrappedValue.geocodingService
    }
    
    var noaaChartService: NOAAChartService {
        wrappedValue.noaaChartService
    }
    
    var mapOverlayService: MapOverlayDatabaseService {
        wrappedValue.mapOverlayService
    }
    
    // GPX and Route Service Extensions
    var gpxService: ExtendedGpxServiceProtocol {
        wrappedValue.gpxService
    }
    
    var routeCalculationService: RouteCalculationService {
        wrappedValue.routeCalculationService
    }
    
    // NEW: Recommendation Service Extension
    var recommendationService: RecommendationCloudService {
        wrappedValue.recommendationService
    }
}

// Extension for converting degrees to cardinal directions
extension Double {
    func toCardinalDirection() -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int(((self + 11.25) / 22.5).truncatingRemainder(dividingBy: 16))
        return directions[index]
    }
}

// Extension for date formatting utilities
extension Date {
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
    
    func formattedDay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }
    
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
    
    func isSameDay(as date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: date)
    }
    
    // NEW: Recommendation-specific date formatting
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    func shortDateFormat() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: self)
    }
    
    func daysSinceNow() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self, to: Date())
        return components.day ?? 0
    }
}

// Extension for temperature conversions
extension Double {
    func fahrenheitToCelsius() -> Double {
        return (self - 32) * 5/9
    }
    
    func celsiusToFahrenheit() -> Double {
        return (self * 9/5) + 32
    }
}

// Extension for wind speed conversions
extension Double {
    func mphToKmh() -> Double {
        return self * 1.60934
    }
    
    func kmhToMph() -> Double {
        return self / 1.60934
    }
}

// Extension for precipitation conversions
extension Double {
    func inchesToMm() -> Double {
        return self * 25.4
    }
    
    func mmToInches() -> Double {
        return self / 25.4
    }
}

// NEW: Extensions for Recommendation-specific functionality
extension CloudRecommendation {
    /// Get a user-friendly status description
    var statusDescription: String {
        switch status {
        case .pending:
            return "Your recommendation is being reviewed"
        case .approved:
            return "Your recommendation has been approved and applied"
        case .rejected:
            return "Your recommendation was reviewed but not applied"
        }
    }
    
    /// Get the number of days since submission
    var daysSinceSubmission: Int {
        createdAt.daysSinceNow()
    }
    
    /// Get a formatted submission date
    var formattedSubmissionDate: String {
        createdAt.shortDateFormat()
    }
    
    /// Get relative time since submission
    var timeAgoText: String {
        createdAt.timeAgoDisplay()
    }
    
    /// Check if this recommendation is recent (within last 7 days)
    var isRecent: Bool {
        daysSinceSubmission <= 7
    }
    
    /// Get a truncated description for list views
    func truncatedDescription(maxLength: Int = 100) -> String {
        if description.count <= maxLength {
            return description
        }
        
        let truncated = String(description.prefix(maxLength))
        return truncated + "..."
    }
}

// Extend existing RecommendationStatus (defined in DatabaseModels.swift)
// Note: CaseIterable conformance should be added to the original enum declaration in DatabaseModels.swift
extension RecommendationStatus {
    var displayName: String {
        switch self {
        case .pending:
            return "Under Review"
        case .approved:
            return "Approved"
        case .rejected:
            return "Not Applied"
        }
    }
    
    var iconName: String {
        switch self {
        case .pending:
            return "clock.fill"
        case .approved:
            return "checkmark.circle.fill"
        case .rejected:
            return "xmark.circle.fill"
        }
    }
    
    /// Get a user-friendly action description
    var actionDescription: String {
        switch self {
        case .pending:
            return "Under Review"
        case .approved:
            return "Applied"
        case .rejected:
            return "Not Applied"
        }
    }
    
    /// Get appropriate color for UI display
    var uiColor: Color {
        switch self {
        case .pending:
            return .orange
        case .approved:
            return .green
        case .rejected:
            return .red
        }
    }
    
    /// Get background color for badges
    var backgroundColor: Color {
        return uiColor.opacity(0.1)
    }
    
    /// Get text color for badges
    var textColor: Color {
        return uiColor
    }
    
    var color: String {
        switch self {
        case .pending:
            return "orange"
        case .approved:
            return "green"
        case .rejected:
            return "red"
        }
    }
}

extension RecommendationCategory {
    /// Get example prompts for each category
    var examplePrompt: String {
        switch self {
        case .contactInfo:
            return "Has the phone number, operator, or ownership changed?"
        case .facilityDetails:
            return "Has the name, type, or facility specifications changed?"
        case .operatingStatus:
            return "Is the facility currently operating? Any closures or restrictions?"
        case .accessNavigation:
            return "Have depths, approaches, or navigation restrictions changed?"
        case .generalInfo:
            return "Any other information that should be updated?"
        }
    }
    
    /// Get priority level for sorting
    var priorityLevel: Int {
        switch self {
        case .operatingStatus:
            return 5  // Highest priority - safety related
        case .accessNavigation:
            return 4  // High priority - navigation safety
        case .contactInfo:
            return 3  // Medium priority - important for mariners
        case .facilityDetails:
            return 2  // Lower priority - general information
        case .generalInfo:
            return 1  // Lowest priority - catch-all
        }
    }
}

// NEW: Array extensions for recommendations
extension Array where Element == CloudRecommendation {
    /// Get recommendations grouped by status
    func groupedByStatus() -> [RecommendationStatus: [CloudRecommendation]] {
        return Dictionary(grouping: self) { $0.status }
    }
    
    /// Get recommendations grouped by category
    func groupedByCategory() -> [RecommendationCategory: [CloudRecommendation]] {
        return Dictionary(grouping: self) { $0.category }
    }
    
    /// Get recent recommendations (last 30 days)
    func recentRecommendations() -> [CloudRecommendation] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return self.filter { $0.createdAt >= thirtyDaysAgo }
    }
    
    /// Sort by priority (status first, then date)
    func sortedByPriority() -> [CloudRecommendation] {
        return self.sorted { first, second in
            // Pending recommendations first
            if first.status == .pending && second.status != .pending {
                return true
            } else if first.status != .pending && second.status == .pending {
                return false
            }
            
            // Then by date (newest first)
            return first.createdAt > second.createdAt
        }
    }
}
