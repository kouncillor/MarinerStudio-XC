//
//  WaypointItem.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//


import Foundation
import Combine

class WaypointItem: ObservableObject, Identifiable {
    let id = UUID()
    
    @Published var index: Int = 0
    @Published var name: String = ""
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0
    @Published var eta: Date = Date()
    @Published var coordinates: String = ""
    @Published var distanceToNext: Double = 0.0
    @Published var bearingToNext: Double = 0.0
    
    // Reference to all waypoints
    var waypoints: [WaypointItem] = []
    
    // Weather properties
    @Published var weatherDataAvailable: Bool = false
    @Published var temperature: Double = 0.0
    @Published var dewPoint: Double = 0.0
    @Published var relativeHumidity: Int = 0
    @Published var windDirection: String = ""
    @Published var windSpeed: Double = 0.0
    @Published var windGusts: Double = 0.0
    @Published var weatherCondition: String = ""
    @Published var weatherIcon: String = ""
    @Published var visibility: Double = 0.0
    
    // Marine properties
    @Published var marineDataAvailable: Bool = false
    @Published var waveHeight: Double = 0.0
    @Published var waveDirection: Double = 0.0
    @Published var wavePeriod: Double = 0.0
    @Published var swellHeight: Double = 0.0
    @Published var swellDirection: Double = 0.0
    @Published var swellPeriod: Double = 0.0
    @Published var windWaveHeight: Double = 0.0
    @Published var windWaveDirection: Double = 0.0
    @Published var relativeWaveDirection: Double = 0.0
    
    // Display formatted properties
    var courseDisplay: String { return "\(String(format: "%.0f", bearingToNext))°" }
    var waveDisplay: String { return "\(String(format: "%.0f", waveDirection))°" }
    var relativeWaveDisplay: String { return "\(String(format: "%.0f", relativeWaveDirection))°" }
    var temperatureDisplay: String { return "\(String(format: "%.1f", temperature))°F" }
    var windSpeedDisplay: String { return "\(String(format: "%.1f", windSpeed)) mph" }
    var windGustsDisplay: String { return "\(String(format: "%.1f", windGusts)) mph" }
    var humidityDisplay: String { return "\(relativeHumidity)%" }
    var dewPointDisplay: String { return "\(String(format: "%.1f", dewPoint))°" }
    var waveHeightDisplay: String { return "\(String(format: "%.1f", waveHeight)) ft" }
    var swellHeightDisplay: String { return "\(String(format: "%.1f", swellHeight)) ft" }
    var windWaveHeightDisplay: String { return "\(String(format: "%.1f", windWaveHeight)) ft" }
    var visibilityDisplay: String { return VisibilityHelper.formatVisibilityWithUnits(visibility) }
    
    var waveDirectionCardinal: String { return getCardinalDirection(waveDirection) }
    var swellDirectionCardinal: String { return getCardinalDirection(swellDirection) }
    var windWaveDirectionCardinal: String { return getCardinalDirection(windWaveDirection) }
    
    // Display image properties for wave direction
    @Published var displayImageOne: Bool = false
    @Published var displayImageTwo: Bool = false
    @Published var displayImageThree: Bool = false
    @Published var displayImageFour: Bool = false
    @Published var displayImageFive: Bool = false
    @Published var displayImageSix: Bool = false
    @Published var displayImageSeven: Bool = false
    @Published var displayImageEight: Bool = false
    @Published var displayImageNine: Bool = false
    @Published var displayImageTen: Bool = false
    @Published var displayImageEleven: Bool = false
    @Published var displayImageTwelve: Bool = false
    @Published var displayImageThirteen: Bool = false
    @Published var displayImageFourteen: Bool = false
    @Published var displayImageFifteen: Bool = false
    @Published var displayImageSixteen: Bool = false
    
    // MARK: - Methods
    
    func calculateRelativeWaveDirection() {
        if !marineDataAvailable { return }
        
        // Get the course to use for relative calculations
        var courseToUse: Double
        
        // If this is the last waypoint, use the bearing from the previous point
        if index == waypoints.count {
            // For the last waypoint, use the bearing TO this point instead of from it
            if waypoints.count >= 2 {
                let previousWaypoint = waypoints[index - 2] // Index is 1-based
                courseToUse = previousWaypoint.bearingToNext
            } else {
                courseToUse = 0.0
            }
        } else {
            courseToUse = bearingToNext
        }
        
        // Calculate relative wave direction
        relativeWaveDirection = normalizeAngle(waveDirection - courseToUse)
        
        // Update the wave direction arrow display
        updateRelativeWaveArrowImage()
    }
    
    func updateRelativeWaveArrowImage() {
        // Reset all flags
        displayImageOne = false
        displayImageTwo = false
        displayImageThree = false
        displayImageFour = false
        displayImageFive = false
        displayImageSix = false
        displayImageSeven = false
        displayImageEight = false
        displayImageNine = false
        displayImageTen = false
        displayImageEleven = false
        displayImageTwelve = false
        displayImageThirteen = false
        displayImageFourteen = false
        displayImageFifteen = false
        displayImageSixteen = false
        
        // First ensure angle is in 0-360 range
        let normalizedDirection = ((relativeWaveDirection.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        
        // Round to nearest 22.5 degrees since we have 16 possible directions (360/16 = 22.5)
        let sector = Int(round(normalizedDirection / 22.5))
        
        // Set only the appropriate flag
        switch sector {
        case 0, 16:
            displayImageOne = true
        case 1:
            displayImageTwo = true
        case 2:
            displayImageThree = true
        case 3:
            displayImageFour = true
        case 4:
            displayImageFive = true
        case 5:
            displayImageSix = true
        case 6:
            displayImageSeven = true
        case 7:
            displayImageEight = true
        case 8:
            displayImageNine = true
        case 9:
            displayImageTen = true
        case 10:
            displayImageEleven = true
        case 11:
            displayImageTwelve = true
        case 12:
            displayImageThirteen = true
        case 13:
            displayImageFourteen = true
        case 14:
            displayImageFifteen = true
        case 15:
            displayImageSixteen = true
        default:
            displayImageOne = true
        }
    }
    
    private func normalizeAngle(_ angle: Double) -> Double {
        var normalizedAngle = angle.truncatingRemainder(dividingBy: 360)
        if normalizedAngle < 0 {
            normalizedAngle += 360
        }
        return normalizedAngle
    }
    
    private func getCardinalDirection(_ degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int(((degrees + 11.25) / 22.5).truncatingRemainder(dividingBy: 16))
        return directions[index]
    }
    
    func setWindDirectionFromDegrees(_ degrees: Double) {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int(((degrees + 11.25) / 22.5).truncatingRemainder(dividingBy: 16))
        windDirection = directions[index]
    }
}