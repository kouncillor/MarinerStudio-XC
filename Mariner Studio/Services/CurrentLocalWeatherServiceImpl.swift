//
//  CurrentLocalWeatherServiceImpl.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/11/25.
//


import Foundation
import CoreLocation

class CurrentLocalWeatherServiceImpl: CurrentLocalWeatherService {
    private let baseUrl = "https://api.open-meteo.com/v1/forecast"
    private let marineBaseUrl = "https://marine-api.open-meteo.com/v1/marine"
    
    func getWeather(latitude: Double, longitude: Double) async throws -> OpenMeteoResponse {
        var components = URLComponents(string: baseUrl)!
        
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current_weather", value: "true"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "windspeed_unit", value: "mph"),
            URLQueryItem(name: "precipitation_unit", value: "inch"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "hourly", value: "temperature_2m,relativehumidity_2m,dewpoint_2m,precipitation,windspeed_10m,wind_direction_10m,wind_gusts_10m,surface_pressure,visibility,is_day,weathercode"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_sum,windspeed_10m_max,windgusts_10m_max,winddirection_10m_dominant,weathercode,surface_pressure_mean")
        ]
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        print("🌦️ CurrentLocalWeatherServiceImpl: Fetching weather data from URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NetworkError.serverError(statusCode: statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let weatherData = try decoder.decode(OpenMeteoResponse.self, from: data)
            
            print("✅ CurrentLocalWeatherServiceImpl: Successfully decoded weather data")
            return weatherData
        } catch {
            print("❌ CurrentLocalWeatherServiceImpl: Failed to decode weather data: \(error)")
            throw NetworkError.decodingError(error)
        }
    }
    
    func getHourlyForecast(year: Int, month: Int, day: Int, latitude: Double, longitude: Double) async throws -> OpenMeteoHourlyResponse {
        let dateString = String(format: "%04d-%02d-%02d", year, month, day)
        var components = URLComponents(string: baseUrl)!
        
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "start_date", value: dateString),
            URLQueryItem(name: "end_date", value: dateString),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "windspeed_unit", value: "mph"),
            URLQueryItem(name: "precipitation_unit", value: "inch"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "hourly", value: "temperature_2m,relativehumidity_2m,dewpoint_2m,precipitation,precipitation_probability,windspeed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl,visibility,weathercode")
        ]
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        print("🌦️ CurrentLocalWeatherServiceImpl: Fetching hourly forecast for \(dateString) from URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NetworkError.serverError(statusCode: statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let forecastData = try decoder.decode(OpenMeteoHourlyResponse.self, from: data)
            
            print("✅ CurrentLocalWeatherServiceImpl: Successfully decoded hourly forecast data")
            return forecastData
        } catch {
            print("❌ CurrentLocalWeatherServiceImpl: Failed to decode hourly forecast data: \(error)")
            throw NetworkError.decodingError(error)
        }
    }
    
    func getMarineForecast(year: Int, month: Int, day: Int, latitude: Double, longitude: Double) async throws -> OpenMeteoMarineResponse? {
        let dateString = String(format: "%04d-%02d-%02d", year, month, day)
        var components = URLComponents(string: marineBaseUrl)!
        
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "start_date", value: dateString),
            URLQueryItem(name: "end_date", value: dateString),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "hourly", value: "wave_height,wave_direction,wave_period,swell_wave_height,swell_wave_direction,swell_wave_period,wind_wave_height,wind_wave_direction")
        ]
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        print("🌊 CurrentLocalWeatherServiceImpl: Fetching marine forecast for \(dateString) from URL: \(url.absoluteString)")
        
        // Using a custom URLSession for marine data to handle potential timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(from: url)
            
            // Check if we got a 404 - this means the location is not a marine location, which is a valid response
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                print("ℹ️ CurrentLocalWeatherServiceImpl: Location is not a marine location (404)")
                return nil
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw NetworkError.serverError(statusCode: statusCode)
            }
            
            let decoder = JSONDecoder()
            let marineData = try decoder.decode(OpenMeteoMarineResponse.self, from: data)
            
            print("✅ CurrentLocalWeatherServiceImpl: Successfully decoded marine forecast data")
            return marineData
        } catch {
            // If timeoutError, return nil instead of throwing error
            if let urlError = error as? URLError, urlError.code == .timedOut {
                print("⏱️ CurrentLocalWeatherServiceImpl: Marine data request timed out. Likely not a marine location.")
                return nil
            }
            
            print("❌ CurrentLocalWeatherServiceImpl: Failed to fetch marine forecast data: \(error)")
            throw error
        }
    }
}