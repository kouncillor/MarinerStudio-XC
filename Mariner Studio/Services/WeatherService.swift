import Foundation

/// Protocol defining the weather service interface
protocol WeatherService {
    /// Fetches weather data for a specific location
    /// - Parameters:
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: Weather data response
    ///
    func getWeather(latitude: Double, longitude: Double) async throws -> OpenMeteoResponse

    /// Fetches hourly forecast data for a specific date and location
    /// - Parameters:
    ///   - year: Year component of the date
    ///   - month: Month component of the date
    ///   - day: Day component of the date
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: Hourly forecast data response
    func getHourlyForecast(year: Int, month: Int, day: Int, latitude: Double, longitude: Double) async throws -> OpenMeteoHourlyResponse

    /// Fetches marine forecast data for a specific date and location
    /// - Parameters:
    ///   - year: Year component of the date
    ///   - month: Month component of the date
    ///   - day: Day component of the date
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: Marine forecast data response, or nil if the location is not a marine location
    func getMarineForecast(year: Int, month: Int, day: Int, latitude: Double, longitude: Double) async throws -> OpenMeteoMarineResponse?

}
