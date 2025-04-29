import Foundation
#if canImport(SQLite)
import SQLite
#endif

class PhotoDatabaseService {
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
            
            try db.run(databaseCore.navUnitPhotos.create(ifNotExists: true) { table in
                table.column(databaseCore.colId, primaryKey: .autoincrement)
                table.column(databaseCore.colNavUnitId)
                table.column(databaseCore.colFilePath)
                table.column(databaseCore.colFileName)
                table.column(databaseCore.colThumbPath)
                table.column(databaseCore.colCreatedAt)
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
            
            let query = databaseCore.navUnitPhotos.filter(databaseCore.colNavUnitId == navUnitId).order(databaseCore.colCreatedAt.desc)
            var results: [NavUnitPhoto] = []
            
            for row in try db.prepare(query) {
                let photo = NavUnitPhoto(
                    id: row[databaseCore.colId],
                    navUnitId: row[databaseCore.colNavUnitId],
                    filePath: row[databaseCore.colFilePath],
                    fileName: row[databaseCore.colFileName],
                    thumbPath: row[databaseCore.colThumbPath],
                    createdAt: row[databaseCore.colCreatedAt]
                )
                results.append(photo)
            }
            
            return results
        } catch {
            print("Error fetching nav unit photos: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Add a new photo for a navigation unit
    func addNavUnitPhotoAsync(photo: NavUnitPhoto) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let insert = databaseCore.navUnitPhotos.insert(
                databaseCore.colNavUnitId <- photo.navUnitId,
                databaseCore.colFilePath <- photo.filePath,
                databaseCore.colFileName <- photo.fileName,
                databaseCore.colThumbPath <- photo.thumbPath,
                databaseCore.colCreatedAt <- photo.createdAt
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
            let photoQuery = databaseCore.navUnitPhotos.filter(databaseCore.colId == photoId)
            
            if let photo = try db.pluck(photoQuery) {
                let filePath = photo[databaseCore.colFilePath]
                
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
            print("Error deleting tug photo: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Barge Photos
    
    // Initialize barge photos table
    func initializeBargePhotosTableAsync() async throws {
        do {
            let db = try databaseCore.ensureConnection()
            
            try db.run(databaseCore.bargePhotos.create(ifNotExists: true) { table in
                table.column(databaseCore.colId, primaryKey: .autoincrement)
                table.column(databaseCore.colVesselId)
                table.column(databaseCore.colFilePath)
                table.column(databaseCore.colFileName)
                table.column(databaseCore.colThumbPath)
                table.column(databaseCore.colCreatedAt)
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
            
            let query = databaseCore.bargePhotos.filter(databaseCore.colVesselId == bargeId).order(databaseCore.colCreatedAt.desc)
            var results: [BargePhoto] = []
            
            for row in try db.prepare(query) {
                let photo = BargePhoto(
                    id: row[databaseCore.colId],
                    bargeId: row[databaseCore.colVesselId],
                    filePath: row[databaseCore.colFilePath],
                    fileName: row[databaseCore.colFileName],
                    thumbPath: row[databaseCore.colThumbPath],
                    createdAt: row[databaseCore.colCreatedAt]
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
            
            let insert = databaseCore.bargePhotos.insert(
                databaseCore.colVesselId <- photo.bargeId,
                databaseCore.colFilePath <- photo.filePath,
                databaseCore.colFileName <- photo.fileName,
                databaseCore.colThumbPath <- photo.thumbPath,
                databaseCore.colCreatedAt <- photo.createdAt
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
            let photoQuery = databaseCore.bargePhotos.filter(databaseCore.colId == photoId)
            
            if let photo = try db.pluck(photoQuery) {
                let filePath = photo[databaseCore.colFilePath]
                
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
