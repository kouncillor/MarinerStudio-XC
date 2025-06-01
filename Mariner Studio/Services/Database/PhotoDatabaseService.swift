
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



