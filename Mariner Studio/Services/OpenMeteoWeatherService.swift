import Foundation
import Combine

// Protocol defining the weather service interface
protocol WeatherService {
    func getWeather(latitude: Double, longitude: Double) async throws -> OpenMeteoResponse
    func getHourlyForecast(year: Int, month: Int, day: Int, latitude: Double, longitude: Double) async throws -> OpenMeteoHourlyResponse
    func getMarineForecast(year: Int, month: Int, day: Int, latitude: Double, longitude: Double) async throws -> OpenMeteoMarineResponse?
}

// Implementation of the Open-Meteo weather service
class OpenMeteoWeatherService: WeatherService {
    // MARK: - Constants
    private let baseUrl = "https://api.open-meteo.com/v1/forecast"
    private let marineUrl = "https://marine-api.open-meteo.com/v1/marine"
    
    // MARK: - Properties
    private let urlSession: URLSession
    private let jsonDecoder: JSONDecoder
    
    // MARK: - Initialization
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // MARK: - Weather Service Methods
    
    /// Fetches weather data for a specific location
    /// - Parameters:
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: Weather data response
    func getWeather(latitude: Double, longitude: Double) async throws -> OpenMeteoResponse {
        // Get today's date and format it for the API
        let today = Date()
        let todayDate = formatDate(today)
        
        // Calculate the end date (today + 7 days)
        let calendar = Calendar.current
        if let endDate = calendar.date(byAdding: .day, value: 7, to: today) {
            let endDateString = formatDate(endDate)
            
            // Build the URL with all required parameters
            let url = URL(string: "\(baseUrl)?" +
                         "latitude=\(latitude)" +
                         "&longitude=\(longitude)" +
                         "&hourly=temperature_2m,relativehumidity_2m,precipitation," +
                         "windspeed_10m,wind_direction_10m,wind_gusts_10m," +
                         "dew_point_2m,surface_pressure,visibility,is_day" +
                         "&daily=weathercode,temperature_2m_max,temperature_2m_min," +
                         "precipitation_sum,windspeed_10m_max,windgusts_10m_max," +
                         "winddirection_10m_dominant,surface_pressure_mean" +
                         "&current_weather=true" +
                         "&temperature_unit=fahrenheit" +
                         "&windspeed_unit=mph" +
                         "&precipitation_unit=inch" +
                         "&start_date=\(todayDate)" +
                         "&end_date=\(endDateString)")
            
            guard let requestUrl = url else {
                throw WeatherError.invalidURL
            }
            
            print("📡 OpenMeteo Weather URL: \(requestUrl)")
            
            let (data, response) = try await urlSession.data(from: requestUrl)
            
            // Validate the response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WeatherError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw WeatherError.serverError(statusCode: httpResponse.statusCode)
            }
            
            // Log a sample of the response
            if let jsonString = String(data: data, encoding: .utf8)?.prefix(200) {
                print("📡 Response sample: \(jsonString)...")
            }
            
            // Decode the response
            do {
                let weatherResponse = try jsonDecoder.decode(OpenMeteoResponse.self, from: data)
                return weatherResponse
            } catch {
                print("📡 JSON decoding error: \(error)")
                throw WeatherError.decodingError(error)
            }
        } else {
            throw WeatherError.invalidDate
        }
    }
    
    /// Fetches hourly forecast data for a specific date and location
    /// - Parameters:
    ///   - year: Year component of the date
    ///   - month: Month component of the date
    ///   - day: Day component of the date
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: Hourly forecast data response
    func getHourlyForecast(year: Int, month: Int, day: Int, latitude: Double, longitude: Double) async throws -> OpenMeteoHourlyResponse {
        // Create date components
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        
        // Create date from components
        guard let date = Calendar.current.date(from: dateComponents) else {
            throw WeatherError.invalidDate
        }
        
        // Format date for API
        let dateString = formatDate(date)
        
        // Build the URL with all required parameters
        let url = URL(string: "\(baseUrl)?" +
                     "latitude=\(latitude)" +
                     "&longitude=\(longitude)" +
                     "&hourly=temperature_2m,relativehumidity_2m,precipitation," +
                     "windspeed_10m,winddirection_10m,windgusts_10m,weathercode," +
                     "pressure_msl,visibility,dewpoint_2m,precipitation_probability" +
                     "&start_date=\(dateString)" +
                     "&end_date=\(dateString)" +
                     "&timezone=auto" +
                     "&temperature_unit=fahrenheit" +
                     "&windspeed_unit=mph" +
                     "&precipitation_unit=inch")
        
        guard let requestUrl = url else {
            throw WeatherError.invalidURL
        }
        
        print("📡 Hourly Forecast URL: \(requestUrl)")
        
        let (data, response) = try await urlSession.data(from: requestUrl)
        
        // Validate the response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw WeatherError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Decode the response
        do {
            let hourlyResponse = try jsonDecoder.decode(OpenMeteoHourlyResponse.self, from: data)
            return hourlyResponse
        } catch {
            print("📡 JSON decoding error: \(error)")
            throw WeatherError.decodingError(error)
        }
    }
    
    /// Fetches marine forecast data for a specific date and location
    /// - Parameters:
    ///   - year: Year component of the date
    ///   - month: Month component of the date
    ///   - day: Day component of the date
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: Marine forecast data response, or nil if the location is not a marine location
    func getMarineForecast(year: Int, month: Int, day: Int, latitude: Double, longitude: Double) async throws -> OpenMeteoMarineResponse? {
        // Create date components
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        
        // Create date from components
        guard let date = Calendar.current.date(from: dateComponents) else {
            throw WeatherError.invalidDate
        }
        
        // Format date for API
        let dateString = formatDate(date)
        
        // Build the URL with all required parameters
        let url = URL(string: "\(marineUrl)?" +
                     "latitude=\(latitude)" +
                     "&longitude=\(longitude)" +
                     "&hourly=wave_height,wave_direction,wave_period," +
                     "swell_wave_height,swell_wave_direction,swell_wave_period," +
                     "wind_wave_height,wind_wave_direction" +
                     "&start_date=\(dateString)" +
                     "&end_date=\(dateString)" +
                     "&timezone=auto")
        
        guard let requestUrl = url else {
            throw WeatherError.invalidURL
        }
        
        print("📡 Marine Forecast URL: \(requestUrl)")
        
        let (data, response) = try await urlSession.data(from: requestUrl)
        
        // Validate the response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // For marine data, we return nil if it's not available rather than throwing an error
            // as many locations won't have marine data
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 404 {
                return nil
            }
            throw WeatherError.serverError(statusCode: httpResponse.statusCode)
        }
        
        // Check if response contains an error message
        if let content = String(data: data, encoding: .utf8), content.contains("Error") {
            return nil
        }
        
        // Decode the response
        do {
            let marineResponse = try jsonDecoder.decode(OpenMeteoMarineResponse.self, from: data)
            return marineResponse
        } catch {
            print("📡 JSON decoding error: \(error)")
            throw WeatherError.decodingError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Formats a date for API requests
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string (yyyy-MM-dd)
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Weather Error Enum
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
