import Foundation

// MARK: - Response Models
struct TidalHeightPredictionResponse: Codable {
    let predictions: [TidalHeightPrediction]
    
    // Custom coding keys to match NOAA API
    enum CodingKeys: String, CodingKey {
        case predictions
    }
}

// MARK: - Error Response Model
struct NOAAErrorResponse: Codable {
    let error: NOAAError
}

struct NOAAError: Codable {
    let message: String
}

// MARK: - Prediction Model
struct TidalHeightPrediction: Identifiable, Codable {
    // MARK: - Properties
    let timeString: String
    let heightString: String
    let type: String
    
    // MARK: - Computed Properties
    var id: String {
        return timeString // Time string is unique for a given day
    }
    
    var timestamp: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: timeString) ?? Date()
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: timestamp)
    }
    
    var height: Double {
        return Double(heightString) ?? 0.0
    }
    
    var formattedHeight: String {
        return String(format: "%.2f", height)
    }
    
    var tideType: String {
        return type == "H" ? "High" : "Low"
    }
    
    // MARK: - Coding Keys to match NOAA API
    enum CodingKeys: String, CodingKey {
        case timeString = "t"
        case heightString = "v"
        case type
    }
}
