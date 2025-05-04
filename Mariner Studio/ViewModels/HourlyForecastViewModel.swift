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
    
    // MARK: - Initialization
    init(weatherService: WeatherService? = nil, databaseService: WeatherDatabaseService? = nil) {
        self.weatherService = weatherService
        self.databaseService = databaseService
    }
    
    // MARK: - Public Methods
    
    /// Initialize the view model with necessary data for display
    func initialize(selectedDate: Date, allDates: [Date], latitude: Double, longitude: Double, locationName: String) {
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
    }
    
    /// Load hourly forecast data for all available dates
    func loadHourlyForecasts() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = ""
                dailyHourlyForecasts = []
                currentDayHourlyForecasts = []
            }
            
            do {
                // Fetch forecasts for each date
                for date in availableDates {
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
                        
                        let hourlyForecasts = try await processHourlyData(hourlyData, for: date)
                        
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
                
                await MainActor.run {
                    updateCurrentDayForecasts()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load hourly forecasts: \(error.localizedDescription)"
                    isLoading = false
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
    
    /// Clean up resources
    func cleanup() {
        dailyHourlyForecasts = []
        currentDayHourlyForecasts = []
        availableDates = []
        errorMessage = ""
    }
    
    // MARK: - Private Methods
    
    /// Update the display for the current day
    private func updateDayDisplay() {
        guard currentDayIndex >= 0 && currentDayIndex < availableDates.count else { return }
        
        let date = availableDates[currentDayIndex]
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        currentDayDisplay = formatter.string(from: date)
        
        canGoToPreviousDay = currentDayIndex > 0
        canGoToNextDay = currentDayIndex < availableDates.count - 1
        
        updateCurrentDayForecasts()
    }
    
    // Change from private to public
    func updateCurrentDayForecasts() {
        guard currentDayIndex >= 0 && currentDayIndex < availableDates.count else { return }
        
        let currentDate = availableDates[currentDayIndex]
        let dayForecast = dailyHourlyForecasts.first { Calendar.current.isDate($0.date, inSameDayAs: currentDate) }
        
        if let forecast = dayForecast {
            currentDayHourlyForecasts = forecast.hourlyForecasts
        } else {
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
        
        // Process each hour
        for i in 0..<min(24, timeCount) {
            do {
                // Create date from time string
                guard let hourTime = ISO8601DateFormatter().date(from: hourlyData.hourly.time[i]) else {
                    continue
                }
                
                // Get pressure in inHg (convert from hPa)
                let pressureHpa = hourlyData.hourly.pressure.count > i ? hourlyData.hourly.pressure[i] : 0
                let currentPressure = Double(round(pressureHpa * 0.02953 * 100) / 100)
                
                // Get moon phase for night hours
                var moonPhaseIcon = "moonphase.new.moon"
                if hourTime.hour >= 18 || hourTime.hour < 6 {
                    let dateString = hourTime.formatted(.iso8601.year().month().day())
                    if let moonPhase = try? await databaseService?.getMoonPhaseForDateAsync(date: dateString) {
                        moonPhaseIcon = WeatherIconMapper.mapMoonPhase(moonPhase.phase)
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
                    dewPoint: hourlyData.hourly.dewPoint?.count ?? 0 > i ? hourlyData.hourly.dewPoint?[i] ?? 0 : 0,
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
            } catch {
                print("Error processing hour \(i): \(error.localizedDescription)")
            }
        }
        
        return items
    }
    
    
    
    
    
    
    
}

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
