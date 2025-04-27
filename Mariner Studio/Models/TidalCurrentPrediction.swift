// TidalCurrentPrediction.swift

import Foundation

struct TidalCurrentPrediction: Codable, Identifiable {
    // MARK: - Properties
    let regularSpeed: Double?
    let velocityMajor: Double?
    let bin: Int
    let timeString: String
    let direction: Double
    let meanFloodDirection: Double
    let meanEbbDirection: Double
    let depth: Double
    let type: String?
    
    // MARK: - Computed Properties
    var id: String {
        return timeString // Using timeString as a unique identifier
    }
    
    var speed: Double {
        return velocityMajor ?? regularSpeed ?? 0.0
    }
    
    var timestamp: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: timeString) ?? Date()
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
    
    var formattedVelocity: String {
        return String(format: "%.2f", abs(speed))
    }
    
    var flowDirection: String {
        return speed >= 0 ? "Flood" : "Ebb"
    }
    
    var directionDisplay: String {
        if direction != 0 {
            return String(format: "%.0f°", direction)
        }
        let direction = speed >= 0 ? meanFloodDirection : meanEbbDirection
        return String(format: "%.0f°", direction)
    }
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case regularSpeed = "Speed"
        case velocityMajor = "Velocity_Major"
        case bin = "Bin"
        case timeString = "Time"
        case direction = "Direction"
        case meanFloodDirection = "meanFloodDir"
        case meanEbbDirection = "meanEbbDir"
        case depth = "Depth"
        case type = "Type"
    }
}
