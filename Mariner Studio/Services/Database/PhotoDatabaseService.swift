
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
    
    // Add a new photo for a navigation unit
    func addNavUnitPhotoAsync(photo: NavUnitPhoto) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let insert = navUnitPhotos.insert(
                colNavUnitId <- photo.navUnitId,
                colFilePath <- photo.filePath,
                colFileName <- photo.fileName,
                colThumbPath <- photo.thumbPath,
                colCreatedAt <- photo.createdAt
            )
            
            let rowId = try db.run(insert)
            try await databaseCore.flushDatabaseAsync()
            return Int(rowId)
        } catch {
            print("Error adding nav unit photo: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Delete a photo
    func deleteNavUnitPhotoAsync(photoId: Int) async throws -> Int {
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
            return 1
        } catch {
            print("Error deleting nav unit photo: \(error.localizedDescription)")
            throw error
        }
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
    func deleteBargePhotoAsync(photoId: Int) async throws -> Int {
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
            return 1
        } catch {
            print("Error deleting barge photo: \(error.localizedDescription)")
            throw error
        }
    }
}
