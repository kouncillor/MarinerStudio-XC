
import Foundation
import CoreLocation
import SwiftUI
import Combine

class CurrentLocalWeatherViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Published Properties
    
    // Loading and error states
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // Location information
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var locationDisplay = "--"
    
    // Location accuracy state
    @Published var locationState: LocationAccuracyState = .unavailable
    @Published var locationAccuracyDescription = "Determining your location..."
    
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
    private var currentLocalWeatherService: CurrentLocalWeatherService?
    private var geocodingService: GeocodingService?
    private var databaseService: WeatherDatabaseService?
    
    // Location Manager (added directly to view model)
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    
    private var cancellables = Set<AnyCancellable>()
    private var weatherTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Initialize location manager right away
        setupLocationManager()
    }
    
    func initialize(
        currentLocalWeatherService: CurrentLocalWeatherService?,
        geocodingService: GeocodingService?,
        databaseService: WeatherDatabaseService?
    ) {
        self.currentLocalWeatherService = currentLocalWeatherService
        self.geocodingService = geocodingService
        self.databaseService = databaseService
        
        print("🚀 CurrentLocalWeatherViewModel: Initialized with services")
    }
    
    deinit {
        // Cancel any ongoing weather task
        weatherTask?.cancel()
    }
    
    // MARK: - Location Manager Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update if device moves by 10 meters
        
        print("📍 LocationManager setup in CurrentLocalWeatherViewModel")
    }
    
    // MARK: - Public Methods
    
    func loadWeatherData() {
        print("🌤️ CurrentLocalWeatherViewModel: loadWeatherData called")
        
        // Reset loading state
        isLoading = true
        errorMessage = ""
        
        // Check if we already have location data
        if let location = currentLocation {
            print("📍 Already have location data, fetching weather directly")
            fetchWeatherWithCurrentLocation()
        } else {
            // Start by requesting location
            requestLocationPermission()
        }
    }
    
    func requestLocationPermission() {
        print("📍 CurrentLocalWeatherViewModel: Requesting location permission")
        
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 Permission already granted, starting updates")
            locationManager.startUpdatingLocation()
            isLoading = true
            
        case .notDetermined:
            print("📍 Permission not determined, requesting...")
            locationManager.requestWhenInUseAuthorization()
            isLoading = true
            
        case .denied, .restricted:
            print("📍 Permission denied or restricted")
            errorMessage = "Location access is restricted. Please enable location services in Settings."
            isLoading = false
            
        @unknown default:
            print("📍 Unknown location authorization status")
            errorMessage = "Unable to determine location permission status."
            isLoading = false
        }
    }
    
    // MARK: - CLLocationManagerDelegate Methods
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("📍 Location authorization status changed: \(manager.authorizationStatus.rawValue)")
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 Permission granted, starting updates")
            locationManager.startUpdatingLocation()
            
        case .denied, .restricted:
            print("📍 Permission denied or restricted after change")
            DispatchQueue.main.async {
                self.errorMessage = "Location access is restricted. Please enable location services in Settings."
                self.isLoading = false
            }
            
        case .notDetermined:
            // Still waiting for user decision
            print("📍 Permission still not determined after change")
            
        @unknown default:
            print("📍 Unknown authorization status after change")
            DispatchQueue.main.async {
                self.errorMessage = "Unknown location authorization status."
                self.isLoading = false
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            print("📍 LocationManager: No locations received")
            return
        }
        
        print("📍 LocationManager: Received location - Lat: \(location.coordinate.latitude), Lon: \(location.coordinate.longitude), Acc: \(location.horizontalAccuracy)m")
        
        // Process only valid locations
        guard location.horizontalAccuracy >= 0 else {
            print("📍 Ignoring location with negative accuracy")
            return
        }
        
        // Update current location
        self.currentLocation = location
        
        // Update published properties on main thread
        DispatchQueue.main.async {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.locationState = .highAccuracy(location: location, accuracy: location.horizontalAccuracy)
            self.locationAccuracyDescription = self.locationState.description
            
            // Once we have a location, fetch weather data
            self.fetchWeatherWithCurrentLocation()
        }
        
        // We can stop updating location once we have a good one
        if location.horizontalAccuracy <= 100 {
            locationManager.stopUpdatingLocation()
            print("📍 Got good location, stopped updates")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 LocationManager error: \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            if self.currentLocation == nil {
                // Only show error if we don't have any location yet
                self.errorMessage = "Failed to get your location: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Weather Data Methods
    
    private func fetchWeatherWithCurrentLocation() {
        // Cancel any existing weather task
        weatherTask?.cancel()
        weatherTask = nil
        
        // Ensure we have a valid location
        guard let location = self.currentLocation else {
            print("⚠️ fetchWeatherWithCurrentLocation: No location available")
            
            // Reset to error state if we don't have location but were expected to
            DispatchQueue.main.async {
                self.errorMessage = "Location data not available. Please try again."
                self.isLoading = false
            }
            return
        }
        
        // Update loading state
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = ""
        }
        
        // Start a new task for fetching weather data
        weatherTask = Task {
            if Task.isCancelled { return }
            
            print("🌤️ Fetching weather for location (\(location.coordinate.latitude), \(location.coordinate.longitude))")
            
            // Get location name through geocoding
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
                    } else {
                        await MainActor.run {
                            locationDisplay = "Location at \(String(format: "%.4f", latitude))°, \(String(format: "%.4f", longitude))°"
                        }
                    }
                } catch {
                    print("⚠️ Geocoding error: \(error), continuing with coordinates only")
                    await MainActor.run {
                        locationDisplay = "Location at \(String(format: "%.4f", latitude))°, \(String(format: "%.4f", longitude))°"
                    }
                }
            }
            
            // Get weather data using our dedicated weather service
            if let weatherService = currentLocalWeatherService {
                do {
                    let weather = try await weatherService.getWeather(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    
                    if Task.isCancelled { return }
                    
                    print("✅ Weather data received, processing...")
                    await processWeatherData(weather)
                    
                    // Check if location is a favorite
                    await updateFavoriteStatus()
                    
                    await MainActor.run {
                        isLoading = false
                    }
                } catch {
                    if !Task.isCancelled {
                        print("❌ Weather API error: \(error)")
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
        if let databaseService = databaseService {
            // Remove do-catch since no errors are thrown
            let favoriteStatus = await databaseService.isWeatherLocationFavoriteAsync(
                latitude: latitude,
                longitude: longitude
            )
            
            await MainActor.run {
                isFavorite = favoriteStatus
                favoriteIcon = favoriteStatus ? "heart.fill" : "heart"
            }
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
