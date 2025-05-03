import SwiftUI

/// Maps weather codes and descriptive strings to SF Symbols
struct WeatherIconMapper {
    
    /// Maps Open-Meteo weather codes to SF Symbols
    /// - Parameter code: The weather code from the API
    /// - Parameter isNight: Whether it's nighttime (for sun/moon variations)
    /// - Returns: The name of the SF Symbol to use
    static func mapWeatherCode(_ code: Int, isNight: Bool = false) -> String {
        if isNight {
            return mapNightWeatherCode(code)
        } else {
            return mapDayWeatherCode(code)
        }
    }
    
    /// Maps string-based weather image names from the original app to SF Symbols
    /// - Parameter imageName: The image name from the original app
    /// - Parameter isNight: Whether it's nighttime
    /// - Returns: The name of the SF Symbol to use
    static func mapImageName(_ imageName: String, isNight: Bool = false) -> String {
        // Handle night variations first
        if isNight && (imageName.contains("sun") || imageName.isEmpty) {
            return "moon.stars.fill"
        }
        
        if imageName.contains("sun") {
            return "sun.max.fill"
        } else if imageName.contains("fewclouds") {
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        } else if imageName.contains("scatteredclouds") || imageName.contains("brokencloud") {
            return "cloud.fill"
        } else if imageName.contains("overcast") {
            return "smoke.fill"
        } else if imageName.contains("rain") {
            return "cloud.rain.fill"
        } else if imageName.contains("shower") {
            return "cloud.heavyrain.fill"
        } else if imageName.contains("drizzle") {
            return "cloud.drizzle.fill"
        } else if imageName.contains("snow") {
            return "snow"
        } else if imageName.contains("sleet") {
            return "cloud.sleet.fill"
        } else if imageName.contains("thunder") || imageName.contains("storm") {
            return "cloud.bolt.fill"
        } else if imageName.contains("fog") || imageName.contains("mist") {
            return "cloud.fog.fill"
        } else if imageName.contains("wind") {
            return "wind"
        } else if imageName.contains("tornado") {
            return "tornado"
        } else {
            return "questionmark.circle"
        }
    }
    
    /// Maps moon phase strings to SF Symbols
    /// - Parameter phaseName: The moon phase string
    /// - Returns: The name of the SF Symbol to use
    static func mapMoonPhase(_ phaseName: String) -> String {
        if phaseName.contains("newmoon") {
            return "moonphase.new.moon"
        } else if phaseName.contains("waxingcrescent") {
            return "moonphase.waxing.crescent"
        } else if phaseName.contains("firstquarter") {
            return "moonphase.first.quarter"
        } else if phaseName.contains("waxinggibbous") {
            return "moonphase.waxing.gibbous"
        } else if phaseName.contains("fullmoon") {
            return "moonphase.full.moon"
        } else if phaseName.contains("waninggibbous") {
            return "moonphase.waning.gibbous"
        } else if phaseName.contains("lastquarter") {
            return "moonphase.last.quarter"
        } else if phaseName.contains("waningcrescent") {
            return "moonphase.waning.crescent"
        } else {
            return "moonphase.new.moon"
        }
    }
    
    // MARK: - Private Helper Methods
    
    private static func mapDayWeatherCode(_ code: Int) -> String {
        switch code {
        // Open-Meteo WMO weather codes
        case 0: // Clear sky
            return "sun.max.fill"
        case 1: // Mainly clear
            return "sun.max.fill"
        case 2: // Partly cloudy
            return "cloud.sun.fill"
        case 3: // Overcast
            return "cloud.fill"
        case 45, 48: // Fog
            return "cloud.fog.fill"
        case 51, 53, 55: // Drizzle
            return "cloud.drizzle.fill"
        case 61, 63, 65: // Rain
            return "cloud.rain.fill"
        case 66, 67: // Freezing rain
            return "cloud.sleet.fill"
        case 71, 73, 75, 77: // Snow
            return "cloud.snow.fill"
        case 80, 81, 82: // Rain showers
            return "cloud.heavyrain.fill"
        case 85, 86: // Snow showers
            return "cloud.snow.fill"
        case 95, 96, 99: // Thunderstorm
            return "cloud.bolt.rain.fill"
            
        // Original OpenWeatherMap codes
        case 200...232: // Thunderstorms
            return "cloud.bolt.rain.fill"
        case 300...321: // Drizzle
            return "cloud.drizzle.fill"
        case 500...531: // Rain
            return "cloud.rain.fill"
        case 600...622: // Snow
            return "cloud.snow.fill"
        case 701: // Mist
            return "cloud.fog.fill"
        case 711: // Smoke
            return "smoke.fill"
        case 721: // Haze
            return "sun.haze.fill"
        case 731, 751, 761: // Dust/Sand
            return "sun.dust.fill"
        case 741: // Fog
            return "cloud.fog.fill"
        case 762: // Ash
            return "smoke.fill"
        case 771: // Squalls
            return "wind"
        case 781: // Tornado
            return "tornado"
        case 800: // Clear
            return "sun.max.fill"
        case 801: // Few clouds
            return "cloud.sun.fill"
        case 802: // Scattered clouds
            return "cloud.sun.fill"
        case 803: // Broken clouds
            return "cloud.fill"
        case 804: // Overcast clouds
            return "cloud.fill"
        default:
            return "cloud.fill"
        }
    }
    
    private static func mapNightWeatherCode(_ code: Int) -> String {
        switch code {
        // Open-Meteo WMO weather codes
        case 0: // Clear sky
            return "moon.stars.fill"
        case 1: // Mainly clear
            return "moon.stars.fill"
        case 2: // Partly cloudy
            return "cloud.moon.fill"
        case 3: // Overcast
            return "cloud.fill"
        case 45, 48: // Fog
            return "cloud.fog.fill"
        case 51, 53, 55: // Drizzle
            return "cloud.drizzle.fill"
        case 61, 63, 65: // Rain
            return "cloud.rain.fill"
        case 66, 67: // Freezing rain
            return "cloud.sleet.fill"
        case 71, 73, 75, 77: // Snow
            return "cloud.snow.fill"
        case 80, 81, 82: // Rain showers
            return "cloud.heavyrain.fill"
        case 85, 86: // Snow showers
            return "cloud.snow.fill"
        case 95, 96, 99: // Thunderstorm
            return "cloud.bolt.rain.fill"
            
        // Original OpenWeatherMap codes
        case 200...232: // Thunderstorms
            return "cloud.bolt.rain.fill"
        case 300...321: // Drizzle
            return "cloud.drizzle.fill"
        case 500...531: // Rain
            return "cloud.rain.fill"
        case 600...622: // Snow
            return "cloud.snow.fill"
        case 701: // Mist
            return "cloud.fog.fill"
        case 711: // Smoke
            return "smoke.fill"
        case 721: // Haze
            return "moon.haze.fill"
        case 731, 751, 761: // Dust/Sand
            return "moon.dust.fill"
        case 741: // Fog
            return "cloud.fog.fill"
        case 762: // Ash
            return "smoke.fill"
        case 771: // Squalls
            return "wind"
        case 781: // Tornado
            return "tornado"
        case 800: // Clear
            return "moon.stars.fill"
        case 801: // Few clouds
            return "cloud.moon.fill"
        case 802: // Scattered clouds
            return "cloud.moon.fill"
        case 803: // Broken clouds
            return "cloud.fill"
        case 804: // Overcast clouds
            return "cloud.fill"
        default:
            return "cloud.fill"
        }
    }
    
    /// Returns a color appropriate for the weather condition
    /// - Parameter code: The weather code
    /// - Returns: A color for the weather icon
    static func colorForWeatherCode(_ code: Int) -> Color {
        switch code {
        case 0, 1, 800, 801: // Clear or mostly clear
            return .yellow
        case 2, 3, 802, 803, 804: // Clouds
            return .gray
        case 45, 48, 701, 711, 721, 731, 741, 751, 761, 762: // Fog, mist, etc.
            return .gray.opacity(0.8)
        case 51, 53, 55, 61, 63, 65, 300...321, 500...531: // Rain and drizzle
            return .blue
        case 71, 73, 75, 77, 85, 86, 600...622: // Snow
            return .cyan
        case 95, 96, 99, 200...232: // Thunderstorms
            return .purple
        default:
            return .gray
        }
    }
    
    /// Returns an appropriate color for a given temperature
    /// - Parameter temperature: The temperature in Fahrenheit
    /// - Returns: A color representing the temperature (blue for cold, red for hot)
    static func colorForTemperature(_ temperature: Double) -> Color {
        if temperature < 32 {
            return .blue
        } else if temperature < 50 {
            return .cyan
        } else if temperature < 65 {
            return .green
        } else if temperature < 80 {
            return .yellow
        } else if temperature < 90 {
            return .orange
        } else {
            return .red
        }
    }
}
