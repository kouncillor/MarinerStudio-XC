import Foundation
import Combine

// MARK: - Database Service Protocol
protocol DatabaseService {
    /// Check if a tide station is marked as favorite
    func isTideStationFavorite(id: String) async -> Bool
    
    /// Toggle favorite status for a tide station
    func toggleTideStationFavorite(id: String) async -> Bool
    
    /// Check if a current station is marked as favorite
    func isCurrentStationFavorite(id: String, bin: Int) async -> Bool
    
    /// Toggle favorite status for a current station
    func toggleCurrentStationFavorite(id: String, bin: Int) async -> Bool
}

// MARK: - Mock Implementation
class MockDatabaseService: ObservableObject, DatabaseService {
    // In-memory storage for favorites
    private var tideStationFavorites: [String: Bool] = [:]
    private var currentStationFavorites: [String: Bool] = [:]
    
    func isTideStationFavorite(id: String) async -> Bool {
        return tideStationFavorites[id] ?? false
    }
    
    func toggleTideStationFavorite(id: String) async -> Bool {
        let newValue = !(tideStationFavorites[id] ?? false)
        tideStationFavorites[id] = newValue
        return newValue
    }
    
    func isCurrentStationFavorite(id: String, bin: Int = 0) async -> Bool {
        let key = "\(id)_\(bin)"
        return currentStationFavorites[key] ?? false
    }
    
    func toggleCurrentStationFavorite(id: String, bin: Int = 0) async -> Bool {
        let key = "\(id)_\(bin)"
        let newValue = !(currentStationFavorites[key] ?? false)
        currentStationFavorites[key] = newValue
        return newValue
    }
}
