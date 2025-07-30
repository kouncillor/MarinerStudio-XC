//
//  PhotoDatabaseService.swift
//  Mariner Studio
//
//  SQLite database service for nav unit photos
//

import Foundation
import SQLite

class PhotoDatabaseServiceImpl: PhotoDatabaseService {

    // MARK: - Properties

    private let databaseCore: DatabaseCore

    // MARK: - Table Definition

    private let photosTable = Table("nav_unit_photos")

    // MARK: - Column Definitions

    private let id = Expression<String>("id")
    private let navUnitId = Expression<String>("nav_unit_id")
    private let localFileName = Expression<String>("local_file_name")
    private let supabaseUrl = Expression<String?>("supabase_url")
    private let timestamp = Expression<Int64>("timestamp")
    private let isUploaded = Expression<Bool>("is_uploaded")
    private let isSyncedFromCloud = Expression<Bool>("is_synced_from_cloud")
    private let userId = Expression<String?>("user_id")
    private let createdAt = Expression<Int64>("created_at")
    private let updatedAt = Expression<Int64>("updated_at")

    // MARK: - Initialization

    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
        print("📸 PhotoDatabaseService: Initialized")
    }

    // MARK: - Photo CRUD Operations

    func insertPhoto(_ photo: NavUnitPhoto) throws {
        let db = try databaseCore.ensureConnection()

        let currentTime = Int64(Date().timeIntervalSince1970)

        try db.run(photosTable.insert(
            id <- photo.id.uuidString,
            navUnitId <- photo.navUnitId,
            localFileName <- photo.localFileName,
            supabaseUrl <- photo.supabaseUrl,
            timestamp <- Int64(photo.timestamp.timeIntervalSince1970),
            isUploaded <- photo.isUploaded,
            isSyncedFromCloud <- photo.isSyncedFromCloud,
            userId <- photo.userId,
            createdAt <- currentTime,
            updatedAt <- currentTime
        ))

        print("📸 PhotoDatabaseService: Inserted photo \(photo.id) for nav unit \(photo.navUnitId)")
    }

    func getPhotos(for navUnitId: String) throws -> [NavUnitPhoto] {
        let db = try databaseCore.ensureConnection()

        let query = photosTable
            .filter(self.navUnitId == navUnitId)
            .order(timestamp.desc)

        var photos: [NavUnitPhoto] = []

        for row in try db.prepare(query) {
            let photo = NavUnitPhoto(
                id: UUID(uuidString: row[self.id]) ?? UUID(),
                navUnitId: row[self.navUnitId],
                localFileName: row[self.localFileName],
                supabaseUrl: row[self.supabaseUrl],
                timestamp: Date(timeIntervalSince1970: TimeInterval(row[self.timestamp])),
                isUploaded: row[self.isUploaded],
                isSyncedFromCloud: row[self.isSyncedFromCloud],
                userId: row[self.userId]
            )
            photos.append(photo)
        }

        print("📸 PhotoDatabaseService: Retrieved \(photos.count) photos for nav unit \(navUnitId)")
        return photos
    }

    func updatePhoto(_ photo: NavUnitPhoto) throws {
        let db = try databaseCore.ensureConnection()

        let photoRow = photosTable.filter(self.id == photo.id.uuidString)
        let currentTime = Int64(Date().timeIntervalSince1970)

        let changes = try db.run(photoRow.update(
            navUnitId <- photo.navUnitId,
            localFileName <- photo.localFileName,
            supabaseUrl <- photo.supabaseUrl,
            timestamp <- Int64(photo.timestamp.timeIntervalSince1970),
            isUploaded <- photo.isUploaded,
            isSyncedFromCloud <- photo.isSyncedFromCloud,
            userId <- photo.userId,
            updatedAt <- currentTime
        ))

        if changes > 0 {
            print("📸 PhotoDatabaseService: Updated photo \(photo.id)")
        } else {
            print("⚠️ PhotoDatabaseService: No photo found with ID \(photo.id)")
        }
    }

    func deletePhoto(id photoId: UUID) throws {
        let db = try databaseCore.ensureConnection()

        let photoRow = photosTable.filter(self.id == photoId.uuidString)
        let changes = try db.run(photoRow.delete())

        if changes > 0 {
            print("📸 PhotoDatabaseService: Deleted photo \(photoId)")
        } else {
            print("⚠️ PhotoDatabaseService: No photo found with ID \(photoId)")
        }
    }

    func getPhotoCount(for navUnitId: String) throws -> Int {
        let db = try databaseCore.ensureConnection()

        let query = photosTable
            .filter(self.navUnitId == navUnitId)
            .count

        let count = try db.scalar(query)
        print("📸 PhotoDatabaseService: Nav unit \(navUnitId) has \(count) photos")
        return count
    }

    // MARK: - Sync-Specific Operations

    func getPhotos(for navUnitId: String, uploaded: Bool) throws -> [NavUnitPhoto] {
        let db = try databaseCore.ensureConnection()

        let query = photosTable
            .filter(self.navUnitId == navUnitId && isUploaded == uploaded)
            .order(timestamp.desc)

        var photos: [NavUnitPhoto] = []

        for row in try db.prepare(query) {
            let photo = NavUnitPhoto(
                id: UUID(uuidString: row[self.id]) ?? UUID(),
                navUnitId: row[self.navUnitId],
                localFileName: row[self.localFileName],
                supabaseUrl: row[self.supabaseUrl],
                timestamp: Date(timeIntervalSince1970: TimeInterval(row[self.timestamp])),
                isUploaded: row[self.isUploaded],
                isSyncedFromCloud: row[self.isSyncedFromCloud],
                userId: row[self.userId]
            )
            photos.append(photo)
        }

        let status = uploaded ? "uploaded" : "pending upload"
        print("📸 PhotoDatabaseService: Retrieved \(photos.count) \(status) photos for nav unit \(navUnitId)")
        return photos
    }

    func markPhotoAsUploaded(id photoId: UUID, supabaseUrl: String) throws {
        let db = try databaseCore.ensureConnection()

        let photoRow = photosTable.filter(self.id == photoId.uuidString)
        let currentTime = Int64(Date().timeIntervalSince1970)

        let changes = try db.run(photoRow.update(
            isUploaded <- true,
            self.supabaseUrl <- supabaseUrl,
            updatedAt <- currentTime
        ))

        if changes > 0 {
            print("📸 PhotoDatabaseService: Marked photo \(photoId) as uploaded")
        } else {
            print("⚠️ PhotoDatabaseService: Failed to mark photo \(photoId) as uploaded")
        }
    }

    func markPhotoAsSyncedFromCloud(id photoId: UUID) throws {
        let db = try databaseCore.ensureConnection()

        let photoRow = photosTable.filter(self.id == photoId.uuidString)
        let currentTime = Int64(Date().timeIntervalSince1970)

        let changes = try db.run(photoRow.update(
            isSyncedFromCloud <- true,
            updatedAt <- currentTime
        ))

        if changes > 0 {
            print("📸 PhotoDatabaseService: Marked photo \(photoId) as synced from cloud")
        } else {
            print("⚠️ PhotoDatabaseService: Failed to mark photo \(photoId) as synced from cloud")
        }
    }

    // MARK: - Utility Methods

    func getPhotoById(_ photoId: UUID) throws -> NavUnitPhoto? {
        let db = try databaseCore.ensureConnection()

        let query = photosTable.filter(self.id == photoId.uuidString)

        for row in try db.prepare(query) {
            return NavUnitPhoto(
                id: UUID(uuidString: row[self.id]) ?? UUID(),
                navUnitId: row[self.navUnitId],
                localFileName: row[self.localFileName],
                supabaseUrl: row[self.supabaseUrl],
                timestamp: Date(timeIntervalSince1970: TimeInterval(row[self.timestamp])),
                isUploaded: row[self.isUploaded],
                isSyncedFromCloud: row[self.isSyncedFromCloud],
                userId: row[self.userId]
            )
        }

        return nil
    }

    func getAllPhotosCount() throws -> Int {
        let db = try databaseCore.ensureConnection()
        let count = try db.scalar(photosTable.count)
        print("📸 PhotoDatabaseService: Total photos in database: \(count)")
        return count
    }
}
