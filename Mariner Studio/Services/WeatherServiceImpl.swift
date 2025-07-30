import Foundation

class WeatherServiceImpl: WeatherService {
    // MARK: - Properties
    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    // MARK: - WeatherService Implementation

    func getWeather(latitude: Double, longitude: Double) async throws -> OpenMeteoResponse {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current_weather=true&hourly=temperature_2m,relativehumidity_2m,precipitation,windspeed_10m,winddirection_10m,windgusts_10m,weathercode,pressure_msl,visibility,is_day&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_sum,windspeed_10m_max,windgusts_10m_max,winddirection_10m_dominant,surface_pressure_mean&timezone=auto&temperature_unit=fahrenheit&windspeed_unit=mph&precipitation_unit=inch"

        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw WeatherError.invalidResponse
            }

            if httpResponse.statusCode >= 400 {
                throw WeatherError.serverError(statusCode: httpResponse.statusCode)
            }

            let weatherResponse = try decoder.decode(OpenMeteoResponse.self, from: data)
            return weatherResponse
        } catch {
            if let decodingError = error as? DecodingError {
                throw WeatherError.decodingError(decodingError)
            } else {
                throw error
            }
        }
    }

    func getHourlyForecast(year: Int, month: Int, day: Int, latitude: Double, longitude: Double) async throws -> OpenMeteoHourlyResponse {
        // Format date string as YYYY-MM-DD
        let dateString = String(format: "%04d-%02d-%02d", year, month, day)

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&hourly=temperature_2m,relativehumidity_2m,precipitation,windspeed_10m,winddirection_10m,windgusts_10m,weathercode,pressure_msl,visibility,dewpoint_2m,precipitation_probability&start_date=\(dateString)&end_date=\(dateString)&timezone=auto&temperature_unit=fahrenheit&windspeed_unit=mph&precipitation_unit=inch"

        print("📡 Hourly Forecast URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw WeatherError.invalidResponse
            }

            print("📡 Hourly Response Status Code: \(httpResponse.statusCode)")

            if httpResponse.statusCode >= 400 {
                throw WeatherError.serverError(statusCode: httpResponse.statusCode)
            }

            // Log response data for debugging (first 500 chars)
            let responsePreview = String(data: data, encoding: .utf8)?.prefix(500) ?? "Invalid UTF-8 data"
            print("📡 Hourly Response Data (First 500 chars): \(responsePreview)...")

            print("🧠 Attempting to parse hourly JSON...")
            let hourlyResponse = try decoder.decode(OpenMeteoHourlyResponse.self, from: data)
            print("🧠 Successfully parsed hourly JSON.")

            return hourlyResponse
        } catch {
            if let decodingError = error as? DecodingError {
                throw WeatherError.decodingError(decodingError)
            } else {
                throw error
            }
        }
    }

    func getMarineForecast(year: Int, month: Int, day: Int, latitude: Double, longitude: Double) async throws -> OpenMeteoMarineResponse? {
        // Construct the date string
        let dateString = String(format: "%04d-%02d-%02d", year, month, day)

        // Construct the URL with additional logging
        let urlString = "https://marine-api.open-meteo.com/v1/marine?latitude=\(latitude)&longitude=\(longitude)&hourly=wave_height,wave_direction,wave_period,swell_wave_height,swell_wave_direction,swell_wave_period,wind_wave_height,wind_wave_direction&start_date=\(dateString)&end_date=\(dateString)&timezone=auto"

        print("📡 Marine Forecast URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        do {
            // Perform the network request
            let (data, response) = try await URLSession.shared.data(from: url)

            // Check if response is valid
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WeatherError.invalidResponse
            }

            // Log response status code
            print("📡 Marine Response Status Code: \(httpResponse.statusCode)")

            // Handle server errors
            if httpResponse.statusCode >= 400 {
                throw WeatherError.serverError(statusCode: httpResponse.statusCode)
            }

            // Decode the response
            do {
                let decoder = JSONDecoder()
                let marineResponse = try decoder.decode(OpenMeteoMarineResponse.self, from: data)

                // Check if we have actual wave data
                if marineResponse.hourly.waveHeight.isEmpty {
                    print("⚠️ Marine API returned empty wave height data for location (\(latitude), \(longitude))")
                    return nil
                }

                return marineResponse
            } catch {
                // Check if response contains error message
                if let jsonError = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = jsonError["reason"] as? String {
                    print("❌ Marine API error: \(errorMessage)")
                } else {
                    print("❌ Failed to decode marine data: \(error.localizedDescription)")
                }
                throw WeatherError.decodingError(error)
            }
        } catch {
            print("❌ Marine API request failed: \(error.localizedDescription)")
            throw error
        }
    }
}
