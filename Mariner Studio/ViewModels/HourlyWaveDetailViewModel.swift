import Foundation
import SwiftUI

class HourlyWaveDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentHourIndex: Int
    @Published var hourlyForecasts: [HourlyForecastItem]
    @Published var locationDisplay: String
    @Published var dateDisplay: String

    // MARK: - Computed Properties
    var currentForecast: HourlyForecastItem? {
        guard currentHourIndex >= 0 && currentHourIndex < hourlyForecasts.count else {
            return nil
        }
        return hourlyForecasts[currentHourIndex]
    }

    var currentTimeDisplay: String {
        guard let forecast = currentForecast else { return "" }
        return forecast.timeDisplay
    }

    var currentHourDisplay: String {
        guard let forecast = currentForecast else { return "" }
        return forecast.hour
    }

    var canGoToPreviousHour: Bool {
        return currentHourIndex > 0
    }

    var canGoToNextHour: Bool {
        return currentHourIndex < hourlyForecasts.count - 1
    }

    var hasMarineData: Bool {
        return currentForecast?.marineDataAvailable ?? false
    }

    // MARK: - Initialization
    init(hourlyForecasts: [HourlyForecastItem], selectedHourIndex: Int, locationName: String, date: Date) {
        self.hourlyForecasts = hourlyForecasts
        self.currentHourIndex = selectedHourIndex
        self.locationDisplay = locationName

        // Format date display
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        self.dateDisplay = formatter.string(from: date)

        print("🌊 HourlyWaveDetailViewModel: Initialized with \(hourlyForecasts.count) forecasts, starting at index \(selectedHourIndex)")
    }

    // MARK: - Public Methods
    func nextHour() {
        guard canGoToNextHour else { return }

        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()

        currentHourIndex += 1
        print("🌊 HourlyWaveDetailViewModel: Moved to next hour, index: \(currentHourIndex)")
    }

    func previousHour() {
        guard canGoToPreviousHour else { return }

        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()

        currentHourIndex -= 1
        print("🌊 HourlyWaveDetailViewModel: Moved to previous hour, index: \(currentHourIndex)")
    }
}
