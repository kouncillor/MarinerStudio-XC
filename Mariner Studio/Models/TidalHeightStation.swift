import Foundation

struct TidalHeightStation: Identifiable, Codable {
    // MARK: - Properties
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let state: String?
    let type: String
    let referenceId: String
    let timezoneCorrection: Int?
    let timeMeridian: Int?
    let tidePredOffsets: TidePredOffsets?
    var isFavorite: Bool = false  // This is already marked as 'var' which is good
    var distanceFromUser: Double?  // Distance in miles, calculated at runtime
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case latitude = "lat"
        case longitude = "lng"
        case state
        case type
        case referenceId = "reference_id"
        case timezoneCorrection = "timezonecorr"
        case timeMeridian = "timemeridian"
        case tidePredOffsets = "tidepredoffsets"
        // isFavorite is not included as it will be set locally, not decoded from API
    }
}
