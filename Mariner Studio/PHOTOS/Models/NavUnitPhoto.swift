//
//  NavUnitPhoto.swift
//  Mariner Studio
//
//  Photo model for nav unit photos with local caching and Supabase sync
//

import Foundation

struct NavUnitPhoto: Identifiable, Codable {
    let id: UUID
    let navUnitId: String
    let localFileName: String
    let supabaseUrl: String?
    let timestamp: Date
    let isUploaded: Bool
    let isSyncedFromCloud: Bool
    var userId: String?
    
    // MARK: - Computed Properties
    
    /// Local file URL in Documents directory
    var localURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("NavUnitPhotos").appendingPathComponent(localFileName)
    }
    
    /// Thumbnail URL in cache directory
    var thumbnailURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let thumbnailFileName = "thumb_" + localFileName
        return documentsPath.appendingPathComponent("NavUnitPhotos/thumbnails").appendingPathComponent(thumbnailFileName)
    }
    
    /// Display name for the photo
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Check if photo exists locally
    var existsLocally: Bool {
        return FileManager.default.fileExists(atPath: localURL.path)
    }
    
    /// Check if thumbnail exists locally
    var thumbnailExists: Bool {
        return FileManager.default.fileExists(atPath: thumbnailURL.path)
    }
    
    // MARK: - Initializers
    
    init(
        id: UUID = UUID(),
        navUnitId: String,
        localFileName: String,
        supabaseUrl: String? = nil,
        timestamp: Date = Date(),
        isUploaded: Bool = false,
        isSyncedFromCloud: Bool = false,
        userId: String? = nil
    ) {
        self.id = id
        self.navUnitId = navUnitId
        self.localFileName = localFileName
        self.supabaseUrl = supabaseUrl
        self.timestamp = timestamp
        self.isUploaded = isUploaded
        self.isSyncedFromCloud = isSyncedFromCloud
        self.userId = userId
    }
    
    // MARK: - Database Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case navUnitId = "nav_unit_id"
        case localFileName = "local_file_name"
        case supabaseUrl = "supabase_url"
        case timestamp
        case isUploaded = "is_uploaded"
        case isSyncedFromCloud = "is_synced_from_cloud"
        case userId = "user_id"
    }
}

// MARK: - Helper Extensions

extension NavUnitPhoto {
    /// Generate a unique filename for a new photo
    static func generateFileName(for navUnitId: String) -> String {
        let timestamp = Date().timeIntervalSince1970
        let randomSuffix = UUID().uuidString.prefix(8)
        return "navunit_\(navUnitId)_\(Int(timestamp))_\(randomSuffix).jpg"
    }
}

// MARK: - Hashable Conformance

extension NavUnitPhoto: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: NavUnitPhoto, rhs: NavUnitPhoto) -> Bool {
        return lhs.id == rhs.id
    }
}