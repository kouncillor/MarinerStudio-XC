//
//  PhotoServiceImpl.swift
//  Mariner Studio
//
//  Main photo service implementation coordinating database, cache, and cloud services
//

import Foundation
import UIKit

class PhotoServiceImpl: PhotoService {
    
    // MARK: - Properties
    
    private let databaseService: PhotoDatabaseService
    private let cacheService: PhotoCacheService
    private let supabaseService: PhotoSupabaseService
    
    // MARK: - Initialization
    
    init(
        databaseService: PhotoDatabaseService,
        cacheService: PhotoCacheService,
        supabaseService: PhotoSupabaseService
    ) {
        self.databaseService = databaseService
        self.cacheService = cacheService
        self.supabaseService = supabaseService
        
        print("📸 PhotoService: Initialized with all services")
    }
    
    // MARK: - Local Photo Operations
    
    func getPhotos(for navUnitId: String) async throws -> [NavUnitPhoto] {
        return try databaseService.getPhotos(for: navUnitId)
    }
    
    func takePhoto(for navUnitId: String, image: UIImage) async throws -> NavUnitPhoto {
        print("📸 PhotoService: Taking new photo for nav unit \(navUnitId)")
        
        // Check if at photo limit
        if try await isAtPhotoLimit(for: navUnitId) {
            throw PhotoSyncError.photoLimitExceeded
        }
        
        // Compress image for storage
        let imageData = try cacheService.compressImageForUpload(image)
        
        // Generate filename and create photo record
        let fileName = NavUnitPhoto.generateFileName(for: navUnitId)
        let photo = NavUnitPhoto(
            navUnitId: navUnitId,
            localFileName: fileName,
            timestamp: Date(),
            isUploaded: false,
            isSyncedFromCloud: false
        )
        
        // Save to local storage
        _ = try cacheService.savePhoto(imageData, fileName: fileName)
        
        // Generate thumbnail
        _ = try cacheService.generateThumbnail(from: imageData, fileName: fileName)
        
        // Save to database
        try databaseService.insertPhoto(photo)
        
        print("📸 PhotoService: Successfully captured photo \(photo.id)")
        return photo
    }
    
    func deletePhoto(_ photo: NavUnitPhoto) async throws {
        print("📸 PhotoService: Deleting photo \(photo.id)")
        
        // Delete from local storage
        do {
            try cacheService.deleteLocalPhoto(fileName: photo.localFileName)
        } catch {
            print("⚠️ PhotoService: Failed to delete local files: \(error)")
        }
        
        // Delete from remote storage if uploaded
        if photo.isUploaded, let supabaseUrl = photo.supabaseUrl {
            do {
                try await supabaseService.deleteRemotePhoto(supabaseUrl: supabaseUrl)
            } catch {
                print("⚠️ PhotoService: Failed to delete remote photo: \(error)")
                // Continue with local deletion even if remote deletion fails
            }
        }
        
        // Delete from database
        try databaseService.deletePhoto(id: photo.id)
        
        print("📸 PhotoService: Successfully deleted photo \(photo.id)")
    }
    
    func getPhotoCount(for navUnitId: String) async throws -> Int {
        return try databaseService.getPhotoCount(for: navUnitId)
    }
    
    // MARK: - Manual Sync Operations
    
    func uploadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus {
        print("📸 PhotoService: Starting manual upload for nav unit \(navUnitId)")
        
        // Get photos pending upload
        let pendingPhotos = try databaseService.getPhotos(for: navUnitId, uploaded: false)
        
        guard !pendingPhotos.isEmpty else {
            print("📸 PhotoService: No photos to upload")
            return try await getSyncStatus(for: navUnitId)
        }
        
        var uploadedCount = 0
        var errors: [PhotoSyncError] = []
        
        for photo in pendingPhotos {
            do {
                // Load image data
                let imageData = try cacheService.loadPhoto(fileName: photo.localFileName)
                
                // Upload to Supabase
                let supabaseUrl = try await supabaseService.uploadPhoto(photo, imageData: imageData)
                
                // Mark as uploaded in database
                try databaseService.markPhotoAsUploaded(id: photo.id, supabaseUrl: supabaseUrl)
                
                uploadedCount += 1
                print("📸 PhotoService: Uploaded photo \(photo.id) (\(uploadedCount)/\(pendingPhotos.count))")
                
            } catch let error as PhotoSyncError {
                errors.append(error)
                print("❌ PhotoService: Failed to upload photo \(photo.id): \(error)")
            } catch {
                errors.append(PhotoSyncError.uploadFailed(photo.localFileName))
                print("❌ PhotoService: Unexpected error uploading photo \(photo.id): \(error)")
            }
        }
        
        let finalStatus = try await getSyncStatus(for: navUnitId)
        
        if errors.isEmpty {
            print("📸 PhotoService: Successfully uploaded all \(uploadedCount) photos")
            return finalStatus
        } else {
            print("📸 PhotoService: Uploaded \(uploadedCount)/\(pendingPhotos.count) photos with \(errors.count) errors")
            // Return status even with errors - partial success
            return finalStatus
        }
    }
    
    func downloadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus {
        print("📸 PhotoService: Starting manual download for nav unit \(navUnitId)")
        
        // Get current user
        guard let session = try? await SupabaseManager.shared.getSession() else {
            throw PhotoSyncError.authenticationFailed
        }
        let user = session.user
        
        // DEBUG: Log the current user ID for comparison
        print("📸 DEBUG: Current user ID for download: \(user.id.uuidString)")
        
        // Get remote photos
        let remotePhotos = try await supabaseService.getRemotePhotos(
            for: navUnitId,
            userId: user.id.uuidString
        )
        
        // Get local photos to check what we already have
        let localPhotos = try databaseService.getPhotos(for: navUnitId)
        let localUrls = Set(localPhotos.compactMap { $0.supabaseUrl })
        
        // Filter out photos we already have
        let photosToDownload = remotePhotos.filter { remotePhoto in
            let remoteUrl = generatePublicUrl(for: remotePhoto)
            return !localUrls.contains(remoteUrl)
        }
        
        guard !photosToDownload.isEmpty else {
            print("📸 PhotoService: No new photos to download")
            return try await getSyncStatus(for: navUnitId)
        }
        
        var downloadedCount = 0
        var errors: [PhotoSyncError] = []
        
        for remotePhoto in photosToDownload {
            do {
                print("📸 PhotoService: Downloading photo \(remotePhoto.id) using storage path: \(remotePhoto.storagePath)")
                
                // Download image data directly using storage path
                let imageData = try await supabaseService.downloadPhotoByPath(storagePath: remotePhoto.storagePath)
                
                // Generate local filename
                let localFileName = NavUnitPhoto.generateFileName(for: navUnitId)
                
                // Save to local storage
                _ = try cacheService.savePhoto(imageData, fileName: localFileName)
                
                // Generate thumbnail
                _ = try cacheService.generateThumbnail(from: imageData, fileName: localFileName)
                
                // Generate the supabase URL for the local record
                let supabaseUrl = generatePublicUrl(for: remotePhoto)
                
                // Create local photo record
                let localPhoto = NavUnitPhoto(
                    id: UUID(uuidString: remotePhoto.id) ?? UUID(),
                    navUnitId: remotePhoto.navUnitId,
                    localFileName: localFileName,
                    supabaseUrl: supabaseUrl,
                    timestamp: remotePhoto.createdAt,
                    isUploaded: true,
                    isSyncedFromCloud: true,
                    userId: remotePhoto.userId
                )
                
                // Save to database
                try databaseService.insertPhoto(localPhoto)
                
                downloadedCount += 1
                print("📸 PhotoService: Downloaded photo \(remotePhoto.id) (\(downloadedCount)/\(photosToDownload.count))")
                
            } catch let error as PhotoSyncError {
                errors.append(error)
                print("❌ PhotoService: Failed to download photo \(remotePhoto.id): \(error)")
            } catch {
                errors.append(PhotoSyncError.downloadFailed(remotePhoto.fileName))
                print("❌ PhotoService: Unexpected error downloading photo \(remotePhoto.id): \(error)")
            }
        }
        
        let finalStatus = try await getSyncStatus(for: navUnitId)
        
        if errors.isEmpty {
            print("📸 PhotoService: Successfully downloaded all \(downloadedCount) photos")
        } else {
            print("📸 PhotoService: Downloaded \(downloadedCount)/\(photosToDownload.count) photos with \(errors.count) errors")
        }
        
        return finalStatus
    }
    
    func getSyncStatus(for navUnitId: String) async throws -> PhotoSyncStatus {
        let allPhotos = try databaseService.getPhotos(for: navUnitId)
        let uploadedPhotos = try databaseService.getPhotos(for: navUnitId, uploaded: true)
        let pendingPhotos = try databaseService.getPhotos(for: navUnitId, uploaded: false)
        
        // Get remote photo count if authenticated
        var cloudPhotos = 0
        if let session = try? await SupabaseManager.shared.getSession() {
            let user = session.user
            do {
                cloudPhotos = try await supabaseService.getPhotoCount(
                    for: navUnitId,
                    userId: user.id.uuidString
                )
            } catch {
                print("⚠️ PhotoService: Failed to get cloud photo count: \(error)")
            }
        }
        
        let downloadedPhotos = allPhotos.filter { $0.isSyncedFromCloud }.count
        
        return PhotoSyncStatus(
            totalPhotos: allPhotos.count,
            uploadedPhotos: uploadedPhotos.count,
            pendingUploads: pendingPhotos.count,
            downloadedPhotos: downloadedPhotos,
            cloudPhotos: cloudPhotos,
            isAtLimit: allPhotos.count >= 10
        )
    }
    
    // MARK: - Photo Data Operations
    
    func loadPhotoImage(_ photo: NavUnitPhoto) async throws -> UIImage {
        let imageData = try cacheService.loadPhoto(fileName: photo.localFileName)
        
        guard let image = UIImage(data: imageData) else {
            throw PhotoSyncError.invalidImageData
        }
        
        return image
    }
    
    func loadThumbnailImage(_ photo: NavUnitPhoto) async throws -> UIImage {
        do {
            let thumbnailData = try cacheService.loadThumbnail(fileName: photo.localFileName)
            
            guard let thumbnail = UIImage(data: thumbnailData) else {
                throw PhotoSyncError.invalidImageData
            }
            
            return thumbnail
            
        } catch {
            // If thumbnail doesn't exist, generate it from the full image
            let fullImage = try await loadPhotoImage(photo)
            let imageData = try cacheService.compressImageForUpload(fullImage)
            _ = try cacheService.generateThumbnail(from: imageData, fileName: photo.localFileName)
            
            // Try loading thumbnail again
            let thumbnailData = try cacheService.loadThumbnail(fileName: photo.localFileName)
            
            guard let thumbnail = UIImage(data: thumbnailData) else {
                throw PhotoSyncError.invalidImageData
            }
            
            return thumbnail
        }
    }
    
    func isAtPhotoLimit(for navUnitId: String) async throws -> Bool {
        let count = try await getPhotoCount(for: navUnitId)
        return count >= 10
    }
    
    // MARK: - Private Helper Methods
    
    private func generatePublicUrl(for remotePhoto: RemotePhoto) -> String {
        // DEBUG: Log the storage path being used
        print("📸 DEBUG: Generating URL for photo \(remotePhoto.id)")
        print("📸 DEBUG: Storage path: '\(remotePhoto.storagePath)'")
        print("📸 DEBUG: User ID: \(remotePhoto.userId)")
        print("📸 DEBUG: Nav Unit ID: \(remotePhoto.navUnitId)")
        print("📸 DEBUG: File name: \(remotePhoto.fileName)")
        
        // Generate the correct Supabase public URL using the client
        do {
            let publicUrl = try SupabaseManager.shared.client.storage
                .from("nav-unit-photos")
                .getPublicURL(path: remotePhoto.storagePath)
                .absoluteString
            print("📸 DEBUG: Generated public URL: \(publicUrl)")
            return publicUrl
        } catch {
            print("❌ PhotoService: Failed to generate public URL for \(remotePhoto.storagePath): \(error)")
            // Fallback to manual URL construction if getPublicURL fails
            let fallbackUrl = "https://lgdsvefqqorvnvkiobth.supabase.co/storage/v1/object/public/nav-unit-photos/\(remotePhoto.storagePath)"
            print("📸 DEBUG: Using fallback URL: \(fallbackUrl)")
            return fallbackUrl
        }
    }
}