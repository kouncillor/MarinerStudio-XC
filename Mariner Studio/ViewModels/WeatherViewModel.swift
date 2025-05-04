import Foundation
import CoreLocation
import SwiftUI
import Combine

class WeatherViewModel: ObservableObject {
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
    
    // Add these to the @Published properties in the ViewModel
    @Published var selectedForecastDate: Date?
    @Published var selectedForecastData: [Date] = []
    @Published var shouldNavigateToHourlyForecast = false
    
    // MARK: - Private Properties
    private var weatherService: WeatherService?
    private var geocodingService: GeocodingService?
    private var locationService: LocationService?
    private var databaseService: WeatherDatabaseService?
    
    private var cancellables = Set<AnyCancellable>()
    private var locationManager = CLLocationManager()
    
    // MARK: - Initialization
    
    /// Initializes the view model with required services
    func initialize(
        weatherService: WeatherService?,
        geocodingService: GeocodingService?,
        locationService: LocationService?,
        databaseService: WeatherDatabaseService?
    ) {
        self.weatherService = weatherService
        self.geocodingService = geocodingService
        self.locationService = locationService
        self.databaseService = databaseService
    }
    
    // MARK: - Public Methods
    
    func loadWeatherData() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = ""
            }
            
            do {
                guard let location = try await getUserLocation() else {
                    throw WeatherError.invalidResponse
                }
                
                // Update location coordinates
                await MainActor.run {
                    latitude = location.coordinate.latitude
                    longitude = location.coordinate.longitude
                }
                
                // Get location name
                if let geocodingService = geocodingService {
                    do {
                        let geocodingResult = try await geocodingService.reverseGeocode(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude
                        )
                        
                        if let locationResult = geocodingResult.results.first {
                            await MainActor.run {
                                locationDisplay = "\(locationResult.name), \(locationResult.state)"
                            }
                        }
                    } catch {
                        print("⚠️ Geocoding error: \(error), continuing with coordinates only")
                        await MainActor.run {
                            locationDisplay = "Location at \(String(format: "%.4f", latitude))°, \(String(format: "%.4f", longitude))°"
                        }
                    }
                }
                
                // Get weather data
                if let weatherService = weatherService {
                    do {
                        let weather = try await weatherService.getWeather(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude
                        )
                        
                        await processWeatherData(weather)
                        
                        // Check if location is a favorite
                        await updateFavoriteStatus()
                    } catch {
                        print("❌ Weather API error: \(error)")
                        await MainActor.run {
                            errorMessage = "Weather data unavailable. Please try again later."
                        }
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Weather service unavailable"
                    }
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Could not retrieve location: \(error.localizedDescription)"
                    print("❌ Location error: \(error)")
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    /// Toggles the favorite status of the current location
    func toggleFavorite() {
        Task {
            guard latitude != 0 && longitude != 0 else { return }
            
            do {
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
            } catch {
                print("❌ Error toggling favorite: \(error)")
            }
        }
    }
    
    /// Prepares hourly forecast data for the selected date
    func navigateToHourlyForecast(forecast: DailyForecastItem) {
        // Instead of navigation service, we'll set up data for SwiftUI navigation
        // This would typically be used with either:
        // 1. State variables that trigger navigation
        // 2. Parameters passed to a NavigationLink destination
        
        // Store relevant data in published properties that the view can access
        Task {
            await MainActor.run {
                // These would be new published properties in the ViewModel
                selectedForecastDate = forecast.date
                selectedForecastData = forecastPeriods.map { $0.date }
                
                // This boolean could be used to trigger navigation in a SwiftUI view
                // if using programmatic navigation with NavigationPath
                shouldNavigateToHourlyForecast = true
            }
        }
        
        // Note: The actual navigation would happen in the view using NavigationLink
        // or NavigationStack's programmatic navigation
    }
    
    // MARK: - Private Methods
    
    /// Get the user's current location
    private func getUserLocation() async throws -> CLLocation? {
        return try await withCheckedThrowingContinuation { continuation in
            if let locationService = locationService {
                if let location = locationService.currentLocation {
                    continuation.resume(returning: location)
                } else {
                    Task {
                        let authorized = await locationService.requestLocationPermission()
                        if authorized {
                            locationService.startUpdatingLocation()
                            // Give it a moment to get a location
                            try await Task.sleep(for: .seconds(1))
                            if let location = locationService.currentLocation {
                                continuation.resume(returning: location)
                            } else {
                                continuation.resume(throwing: NSError(
                                    domain: "WeatherViewModel",
                                    code: 0,
                                    userInfo: [NSLocalizedDescriptionKey: "Unable to get location"]
                                ))
                            }
                        } else {
                            continuation.resume(throwing: NSError(
                                domain: "WeatherViewModel",
                                code: 2,
                                userInfo: [NSLocalizedDescriptionKey: "Location access denied"]
                            ))
                        }
                    }
                }
            } else {
                // Fallback to using CLLocationManager directly
                let locationManager = CLLocationManager()
                
                switch locationManager.authorizationStatus {
                case .authorizedWhenInUse, .authorizedAlways:
                    if let location = locationManager.location {
                        continuation.resume(returning: location)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "WeatherViewModel",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Unable to get location"]
                        ))
                    }
                case .notDetermined:
                    continuation.resume(throwing: NSError(
                        domain: "WeatherViewModel",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Location authorization not determined"]
                    ))
                case .restricted, .denied:
                    continuation.resume(throwing: NSError(
                        domain: "WeatherViewModel",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Location access denied"]
                    ))
                @unknown default:
                    continuation.resume(throwing: NSError(
                        domain: "WeatherViewModel",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown location authorization status"]
                    ))
                }
            }
        }
    }
    
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
                            if let moonPhase = try? await databaseService.getMoonPhaseForDateAsync(date: dateString) {
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
    
    /// Process the forecast data
    private func processForecastData(_ weather: OpenMeteoResponse) {
        Task {
            var forecastItems: [DailyForecastItem] = []
            
            for i in 0..<min(7, weather.daily.time.count) {
                guard let forecastDate = ISO8601DateFormatter().date(from: weather.daily.time[i] + "T12:00:00Z") else {
                    continue
                }
                
                // Get moon phase from database
                var moonPhaseIcon = "moonphase.new.moon"
                var isWaxingMoon = true
                
                if let databaseService = databaseService {
                    let dateString = forecastDate.formatted(.iso8601.year().month().day())
                    // Added 'date:' parameter label here
                    if let moonPhase = try? await databaseService.getMoonPhaseForDateAsync(date: dateString) {
                        // If using the DbMoonPhase that doesn't have icon/isWaxing properties,
                        // you'll need to determine these values from the phase string
                        // For now, keeping defaults
                        moonPhaseIcon = "moonphase.new.moon"
                        isWaxingMoon = true
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
            
            await MainActor.run {
                forecastPeriods = forecastItems
            }
        }
    }
    
    /// Check if the current location is a favorite
    private func updateFavoriteStatus() async {
        if let databaseService = databaseService {
            do {
                let favoriteStatus = await databaseService.isWeatherLocationFavoriteAsync(
                    latitude: latitude,
                    longitude: longitude
                )
                
                await MainActor.run {
                    isFavorite = favoriteStatus
                    favoriteIcon = favoriteStatus ? "heart.fill" : "heart"
                }
            } catch {
                print("❌ Error checking favorite status: \(error)")
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
