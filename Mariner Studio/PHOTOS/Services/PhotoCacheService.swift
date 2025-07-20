//
//  PhotoCacheService.swift
//  Mariner Studio
//
//  Local photo caching and file management service
//

import Foundation
import UIKit

class PhotoCacheServiceImpl: PhotoCacheService {
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let photosDirectory: URL
    private let thumbnailDirectory: URL
    
    // MARK: - Constants
    
    private struct Constants {
        static let photosFolder = "NavUnitPhotos"
        static let thumbnailsFolder = "thumbnails"
        static let thumbnailSize = CGSize(width: 150, height: 150)
        static let maxUploadSize: Int = 2 * 1024 * 1024 // 2MB
        static let compressionQuality: CGFloat = 0.8
    }
    
    // MARK: - Initialization
    
    init() throws {
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.photosDirectory = documentsDirectory.appendingPathComponent(Constants.photosFolder)
        self.thumbnailDirectory = photosDirectory.appendingPathComponent(Constants.thumbnailsFolder)
        
        try setupDirectories()
        
        print("📸 PhotoCacheService: Initialized with directories:")
        print("📸   Photos: \(photosDirectory.path)")
        print("📸   Thumbnails: \(thumbnailDirectory.path)")
    }
    
    // MARK: - Directory Management
    
    func setupDirectories() throws {
        // Create photos directory
        if !fileManager.fileExists(atPath: photosDirectory.path) {
            try fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            print("📸 PhotoCacheService: Created photos directory")
        }
        
        // Create thumbnails directory
        if !fileManager.fileExists(atPath: thumbnailDirectory.path) {
            try fileManager.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)
            print("📸 PhotoCacheService: Created thumbnails directory")
        }
    }
    
    // MARK: - Photo Storage
    
    func savePhoto(_ imageData: Data, fileName: String) throws -> URL {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        
        try imageData.write(to: fileURL)
        print("📸 PhotoCacheService: Saved photo \(fileName) (\(imageData.count) bytes)")
        
        return fileURL
    }
    
    func loadPhoto(fileName: String) throws -> Data {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw PhotoSyncError.fileNotFound(fileName)
        }
        
        let data = try Data(contentsOf: fileURL)
        print("📸 PhotoCacheService: Loaded photo \(fileName) (\(data.count) bytes)")
        
        return data
    }
    
    // MARK: - Thumbnail Management
    
    func generateThumbnail(from imageData: Data, fileName: String) throws -> URL {
        guard let originalImage = UIImage(data: imageData) else {
            throw PhotoSyncError.invalidImageData
        }
        
        // Generate thumbnail
        let thumbnailImage = try resizeImage(originalImage, to: Constants.thumbnailSize)
        
        guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: Constants.compressionQuality) else {
            throw PhotoSyncError.compressionFailed
        }
        
        // Save thumbnail
        let thumbnailFileName = "thumb_" + fileName
        let thumbnailURL = thumbnailDirectory.appendingPathComponent(thumbnailFileName)
        
        try thumbnailData.write(to: thumbnailURL)
        print("📸 PhotoCacheService: Generated thumbnail for \(fileName) (\(thumbnailData.count) bytes)")
        
        return thumbnailURL
    }
    
    func loadThumbnail(fileName: String) throws -> Data {
        let thumbnailFileName = "thumb_" + fileName
        let thumbnailURL = thumbnailDirectory.appendingPathComponent(thumbnailFileName)
        
        guard fileManager.fileExists(atPath: thumbnailURL.path) else {
            throw PhotoSyncError.fileNotFound(thumbnailFileName)
        }
        
        let data = try Data(contentsOf: thumbnailURL)
        print("📸 PhotoCacheService: Loaded thumbnail \(thumbnailFileName) (\(data.count) bytes)")
        
        return data
    }
    
    // MARK: - Photo Deletion
    
    func deleteLocalPhoto(fileName: String) throws {
        // Delete main photo
        let photoURL = photosDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: photoURL.path) {
            try fileManager.removeItem(at: photoURL)
            print("📸 PhotoCacheService: Deleted photo \(fileName)")
        }
        
        // Delete thumbnail
        let thumbnailFileName = "thumb_" + fileName
        let thumbnailURL = thumbnailDirectory.appendingPathComponent(thumbnailFileName)
        if fileManager.fileExists(atPath: thumbnailURL.path) {
            try fileManager.removeItem(at: thumbnailURL)
            print("📸 PhotoCacheService: Deleted thumbnail \(thumbnailFileName)")
        }
    }
    
    func clearCache(for navUnitId: String) throws {
        let contents = try fileManager.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: nil)
        
        for fileURL in contents {
            let fileName = fileURL.lastPathComponent
            if fileName.contains("navunit_\(navUnitId)_") {
                try fileManager.removeItem(at: fileURL)
                print("📸 PhotoCacheService: Cleared cached file \(fileName)")
            }
        }
        
        // Clear thumbnails too
        let thumbnailContents = try fileManager.contentsOfDirectory(at: thumbnailDirectory, includingPropertiesForKeys: nil)
        
        for fileURL in thumbnailContents {
            let fileName = fileURL.lastPathComponent
            if fileName.contains("navunit_\(navUnitId)_") {
                try fileManager.removeItem(at: fileURL)
                print("📸 PhotoCacheService: Cleared cached thumbnail \(fileName)")
            }
        }
    }
    
    // MARK: - Image Processing
    
    func compressImageForUpload(_ image: UIImage) throws -> Data {
        // Start with high quality and reduce if needed
        var compressionQuality: CGFloat = Constants.compressionQuality
        var imageData: Data?
        
        repeat {
            imageData = image.jpegData(compressionQuality: compressionQuality)
            compressionQuality -= 0.1
        } while (imageData?.count ?? 0) > Constants.maxUploadSize && compressionQuality > 0.1
        
        guard let finalData = imageData, finalData.count <= Constants.maxUploadSize else {
            throw PhotoSyncError.compressionFailed
        }
        
        print("📸 PhotoCacheService: Compressed image to \(finalData.count) bytes (quality: \(compressionQuality + 0.1))")
        return finalData
    }
    
    // MARK: - Private Helper Methods
    
    private func resizeImage(_ image: UIImage, to size: CGSize) throws -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        
        return resizedImage
    }
}

// MARK: - Error Extensions

extension PhotoSyncError {
    static func fileSystemError(_ error: Error) -> PhotoSyncError {
        return .supabaseError("File system error: \(error.localizedDescription)")
    }
}