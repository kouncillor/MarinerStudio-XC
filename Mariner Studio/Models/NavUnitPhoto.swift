
import Foundation

// Model for NavUnitPhoto (converted from C#)
struct NavUnitPhoto: Identifiable {
    let id: Int
    let navUnitId: String
    let filePath: String
    let fileName: String
    let thumbPath: String?
    let description: String?
    let createdAt: Date
    let cloudRecordID: String? // NEW: CloudKit record ID for iCloud deletion
    
    // Initializer with default values
    init(
        id: Int = 0,
        navUnitId: String,
        filePath: String,
        fileName: String,
        thumbPath: String? = nil,
        description: String? = nil,
        createdAt: Date = Date(),
        cloudRecordID: String? = nil
    ) {
        self.id = id
        self.navUnitId = navUnitId
        self.filePath = filePath
        self.fileName = fileName
        self.thumbPath = thumbPath
        self.description = description
        self.createdAt = createdAt
        self.cloudRecordID = cloudRecordID
    }
    
    // Convenience method to check if photo is synced to iCloud
    var isSyncedToiCloud: Bool {
        return cloudRecordID != nil && !cloudRecordID!.isEmpty
    }
    
    // Convenience method to create a copy with updated CloudKit record ID
    func withCloudRecordID(_ recordID: String?) -> NavUnitPhoto {
        return NavUnitPhoto(
            id: self.id,
            navUnitId: self.navUnitId,
            filePath: self.filePath,
            fileName: self.fileName,
            thumbPath: self.thumbPath,
            description: self.description,
            createdAt: self.createdAt,
            cloudRecordID: recordID
        )
    }
}
