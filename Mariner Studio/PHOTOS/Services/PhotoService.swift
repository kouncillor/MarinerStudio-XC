//
//  PhotoService.swift
//  Mariner Studio
//
//  Main photo service protocol for nav unit photo management
//

import Foundation
import UIKit

// MARK: - Photo Service Protocol

protocol PhotoService {
    // MARK: - Local Photo Operations
    
    /// Get all photos for a specific nav unit
    func getPhotos(for navUnitId: String) async throws -> [NavUnitPhoto]
    
    /// Take a new photo for a nav unit
    func takePhoto(for navUnitId: String, image: UIImage) async throws -> NavUnitPhoto
    
    /// Delete a photo (local and remote if uploaded)
    func deletePhoto(_ photo: NavUnitPhoto) async throws
    
    /// Get photo count for a nav unit
    func getPhotoCount(for navUnitId: String) async throws -> Int
    
    // MARK: - Manual Sync Operations
    
    /// Upload all pending photos for a nav unit (manual trigger only)
    func uploadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus
    
    /// Download all available photos for a nav unit (manual trigger only)
    func downloadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus
    
    /// Get current sync status for a nav unit
    func getSyncStatus(for navUnitId: String) async throws -> PhotoSyncStatus
    
    // MARK: - Photo Data Operations
    
    /// Load photo image data
    func loadPhotoImage(_ photo: NavUnitPhoto) async throws -> UIImage
    
    /// Load thumbnail image data
    func loadThumbnailImage(_ photo: NavUnitPhoto) async throws -> UIImage
    
    /// Check if nav unit is at photo limit (10 photos)
    func isAtPhotoLimit(for navUnitId: String) async throws -> Bool
}

// MARK: - Photo Cache Service Protocol

protocol PhotoCacheService {
    /// Save photo to local storage
    func savePhoto(_ imageData: Data, fileName: String) throws -> URL
    
    /// Load photo from local storage
    func loadPhoto(fileName: String) throws -> Data
    
    /// Generate and save thumbnail
    func generateThumbnail(from imageData: Data, fileName: String) throws -> URL
    
    /// Load thumbnail from cache
    func loadThumbnail(fileName: String) throws -> Data
    
    /// Delete local photo file
    func deleteLocalPhoto(fileName: String) throws
    
    /// Clear all cached photos for a nav unit
    func clearCache(for navUnitId: String) throws
    
    /// Compress image for upload
    func compressImageForUpload(_ image: UIImage) throws -> Data
    
    /// Setup required directories
    func setupDirectories() throws
}

// MARK: - Photo Database Service Protocol

protocol PhotoDatabaseService {
    /// Insert new photo record
    func insertPhoto(_ photo: NavUnitPhoto) throws
    
    /// Get all photos for a nav unit
    func getPhotos(for navUnitId: String) throws -> [NavUnitPhoto]
    
    /// Update photo record
    func updatePhoto(_ photo: NavUnitPhoto) throws
    
    /// Delete photo record
    func deletePhoto(id: UUID) throws
    
    /// Get photo count for nav unit
    func getPhotoCount(for navUnitId: String) throws -> Int
    
    /// Get photos by upload status
    func getPhotos(for navUnitId: String, uploaded: Bool) throws -> [NavUnitPhoto]
    
    /// Mark photo as uploaded
    func markPhotoAsUploaded(id: UUID, supabaseUrl: String) throws
    
    /// Mark photo as synced from cloud
    func markPhotoAsSyncedFromCloud(id: UUID) throws
}

// MARK: - Photo Supabase Service Protocol

protocol PhotoSupabaseService {
    /// Upload photo to Supabase storage
    func uploadPhoto(_ photo: NavUnitPhoto, imageData: Data) async throws -> String
    
    /// Download photo from Supabase storage
    func downloadPhoto(supabaseUrl: String) async throws -> Data
    
    /// Download photo from Supabase storage using storage path directly
    func downloadPhotoByPath(storagePath: String) async throws -> Data
    
    /// Get remote photos for nav unit
    func getRemotePhotos(for navUnitId: String, userId: String) async throws -> [RemotePhoto]
    
    /// Delete remote photo
    func deleteRemotePhoto(supabaseUrl: String) async throws
    
    /// Check photo count for nav unit (enforce 10 photo limit)
    func getPhotoCount(for navUnitId: String, userId: String) async throws -> Int
    
    /// Delete oldest photo if at limit
    func enforcePhotoLimit(for navUnitId: String, userId: String) async throws
}