import Foundation

// MARK: - Error Handling
struct ApiError: Error, LocalizedError {
    let message: String
    
    var errorDescription: String? {
        return message
    }
}

// MARK: - Protocol
protocol TidalHeightPredictionService {
    func getPredictions(stationId: String, date: Date) async throws -> TidalHeightPredictionResponse
}

// MARK: - Implementation
class TidalHeightPredictionServiceImpl: TidalHeightPredictionService {
    // MARK: - Constants
    private let baseUrl = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
    
    // MARK: - Properties
    private let urlSession: URLSession
    
    // MARK: - Initialization
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    // MARK: - Methods
    func getPredictions(stationId: String, date: Date) async throws -> TidalHeightPredictionResponse {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: date)
        
        // Build URL exactly as in MAUI version
        let urlString = "\(baseUrl)?station=\(stationId)" +
                      "&begin_date=\(dateString)" +
                      "&end_date=\(dateString)" +
                      "&product=predictions" +
                      "&datum=MLLW" +
                      "&time_zone=lst_ldt" +
                      "&units=english" +
                      "&interval=hilo" +
                      "&format=json"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw URLError(.badURL)
        }
        
        print("🌊 Fetching predictions from: \(url.absoluteString)")
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌊 Response status code: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    print("❌ Server error: \(httpResponse.statusCode)")
                    throw URLError(.badServerResponse)
                }
            }
            
            // Debug: Print response data
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🌊 Response data: \(jsonString.prefix(200))...")
                
                // Check for error response which would be in a different format
                if jsonString.contains("\"error\"") {
                    if let errorMessage = extractErrorMessage(from: jsonString) {
                        print("❌ API error: \(errorMessage)")
                        throw ApiError(message: errorMessage)
                    }
                }
            }
            
            // Decode JSON response
            let decoder = JSONDecoder()
            do {
                let response = try decoder.decode(TidalHeightPredictionResponse.self, from: data)
                print("🌊 Successfully decoded \(response.predictions.count) predictions")
                return response
            } catch {
                print("❌ JSON decoding error: \(error)")
                throw error
            }
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Helper method to extract error message from JSON string
    private func extractErrorMessage(from jsonString: String) -> String? {
        // Simple parsing to extract error message
        if let range = jsonString.range(of: "\"message\":\""),
           let endRange = jsonString[range.upperBound...].range(of: "\"") {
            return String(jsonString[range.upperBound..<endRange.lowerBound])
        }
        return nil
    }
}
