import Foundation

// Protocol for any station type that has coordinates
protocol StationCoordinates {
    var latitude: Double { get }
    var longitude: Double { get }
}

// Make TidalHeightStation conform to StationCoordinates
extension TidalHeightStation: StationCoordinates {}
