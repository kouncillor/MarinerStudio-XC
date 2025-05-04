import Foundation
import CoreLocation
import SwiftUI
import Combine

class WeatherMapLocationViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Loading and error states
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // Location information
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var locationDisplay = "--"
    
    // Current weather conditions
    @Published var temperature = "--"
    @Published var feelsLike = "--"
    @Published var weatherDescription = "--"
    @Published var precipitation = "0.00"
    @Published var windSpeed = "--"
    @Published var windGusts = "--"
    @Published var windDirection = "--"
    @Published var humidity = "--"
    @Published var visibility = "--"
    @Published var pressure = "--"
    @Published var dewPoint = "--"
    @Published var weatherImage = "sun.max.fill"
    
    // Forecast data
    @Published var forecastPeriods: [DailyForecastItem] = []
    
    // Favorite state
    @Published var isFavorite = false
    @Published var favoriteIcon = "heart"
    
    // Other UI properties
    @Published var attribution = "Weather data provided by Open-Meteo.com"
    
    // Navigation to hourly forecast
    @Published var selectedForecastDate: Date?
    @Published var selectedForecastData: [Date] = []
    @Published var shouldNavigateToHourlyForecast = false
    
    // MARK: - Private Properties
    private var weatherService: WeatherService?
    private var geocodingService: GeocodingService?
    private var databaseService: WeatherDatabaseService?
    private var weatherTask: Task<Void, Never>?
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        // Cancel any ongoing tasks when view model is deallocated
        weatherTask?.cancel()
    }
    
    // MARK: - Initialization
    
    /// Initializes the view model with required services and location
    func initialize(
        weatherService: WeatherService?,
        geocodingService: GeocodingService?,
        databaseService: WeatherDatabaseService?,
        latitude: Double,
        longitude: Double,
        locationName: String
    ) {
        // Cancel any existing tasks
        weatherTask?.cancel()
        
        // Set services
        self.weatherService = weatherService
        self.geocodingService = geocodingService
        self.databaseService = databaseService
        
        // Set location data
        self.latitude = latitude
        self.longitude = longitude
        
        // Set the location display to the passed location name
        self.locationDisplay = locationName
        
        // Reset all other properties to default values
        resetUIState()
    }
    
    // Reset UI state without changing location
    private func resetUIState() {
        temperature = "--"
        feelsLike = "--"
        weatherDescription = "--"
        precipitation = "0.00"
        windSpeed = "--"
        windGusts = "--"
        windDirection = "--"
        humidity = "--"
        visibility = "--"
        pressure = "--"
        dewPoint = "--"
        weatherImage = "sun.max.fill"
        forecastPeriods = []
        isFavorite = false
        favoriteIcon = "heart"
        errorMessage = ""
    }
    
    // MARK: - Public Methods
    
    /// Loads weather data for the specified coordinates
    func loadWeatherData() {
        // Cancel any existing weather task
        weatherTask?.cancel()
        
        // Start a new task for fetching weather data
        weatherTask = Task {
            // Check if task is cancelled
            if Task.isCancelled { return }
            
            await MainActor.run {
                isLoading = true
                errorMessage = ""
            }
            
            // Get weather data using the specified coordinates
            if let weatherService = weatherService {
                do {
                    // Make sure we have valid coordinates
                    guard latitude != 0 && longitude != 0 else {
                        await MainActor.run {
                            errorMessage = "Invalid location coordinates"
                            isLoading = false
                        }
                        return
                    }
                    
                    // Get weather data
                    let weather = try await weatherService.getWeather(
                        latitude: latitude,
                        longitude: longitude
                    )
                    
                    // Check if task is cancelled before processing data
                    if Task.isCancelled { return }
                    
                    await processWeatherData(weather)
                    
                    // Check if location is a favorite
                    await updateFavoriteStatus()
                } catch {
                    // Only update UI if task hasn't been cancelled
                    if !Task.isCancelled {
                        print("❌ Weather API error: \(error)")
                        await MainActor.run {
                            errorMessage = "Weather data unavailable. Please try again later."
                            isLoading = false
                        }
                    }
                }
            } else {
                // Only update UI if task hasn't been cancelled
                if !Task.isCancelled {
                    await MainActor.run {
                        errorMessage = "Weather service unavailable"
                        isLoading = false
                    }
                }
            }
            
            // Only update UI if task hasn't been cancelled
            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    /// Toggles the favorite status of the current location
    func toggleFavorite() {
        Task {
            guard latitude != 0 && longitude != 0 else { return }
            
            if let databaseService = databaseService {
                let newFavoriteStatus = await databaseService.toggleWeatherLocationFavoriteAsync(
                    latitude: latitude,
                    longitude: longitude,
                    locationName: locationDisplay
                )
                
                await MainActor.run {
                    isFavorite = newFavoriteStatus
                    favoriteIcon = newFavoriteStatus ? "heart.fill" : "heart"
                }
            }
        }
    }
    
    /// Prepares hourly forecast data for the selected date
    func navigateToHourlyForecast(forecast: DailyForecastItem) {
        Task {
            await MainActor.run {
                selectedForecastDate = forecast.date
                selectedForecastData = forecastPeriods.map { $0.date }
                shouldNavigateToHourlyForecast = true
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func processWeatherData(_ weather: OpenMeteoResponse) async {
        await MainActor.run {
            // Current conditions
            temperature = "\(Int(weather.currentWeather.temperature.rounded()))"
            weatherDescription = getWeatherDescription(weather.currentWeather.weatherCode)
            
            // Check if it's night and the sky is clear for moon phase
            if weather.currentWeather.isDay == 0 && weather.currentWeather.weatherCode == 0 {
                Task {
                    if let currentDate = ISO8601DateFormatter().date(from: weather.currentWeather.time) {
                        if let databaseService = databaseService {
                            let dateString = currentDate.formatted(.iso8601.year().month().day())
                            if (try? await databaseService.getMoonPhaseForDateAsync(date: dateString)) != nil {
                                if !Task.isCancelled {
                                    await MainActor.run {
                                        weatherImage = "moon.stars.fill" // Default moon image
                                    }
                                }
                            } else {
                                if !Task.isCancelled {
                                    await MainActor.run {
                                        weatherImage = "moon.stars.fill"
                                    }
                                }
                            }
                        } else {
                            if !Task.isCancelled {
                                await MainActor.run {
                                    weatherImage = "moon.stars.fill"
                                }
                            }
                        }
                    } else {
                        if !Task.isCancelled {
                            await MainActor.run {
                                weatherImage = WeatherIconMapper.mapWeatherCode(
                                    weather.currentWeather.weatherCode,
                                    isNight: weather.currentWeather.isDay == 0
                                )
                            }
                        }
                    }
                }
            } else {
                weatherImage = WeatherIconMapper.mapWeatherCode(
                    weather.currentWeather.weatherCode,
                    isNight: weather.currentWeather.isDay == 0
                )
            }
            
            // Get current hour index - handle potential out of bounds
            let currentHourIndex = min(Calendar.current.component(.hour, from: Date()), weather.hourly.temperature.count - 1)
            
            // Current conditions from hourly data - with bound checking
            if currentHourIndex < weather.hourly.temperature.count {
                feelsLike = "\(Int(weather.hourly.temperature[currentHourIndex].rounded()))"
                windSpeed = "\(weather.hourly.windSpeed[currentHourIndex].rounded(.toNearestOrAwayFromZero)) mph"
                windDirection = getWindDirection(weather.hourly.windDirection[currentHourIndex])
                
                if let humidityValues = weather.hourly.relativeHumidity,
                   currentHourIndex < humidityValues.count {
                    humidity = "\(humidityValues[currentHourIndex])"
                }
                
                if currentHourIndex < weather.hourly.windGusts.count {
                    windGusts = "\(weather.hourly.windGusts[currentHourIndex].rounded(.toNearestOrAwayFromZero)) mph"
                }
                
                // Visibility (convert meters to miles)
                if currentHourIndex < weather.hourly.visibility.count {
                    let visibilityMiles = weather.hourly.visibility[currentHourIndex] / 1609.34
                    visibility = visibilityMiles >= 15.0 ? "15+ mi" : "\(String(format: "%.1f", visibilityMiles)) mi"
                }
                
                // Pressure (convert hPa to inHg)
                if currentHourIndex < weather.hourly.pressure.count {
                    pressure = String(format: "%.2f", weather.hourly.pressure[currentHourIndex] * 0.02953)
                }
                
                if let dewPointValues = weather.hourly.dewPoint,
                   currentHourIndex < dewPointValues.count {
                    dewPoint = "\(dewPointValues[currentHourIndex].rounded(.toNearestOrAwayFromZero))"
                }
                
                // Calculate 24-hour precipitation - safely
                let precipCount = weather.hourly.precipitation.count
                let last24HoursPrecip = weather.hourly.precipitation
                    .prefix(min(24, precipCount))
                    .reduce(0, +)
                precipitation = String(format: "%.2f", last24HoursPrecip)
            }
            
            // Process forecast data
            processForecastData(weather)
        }
    }
    
    /// Process the forecast data
    private func processForecastData(_ weather: OpenMeteoResponse) {
        Task {
            if Task.isCancelled { return }
            
            var forecastItems: [DailyForecastItem] = []
            
            for i in 0..<min(7, weather.daily.time.count) {
                guard let forecastDate = ISO8601DateFormatter().date(from: weather.daily.time[i] + "T12:00:00Z") else {
                    continue
                }
                
                // Get moon phase from database
                let moonPhaseIcon = "moonphase.new.moon"
                let isWaxingMoon = true
                
                if let databaseService = databaseService {
                    let dateString = forecastDate.formatted(.iso8601.year().month().day())
                    // Try to safely get moon phase, but don't break if it fails
                    _ = try? await databaseService.getMoonPhaseForDateAsync(date: dateString)
                    // In a real implementation, we would use the result to determine moonPhaseIcon and isWaxingMoon
                }
                
                // Get visibility for noon of this day
                var visibilityMeters = 10000.0 // Default 10km if not available
                let noonIndex = i * 24 + 12
                if noonIndex < weather.hourly.visibility.count {
                    visibilityMeters = weather.hourly.visibility[noonIndex]
                }
                
                // Format visibility as string
                let visibilityMiles = visibilityMeters / 1609.34
                let visibilityString = visibilityMiles >= 15.0 ? "15+ mi" : "\(String(format: "%.1f", visibilityMiles)) mi"
                
                // Get cardinal wind direction
                let windDirection = getCardinalDirection(weather.daily.windDirectionDominant[i])
                
                // Get weather icon name
                let weatherIcon = WeatherIconMapper.mapWeatherCode(weather.daily.weatherCode[i], isNight: false)
                
                let item = DailyForecastItem(
                    date: forecastDate,
                    high: weather.daily.temperatureMax[i],
                    low: weather.daily.temperatureMin[i],
                    description: "Precipitation: \(String(format: "%.2f", weather.daily.precipitationSum[i])) in",
                    windSpeed: weather.daily.windSpeedMax[i],
                    windGusts: weather.daily.windGustsMax[i],
                    windDirection: windDirection,
                    visibility: visibilityString,
                    rowIndex: i,
                    pressure: round(weather.daily.surfacePressure[i] * 0.02953 * 100) / 100,
                    weatherImage: weatherIcon,
                    moonPhaseIcon: moonPhaseIcon,
                    isWaxingMoon: isWaxingMoon,
                    visibilityMeters: visibilityMeters,
                    weatherCode: weather.daily.weatherCode[i],
                    isToday: Calendar.current.isDateInToday(forecastDate)
                )
                
                forecastItems.append(item)
            }
            
            // Fix for concurrent access warning - capture the array locally
            let items = forecastItems
            
            // Only update UI if task hasn't been cancelled
            if !Task.isCancelled {
                await MainActor.run {
                    self.forecastPeriods = items
                }
            }
        }
    }
    
    /// Check if the current location is a favorite
    private func updateFavoriteStatus() async {
        if Task.isCancelled { return }
        
        if let databaseService = databaseService {
            let favoriteStatus = await databaseService.isWeatherLocationFavoriteAsync(
                latitude: latitude,
                longitude: longitude
            )
            
            // Only update UI if task hasn't been cancelled
            if !Task.isCancelled {
                await MainActor.run {
                    isFavorite = favoriteStatus
                    favoriteIcon = favoriteStatus ? "heart.fill" : "heart"
                }
            }
        }
    }
    
    /// Get a descriptive string for the weather code
    private func getWeatherDescription(_ code: Int) -> String {
        // Map to condition enum
        if let condition = WeatherCondition(rawValue: code) {
            return condition.getDescription()
        }
        
        // Handle Open-Meteo codes that don't match the enum raw values
        switch code {
        case 0:
            return "Clear sky"
        case 1:
            return "Mainly clear"
        case 2:
            return "Partly cloudy"
        case 3:
            return "Overcast"
        case 45:
            return "Foggy"
        case 48:
            return "Depositing rime fog"
        case 51:
            return "Light drizzle"
        case 53:
            return "Moderate drizzle"
        case 55:
            return "Dense drizzle"
        case 61:
            return "Slight rain"
        case 63:
            return "Moderate rain"
        case 65:
            return "Heavy rain"
        case 71:
            return "Slight snow fall"
        case 73:
            return "Moderate snow fall"
        case 75:
            return "Heavy snow fall"
        case 77:
            return "Snow grains"
        case 80:
            return "Slight rain showers"
        case 81:
            return "Moderate rain showers"
        case 82:
            return "Violent rain showers"
        case 85:
            return "Slight snow showers"
        case 86:
            return "Heavy snow showers"
        case 95:
            return "Thunderstorm"
        case 96:
            return "Thunderstorm with slight hail"
        case 99:
            return "Thunderstorm with heavy hail"
        default:
            return "Unknown weather condition"
        }
    }
    
    /// Get a string description of wind direction
    private func getWindDirection(_ degrees: Double) -> String {
        let directions = ["from N", "from NNE", "from NE", "from ENE", "from E", "from ESE", "from SE", "from SSE",
                         "from S", "from SSW", "from SW", "from WSW", "from W", "from WNW", "from NW", "from NNW"]
        let index = Int(((degrees + 11.25) / 22.5).truncatingRemainder(dividingBy: 16))
        return directions[index]
    }
    
    /// Get a cardinal direction from degrees
    private func getCardinalDirection(_ degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int(((degrees + 11.25) / 22.5).truncatingRemainder(dividingBy: 16))
        return directions[index]
    }
}
