import Foundation

// MARK: - Model Classes for Database Entities

struct TideStationFavorite {
    let stationId: String
    let isFavorite: Bool
}

struct TidalCurrentStationFavorite {
    let stationId: String
    let currentBin: Int
    let isFavorite: Bool
}

struct Tug: Identifiable {
    let id = UUID()
    let tugId: String
    let vesselName: String
}

struct Barge: Identifiable {
    let id = UUID()
    let bargeId: String
    let vesselName: String
}

struct PersonalNote: Identifiable {
    let id: Int
    let navUnitId: String
    let noteText: String
    let createdAt: Date
    var modifiedAt: Date?
    
    init(id: Int = 0, navUnitId: String, noteText: String, createdAt: Date = Date(), modifiedAt: Date? = nil) {
        self.id = id
        self.navUnitId = navUnitId
        self.noteText = noteText
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

enum RecommendationStatus: Int {
    case pending = 0
    case approved = 1
    case rejected = 2
}

struct ChangeRecommendation: Identifiable {
    let id: Int
    let navUnitId: String
    let recommendationText: String
    let createdAt: Date
    var status: RecommendationStatus
    
    init(id: Int = 0, navUnitId: String, recommendationText: String, createdAt: Date = Date(), status: RecommendationStatus = .pending) {
        self.id = id
        self.navUnitId = navUnitId
        self.recommendationText = recommendationText
        self.createdAt = createdAt
        self.status = status
    }
}

struct NavUnitPhoto: Identifiable {
    let id: Int
    let navUnitId: String
    let filePath: String
    let fileName: String
    let thumbPath: String?
    let createdAt: Date
    
    init(id: Int = 0, navUnitId: String, filePath: String, fileName: String, thumbPath: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.navUnitId = navUnitId
        self.filePath = filePath
        self.fileName = fileName
        self.thumbPath = thumbPath
        self.createdAt = createdAt
    }
}

struct TugPhoto: Identifiable {
    let id: Int
    let tugId: String
    let filePath: String
    let fileName: String
    let thumbPath: String?
    let createdAt: Date
    
    init(id: Int = 0, tugId: String, filePath: String, fileName: String, thumbPath: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.tugId = tugId
        self.filePath = filePath
        self.fileName = fileName
        self.thumbPath = thumbPath
        self.createdAt = createdAt
    }
}

struct TugNote: Identifiable {
    let id: Int
    let tugId: String
    let noteText: String
    let createdAt: Date
    var modifiedAt: Date?
    
    init(id: Int = 0, tugId: String, noteText: String, createdAt: Date = Date(), modifiedAt: Date? = nil) {
        self.id = id
        self.tugId = tugId
        self.noteText = noteText
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

struct TugChangeRecommendation: Identifiable {
    let id: Int
    let tugId: String
    let recommendationText: String
    let createdAt: Date
    var status: RecommendationStatus
    
    init(id: Int = 0, tugId: String, recommendationText: String, createdAt: Date = Date(), status: RecommendationStatus = .pending) {
        self.id = id
        self.tugId = tugId
        self.recommendationText = recommendationText
        self.createdAt = createdAt
        self.status = status
    }
}

struct BargePhoto: Identifiable {
    let id: Int
    let bargeId: String
    let filePath: String
    let fileName: String
    let thumbPath: String?
    let createdAt: Date
    
    init(id: Int = 0, bargeId: String, filePath: String, fileName: String, thumbPath: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.bargeId = bargeId
        self.filePath = filePath
        self.fileName = fileName
        self.thumbPath = thumbPath
        self.createdAt = createdAt
    }
}

struct BuoyStationFavorite {
    let stationId: String
    let isFavorite: Bool
}

struct MoonPhase {
    let date: String
    let phase: String
}

struct WeatherLocationFavorite: Identifiable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let locationName: String
    let isFavorite: Bool
    let createdAt: Date
}
