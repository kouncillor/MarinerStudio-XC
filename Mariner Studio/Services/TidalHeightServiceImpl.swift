import Foundation

class TidalHeightServiceImpl: TidalHeightService {
    // MARK: - Constants
    private let baseUrl = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi"
    
    // MARK: - Properties
    private let urlSession: URLSession
    
    // MARK: - Initialization
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    // MARK: - TidalHeightService Methods
    func getTidalHeightStations() async throws -> TidalHeightStationResponse {
        guard let url = URL(string: "\(baseUrl)/stations.json?type=tidepredictions") else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(TidalHeightStationResponse.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}
