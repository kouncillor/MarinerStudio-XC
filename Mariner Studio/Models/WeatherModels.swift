import Foundation

// MARK: - Weather Condition Enum
enum WeatherCondition: Int {
    // Thunderstorm Group (2xx)
    case thunderstormWithLightRain = 200
    case thunderstormWithRain = 201
    case thunderstormWithHeavyRain = 202
    case lightThunderstorm = 210
    case thunderstorm = 211
    case heavyThunderstorm = 212
    case raggedThunderstorm = 221
    case thunderstormWithLightDrizzle = 230
    case thunderstormWithDrizzle = 231
    case thunderstormWithHeavyDrizzle = 232
    
    // Drizzle Group (3xx)
    case lightIntensityDrizzle = 300
    case drizzle = 301
    case heavyIntensityDrizzle = 302
    case lightIntensityDrizzleRain = 310
    case drizzleRain = 311
    case heavyIntensityDrizzleRain = 312
    case showerRainAndDrizzle = 313
    case heavyShowerRainAndDrizzle = 314
    case showerDrizzle = 321
    
    // Rain Group (5xx)
    case lightRain = 500
    case moderateRain = 501
    case heavyIntensityRain = 502
    case veryHeavyRain = 503
    case extremeRain = 504
    case freezingRain = 511
    case lightIntensityShowerRain = 520
    case showerRain = 521
    case heavyIntensityShowerRain = 522
    case raggedShowerRain = 531
    
    // Snow Group (6xx)
    case lightSnow = 600
    case snow = 601
    case heavySnow = 602
    case sleet = 611
    case lightShowerSleet = 612
    case showerSleet = 613
    case lightRainAndSnow = 615
    case rainAndSnow = 616
    case lightShowerSnow = 620
    case showerSnow = 621
    case heavyShowerSnow = 622
    
    // Atmosphere Group (7xx)
    case mist = 701
    case smoke = 711
    case haze = 721
    case sandDustWhirls = 731
    case fog = 741
    case sand = 751
    case dust = 761
    case volcanicAsh = 762
    case squalls = 771
    case tornado = 781
    
    // Clear and Clouds (800-804)
    case clearSky = 800
    case fewClouds = 801        // 11-25%
    case scatteredClouds = 802  // 25-50%
    case brokenClouds = 803     // 51-84%
    case overcastClouds = 804   // 85-100%
    
    // Open-Meteo weather codes
    case clearSkyOm = 0
    case mainlyClearOm = 1
    case partlyCloudyOm = 2
    case overcastOm = 3
    case fogOm = 45
    case depositingRimeFogOm = 48
    case lightDrizzleOm = 51
    case moderateDrizzleOm = 53
    case denseDrizzleOm = 55
    case slightRainOm = 61
    case moderateRainOm = 63
    case heavyRainOm = 65
    case slightSnowFallOm = 71
    case moderateSnowFallOm = 73
    case heavySnowFallOm = 75
    case snowGrainsOm = 77
    case slightRainShowersOm = 80
    case moderateRainShowersOm = 81
    case violentRainShowersOm = 82
    case slightSnowShowersOm = 85
    case heavySnowShowersOm = 86
    case thunderstormOm = 95
    case thunderstormWithSlightHailOm = 96
    case thunderstormWithHeavyHailOm = 99
    
    func getIconName() -> String {
        switch self {
        case .clearSky, .clearSkyOm:
            return "sun.max.fill"
        case .fewClouds, .mainlyClearOm, .partlyCloudyOm:
            return "cloud.sun.fill"
        case .scatteredClouds, .brokenClouds, .overcastClouds, .overcastOm:
            return "cloud.fill"
        case .lightRain, .moderateRain, .heavyIntensityRain, .veryHeavyRain, .extremeRain,
             .freezingRain, .lightIntensityShowerRain, .showerRain, .heavyIntensityShowerRain,
             .raggedShowerRain, .slightRainOm, .moderateRainOm, .heavyRainOm,
             .slightRainShowersOm, .moderateRainShowersOm, .violentRainShowersOm:
            return "cloud.rain.fill"
        case .thunderstorm, .lightThunderstorm, .heavyThunderstorm, .raggedThunderstorm,
             .thunderstormWithLightRain, .thunderstormWithRain, .thunderstormWithHeavyRain,
             .thunderstormWithLightDrizzle, .thunderstormWithDrizzle, .thunderstormWithHeavyDrizzle,
             .thunderstormOm, .thunderstormWithSlightHailOm, .thunderstormWithHeavyHailOm:
            return "cloud.bolt.fill"
        case .drizzle, .lightIntensityDrizzle, .heavyIntensityDrizzle, .lightIntensityDrizzleRain,
             .drizzleRain, .heavyIntensityDrizzleRain, .showerRainAndDrizzle, .heavyShowerRainAndDrizzle,
             .showerDrizzle, .lightDrizzleOm, .moderateDrizzleOm, .denseDrizzleOm:
            return "cloud.drizzle.fill"
        case .snow, .lightSnow, .heavySnow, .sleet, .lightShowerSleet, .showerSleet,
             .lightRainAndSnow, .rainAndSnow, .lightShowerSnow, .showerSnow, .heavyShowerSnow,
             .slightSnowFallOm, .moderateSnowFallOm, .heavySnowFallOm, .snowGrainsOm,
             .slightSnowShowersOm, .heavySnowShowersOm:
            return "snow"
        case .fog, .mist, .smoke, .haze, .sandDustWhirls, .sand, .dust, .volcanicAsh,
             .squalls, .tornado, .fogOm, .depositingRimeFogOm:
            return "cloud.fog.fill"
        default:
            return "cloud.fill"
        }
    }
    
    func getDescription() -> String {
        switch self {
        // Open-Meteo codes
        case .clearSkyOm:
            return "Clear sky"
        case .mainlyClearOm:
            return "Mainly clear"
        case .partlyCloudyOm:
            return "Partly cloudy"
        case .overcastOm:
            return "Overcast"
        case .fogOm:
            return "Foggy"
        case .depositingRimeFogOm:
            return "Depositing rime fog"
        case .lightDrizzleOm:
            return "Light drizzle"
        case .moderateDrizzleOm:
            return "Moderate drizzle"
        case .denseDrizzleOm:
            return "Dense drizzle"
        case .slightRainOm:
            return "Slight rain"
        case .moderateRainOm:
            return "Moderate rain"
        case .heavyRainOm:
            return "Heavy rain"
        case .slightSnowFallOm:
            return "Slight snow fall"
        case .moderateSnowFallOm:
            return "Moderate snow fall"
        case .heavySnowFallOm:
            return "Heavy snow fall"
        case .snowGrainsOm:
            return "Snow grains"
        case .slightRainShowersOm:
            return "Slight rain showers"
        case .moderateRainShowersOm:
            return "Moderate rain showers"
        case .violentRainShowersOm:
            return "Violent rain showers"
        case .slightSnowShowersOm:
            return "Slight snow showers"
        case .heavySnowShowersOm:
            return "Heavy snow showers"
        case .thunderstormOm:
            return "Thunderstorm"
        case .thunderstormWithSlightHailOm:
            return "Thunderstorm with slight hail"
        case .thunderstormWithHeavyHailOm:
            return "Thunderstorm with heavy hail"
            
        // Regular OWM codes
        case .clearSky:
            return "Clear sky"
        case .fewClouds:
            return "Few clouds"
        case .scatteredClouds:
            return "Scattered clouds"
        case .brokenClouds:
            return "Broken clouds"
        case .overcastClouds:
            return "Overcast clouds"
        case .lightRain:
            return "Light rain"
        case .moderateRain:
            return "Moderate rain"
        case .heavyIntensityRain:
            return "Heavy rain"
        case .thunderstorm:
            return "Thunderstorm"
        case .snow:
            return "Snow"
        case .fog, .mist:
            return "Foggy"
        default:
            return "Unknown weather"
        }
    }
}

// MARK: - Daily Forecast Item
struct DailyForecastItem: Identifiable {
    let id: UUID
    let date: Date
    let dayOfWeek: String
    let dateDisplay: String
    let high: Double
    let low: Double
    let description: String
    let windSpeed: Double
    let windGusts: Double
    let windDirection: String
    let visibility: String
    let rowIndex: Int
    let pressure: Double
    let weatherImage: String
    let moonPhaseIcon: String
    let isWaxingMoon: Bool
    let visibilityMeters: Double
    let weatherCode: Int
    let isToday: Bool
    
    init(
        id: UUID = UUID(),
        date: Date,
        dayOfWeek: String? = nil,
        dateDisplay: String? = nil,
        high: Double,
        low: Double,
        description: String,
        windSpeed: Double,
        windGusts: Double,
        windDirection: String,
        visibility: String,
        rowIndex: Int,
        pressure: Double,
        weatherImage: String,
        moonPhaseIcon: String,
        isWaxingMoon: Bool,
        visibilityMeters: Double,
        weatherCode: Int,
        isToday: Bool = false
    ) {
        self.id = id
        self.date = date
        self.dayOfWeek = dayOfWeek ?? date.formatted(.dateTime.weekday(.abbreviated))
        self.dateDisplay = dateDisplay ?? date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
        self.high = high
        self.low = low
        self.description = description
        self.windSpeed = windSpeed
        self.windGusts = windGusts
        self.windDirection = windDirection
        self.visibility = visibility
        self.rowIndex = rowIndex
        self.pressure = pressure
        self.weatherImage = weatherImage
        self.moonPhaseIcon = moonPhaseIcon
        self.isWaxingMoon = isWaxingMoon
        self.visibilityMeters = visibilityMeters
        self.weatherCode = weatherCode
        self.isToday = isToday
    }
}

// MARK: - Hourly Forecast Item
struct HourlyForecastItem: Identifiable {
    let id = UUID()
    let time: Date
    let hour: String
    let timeDisplay: String
    let temperature: Double
    let humidity: Int
    let precipitation: Double
    let precipitationChance: Double
    let windSpeed: Double
    let windDirection: Double
    let windGusts: Double
    let dewPoint: Double
    let pressure: Double
    let previousPressure: Double?
    let visibilityMeters: Double
    let weatherCode: Int
    let isNightTime: Bool
    let cardinalDirection: String
    let weatherIcon: String
    let moonPhase: String
    
    var visibility: String {
        return formatVisibility()
    }
    
    var pressureTrendIcon: String {
        guard let prevPressure = previousPressure else { return "" }
        
        let difference = pressure - prevPressure
        if abs(difference) < 0.02 {
            return "minus"
        }
        return difference > 0 ? "arrow.up" : "arrow.down"
    }
    
    private func formatVisibility() -> String {
        let visibilityMiles = visibilityMeters / 1609.34
        return visibilityMiles >= 15.0 ? "15+ mi" : "\(String(format: "%.1f", visibilityMiles)) mi"
    }
}

// MARK: - Moon Phase
struct MoonPhase: Identifiable {
    let id = UUID()
    let date: String
    let phase: String
    let icon: String
    let isWaxing: Bool
    let illumination: Double
    let previousMajorPhase: String
    let nextMajorPhase: String
    
    init(date: String, phase: String, icon: String = "moonphase.new.moon", isWaxing: Bool = true, illumination: Double = 0.0, previousMajorPhase: String = "", nextMajorPhase: String = "") {
        self.date = date
        self.phase = phase
        self.icon = icon
        self.isWaxing = isWaxing
        self.illumination = illumination
        self.previousMajorPhase = previousMajorPhase
        self.nextMajorPhase = nextMajorPhase
    }
}

// MARK: - Weather Location Favorite
struct DbWeatherLocationFavorite: Identifiable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let locationName: String
    let isFavorite: Bool
    let createdAt: Date
}

// MARK: - OpenMeteo Responses
struct OpenMeteoResponse: Decodable {
    let isDay: Int?
    let latitude: Double
    let longitude: Double
    let timezone: String
    let currentWeather: CurrentWeather
    let hourly: HourlyWeather
    let daily: DailyWeather
    
    enum CodingKeys: String, CodingKey {
        case isDay = "is_day"
        case latitude, longitude, timezone
        case currentWeather = "current_weather"
        case hourly, daily
    }
}

struct CurrentWeather: Decodable {
    let temperature: Double
    let windSpeed: Double
    let windDirection: Double
    let weatherCode: Int
    let time: String
    let isDay: Int
    
    enum CodingKeys: String, CodingKey {
        case temperature
        case windSpeed = "windspeed"
        case windDirection = "winddirection"
        case weatherCode = "weathercode"
        case time
        case isDay = "is_day"
    }
}










struct HourlyWeather: Decodable {
    let time: [String]
    let temperature: [Double]
    let relativeHumidity: [Int]?
    let precipitation: [Double]
    let windSpeed: [Double]
    let windDirection: [Double]
    let windGusts: [Double]
    let dewPoint: [Double]?
    let pressure: [Double]
    let visibility: [Double]
    var isDay: [Int]
    var weatherCode: [Int]
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case relativeHumidity = "relativehumidity_2m"
        case precipitation
        case windSpeed = "windspeed_10m"
        case windDirection = "wind_direction_10m"
        case windGusts = "wind_gusts_10m"
        case dewPoint = "dew_point_2m"
        case pressure = "surface_pressure"
        case visibility
        case isDay = "is_day"
        case weatherCode = "weathercode"
    }
    
    // Custom initializer with default values for the new fields
    init(time: [String], temperature: [Double], relativeHumidity: [Int]?, precipitation: [Double],
         windSpeed: [Double], windDirection: [Double], windGusts: [Double], dewPoint: [Double]?,
         pressure: [Double], visibility: [Double], isDay: [Int] = [], weatherCode: [Int] = []) {
        self.time = time
        self.temperature = temperature
        self.relativeHumidity = relativeHumidity
        self.precipitation = precipitation
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.windGusts = windGusts
        self.dewPoint = dewPoint
        self.pressure = pressure
        self.visibility = visibility
        self.isDay = isDay
        self.weatherCode = weatherCode
    }
}















struct DailyWeather: Decodable {
    let time: [String]
    let temperatureMax: [Double]
    let temperatureMin: [Double]
    let precipitationSum: [Double]
    let windSpeedMax: [Double]
    let windGustsMax: [Double]
    let windDirectionDominant: [Double]
    let weatherCode: [Int]
    let surfacePressure: [Double]
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperatureMax = "temperature_2m_max"
        case temperatureMin = "temperature_2m_min"
        case precipitationSum = "precipitation_sum"
        case windSpeedMax = "windspeed_10m_max"
        case windGustsMax = "windgusts_10m_max"
        case windDirectionDominant = "winddirection_10m_dominant"
        case weatherCode = "weathercode"
        case surfacePressure = "surface_pressure_mean"
    }
}

// MARK: - OpenMeteo Hourly Response
struct OpenMeteoHourlyResponse: Decodable {
    let hourly: HourlyData
    let hourlyUnits: HourlyUnits
    
    enum CodingKeys: String, CodingKey {
        case hourly
        case hourlyUnits = "hourly_units"
    }
}

struct HourlyData: Decodable {
    let time: [String]
    let temperature: [Double]
    let relativeHumidity: [Int]?
    let dewPoint: [Double]?
    let precipitation: [Double]
    let precipitationProbability: [Double]?
    let weatherCode: [Int]
    let pressure: [Double]
    let visibility: [Double]
    let windSpeed: [Double]
    let windDirection: [Double]
    let windGusts: [Double]
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case relativeHumidity = "relativehumidity_2m"
        case dewPoint = "dewpoint_2m"
        case precipitation
        case precipitationProbability = "precipitation_probability"
        case weatherCode = "weathercode"
        case pressure = "pressure_msl"
        case visibility
        case windSpeed = "windspeed_10m"
        case windDirection = "winddirection_10m"
        case windGusts = "windgusts_10m"
    }
}

struct HourlyUnits: Decodable {
    let time: String
    let temperature: String
    let relativeHumidity: String?
    let dewPoint: String?
    let precipitation: String
    let weatherCode: String
    let pressure: String
    let visibility: String
    let windSpeed: String
    let windDirection: String
    let windGusts: String
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case relativeHumidity = "relativehumidity_2m"
        case dewPoint = "dewpoint_2m"
        case precipitation
        case weatherCode = "weathercode"
        case pressure = "pressure_msl"
        case visibility
        case windSpeed = "windspeed_10m"
        case windDirection = "winddirection_10m"
        case windGusts = "windgusts_10m"
    }
}

// MARK: - OpenMeteo Marine Response
struct OpenMeteoMarineResponse: Decodable {
    let hourly: MarineHourlyData
    let hourlyUnits: MarineHourlyUnits
    
    enum CodingKeys: String, CodingKey {
        case hourly
        case hourlyUnits = "hourly_units"
    }
}

struct MarineHourlyData: Decodable {
    let time: [String]
    let waveHeight: [Double]
    let waveDirection: [Double]
    let wavePeriod: [Double]
    let swellWaveHeight: [Double]
    let swellWaveDirection: [Double]
    let swellWavePeriod: [Double]
    let windWaveHeight: [Double]
    let windWaveDirection: [Double]
    
    var waveHeightFeet: [Double] {
        waveHeight.map { round($0 * 3.28084 * 10) / 10 }
    }
    
    var swellWaveHeightFeet: [Double] {
        swellWaveHeight.map { round($0 * 3.28084 * 10) / 10 }
    }
    
    var windWaveHeightFeet: [Double] {
        windWaveHeight.map { round($0 * 3.28084 * 10) / 10 }
    }
    
    enum CodingKeys: String, CodingKey {
        case time
        case waveHeight = "wave_height"
        case waveDirection = "wave_direction"
        case wavePeriod = "wave_period"
        case swellWaveHeight = "swell_wave_height"
        case swellWaveDirection = "swell_wave_direction"
        case swellWavePeriod = "swell_wave_period"
        case windWaveHeight = "wind_wave_height"
        case windWaveDirection = "wind_wave_direction"
    }
}

struct MarineHourlyUnits: Decodable {
    let time: String
    let waveHeight: String
    let waveDirection: String
    let wavePeriod: String
    let swellWaveHeight: String
    let swellWaveDirection: String
    let swellWavePeriod: String
    let windWaveHeight: String
    let windWaveDirection: String
    
    enum CodingKeys: String, CodingKey {
        case time
        case waveHeight = "wave_height"
        case waveDirection = "wave_direction"
        case wavePeriod = "wave_period"
        case swellWaveHeight = "swell_wave_height"
        case swellWaveDirection = "swell_wave_direction"
        case swellWavePeriod = "swell_wave_period"
        case windWaveHeight = "wind_wave_height"
        case windWaveDirection = "wind_wave_direction"
    }
}

// MARK: - Weather Error
enum WeatherError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError(Error)
    case invalidDate
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for weather request"
        case .invalidResponse:
            return "Invalid response from weather service"
        case .serverError(let statusCode):
            return "Server error with status code: \(statusCode)"
        case .decodingError(let error):
            return "Error decoding weather data: \(error.localizedDescription)"
        case .invalidDate:
            return "Invalid date for weather request"
        }
    }
}
