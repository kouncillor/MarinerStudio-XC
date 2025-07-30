//
//  WeatherConditionHelper.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//

import Foundation

struct WeatherConditionHelper {
    /// Gets a descriptive string for a weather code
    static func getWeatherDescription(_ code: Int) -> String {
        switch code {
        // Open-Meteo WMO codes
        case 0: // Clear sky
            return "Clear sky"
        case 1: // Mainly clear
            return "Mainly clear"
        case 2: // Partly cloudy
            return "Partly cloudy"
        case 3: // Overcast
            return "Overcast"
        case 45, 48: // Fog
            return "Foggy"
        case 51, 53, 55: // Drizzle
            return "Drizzle"
        case 61, 63, 65: // Rain
            return "Rain"
        case 66, 67: // Freezing rain
            return "Freezing rain"
        case 71, 73, 75, 77: // Snow
            return "Snow"
        case 80, 81, 82: // Rain showers
            return "Rain showers"
        case 85, 86: // Snow showers
            return "Snow showers"
        case 95, 96, 99: // Thunderstorm
            return "Thunderstorm"

        // Classic OpenWeatherMap codes
        case 200...232: // Thunderstorm
            return "Thunderstorm"
        case 300...321: // Drizzle
            return "Drizzle"
        case 500...531: // Rain
            return "Rain"
        case 600...622: // Snow
            return "Snow"
        case 701: // Mist
            return "Mist"
        case 711: // Smoke
            return "Smoke"
        case 721: // Haze
            return "Haze"
        case 731, 751, 761: // Dust/Sand
            return "Dusty"
        case 741: // Fog
            return "Foggy"
        case 800: // Clear sky
            return "Clear sky"
        case 801: // Few clouds
            return "Few clouds"
        case 802: // Scattered clouds
            return "Scattered clouds"
        case 803: // Broken clouds
            return "Broken clouds"
        case 804: // Overcast clouds
            return "Overcast"
        default:
            return "Unknown"
        }
    }

    /// Gets the appropriate image name for a weather code
    static func getWeatherImage(_ code: Int) -> String {
        switch code {
        // Open-Meteo WMO codes
        case 0: // Clear sky
            return "clearsixseven"
        case 1: // Mainly clear
            return "fewcloudssixseven"
        case 2: // Partly cloudy
            return "scatteredcloudssixseven"
        case 3: // Overcast
            return "brokencloudssixseven"
        case 45, 48: // Fog
            return "mistsixseven"
        case 51, 53, 55: // Drizzle
            return "showersixseven"
        case 61, 63, 65: // Rain
            return "rainsixseven"
        case 66, 67: // Freezing rain
            return "sleetsixseven"
        case 71, 73, 75, 77: // Snow
            return "snowsixseven"
        case 80, 81, 82: // Rain showers
            return "showersixseven"
        case 85, 86: // Snow showers
            return "snowsixseven"
        case 95, 96, 99: // Thunderstorm
            return "thunderstormsixseven"

        // Classic OpenWeatherMap codes
        case 200...232: // Thunderstorm
            return "thunderstormsixseven"
        case 300...321: // Drizzle
            return "showersixseven"
        case 500...531: // Rain
            return "rainsixseven"
        case 600...622: // Snow
            return "snowsixseven"
        case 701: // Mist
            return "mistsixseven"
        case 711: // Smoke
            return "mistsixseven"
        case 721: // Haze
            return "mistsixseven"
        case 731, 751, 761: // Dust/Sand
            return "mistsixseven"
        case 741: // Fog
            return "mistsixseven"
        case 800: // Clear sky
            return "clearsixseven"
        case 801: // Few clouds
            return "fewcloudssixseven"
        case 802: // Scattered clouds
            return "scatteredcloudssixseven"
        case 803: // Broken clouds
            return "brokencloudssixseven"
        case 804: // Overcast clouds
            return "overcastsixseven"
        default:
            return "clearsixseven" // Default
        }
    }
}
