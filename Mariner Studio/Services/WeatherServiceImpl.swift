import Foundation

/// Implementation of the Open-Meteo weather service
class WeatherServiceImpl: WeatherService {
    // MARK: - Constants
    private let baseUrl = "https://api.open-meteo.com/v1/forecast"
    private let marineUrl = "https://marine-api.open-meteo.com/v1/marine"
    
    // MARK: - Properties
    private let urlSession: URLSession
    
    // MARK: - Initialization
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    // MARK: - Weather Service Methods
    
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
                         "dew_point_2m,surface_pressure,visibility,is_day,weathercode" +
                         "&daily=weathercode,temperature_2m_max,temperature_2m_min," +
                         "precipitation_sum,windspeed_10m_max,windgusts_10m_max," +
                         "winddirection_10m_dominant,surface_pressure_mean" +
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
            
            // Parse the JSON manually using JSONSerialization
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw WeatherError.decodingError(NSError(domain: "WeatherService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"]))
                }
                
                // Create an OpenMeteoResponse from the raw JSON
                return try createResponseFromRawJSON(json)
            } catch {
                print("📡 JSON parsing error: \(error)")
                throw WeatherError.decodingError(error)
            }
        } else {
            throw WeatherError.invalidDate
        }
    }
    
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
        
        // Decode the response using JSONSerialization for flexibility
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw WeatherError.decodingError(NSError(domain: "WeatherService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"]))
            }
            
            // Parse the JSON into our model
            return try createHourlyResponseFromRawJSON(json)
        } catch {
            print("📡 JSON parsing error: \(error)")
            throw WeatherError.decodingError(error)
        }
    }
    
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
        
        // Parse the JSON using JSONSerialization
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw WeatherError.decodingError(NSError(domain: "WeatherService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"]))
            }
            
            // Create the marine response from the raw JSON
            return try createMarineResponseFromRawJSON(json)
        } catch {
            print("📡 JSON parsing error: \(error)")
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
    
    // MARK: - JSON Parsing Methods
    
    /// Create an OpenMeteoResponse from raw JSON
    private func createResponseFromRawJSON(_ json: [String: Any]) throws -> OpenMeteoResponse {
        // Extract basic properties
        guard let latitude = json["latitude"] as? Double,
              let longitude = json["longitude"] as? Double,
              let timezone = json["timezone"] as? String,
              let hourlyData = json["hourly"] as? [String: Any],
              let dailyData = json["daily"] as? [String: Any] else {
            throw WeatherError.decodingError(NSError(domain: "WeatherService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing required fields in JSON"]))
        }
        
        // Extract hourly arrays
        guard let timeArray = hourlyData["time"] as? [String],
              let temperatureArray = hourlyData["temperature_2m"] as? [Double],
              let precipitationArray = hourlyData["precipitation"] as? [Double],
              let windSpeedArray = hourlyData["windspeed_10m"] as? [Double],
              let windDirectionArray = hourlyData["wind_direction_10m"] as? [Double],
              let windGustsArray = hourlyData["wind_gusts_10m"] as? [Double],
              let pressureArray = hourlyData["surface_pressure"] as? [Double],
              let visibilityArray = hourlyData["visibility"] as? [Double],
              let isDayArray = hourlyData["is_day"] as? [Int],
              let weatherCodeArray = hourlyData["weathercode"] as? [Int] else {
            throw WeatherError.decodingError(NSError(domain: "WeatherService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing hourly data fields in JSON"]))
        }
        
        // Extract optional hourly arrays
        let relativeHumidityArray = hourlyData["relativehumidity_2m"] as? [Int]
        let dewPointArray = hourlyData["dew_point_2m"] as? [Double]
        
        // Extract daily arrays
        guard let dailyTimeArray = dailyData["time"] as? [String],
              let dailyWeatherCodeArray = dailyData["weathercode"] as? [Int],
              let dailyTempMaxArray = dailyData["temperature_2m_max"] as? [Double],
              let dailyTempMinArray = dailyData["temperature_2m_min"] as? [Double],
              let dailyPrecipSumArray = dailyData["precipitation_sum"] as? [Double],
              let dailyWindSpeedMaxArray = dailyData["windspeed_10m_max"] as? [Double],
              let dailyWindGustsMaxArray = dailyData["windgusts_10m_max"] as? [Double],
              let dailyWindDirectionArray = dailyData["winddirection_10m_dominant"] as? [Double],
              let dailySurfacePressureArray = dailyData["surface_pressure_mean"] as? [Double] else {
            throw WeatherError.decodingError(NSError(domain: "WeatherService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing daily data fields in JSON"]))
        }
        
        // Create the hourly weather object
        let hourlyWeather = HourlyWeather(
            time: timeArray,
            temperature: temperatureArray,
            relativeHumidity: relativeHumidityArray,
            precipitation: precipitationArray,
            windSpeed: windSpeedArray,
            windDirection: windDirectionArray,
            windGusts: windGustsArray,
            dewPoint: dewPointArray,
            pressure: pressureArray,
            visibility: visibilityArray,
            isDay: isDayArray,
            weatherCode: weatherCodeArray
        )
        
        // Create the daily weather object
        let dailyWeather = DailyWeather(
            time: dailyTimeArray,
            temperatureMax: dailyTempMaxArray,
            temperatureMin: dailyTempMinArray,
            precipitationSum: dailyPrecipSumArray,
            windSpeedMax: dailyWindSpeedMaxArray,
            windGustsMax: dailyWindGustsMaxArray,
            windDirectionDominant: dailyWindDirectionArray,
            weatherCode: dailyWeatherCodeArray,
            surfacePressure: dailySurfacePressureArray
        )
        
        // Get the current hour index
        let currentHourIndex = min(Calendar.current.component(.hour, from: Date()), timeArray.count - 1)
        
        // Create the current weather object from the hourly data
        let currentWeather = CurrentWeather(
            temperature: temperatureArray[currentHourIndex],
            windSpeed: windSpeedArray[currentHourIndex],
            windDirection: windDirectionArray[currentHourIndex],
            weatherCode: weatherCodeArray[currentHourIndex],
            time: timeArray[currentHourIndex],
            isDay: isDayArray[currentHourIndex]
        )
        
        // Create the full response
        return OpenMeteoResponse(
            isDay: currentWeather.isDay,
            latitude: latitude,
            longitude: longitude,
            timezone: timezone,
            currentWeather: currentWeather,
            hourly: hourlyWeather,
            daily: dailyWeather
        )
    }
    
    /// Create an OpenMeteoHourlyResponse from raw JSON
    private func createHourlyResponseFromRawJSON(_ json: [String: Any]) throws -> OpenMeteoHourlyResponse {
        // This is a simplified placeholder implementation
        // In a real app, you would parse the JSON to create the HourlyData and HourlyUnits objects
        
        // For now, we'll return a minimal response
        let hourlyData = HourlyData(
            time: [],
            temperature: [],
            relativeHumidity: nil,
            dewPoint: nil,
            precipitation: [],
            precipitationProbability: nil,
            weatherCode: [],
            pressure: [],
            visibility: [],
            windSpeed: [],
            windDirection: [],
            windGusts: []
        )
        
        let hourlyUnits = HourlyUnits(
            time: "",
            temperature: "",
            relativeHumidity: nil,
            dewPoint: nil,
            precipitation: "",
            weatherCode: "",
            pressure: "",
            visibility: "",
            windSpeed: "",
            windDirection: "",
            windGusts: ""
        )
        
        return OpenMeteoHourlyResponse(
            hourly: hourlyData,
            hourlyUnits: hourlyUnits
        )
    }
    
    /// Create an OpenMeteoMarineResponse from raw JSON
    private func createMarineResponseFromRawJSON(_ json: [String: Any]) throws -> OpenMeteoMarineResponse? {
        // This is a simplified placeholder implementation
        // In a real app, you would parse the JSON to create the MarineHourlyData and MarineHourlyUnits objects
        
        // For now, we'll return a minimal response
        let marineHourlyData = MarineHourlyData(
            time: [],
            waveHeight: [],
            waveDirection: [],
            wavePeriod: [],
            swellWaveHeight: [],
            swellWaveDirection: [],
            swellWavePeriod: [],
            windWaveHeight: [],
            windWaveDirection: []
        )
        
        let marineHourlyUnits = MarineHourlyUnits(
            time: "",
            waveHeight: "",
            waveDirection: "",
            wavePeriod: "",
            swellWaveHeight: "",
            swellWaveDirection: "",
            swellWavePeriod: "",
            windWaveHeight: "",
            windWaveDirection: ""
        )
        
        return OpenMeteoMarineResponse(
            hourly: marineHourlyData,
            hourlyUnits: marineHourlyUnits
        )
    }
}
