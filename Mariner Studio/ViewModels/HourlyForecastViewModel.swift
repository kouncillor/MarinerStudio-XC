

import Foundation
import SwiftUI
import Combine

class HourlyForecastViewModel: ObservableObject {
    // MARK: - Published Properties

    // Location information
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var locationDisplay = ""

    // Date navigation
    @Published var availableDates: [Date] = []
    @Published var currentDayIndex: Int = 0
    @Published var currentDayDisplay = ""
    @Published var canGoToPreviousDay = false
    @Published var canGoToNextDay = false

    // Hourly data
    @Published var dailyHourlyForecasts: [DailyHourlyForecast] = []
    @Published var currentDayHourlyForecasts: [HourlyForecastItem] = []

    // Loading and error states
    @Published var isLoading = false
    @Published var errorMessage = ""

    // MARK: - Private Properties
    private var weatherService: WeatherService?
    private var databaseService: WeatherDatabaseService?
    private var cancellables = Set<AnyCancellable>()
    
    // Task tracking
    private var forecastTask: Task<Void, Never>?

    // MARK: - Initialization
    init(weatherService: WeatherService? = nil, databaseService: WeatherDatabaseService? = nil) {
        self.weatherService = weatherService
        self.databaseService = databaseService
    }
    
    deinit {
        cleanup()
    }

    // MARK: - Public Methods

    /// Initialize the view model with necessary data for display
    func initialize(selectedDate: Date, allDates: [Date], latitude: Double, longitude: Double, locationName: String) {
        // Clear previous state
        cleanup()
        
        // Set new data
        self.availableDates = allDates.sorted()
        self.latitude = latitude
        self.longitude = longitude
        self.locationDisplay = locationName

        // Find the index of the selected date
        if let index = availableDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) {
            currentDayIndex = index
        } else {
            currentDayIndex = 0
        }

        updateDayDisplay()
        
        print("🕐 HourlyForecastViewModel: Initialized for date \(selectedDate), day index: \(currentDayIndex)")
    }

    /// Load hourly forecast data for all available dates
    func loadHourlyForecasts() {
        // Cancel any existing task
        forecastTask?.cancel()
        forecastTask = nil
        
        // Update UI state
        Task { @MainActor in
            isLoading = true
            errorMessage = ""
            dailyHourlyForecasts = []
            currentDayHourlyForecasts = []
        }
        
        // Print day information for debugging
        print("🕐 HourlyForecastViewModel: loadHourlyForecasts called for day index \(currentDayIndex) of \(availableDates.count) days")
        if currentDayIndex < availableDates.count {
            print("🕐 Loading forecasts for date: \(availableDates[currentDayIndex])")
        }
        
        // Create a new task for loading forecasts
        forecastTask = Task {
            do {
                // Fetch forecasts for each date
                for date in availableDates {
                    if Task.isCancelled { break }
                    
                    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)

                    if let weatherService = weatherService,
                       let year = components.year,
                       let month = components.month,
                       let day = components.day {

                        let hourlyData = try await weatherService.getHourlyForecast(
                            year: year,
                            month: month,
                            day: day,
                            latitude: latitude,
                            longitude: longitude
                        )
                        
                        if Task.isCancelled { break }

                        let hourlyForecasts = try await processHourlyData(hourlyData, for: date)
                        
                        if Task.isCancelled { break }

                        await MainActor.run {
                            dailyHourlyForecasts.append(
                                DailyHourlyForecast(
                                    date: date,
                                    hourlyForecasts: hourlyForecasts
                                )
                            )
                        }
                    }
                }

                if !Task.isCancelled {
                    await MainActor.run {
                        updateCurrentDayForecasts()
                        isLoading = false
                        
                        // Log the current day forecasts for debugging
                        print("🕐 Finished loading hourly forecasts. Current day index: \(currentDayIndex), forecasts count: \(currentDayHourlyForecasts.count)")
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        errorMessage = "Failed to load hourly forecasts: \(error.localizedDescription)"
                        isLoading = false
                    }
                }
            }
        }
    }

    /// Navigate to the previous day
    func previousDay() {
        guard currentDayIndex > 0 else { return }

        // Optional: Add haptic feedback similar to MAUI implementation
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()

        currentDayIndex -= 1
        updateDayDisplay()
    }

    /// Navigate to the next day
    func nextDay() {
        guard currentDayIndex < availableDates.count - 1 else { return }

        // Optional: Add haptic feedback similar to MAUI implementation
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()

        currentDayIndex += 1
        updateDayDisplay()
    }

    /// Clean up resources when the view disappears
    func cleanup() {
        // Cancel any ongoing forecast task
        forecastTask?.cancel()
        forecastTask = nil
        
        // Clear data to prevent state issues when returning
        dailyHourlyForecasts = []
        currentDayHourlyForecasts = []
        availableDates = []
        errorMessage = ""
    }

    // MARK: - Private Methods

    /// Update the display for the current day
    private func updateDayDisplay() {
        guard currentDayIndex >= 0 && currentDayIndex < availableDates.count else {
            print("🕐 ERROR: currentDayIndex \(currentDayIndex) out of bounds for \(availableDates.count) dates")
            return
        }

        let date = availableDates[currentDayIndex]
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        currentDayDisplay = formatter.string(from: date)

        canGoToPreviousDay = currentDayIndex > 0
        canGoToNextDay = currentDayIndex < availableDates.count - 1

        print("🕐 Updated day display: \(currentDayDisplay), index: \(currentDayIndex), date: \(date)")
        
        updateCurrentDayForecasts()
    }

    // Public to be accessible where needed
    func updateCurrentDayForecasts() {
        guard currentDayIndex >= 0 && currentDayIndex < availableDates.count else {
            print("🕐 ERROR: Cannot update forecasts - currentDayIndex \(currentDayIndex) is out of bounds")
            return
        }

        let currentDate = availableDates[currentDayIndex]
        print("🕐 Updating forecasts for date: \(currentDate), day index: \(currentDayIndex)")
        
        let dayForecast = dailyHourlyForecasts.first { Calendar.current.isDate($0.date, inSameDayAs: currentDate) }

        if let forecast = dayForecast {
            print("🕐 Found matching forecast with \(forecast.hourlyForecasts.count) hourly items")
            currentDayHourlyForecasts = forecast.hourlyForecasts
        } else {
            print("🕐 No matching forecast found for date \(currentDate)")
            currentDayHourlyForecasts = []
        }
    }

    /// Process hourly data from the API
    private func processHourlyData(_ hourlyData: OpenMeteoHourlyResponse, for date: Date) async throws -> [HourlyForecastItem] {
        var items: [HourlyForecastItem] = []
        var previousPressure: Double?

        // Ensure we have data to process
        let timeCount = hourlyData.hourly.time.count
        guard timeCount > 0 else { return [] }

        // --- Start Change: Use specific DateFormatter ---
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        // Important: Set timezone to avoid misinterpretation. Using UTC/GMT as a common base.
        // If the API guarantees a specific timezone (like the one in the main response), use that.
       // dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        // --- End Change ---


        // Process each hour
        for i in 0..<min(24, timeCount) {
            if Task.isCancelled { break }

            // --- Start Change: Use the configured dateFormatter ---
            guard let hourTime = dateFormatter.date(from: hourlyData.hourly.time[i]) else {
                 print("⚠️ Could not parse date string: \(hourlyData.hourly.time[i]) with format yyyy-MM-dd'T'HH:mm")
                 continue // Skip this hour if date parsing fails
             }
            // --- End Change ---


            // Get pressure in inHg (convert from hPa)
            let pressureHpa = hourlyData.hourly.pressure.count > i ? hourlyData.hourly.pressure[i] : 0
            let currentPressure = Double(round(pressureHpa * 0.02953 * 100) / 100)

            // Get moon phase for night hours
            var moonPhaseIcon = "moonphase.new.moon" // Default value
            if hourTime.hour >= 18 || hourTime.hour < 6 {
                let dateString = hourTime.formatted(.iso8601.year().month().day())
                do {
                    if let databaseService = databaseService,
                       let moonPhase = try await databaseService.getMoonPhaseForDateAsync(date: dateString) {
                        moonPhaseIcon = WeatherIconMapper.mapMoonPhase(moonPhase.phase)
                        print("🌕 Moon phase for \(dateString): \(moonPhase.phase)") // Optional: Log success
                    }
                } catch {
                    // Log the error but continue processing the hour
                    print("⚠️ Error getting moon phase for \(dateString): \(error.localizedDescription). Using default icon.")
                    // moonPhaseIcon keeps its default value "moonphase.new.moon"
                }
            }

            // Create hourly forecast item
            let weatherCode = hourlyData.hourly.weatherCode.count > i ? hourlyData.hourly.weatherCode[i] : 0
            let isNightTime = hourTime.hour >= 18 || hourTime.hour < 6

            // Get wind direction as cardinal direction
            let windDirectionDegrees = hourlyData.hourly.windDirection.count > i ? hourlyData.hourly.windDirection[i] : 0
            let cardinalDirection = windDirectionDegrees.toCardinalDirection()

            // Get visibility
            let visibilityMeters = hourlyData.hourly.visibility.count > i ? hourlyData.hourly.visibility[i] : 0

            // Get precipitation probability (if available)
            let precipProbability = hourlyData.hourly.precipitationProbability?.count ?? 0 > i ?
                hourlyData.hourly.precipitationProbability?[i] ?? 0 : 0

            // Get relative humidity (if available)
            let humidity = hourlyData.hourly.relativeHumidity?.count ?? 0 > i ?
                hourlyData.hourly.relativeHumidity?[i] ?? 0 : 0

            // Get dew point (if available)
             let dewPoint = hourlyData.hourly.dewPoint?.count ?? 0 > i ?
                 hourlyData.hourly.dewPoint?[i] ?? 0.0 : 0.0 // Use 0.0 as default if nil


            // Create the item
            let item = HourlyForecastItem(
                time: hourTime,
                hour: hourTime.formatted(date: .omitted, time: .shortened),
                timeDisplay: hourTime.formatted(date: .numeric, time: .standard),
                temperature: hourlyData.hourly.temperature.count > i ? hourlyData.hourly.temperature[i] : 0,
                humidity: humidity,
                precipitation: hourlyData.hourly.precipitation.count > i ? hourlyData.hourly.precipitation[i] : 0,
                precipitationChance: precipProbability,
                windSpeed: hourlyData.hourly.windSpeed.count > i ? hourlyData.hourly.windSpeed[i] : 0,
                windDirection: windDirectionDegrees,
                windGusts: hourlyData.hourly.windGusts.count > i ? hourlyData.hourly.windGusts[i] : 0,
                dewPoint: dewPoint, // Use the extracted dewPoint
                pressure: currentPressure,
                previousPressure: previousPressure,
                visibilityMeters: visibilityMeters,
                weatherCode: weatherCode,
                isNightTime: isNightTime,
                cardinalDirection: cardinalDirection,
                weatherIcon: WeatherIconMapper.mapWeatherCode(weatherCode, isNight: isNightTime),
                moonPhase: moonPhaseIcon
            )

            items.append(item)
            previousPressure = currentPressure

        } // End of for loop

        return items
    }
} // End of class

// MARK: - Helper Structures

/// Structure to group hourly forecasts by day
struct DailyHourlyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let hourlyForecasts: [HourlyForecastItem]
}

// MARK: - Date Extensions

extension Date {
    var hour: Int {
        return Calendar.current.component(.hour, from: self)
    }
}
