////
////import Foundation
////#if canImport(SQLite)
////import SQLite
////#endif
////
////class PhotoDatabaseService {
////    // MARK: - Table Definitions
////    private let navUnitPhotos = Table("NavUnitPhoto")
////    private let bargePhotos = Table("BargePhoto")
////    
////    // MARK: - Column Definitions - Common
////    private let colId = Expression<Int>("Id")
////    private let colCreatedAt = Expression<Date>("CreatedAt")
////    
////    // MARK: - Column Definitions - NavUnitPhoto
////    private let colNavUnitId = Expression<String>("NavUnitId")
////    private let colFilePath = Expression<String>("FilePath")
////    private let colFileName = Expression<String>("FileName")
////    private let colThumbPath = Expression<String?>("ThumbPath")
////    
////    // MARK: - Column Definitions - BargePhoto
////    private let colVesselId = Expression<String>("VesselId")
////    
////    // MARK: - Properties
////    private let databaseCore: DatabaseCore
////    
////    // MARK: - Initialization
////    init(databaseCore: DatabaseCore) {
////        self.databaseCore = databaseCore
////    }
////    
////    // MARK: - Nav Unit Photos
////    
////    // Initialize photos table
////    func initializePhotosTableAsync() async throws {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////            try db.run(navUnitPhotos.create(ifNotExists: true) { table in
////                table.column(colId, primaryKey: .autoincrement)
////                table.column(colNavUnitId)
////                table.column(colFilePath)
////                table.column(colFileName)
////                table.column(colThumbPath)
////                table.column(colCreatedAt)
////            })
////        } catch {
////            print("Error initializing photos table: \(error.localizedDescription)")
////            throw error
////        }
////    }
////    
////    // Get photos for a navigation unit
////    func getNavUnitPhotosAsync(navUnitId: String) async throws -> [NavUnitPhoto] {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////            let query = navUnitPhotos.filter(colNavUnitId == navUnitId).order(colCreatedAt.desc)
////            var results: [NavUnitPhoto] = []
////            
////            for row in try db.prepare(query) {
////                let photo = NavUnitPhoto(
////                    id: row[colId],
////                    navUnitId: row[colNavUnitId],
////                    filePath: row[colFilePath],
////                    fileName: row[colFileName],
////                    thumbPath: row[colThumbPath],
////                    createdAt: row[colCreatedAt]
////                )
////                results.append(photo)
////            }
////            
////            return results
////        } catch {
////            print("Error fetching nav unit photos: \(error.localizedDescription)")
////            throw error
////        }
////    }
////    
////    // Get all nav unit photos from the database (for bulk sync operations)
////    func getAllNavUnitPhotosAsync() async throws -> [NavUnitPhoto] {
////        print("📊 PhotoDatabaseService: Getting all nav unit photos...")
////        
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////            let query = navUnitPhotos.order(colCreatedAt.desc)
////            var results: [NavUnitPhoto] = []
////            
////            for row in try db.prepare(query) {
////                let photo = NavUnitPhoto(
////                    id: row[colId],
////                    navUnitId: row[colNavUnitId],
////                    filePath: row[colFilePath],
////                    fileName: row[colFileName],
////                    thumbPath: row[colThumbPath],
////                    createdAt: row[colCreatedAt]
////                )
////                results.append(photo)
////            }
////            
////            print("✅ PhotoDatabaseService: Retrieved \(results.count) total photos")
////            return results
////        } catch {
////            print("❌ PhotoDatabaseService: Error getting all photos: \(error.localizedDescription)")
////            throw error
////        }
////    }
////    
////    // Add a new photo for a navigation unit
////    func addNavUnitPhotoAsync(photo: NavUnitPhoto) async throws -> Int {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////            let insert = navUnitPhotos.insert(
////                colNavUnitId <- photo.navUnitId,
////                colFilePath <- photo.filePath,
////                colFileName <- photo.fileName,
////                colThumbPath <- photo.thumbPath,
////                colCreatedAt <- photo.createdAt
////            )
////            
////            let rowId = try db.run(insert)
////            try await databaseCore.flushDatabaseAsync()
////            return Int(rowId)
////        } catch {
////            print("Error adding nav unit photo: \(error.localizedDescription)")
////            throw error
////        }
////    }
////    
////    // Delete a photo
////    func deleteNavUnitPhotoAsync(photoId: Int) async throws -> Int {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////            // First get the photo to delete the file
////            let photoQuery = navUnitPhotos.filter(colId == photoId)
////            
////            if let photo = try db.pluck(photoQuery) {
////                let filePath = photo[colFilePath]
////                
////                // Delete the file if it exists
////                if FileManager.default.fileExists(atPath: filePath) {
////                    try FileManager.default.removeItem(atPath: filePath)
////                }
////                
////                // Delete the database record
////                try db.run(photoQuery.delete())
////            }
////            
////            try await databaseCore.flushDatabaseAsync()
////            return 1
////        } catch {
////            print("Error deleting nav unit photo: \(error.localizedDescription)")
////            throw error
////        }
////    }
////    
////    // MARK: - Barge Photos
////    
////    // Initialize barge photos table
////    func initializeBargePhotosTableAsync() async throws {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////            try db.run(bargePhotos.create(ifNotExists: true) { table in
////                table.column(colId, primaryKey: .autoincrement)
////                table.column(colVesselId)
////                table.column(colFilePath)
////                table.column(colFileName)
////                table.column(colThumbPath)
////                table.column(colCreatedAt)
////            })
////        } catch {
////            print("Error initializing barge photos table: \(error.localizedDescription)")
////            throw error
////        }
////    }
////    
////    // Get photos for a barge
////    func getBargePhotosAsync(bargeId: String) async throws -> [BargePhoto] {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////            let query = bargePhotos.filter(colVesselId == bargeId).order(colCreatedAt.desc)
////            var results: [BargePhoto] = []
////            
////            for row in try db.prepare(query) {
////                let photo = BargePhoto(
////                    id: row[colId],
////                    bargeId: row[colVesselId],
////                    filePath: row[colFilePath],
////                    fileName: row[colFileName],
////                    thumbPath: row[colThumbPath],
////                    createdAt: row[colCreatedAt]
////                )
////                results.append(photo)
////            }
////            
////            return results
////        } catch {
////            print("Error fetching barge photos: \(error.localizedDescription)")
////            throw error
////        }
////    }
////    
////    // Add a new photo for a barge
////    func addBargePhotoAsync(photo: BargePhoto) async throws -> Int {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////            let insert = bargePhotos.insert(
////                colVesselId <- photo.bargeId,
////                colFilePath <- photo.filePath,
////                colFileName <- photo.fileName,
////                colThumbPath <- photo.thumbPath,
////                colCreatedAt <- photo.createdAt
////            )
////            
////            let rowId = try db.run(insert)
////            try await databaseCore.flushDatabaseAsync()
////            return Int(rowId)
////        } catch {
////            print("Error adding barge photo: \(error.localizedDescription)")
////            throw error
////        }
////    }
////    
////    // Delete a barge photo
////    func deleteBargePhotoAsync(photoId: Int) async throws -> Int {
////        do {
////            let db = try databaseCore.ensureConnection()
////            
////            // First get the photo to delete the file
////            let photoQuery = bargePhotos.filter(colId == photoId)
////            
////            if let photo = try db.pluck(photoQuery) {
////                let filePath = photo[colFilePath]
////                
////                // Delete the file if it exists
////                if FileManager.default.fileExists(atPath: filePath) {
////                    try FileManager.default.removeItem(atPath: filePath)
////                }
////                
////                // Delete the database record
////                try db.run(photoQuery.delete())
////            }
////            
////            try await databaseCore.flushDatabaseAsync()
////            return 1
////        } catch {
////            print("Error deleting barge photo: \(error.localizedDescription)")
////            throw error
////        }
////    }
////}
//
//
//
//
//
//
//import Foundation
//import SQLite
//
//class PhotoDatabaseService {
//    private let databaseCore: DatabaseCore
//    
//    // Table and column definitions
//    private let navUnitPhotosTable = Table("nav_unit_photos")
//    private let id = Expression<Int>("id")
//    private let navUnitId = Expression<String>("nav_unit_id")
//    private let filePath = Expression<String>("file_path")
//    private let fileName = Expression<String>("file_name")
//    private let thumbPath = Expression<String?>("thumb_path")
//    private let description = Expression<String?>("description")
//    private let createdAt = Expression<Date>("created_at")
//    
//    init(databaseCore: DatabaseCore) {
//        self.databaseCore = databaseCore
//    }
//    
//    // MARK: - Table Initialization
//    func initializePhotosTableAsync() async throws {
//        let db = try await databaseCore.getDatabaseConnection()
//        
//        try db.run(navUnitPhotosTable.create(ifNotExists: true) { t in
//            t.column(id, primaryKey: .autoincrement)
//            t.column(navUnitId)
//            t.column(filePath)
//            t.column(fileName)
//            t.column(thumbPath)
//            t.column(description)
//            t.column(createdAt)
//            
//            // Add unique constraint to prevent duplicates
//            // Combination of navUnitId + fileName + createdAt should be unique
//            t.unique([navUnitId, fileName, createdAt])
//        })
//        
//        print("📊 PhotoDatabaseService: nav_unit_photos table initialized with unique constraints")
//        
//        // Create index for better performance on queries
//        try db.run("CREATE INDEX IF NOT EXISTS idx_nav_unit_photos_nav_unit_id ON nav_unit_photos(nav_unit_id)")
//        try db.run("CREATE INDEX IF NOT EXISTS idx_nav_unit_photos_created_at ON nav_unit_photos(created_at)")
//        
//        print("📊 PhotoDatabaseService: Indexes created for nav_unit_photos table")
//    }
//    
//    // MARK: - CRUD Operations with Duplicate Prevention
//    
//    func addNavUnitPhotoAsync(photo: NavUnitPhoto) async throws -> Int {
//        print("📸 PhotoDatabaseService: Adding photo - NavUnit: \(photo.navUnitId), File: \(photo.fileName)")
//        
//        // First check if photo already exists to prevent duplicates
//        if let existingPhoto = try await findExistingPhoto(photo) {
//            print("⚠️ PhotoDatabaseService: Photo already exists with ID: \(existingPhoto.id), skipping insert")
//            return existingPhoto.id
//        }
//        
//        let db = try await databaseCore.getDatabaseConnection()
//        
//        do {
//            let insert = navUnitPhotosTable.insert(
//                navUnitId <- photo.navUnitId,
//                filePath <- photo.filePath,
//                fileName <- photo.fileName,
//                thumbPath <- photo.thumbPath,
//                description <- photo.description,
//                createdAt <- photo.createdAt
//            )
//            
//            let rowId = try db.run(insert)
//            print("✅ PhotoDatabaseService: Successfully added photo with ID: \(rowId)")
//            return Int(rowId)
//            
//        } catch let error as SQLite.Result where error == .constraint {
//            // Handle unique constraint violation
//            print("🚫 PhotoDatabaseService: Duplicate photo detected by database constraint")
//            
//            // Try to find the existing photo and return its ID
//            if let existingPhoto = try await findExistingPhoto(photo) {
//                print("✅ PhotoDatabaseService: Found existing duplicate with ID: \(existingPhoto.id)")
//                return existingPhoto.id
//            } else {
//                throw PhotoDatabaseError.duplicatePhoto
//            }
//        } catch {
//            print("❌ PhotoDatabaseService: Error adding photo: \(error.localizedDescription)")
//            throw PhotoDatabaseError.insertFailed(error)
//        }
//    }
//    
//    // Helper method to find existing photos with multiple matching criteria
//    private func findExistingPhoto(_ photo: NavUnitPhoto) async throws -> NavUnitPhoto? {
//        let db = try await databaseCore.getDatabaseConnection()
//        
//        // First try exact match (navUnitId + fileName + createdAt within 1 minute)
//        let exactQuery = navUnitPhotosTable.filter(
//            navUnitId == photo.navUnitId &&
//            fileName == photo.fileName
//        )
//        
//        for row in try db.prepare(exactQuery) {
//            let existingCreatedAt = row[createdAt]
//            let timeDifference = abs(existingCreatedAt.timeIntervalSince(photo.createdAt))
//            
//            // Consider it a duplicate if created within 1 minute
//            if timeDifference < 60 {
//                print("🔍 PhotoDatabaseService: Found existing photo by exact match (time diff: \(timeDifference)s)")
//                return mapRowToNavUnitPhoto(row)
//            }
//        }
//        
//        // If no exact match, try file path match (for photos downloaded from iCloud)
//        let pathQuery = navUnitPhotosTable.filter(
//            navUnitId == photo.navUnitId &&
//            filePath == photo.filePath
//        )
//        
//        for row in try db.prepare(pathQuery) {
//            print("🔍 PhotoDatabaseService: Found existing photo by file path match")
//            return mapRowToNavUnitPhoto(row)
//        }
//        
//        return nil
//    }
//    
//    func getNavUnitPhotosAsync(navUnitId: String) async throws -> [NavUnitPhoto] {
//        print("📸 PhotoDatabaseService: Getting photos for navUnitId: \(navUnitId)")
//        
//        let db = try await databaseCore.getDatabaseConnection()
//        let query = navUnitPhotosTable
//            .filter(self.navUnitId == navUnitId)
//            .order(createdAt.desc)
//        
//        var photos: [NavUnitPhoto] = []
//        
//        for row in try db.prepare(query) {
//            let photo = mapRowToNavUnitPhoto(row)
//            photos.append(photo)
//        }
//        
//        print("📸 PhotoDatabaseService: Found \(photos.count) photos for navUnitId: \(navUnitId)")
//        
//        // Log photo details for debugging
//        for photo in photos {
//            print("  📷 Photo ID: \(photo.id), File: \(photo.fileName), Created: \(photo.createdAt)")
//        }
//        
//        return photos
//    }
//    
//    func getAllNavUnitPhotosAsync() async throws -> [NavUnitPhoto] {
//        print("📸 PhotoDatabaseService: Getting all NavUnit photos")
//        
//        let db = try await databaseCore.getDatabaseConnection()
//        let query = navUnitPhotosTable.order(createdAt.desc)
//        
//        var photos: [NavUnitPhoto] = []
//        
//        for row in try db.prepare(query) {
//            let photo = mapRowToNavUnitPhoto(row)
//            photos.append(photo)
//        }
//        
//        print("📸 PhotoDatabaseService: Found \(photos.count) total photos")
//        return photos
//    }
//    
//    func deleteNavUnitPhotoAsync(photoId: Int) async throws -> Bool {
//        print("🗑️ PhotoDatabaseService: Deleting photo with ID: \(photoId)")
//        
//        let db = try await databaseCore.getDatabaseConnection()
//        let query = navUnitPhotosTable.filter(id == photoId)
//        
//        let changes = try db.run(query.delete())
//        let success = changes > 0
//        
//        if success {
//            print("✅ PhotoDatabaseService: Successfully deleted photo with ID: \(photoId)")
//        } else {
//            print("⚠️ PhotoDatabaseService: No photo found with ID: \(photoId)")
//        }
//        
//        return success
//    }
//    
//    // MARK: - Duplicate Detection and Cleanup
//    
//    func findDuplicatePhotosAsync(navUnitId: String) async throws -> [String: [NavUnitPhoto]] {
//        print("🔍 PhotoDatabaseService: Finding duplicate photos for navUnitId: \(navUnitId)")
//        
//        let photos = try await getNavUnitPhotosAsync(navUnitId: navUnitId)
//        var duplicateGroups: [String: [NavUnitPhoto]] = [:]
//        
//        // Group photos by fileName
//        var photosByFileName: [String: [NavUnitPhoto]] = [:]
//        for photo in photos {
//            if photosByFileName[photo.fileName] == nil {
//                photosByFileName[photo.fileName] = []
//            }
//            photosByFileName[photo.fileName]?.append(photo)
//        }
//        
//        // Find groups with more than one photo
//        for (fileName, photosWithName) in photosByFileName {
//            if photosWithName.count > 1 {
//                duplicateGroups[fileName] = photosWithName
//                print("🚨 PhotoDatabaseService: Found \(photosWithName.count) duplicates for file: \(fileName)")
//            }
//        }
//        
//        return duplicateGroups
//    }
//    
//    func removeDuplicatePhotosAsync(navUnitId: String) async throws -> Int {
//        print("🧹 PhotoDatabaseService: Removing duplicate photos for navUnitId: \(navUnitId)")
//        
//        let duplicateGroups = try await findDuplicatePhotosAsync(navUnitId: navUnitId)
//        var removedCount = 0
//        
//        for (fileName, duplicates) in duplicateGroups {
//            // Keep the oldest photo (first created), remove the rest
//            let sortedDuplicates = duplicates.sorted { $0.createdAt < $1.createdAt }
//            let toKeep = sortedDuplicates.first!
//            let toRemove = Array(sortedDuplicates.dropFirst())
//            
//            print("🧹 PhotoDatabaseService: For file \(fileName), keeping photo ID \(toKeep.id), removing \(toRemove.count) duplicates")
//            
//            for duplicate in toRemove {
//                if try await deleteNavUnitPhotoAsync(photoId: duplicate.id) {
//                    removedCount += 1
//                    print("🗑️ PhotoDatabaseService: Removed duplicate photo ID: \(duplicate.id)")
//                }
//            }
//        }
//        
//        print("✅ PhotoDatabaseService: Removed \(removedCount) duplicate photos")
//        return removedCount
//    }
//    
//    // MARK: - Helper Methods
//    
//    private func mapRowToNavUnitPhoto(_ row: Row) -> NavUnitPhoto {
//        return NavUnitPhoto(
//            id: row[id],
//            navUnitId: row[navUnitId],
//            filePath: row[filePath],
//            fileName: row[fileName],
//            thumbPath: row[thumbPath],
//            description: row[description],
//            createdAt: row[createdAt]
//        )
//    }
//    
//    // MARK: - Barge Photos (existing code)
//    
//    private let bargePhotosTable = Table("barge_photos")
//    private let bargeId = Expression<String>("barge_id")
//    
//    func initializeBargePhotosTableAsync() async throws {
//        let db = try await databaseCore.getDatabaseConnection()
//        
//        try db.run(bargePhotosTable.create(ifNotExists: true) { t in
//            t.column(id, primaryKey: .autoincrement)
//            t.column(bargeId)
//            t.column(filePath)
//            t.column(fileName)
//            t.column(thumbPath)
//            t.column(createdAt)
//        })
//        
//        print("📊 PhotoDatabaseService: barge_photos table initialized")
//    }
//}
//
//// MARK: - Error Types
//
//enum PhotoDatabaseError: Error, LocalizedError {
//    case duplicatePhoto
//    case insertFailed(Error)
//    case photoNotFound
//    case databaseError(Error)
//    
//    var errorDescription: String? {
//        switch self {
//        case .duplicatePhoto:
//            return "Photo already exists in database"
//        case .insertFailed(let error):
//            return "Failed to insert photo: \(error.localizedDescription)"
//        case .photoNotFound:
//            return "Photo not found in database"
//        case .databaseError(let error):
//            return "Database error: \(error.localizedDescription)"
//        }
//    }
//}















import Foundation
#if canImport(SQLite)
import SQLite
#endif

class PhotoDatabaseService {
    // MARK: - Table Definitions
    private let navUnitPhotos = Table("NavUnitPhoto")
    private let bargePhotos = Table("BargePhoto")
    
    // MARK: - Column Definitions - Common
    private let colId = Expression<Int>("Id")
    private let colCreatedAt = Expression<Date>("CreatedAt")
    
    // MARK: - Column Definitions - NavUnitPhoto
    private let colNavUnitId = Expression<String>("NavUnitId")
    private let colFilePath = Expression<String>("FilePath")
    private let colFileName = Expression<String>("FileName")
    private let colThumbPath = Expression<String?>("ThumbPath")
    // Note: Description column doesn't exist in the actual database schema
    
    // MARK: - Column Definitions - BargePhoto
    private let colVesselId = Expression<String>("VesselId")
    
    // MARK: - Properties
    private let databaseCore: DatabaseCore
    
    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }
    
    // MARK: - Nav Unit Photos
    
    // Initialize photos table
    func initializePhotosTableAsync() async throws {
        do {
            let db = try databaseCore.ensureConnection()
            
            try db.run(navUnitPhotos.create(ifNotExists: true) { table in
                table.column(colId, primaryKey: .autoincrement)
                table.column(colNavUnitId)
                table.column(colFilePath)
                table.column(colFileName)
                table.column(colThumbPath)
                table.column(colCreatedAt)
            })
            
            print("📊 PhotoDatabaseService: NavUnitPhoto table initialized")
            
            // Create indexes for better performance
            try db.run("CREATE INDEX IF NOT EXISTS idx_nav_unit_photos_nav_unit_id ON NavUnitPhoto(NavUnitId)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_nav_unit_photos_created_at ON NavUnitPhoto(CreatedAt)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_nav_unit_photos_filename ON NavUnitPhoto(FileName)")
            
        } catch {
            print("Error initializing photos table: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Get photos for a navigation unit
    func getNavUnitPhotosAsync(navUnitId: String) async throws -> [NavUnitPhoto] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = navUnitPhotos.filter(colNavUnitId == navUnitId).order(colCreatedAt.desc)
            var results: [NavUnitPhoto] = []
            
            for row in try db.prepare(query) {
                let photo = NavUnitPhoto(
                    id: row[colId],
                    navUnitId: row[colNavUnitId],
                    filePath: row[colFilePath],
                    fileName: row[colFileName],
                    thumbPath: row[colThumbPath],
                    createdAt: row[colCreatedAt]
                )
                results.append(photo)
            }
            
            return results
        } catch {
            print("Error fetching nav unit photos: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Get all nav unit photos from the database (for bulk sync operations)
    func getAllNavUnitPhotosAsync() async throws -> [NavUnitPhoto] {
        print("📊 PhotoDatabaseService: Getting all nav unit photos...")
        
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = navUnitPhotos.order(colCreatedAt.desc)
            var results: [NavUnitPhoto] = []
            
            for row in try db.prepare(query) {
                let photo = NavUnitPhoto(
                    id: row[colId],
                    navUnitId: row[colNavUnitId],
                    filePath: row[colFilePath],
                    fileName: row[colFileName],
                    thumbPath: row[colThumbPath],
                    createdAt: row[colCreatedAt]
                )
                results.append(photo)
            }
            
            print("✅ PhotoDatabaseService: Retrieved \(results.count) total photos")
            return results
        } catch {
            print("❌ PhotoDatabaseService: Error getting all photos: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Add a new photo for a navigation unit with duplicate checking
    func addNavUnitPhotoAsync(photo: NavUnitPhoto) async throws -> Int {
        print("📸 PhotoDatabaseService: Adding photo - NavUnit: \(photo.navUnitId), File: \(photo.fileName)")
        
        // First check if photo already exists to prevent duplicates
        if let existingPhoto = try await findExistingPhoto(photo) {
            print("⚠️ PhotoDatabaseService: Photo already exists with ID: \(existingPhoto.id), skipping insert")
            return existingPhoto.id
        }
        
        let db = try databaseCore.ensureConnection()
        
        do {
            let insert = navUnitPhotos.insert(
                colNavUnitId <- photo.navUnitId,
                colFilePath <- photo.filePath,
                colFileName <- photo.fileName,
                colThumbPath <- photo.thumbPath,
                colCreatedAt <- photo.createdAt
            )
            
            let rowId = try db.run(insert)
            try await databaseCore.flushDatabaseAsync()
            print("✅ PhotoDatabaseService: Successfully added photo with ID: \(rowId)")
            return Int(rowId)
            
        } catch {
            print("❌ PhotoDatabaseService: Error adding photo: \(error.localizedDescription)")
            
            // Check if it's a constraint error and handle gracefully
            if error.localizedDescription.contains("UNIQUE constraint failed") {
                print("🚫 PhotoDatabaseService: Duplicate photo detected by database constraint")
                
                // Try to find the existing photo and return its ID
                if let existingPhoto = try await findExistingPhoto(photo) {
                    print("✅ PhotoDatabaseService: Found existing duplicate with ID: \(existingPhoto.id)")
                    return existingPhoto.id
                } else {
                    throw PhotoDatabaseError.duplicatePhoto
                }
            } else {
                throw PhotoDatabaseError.insertFailed(error)
            }
        }
    }
    
    // Helper method to find existing photos with multiple matching criteria
    private func findExistingPhoto(_ photo: NavUnitPhoto) async throws -> NavUnitPhoto? {
        let db = try databaseCore.ensureConnection()
        
        // First try exact match (navUnitId + fileName + createdAt within 1 minute)
        let exactQuery = navUnitPhotos.filter(
            colNavUnitId == photo.navUnitId &&
            colFileName == photo.fileName
        )
        
        for row in try db.prepare(exactQuery) {
            let existingCreatedAt = row[colCreatedAt]
            let timeDifference = abs(existingCreatedAt.timeIntervalSince(photo.createdAt))
            
            // Consider it a duplicate if created within 1 minute
            if timeDifference < 60 {
                print("🔍 PhotoDatabaseService: Found existing photo by exact match (time diff: \(timeDifference)s)")
                return mapRowToNavUnitPhoto(row)
            }
        }
        
        // If no exact match, try file path match (for photos downloaded from iCloud)
        let pathQuery = navUnitPhotos.filter(
            colNavUnitId == photo.navUnitId &&
            colFilePath == photo.filePath
        )
        
        for row in try db.prepare(pathQuery) {
            print("🔍 PhotoDatabaseService: Found existing photo by file path match")
            return mapRowToNavUnitPhoto(row)
        }
        
        return nil
    }
    
    // Delete a photo
    func deleteNavUnitPhotoAsync(photoId: Int) async throws -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            // First get the photo to delete the file
            let photoQuery = navUnitPhotos.filter(colId == photoId)
            
            if let photo = try db.pluck(photoQuery) {
                let filePath = photo[colFilePath]
                
                // Delete the file if it exists
                if FileManager.default.fileExists(atPath: filePath) {
                    try FileManager.default.removeItem(atPath: filePath)
                }
                
                // Delete the database record
                try db.run(photoQuery.delete())
            }
            
            try await databaseCore.flushDatabaseAsync()
            return true
        } catch {
            print("Error deleting nav unit photo: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Duplicate Detection and Cleanup
    
    func findDuplicatePhotosAsync(navUnitId: String) async throws -> [String: [NavUnitPhoto]] {
        print("🔍 PhotoDatabaseService: Finding duplicate photos for navUnitId: \(navUnitId)")
        
        let photos = try await getNavUnitPhotosAsync(navUnitId: navUnitId)
        var duplicateGroups: [String: [NavUnitPhoto]] = [:]
        
        // Group photos by fileName
        var photosByFileName: [String: [NavUnitPhoto]] = [:]
        for photo in photos {
            let fileName = photo.fileName
            if photosByFileName[fileName] == nil {
                photosByFileName[fileName] = []
            }
            photosByFileName[fileName]?.append(photo)
        }
        
        // Find groups with more than one photo
        for (fileName, photosWithName) in photosByFileName {
            if photosWithName.count > 1 {
                duplicateGroups[fileName] = photosWithName
                print("🚨 PhotoDatabaseService: Found \(photosWithName.count) duplicates for file: \(fileName)")
            }
        }
        
        return duplicateGroups
    }
    
    func removeDuplicatePhotosAsync(navUnitId: String) async throws -> Int {
        print("🧹 PhotoDatabaseService: Removing duplicate photos for navUnitId: \(navUnitId)")
        
        let duplicateGroups = try await findDuplicatePhotosAsync(navUnitId: navUnitId)
        var removedCount = 0
        
        for (fileName, duplicates) in duplicateGroups {
            // Keep the oldest photo (first created), remove the rest
            let sortedDuplicates = duplicates.sorted { $0.createdAt < $1.createdAt }
            let toKeep = sortedDuplicates.first!
            let toRemove = Array(sortedDuplicates.dropFirst())
            
            print("🧹 PhotoDatabaseService: For file \(fileName), keeping photo ID \(toKeep.id), removing \(toRemove.count) duplicates")
            
            for duplicate in toRemove {
                if try await deleteNavUnitPhotoAsync(photoId: duplicate.id) {
                    removedCount += 1
                    print("🗑️ PhotoDatabaseService: Removed duplicate photo ID: \(duplicate.id)")
                }
            }
        }
        
        print("✅ PhotoDatabaseService: Removed \(removedCount) duplicate photos")
        return removedCount
    }
    
    // MARK: - Helper Methods
    
    private func mapRowToNavUnitPhoto(_ row: Row) -> NavUnitPhoto {
        return NavUnitPhoto(
            id: row[colId],
            navUnitId: row[colNavUnitId],
            filePath: row[colFilePath],
            fileName: row[colFileName],
            thumbPath: row[colThumbPath],
            createdAt: row[colCreatedAt]
        )
    }
    
    // MARK: - Barge Photos
    
    // Initialize barge photos table
    func initializeBargePhotosTableAsync() async throws {
        do {
            let db = try databaseCore.ensureConnection()
            
            try db.run(bargePhotos.create(ifNotExists: true) { table in
                table.column(colId, primaryKey: .autoincrement)
                table.column(colVesselId)
                table.column(colFilePath)
                table.column(colFileName)
                table.column(colThumbPath)
                table.column(colCreatedAt)
            })
            
            print("📊 PhotoDatabaseService: BargePhoto table initialized")
        } catch {
            print("Error initializing barge photos table: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Get photos for a barge
    func getBargePhotosAsync(bargeId: String) async throws -> [BargePhoto] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = bargePhotos.filter(colVesselId == bargeId).order(colCreatedAt.desc)
            var results: [BargePhoto] = []
            
            for row in try db.prepare(query) {
                let photo = BargePhoto(
                    id: row[colId],
                    bargeId: row[colVesselId],
                    filePath: row[colFilePath],
                    fileName: row[colFileName],
                    thumbPath: row[colThumbPath],
                    createdAt: row[colCreatedAt]
                )
                results.append(photo)
            }
            
            return results
        } catch {
            print("Error fetching barge photos: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Add a new photo for a barge
    func addBargePhotoAsync(photo: BargePhoto) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let insert = bargePhotos.insert(
                colVesselId <- photo.bargeId,
                colFilePath <- photo.filePath,
                colFileName <- photo.fileName,
                colThumbPath <- photo.thumbPath,
                colCreatedAt <- photo.createdAt
            )
            
            let rowId = try db.run(insert)
            try await databaseCore.flushDatabaseAsync()
            return Int(rowId)
        } catch {
            print("Error adding barge photo: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Delete a barge photo
    func deleteBargePhotoAsync(photoId: Int) async throws -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            // First get the photo to delete the file
            let photoQuery = bargePhotos.filter(colId == photoId)
            
            if let photo = try db.pluck(photoQuery) {
                let filePath = photo[colFilePath]
                
                // Delete the file if it exists
                if FileManager.default.fileExists(atPath: filePath) {
                    try FileManager.default.removeItem(atPath: filePath)
                }
                
                // Delete the database record
                try db.run(photoQuery.delete())
            }
            
            try await databaseCore.flushDatabaseAsync()
            return true
        } catch {
            print("Error deleting barge photo: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Error Types

enum PhotoDatabaseError: Error, LocalizedError {
    case duplicatePhoto
    case insertFailed(Error)
    case photoNotFound
    case databaseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .duplicatePhoto:
            return "Photo already exists in database"
        case .insertFailed(let error):
            return "Failed to insert photo: \(error.localizedDescription)"
        case .photoNotFound:
            return "Photo not found in database"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}
