// TidalCurrentService.swift

import Foundation

protocol TidalCurrentService {
    /// Fetches tidal current stations from the NOAA API
    /// - Returns: A TidalCurrentStationResponse or throws an error
    func getTidalCurrentStations() async throws -> TidalCurrentStationResponse
}
