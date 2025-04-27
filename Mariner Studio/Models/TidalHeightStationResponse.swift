import Foundation

struct TidalHeightStationResponse: Codable {
    let count: Int
    let units: String?
    let stations: [TidalHeightStation]
}
