// TidalCurrentPredictionService.swift

import Foundation

enum TidalCurrentStationType {
    case unknown
    case maxSlackMin
}

protocol TidalCurrentPredictionService {
    /// Gets predictions for a tidal current station
    /// - Parameters:
    ///   - stationId: The ID of the station
    ///   - bin: The bin number
    ///   - date: The date for which to get predictions
    /// - Returns: A TidalCurrentPredictionResponse or throws an error
    func getPredictions(stationId: String, bin: Int, date: Date) async throws -> TidalCurrentPredictionResponse

    /// Gets extremes for a tidal current station
    /// - Parameters:
    ///   - stationId: The ID of the station
    ///   - bin: The bin number
    ///   - date: The date for which to get extremes
    /// - Returns: A TidalCurrentPredictionResponse or throws an error
    func getExtremes(stationId: String, bin: Int, date: Date) async throws -> TidalCurrentPredictionResponse

    /// Gets the type of a tidal current station
    /// - Parameters:
    ///   - stationId: The ID of the station
    ///   - bin: The bin number
    /// - Returns: The station type
    func getStationType(stationId: String, bin: Int) async throws -> TidalCurrentStationType
}
