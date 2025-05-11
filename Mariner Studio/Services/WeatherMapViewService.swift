//
//  WeatherMapViewService.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/11/25.
//


import Foundation

protocol WeatherMapViewService {
    /// Fetches weather map data for a specific region
    /// - Parameters:
    ///   - latitude: Central latitude coordinate
    ///   - longitude: Central longitude coordinate
    ///   - radius: Radius in kilometers to include
    /// - Returns: Weather map data (to be defined later)
    func getWeatherMapData(latitude: Double, longitude: Double, radius: Double) async throws -> Data
}