

import Foundation
import CoreLocation
import SwiftUI
import Combine

class CurrentLocalWeatherViewModelForMap: ObservableObject {
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
    private var weatherService: CurrentLocalWeatherServiceForMap?
    private var geocodingService: GeocodingService?
    private var databaseService: WeatherDatabaseService?
    private var weatherFavoritesCloudService: WeatherFavoritesCloudService?
    
    private var cancellables = Set<AnyCancellable>()
    private var weatherTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    // This initializer accepts latitude and longitude directly
    func initialize(
        latitude: Double,
        longitude: Double,
        weatherService: CurrentLocalWeatherServiceForMap?,
        geocodingService: GeocodingService?,
        databaseService: WeatherDatabaseService?,
        weatherFavoritesCloudService: WeatherFavoritesCloudService?
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.weatherService = weatherService
        self.geocodingService = geocodingService
        self.databaseService = databaseService
        self.weatherFavoritesCloudService = weatherFavoritesCloudService
        
        print("🚀 CurrentLocalWeatherViewModelForMap: Initialized with location (\(latitude), \(longitude))")
        print("🚀 CurrentLocalWeatherViewModelForMap: WeatherFavoritesCloudService injected: \(weatherFavoritesCloudService != nil)")
    }
    
    deinit {
        // Cancel any ongoing weather task
        weatherTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func loadWeatherData() {
        // Cancel any existing weather task
        weatherTask?.cancel()
        
        // Start a new task for fetching weather data
        weatherTask = Task {
            if Task.isCancelled { return }
            
            await MainActor.run {
                isLoading = true
                errorMessage = ""
            }
            
            // Get location name through geocoding
            if let geocodingService = geocodingService {
                do {
                    let geocodingResult = try await geocodingService.reverseGeocode(
                        latitude: latitude,
                        longitude: longitude
                    )
                    
                    if let locationResult = geocodingResult.results.first {
                        await MainActor.run {
                            locationDisplay = "\(locationResult.name), \(locationResult.state)"
                        }
                    } else {
                        await MainActor.run {
                            locationDisplay = "Location at \(String(format: "%.4f", latitude))°, \(String(format: "%.4f", longitude))°"
                        }
                    }
                } catch {
                    print("⚠️ CurrentLocalWeatherViewModelForMap: Geocoding error: \(error), continuing with coordinates only")
                    await MainActor.run {
                        locationDisplay = "Location at \(String(format: "%.4f", latitude))°, \(String(format: "%.4f", longitude))°"
                    }
                }
            }
            
            // Get weather data using our dedicated weather service
            if let weatherService = weatherService {
                do {
                    print("🌤️ CurrentLocalWeatherViewModelForMap: Fetching weather for location (\(latitude), \(longitude))")
                    let weather = try await weatherService.getWeather(
                        latitude: latitude,
                        longitude: longitude
                    )
                    
                    if Task.isCancelled { return }
                    
                    print("✅ CurrentLocalWeatherViewModelForMap: Weather data received, processing...")
                    await processWeatherData(weather)
                    
                    // Check if location is a favorite
                    await updateFavoriteStatus()
                } catch {
                    if !Task.isCancelled {
                        print("❌ CurrentLocalWeatherViewModelForMap: Weather API error: \(error)")
                        await MainActor.run {
                            errorMessage = "Weather data unavailable: \(error.localizedDescription)"
                            isLoading = false
                        }
                    }
                }
            } else {
                if !Task.isCancelled {
                    await MainActor.run {
                        errorMessage = "Weather service unavailable"
                        isLoading = false
                    }
                }
            }
            
            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Lifecycle Methods
    
    /// Call when view disappears to cancel tasks
    func cleanup() {
        // Cancel any ongoing weather task
        weatherTask?.cancel()
        weatherTask = nil
    }
    
    func toggleFavorite() {
        Task {
            guard latitude != 0 && longitude != 0 else { 
                print("❌ CURRENT_LOCAL_WEATHER_VM_MAP: Cannot toggle favorite - invalid coordinates")
                return 
            }
            
            guard !locationDisplay.isEmpty && locationDisplay != "--" else {
                print("❌ CURRENT_LOCAL_WEATHER_VM_MAP: Cannot toggle favorite - invalid location name")
                return
            }
            
            print("⭐ CURRENT_LOCAL_WEATHER_VM_MAP: Toggling favorite for \(locationDisplay) at (\(latitude), \(longitude))")
            print("⭐ CURRENT_LOCAL_WEATHER_VM_MAP: Current favorite status: \(isFavorite)")
            
            if let weatherFavoritesCloudService = weatherFavoritesCloudService {
                let result = await weatherFavoritesCloudService.toggleFavorite(
                    latitude: latitude,
                    longitude: longitude,
                    locationName: locationDisplay
                )
                
                switch result {
                case .success(let newFavoriteStatus):
                    print("✅ CURRENT_LOCAL_WEATHER_VM_MAP: Successfully toggled favorite to: \(newFavoriteStatus)")
                    await MainActor.run {
                        isFavorite = newFavoriteStatus
                        favoriteIcon = newFavoriteStatus ? "heart.fill" : "heart"
                    }
                case .failure(let error):
                    print("❌ CURRENT_LOCAL_WEATHER_VM_MAP: Failed to toggle favorite: \(error.localizedDescription)")
                }
            } else {
                print("❌ CURRENT_LOCAL_WEATHER_VM_MAP: WeatherFavoritesCloudService not available")
            }
        }
    }
    
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
                            // Use a boolean check instead of unused variable
                            if (try? await databaseService.getMoonPhaseForDateAsync(date: dateString)) != nil {
                                await MainActor.run {
                                    weatherImage = "moon.stars.fill" // Default moon image
                                }
                            } else {
                                await MainActor.run {
                                    weatherImage = "moon.stars.fill"
                                }
                            }
                        } else {
                            await MainActor.run {
                                weatherImage = "moon.stars.fill"
                            }
                        }
                    } else {
                        await MainActor.run {
                            weatherImage = WeatherIconMapper.mapWeatherCode(
                                weather.currentWeather.weatherCode,
                                isNight: weather.currentWeather.isDay == 0
                            )
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
    
    private func processForecastData(_ weather: OpenMeteoResponse) {
        Task {
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
                    // Use boolean check instead of unused variable
                    if (try? await databaseService.getMoonPhaseForDateAsync(date: dateString)) != nil {
                        // Set values if needed based on moon phase
                        // For now, keeping defaults
                    }
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
            
            await MainActor.run {
                self.forecastPeriods = items
            }
        }
    }
    
    private func updateFavoriteStatus() async {
        print("🔍 CURRENT_LOCAL_WEATHER_VM_MAP: Checking favorite status for \(locationDisplay)")
        
        if let weatherFavoritesCloudService = weatherFavoritesCloudService {
            let result = await weatherFavoritesCloudService.isFavorite(
                latitude: latitude,
                longitude: longitude
            )
            
            switch result {
            case .success(let favoriteStatus):
                print("✅ CURRENT_LOCAL_WEATHER_VM_MAP: Favorite status check result: \(favoriteStatus)")
                await MainActor.run {
                    isFavorite = favoriteStatus
                    favoriteIcon = favoriteStatus ? "heart.fill" : "heart"
                }
            case .failure(let error):
                print("❌ CURRENT_LOCAL_WEATHER_VM_MAP: Failed to check favorite status: \(error.localizedDescription)")
                await MainActor.run {
                    isFavorite = false
                    favoriteIcon = "heart"
                }
            }
        } else {
            print("❌ CURRENT_LOCAL_WEATHER_VM_MAP: WeatherFavoritesCloudService not available for favorite status check")
        }
    }
    
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
    
    private func getWindDirection(_ degrees: Double) -> String {
        let directions = ["from N", "from NNE", "from NE", "from ENE", "from E", "from ESE", "from SE", "from SSE",
                         "from S", "from SSW", "from SW", "from WSW", "from W", "from WNW", "from NW", "from NNW"]
        let index = Int(((degrees + 11.25) / 22.5).truncatingRemainder(dividingBy: 16))
        return directions[index]
    }
    
    private func getCardinalDirection(_ degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int(((degrees + 11.25) / 22.5).truncatingRemainder(dividingBy: 16))
        return directions[index]
    }
}
