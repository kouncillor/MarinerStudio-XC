import Foundation

protocol TidalHeightService {
    /// Fetches tidal height stations from the NOAA API
    /// - Returns: A publisher that emits a TidalHeightStationResponse or an error
    func getTidalHeightStations() async throws -> TidalHeightStationResponse
}
