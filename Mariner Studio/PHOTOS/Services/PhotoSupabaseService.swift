//
//  PhotoSupabaseService.swift
//  Mariner Studio
//
//  Supabase integration service for nav unit photo storage and sync
//

import Foundation
import Supabase

class PhotoSupabaseServiceImpl: PhotoSupabaseService {
    
    // MARK: - Properties
    
    private let supabaseManager: SupabaseManager
    
    // MARK: - Constants
    
    private struct Constants {
        static let bucketName = "nav-unit-photos"
        static let tableName = "nav_unit_photos"
        static let maxPhotosPerNavUnit = 10
    }
    
    // MARK: - Initialization
    
    init(supabaseManager: SupabaseManager = SupabaseManager.shared) {
        self.supabaseManager = supabaseManager
        print("📸 PhotoSupabaseService: Initialized")
    }
    
    // MARK: - Photo Upload Operations
    
    func uploadPhoto(_ photo: NavUnitPhoto, imageData: Data) async throws -> String {
        print("📸 PhotoSupabaseService: Starting upload for photo \(photo.id)")
        
        // Check authentication
        guard let session = try? await supabaseManager.getSession() else {
            throw PhotoSyncError.authenticationFailed
        }
        let user = session.user
        
        // Check photo limit before upload
        try await enforcePhotoLimit(for: photo.navUnitId, userId: user.id.uuidString)
        
        // Generate storage path
        let storagePath = generateStoragePath(for: photo, userId: user.id.uuidString)
        
        print("📸 PhotoSupabaseService: Upload details:")
        print("📸   User ID: \(user.id.uuidString)")
        print("📸   User Email: \(user.email ?? "none")")
        print("📸   Storage path: \(storagePath)")
        print("📸   Bucket: \(Constants.bucketName)")
        print("📸   Image size: \(imageData.count) bytes")
        
        // Debug: Check if the client has the session properly set
        do {
            let currentSession = try await supabaseManager.client.auth.session
            print("📸   Current session user: \(currentSession.user.id)")
            print("📸   Current session email: \(currentSession.user.email ?? "none")")
            print("📸   Session expires: \(Date(timeIntervalSince1970: TimeInterval(currentSession.expiresAt)))")
        } catch {
            print("❌   Failed to get current session: \(error)")
        }
        
        do {
            print("📸 PhotoSupabaseService: Starting storage upload...")
            
            // Upload to Supabase Storage
            let uploadResponse = try await supabaseManager.client.storage
                .from(Constants.bucketName)
                .upload(path: storagePath, file: imageData, options: FileOptions(cacheControl: "3600"))
            
            print("📸 PhotoSupabaseService: Storage upload successful")
            print("📸   Upload response: \(uploadResponse)")
            
            // Get public URL
            let publicURL = try supabaseManager.client.storage
                .from(Constants.bucketName)
                .getPublicURL(path: storagePath)
            
            print("📸 PhotoSupabaseService: Generated public URL: \(publicURL.absoluteString)")
            
            // Insert metadata record
            let photoRecord = PhotoMetadataRecord(
                navUnitId: photo.navUnitId,
                fileName: photo.localFileName,
                userId: user.id,
                storagePath: storagePath,
                fileSize: imageData.count,
                mimeType: "image/jpeg"
            )
            
            print("📸 PhotoSupabaseService: Starting database insert...")
            print("📸   Table: \(Constants.tableName)")
            print("📸   Photo record: nav_unit_id=\(photoRecord.navUnitId), user_id=\(photoRecord.userId)")
            
            let dbResponse = try await supabaseManager.client.database
                .from(Constants.tableName)
                .insert(photoRecord)
                .execute()
            
            print("📸 PhotoSupabaseService: Database insert successful")
            print("📸   DB response: \(dbResponse)")
            
            print("📸 PhotoSupabaseService: Successfully uploaded photo \(photo.id)")
            print("📸   Storage path: \(storagePath)")
            print("📸   Public URL: \(publicURL.absoluteString)")
            
            return publicURL.absoluteString
            
        } catch let storageError as StorageError {
            print("❌ PhotoSupabaseService: Storage error for photo \(photo.id):")
            print("❌   Status code: \(storageError.statusCode ?? "none")")
            print("❌   Message: \(storageError.message)")
            print("❌   Error: \(storageError.error ?? "none")")
            print("❌   Full error: \(storageError)")
            throw PhotoSyncError.uploadFailed(photo.localFileName)
        } catch let dbError {
            print("❌ PhotoSupabaseService: Database error for photo \(photo.id):")
            print("❌   Error type: \(type(of: dbError))")
            print("❌   Error description: \(dbError.localizedDescription)")
            print("❌   Full error: \(dbError)")
            throw PhotoSyncError.uploadFailed(photo.localFileName)
        } catch let error {
            print("❌ PhotoSupabaseService: General error for photo \(photo.id):")
            print("❌   Error type: \(type(of: error))")
            print("❌   Error description: \(error.localizedDescription)")
            print("❌   Full error: \(error)")
            throw PhotoSyncError.uploadFailed(photo.localFileName)
        }
    }
    
    // MARK: - Photo Download Operations
    
    func downloadPhoto(supabaseUrl: String) async throws -> Data {
        print("📸 PhotoSupabaseService: Starting download from URL: \(supabaseUrl)")
        
        do {
            // Extract storage path from URL
            guard let storagePath = extractStoragePath(from: supabaseUrl) else {
                throw PhotoSyncError.downloadFailed("Invalid URL format")
            }
            
            print("📸 DEBUG: Extracted storage path: '\(storagePath)'")
            
            // Download from Supabase Storage
            let data = try await supabaseManager.client.storage
                .from(Constants.bucketName)
                .download(path: storagePath)
                
            print("📸 PhotoSupabaseService: Successfully downloaded \(data.count) bytes")
            return data
            
        } catch let error {
            print("❌ PhotoSupabaseService: Download failed: \(error)")
            throw PhotoSyncError.downloadFailed(supabaseUrl)
        }
    }
    
    func downloadPhotoByPath(storagePath: String) async throws -> Data {
        print("📸 PhotoSupabaseService: Starting download from path: \(storagePath)")
        
        // Ensure we have a valid session before attempting download
        guard let session = try? await supabaseManager.getSession() else {
            print("❌ PhotoSupabaseService: No valid session for authenticated download")
            throw PhotoSyncError.authenticationFailed
        }
        
        print("📸 DEBUG: Using session for download - User ID: \(session.user.id)")
        
        do {
            // Download directly from Supabase Storage using the authenticated path
            let data = try await supabaseManager.client.storage
                .from(Constants.bucketName)
                .download(path: storagePath)
            
            print("📸 PhotoSupabaseService: Successfully downloaded \(data.count) bytes")
            return data
            
        } catch let error {
            print("❌ PhotoSupabaseService: Download failed for path \(storagePath): \(error)")
            print("❌ PhotoSupabaseService: Session user ID: \(session.user.id)")
            print("❌ PhotoSupabaseService: Expected folder: \(storagePath.components(separatedBy: "/").first ?? "none")")
            throw PhotoSyncError.downloadFailed(storagePath)
        }
    }
    
    // MARK: - Remote Photo Management
    
    func getRemotePhotos(for navUnitId: String, userId: String) async throws -> [RemotePhoto] {
        print("📸 PhotoSupabaseService: Fetching remote photos for nav unit \(navUnitId)")
        
        do {
            let response: [PhotoMetadataRecord] = try await supabaseManager.client.database
                .from(Constants.tableName)
                .select()
                .eq("nav_unit_id", value: navUnitId)
                .eq("user_id", value: userId.lowercased())
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let remotePhotos = response.map { record in
                print("📸 DEBUG: Database record - ID: \(record.id?.uuidString ?? "nil")")
                print("📸 DEBUG: Database record - Storage path: '\(record.storagePath)'")
                print("📸 DEBUG: Database record - User ID: \(record.userId.uuidString)")
                print("📸 DEBUG: Database record - Nav Unit ID: \(record.navUnitId)")
                print("📸 DEBUG: Database record - File name: \(record.fileName)")
                
                return RemotePhoto(
                    id: record.id?.uuidString ?? UUID().uuidString,
                    navUnitId: record.navUnitId,
                    fileName: record.fileName,
                    userId: record.userId.uuidString,
                    storagePath: record.storagePath,
                    fileSize: record.fileSize,
                    mimeType: record.mimeType,
                    createdAt: record.createdAt ?? Date(),
                    updatedAt: record.updatedAt ?? Date()
                )
            }
            
            print("📸 PhotoSupabaseService: Found \(remotePhotos.count) remote photos")
            return remotePhotos
            
        } catch let error {
            print("❌ PhotoSupabaseService: Failed to fetch remote photos: \(error)")
            throw PhotoSyncError.supabaseError(error.localizedDescription)
        }
    }
    
    func deleteRemotePhoto(supabaseUrl: String) async throws {
        print("📸 PhotoSupabaseService: Deleting remote photo: \(supabaseUrl)")
        
        do {
            // Extract storage path
            guard let storagePath = extractStoragePath(from: supabaseUrl) else {
                throw PhotoSyncError.supabaseError("Invalid URL format")
            }
            
            // Delete from storage
            _ = try await supabaseManager.client.storage
                .from(Constants.bucketName)
                .remove(paths: [storagePath])
            
            // Delete metadata record
            try await supabaseManager.client.database
                .from(Constants.tableName)
                .delete()
                .eq("storage_path", value: storagePath)
                .execute()
            
            print("📸 PhotoSupabaseService: Successfully deleted remote photo")
            
        } catch let error {
            print("❌ PhotoSupabaseService: Failed to delete remote photo: \(error)")
            throw PhotoSyncError.supabaseError(error.localizedDescription)
        }
    }
    
    // MARK: - Photo Limit Management
    
    func getPhotoCount(for navUnitId: String, userId: String) async throws -> Int {
        do {
            struct CountResponse: Codable { let id: UUID }
            let response: [CountResponse] = try await supabaseManager.client.database
                .from(Constants.tableName)
                .select("id")
                .eq("nav_unit_id", value: navUnitId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let count = response.count
            print("📸 PhotoSupabaseService: Nav unit \(navUnitId) has \(count) remote photos")
            return count
            
        } catch let error {
            print("❌ PhotoSupabaseService: Failed to get photo count: \(error)")
            throw PhotoSyncError.supabaseError(error.localizedDescription)
        }
    }
    
    func enforcePhotoLimit(for navUnitId: String, userId: String) async throws {
        let currentCount = try await getPhotoCount(for: navUnitId, userId: userId)
        
        if currentCount >= Constants.maxPhotosPerNavUnit {
            print("⚠️ PhotoSupabaseService: Photo limit reached for nav unit \(navUnitId)")
            
            // Get oldest photo
            let oldestPhotos: [PhotoMetadataRecord] = try await supabaseManager.client.database
                .from(Constants.tableName)
                .select()
                .eq("nav_unit_id", value: navUnitId)
                .eq("user_id", value: userId)
                .order("created_at", ascending: true)
                .limit(1)
                .execute()
                .value
            
            if let oldestPhoto = oldestPhotos.first {
                // Delete oldest photo to make room
                try await deleteOldestPhoto(oldestPhoto)
                print("📸 PhotoSupabaseService: Deleted oldest photo to enforce limit")
            } else {
                throw PhotoSyncError.photoLimitExceeded
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func generateStoragePath(for photo: NavUnitPhoto, userId: String) -> String {
        let timestamp = Int(photo.timestamp.timeIntervalSince1970)
        let storagePath = "\(userId)/\(photo.navUnitId)/\(timestamp)_\(photo.localFileName)"
        print("📸 DEBUG: Generated storage path: '\(storagePath)'")
        print("📸 DEBUG: User ID: \(userId)")
        print("📸 DEBUG: Nav Unit ID: \(photo.navUnitId)")
        print("📸 DEBUG: Timestamp: \(timestamp)")
        print("📸 DEBUG: Local filename: \(photo.localFileName)")
        return storagePath
    }
    
    private func extractStoragePath(from url: String) -> String? {
        // Extract path from Supabase public URL
        // Format: https://xxx.supabase.co/storage/v1/object/public/nav-unit-photos/path
        guard let urlComponents = URLComponents(string: url),
              let path = urlComponents.path.components(separatedBy: "/public/\(Constants.bucketName)/").last else {
            return nil
        }
        return path
    }
    
    private func deleteOldestPhoto(_ photo: PhotoMetadataRecord) async throws {
        // Delete from storage
        _ = try await supabaseManager.client.storage
            .from(Constants.bucketName)
            .remove(paths: [photo.storagePath])
        
        // Delete metadata record
        if let photoId = photo.id {
            try await supabaseManager.client.database
                .from(Constants.tableName)
                .delete()
                .eq("id", value: photoId.uuidString)
                .execute()
        }
    }
}

// MARK: - Supabase Data Models

private struct PhotoMetadataRecord: Codable {
    let id: UUID?
    let navUnitId: String
    let fileName: String
    let userId: UUID
    let storagePath: String
    let fileSize: Int?
    let mimeType: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case navUnitId = "nav_unit_id"
        case fileName = "file_name"
        case userId = "user_id"
        case storagePath = "storage_path"
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(navUnitId: String, fileName: String, userId: UUID, storagePath: String, fileSize: Int?, mimeType: String?) {
        self.id = nil // Will be generated by Supabase
        self.navUnitId = navUnitId
        self.fileName = fileName
        self.userId = userId
        self.storagePath = storagePath
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.createdAt = nil // Will be set by Supabase
        self.updatedAt = nil // Will be set by Supabase
    }
}