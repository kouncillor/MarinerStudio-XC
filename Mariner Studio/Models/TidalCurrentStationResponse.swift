// TidalCurrentStationResponse.swift

import Foundation

struct TidalCurrentStationResponse: Codable {
    let count: Int
    let units: String?
    let stations: [TidalCurrentStation]
}
