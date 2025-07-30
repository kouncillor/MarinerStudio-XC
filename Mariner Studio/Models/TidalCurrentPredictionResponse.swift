// TidalCurrentPredictionResponse.swift

import Foundation

struct TidalCurrentPredictionResponse: Codable {
    let units: String
    let predictions: [TidalCurrentPrediction]

    enum CodingKeys: String, CodingKey {
        case units
        case predictions = "cp"
    }
}
