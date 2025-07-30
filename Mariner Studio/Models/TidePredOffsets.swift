import Foundation

struct TidePredOffsets: Codable {
    let selfUrl: String

    enum CodingKeys: String, CodingKey {
        case selfUrl = "self"
    }
}
