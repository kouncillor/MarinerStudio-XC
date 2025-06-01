//import Foundation
//
//// Model for NavUnitPhoto (converted from C#)
//struct NavUnitPhoto: Identifiable {
//    let id: Int
//    let navUnitId: String
//    let filePath: String
//    let fileName: String
//    let thumbPath: String?
//    let description: String?
//    let createdAt: Date
//    
//    // Initializer with default values
//    init(
//        id: Int = 0,
//        navUnitId: String,
//        filePath: String,
//        fileName: String,
//        thumbPath: String? = nil,
//        description: String? = nil,
//        createdAt: Date = Date()
//    ) {
//        self.id = id
//        self.navUnitId = navUnitId
//        self.filePath = filePath
//        self.fileName = fileName
//        self.thumbPath = thumbPath
//        self.description = description
//        self.createdAt = createdAt
//    }
//}


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
    let cloudKitRecordID: String? // NEW: Track CloudKit record ID
    
    // Initializer with default values
    init(
        id: Int = 0,
        navUnitId: String,
        filePath: String,
        fileName: String,
        thumbPath: String? = nil,
        description: String? = nil,
        createdAt: Date = Date(),
        cloudKitRecordID: String? = nil // NEW: CloudKit record ID
    ) {
        self.id = id
        self.navUnitId = navUnitId
        self.filePath = filePath
        self.fileName = fileName
        self.thumbPath = thumbPath
        self.description = description
        self.createdAt = createdAt
        self.cloudKitRecordID = cloudKitRecordID // NEW
    }
}
