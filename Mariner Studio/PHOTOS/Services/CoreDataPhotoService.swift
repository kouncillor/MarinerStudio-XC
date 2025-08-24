//
//  CoreDataPhotoService.swift
//  Mariner Studio
//
//  Core Data + CloudKit implementation of PhotoService
//  Replaces complex Supabase photo management with simple Core Data operations
//

import Foundation
import UIKit

class CoreDataPhotoService: PhotoService {
    
    // MARK: - Properties
    
    private let coreDataManager: CoreDataManager
    
    // MARK: - Initialization
    
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        print("📸 CoreDataPhotoService: Initialized with Core Data + CloudKit")
    }
    
    // MARK: - Local Photo Operations
    
    func getPhotos(for navUnitId: String) async throws -> [NavUnitPhoto] {
        let coreDataPhotos = coreDataManager.getNavUnitPhotos(for: navUnitId)
        return coreDataPhotos.map { convertToNavUnitPhoto($0) }
    }
    
    func takePhoto(for navUnitId: String, image: UIImage) async throws -> NavUnitPhoto {
        print("📸 CoreDataPhotoService: Taking new photo for nav unit \(navUnitId)")
        
        // Compress image for storage
        let imageData = try compressImageForStorage(image)
        let thumbnailData = try generateThumbnail(from: image)
        
        // Save to Core Data (CloudKit will sync automatically)
        coreDataManager.addNavUnitPhoto(
            navUnitId: navUnitId,
            imageData: imageData,
            thumbnailData: thumbnailData
        )
        
        // Get the most recently added photo for this nav unit
        let coreDataPhotos = coreDataManager.getNavUnitPhotos(for: navUnitId)
        guard let newestPhoto = coreDataPhotos.sorted(by: { $0.timestamp > $1.timestamp }).first else {
            throw PhotoSyncError.invalidImageData
        }
        
        // Create NavUnitPhoto representation using the actual Core Data entity
        let photo = convertToNavUnitPhoto(newestPhoto)
        
        print("📸 CoreDataPhotoService: Successfully captured photo \(photo.id)")
        return photo
    }
    
    func deletePhoto(_ photo: NavUnitPhoto) async throws {
        print("📸 CoreDataPhotoService: Deleting photo \(photo.id)")
        
        // Find and delete from Core Data
        coreDataManager.removeNavUnitPhoto(photoId: photo.id)
        
        print("📸 CoreDataPhotoService: Successfully deleted photo \(photo.id)")
    }
    
    func getPhotoCount(for navUnitId: String) async throws -> Int {
        return coreDataManager.getNavUnitPhotoCount(for: navUnitId)
    }
    
    // MARK: - Manual Sync Operations (No longer needed with CloudKit)
    
    func uploadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus {
        // CloudKit handles sync automatically - return current status
        return PhotoSyncStatus(
            totalPhotos: try await getPhotoCount(for: navUnitId),
            uploadedPhotos: try await getPhotoCount(for: navUnitId), // All photos are "uploaded" with CloudKit
            pendingUploads: 0, // No pending uploads with CloudKit
            downloadedPhotos: 0, // No distinction needed
            cloudPhotos: try await getPhotoCount(for: navUnitId),
            isAtLimit: false // No limit with CloudKit
        )
    }
    
    func downloadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus {
        // CloudKit handles sync automatically - return current status
        return try await getSyncStatus(for: navUnitId)
    }
    
    func getSyncStatus(for navUnitId: String) async throws -> PhotoSyncStatus {
        let totalPhotos = try await getPhotoCount(for: navUnitId)
        
        return PhotoSyncStatus(
            totalPhotos: totalPhotos,
            uploadedPhotos: totalPhotos, // All photos are synced with CloudKit
            pendingUploads: 0, // No pending uploads
            downloadedPhotos: 0, // No distinction needed
            cloudPhotos: totalPhotos,
            isAtLimit: false // No photo limit with CloudKit
        )
    }
    
    // MARK: - Photo Data Operations
    
    func loadPhotoImage(_ photo: NavUnitPhoto) async throws -> UIImage {
        guard let coreDataPhoto = coreDataManager.getNavUnitPhoto(by: photo.id),
              let imageData = coreDataPhoto.imageData,
              let image = UIImage(data: imageData) else {
            throw PhotoSyncError.invalidImageData
        }
        
        return image
    }
    
    func loadThumbnailImage(_ photo: NavUnitPhoto) async throws -> UIImage {
        guard let coreDataPhoto = coreDataManager.getNavUnitPhoto(by: photo.id),
              let thumbnailData = coreDataPhoto.thumbnailData,
              let thumbnail = UIImage(data: thumbnailData) else {
            throw PhotoSyncError.invalidImageData
        }
        
        return thumbnail
    }
    
    func isAtPhotoLimit(for navUnitId: String) async throws -> Bool {
        // No photo limit with CloudKit
        return false
    }
    
    // MARK: - Private Helper Methods
    
    private func convertToNavUnitPhoto(_ coreDataPhoto: NavUnitPhotoEntity) -> NavUnitPhoto {
        return NavUnitPhoto(
            id: coreDataPhoto.id,
            navUnitId: coreDataPhoto.navUnitId,
            localFileName: "coredata_\(coreDataPhoto.id).jpg", // Not actually used
            timestamp: coreDataPhoto.timestamp,
            isUploaded: true, // CloudKit handles sync
            isSyncedFromCloud: true
        )
    }
    
    private func compressImageForStorage(_ image: UIImage) throws -> Data {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw PhotoSyncError.invalidImageData
        }
        return imageData
    }
    
    private func generateThumbnail(from image: UIImage) throws -> Data {
        let thumbnailSize = CGSize(width: 150, height: 150)
        
        UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        let thumbnailImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let thumbnail = thumbnailImage,
              let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
            throw PhotoSyncError.invalidImageData
        }
        
        return thumbnailData
    }
}