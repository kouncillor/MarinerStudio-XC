
import Foundation
import UIKit

// Protocol for file storage operations
protocol FileStorageService {
    func savePhoto(_ image: UIImage, for navUnitId: String) async throws -> (filePath: String, fileName: String)
    func loadImage(from filePath: String) async -> UIImage?
    func generateThumbnail(from filePath: String, maxSize: CGSize) async -> UIImage?
    func deletePhoto(at filePath: String) async throws
    func createNavUnitDirectory(for navUnitId: String) throws -> URL
}

// Implementation of file storage service
class FileStorageServiceImpl: FileStorageService {
    
    private let documentsDirectory: URL
    private let photosBaseDirectory: URL
    
    init() throws {
        // Get documents directory
        documentsDirectory = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        
        // Create photos base directory
        photosBaseDirectory = documentsDirectory.appendingPathComponent("NavUnitPhotos")
        
        // Ensure the base directory exists
        try FileManager.default.createDirectory(
            at: photosBaseDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        print("📁 FileStorageService: Initialized with base directory: \(photosBaseDirectory.path)")
    }
    
    func savePhoto(_ image: UIImage, for navUnitId: String) async throws -> (filePath: String, fileName: String) {
        // Create directory for this nav unit
        let navUnitDirectory = try createNavUnitDirectory(for: navUnitId)
        
        // Generate truly unique filename with UUID + timestamp + navUnitId
        let uuid = UUID().uuidString.prefix(8) // First 8 chars of UUID
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let cleanTimestamp = timestamp.replacingOccurrences(of: ":", with: "-")
        let fileName = "\(navUnitId)_\(cleanTimestamp)_\(uuid).jpg"
        let fileURL = navUnitDirectory.appendingPathComponent(fileName)
        
        // Convert image to JPEG data (use default quality)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FileStorageError.imageConversionFailed
        }
        
        // Write to file
        try imageData.write(to: fileURL)
        
        // Return RELATIVE path from Documents directory
        let relativePath = "NavUnitPhotos/\(navUnitId)/\(fileName)"
        
        print("💾 FileStorageService: Saved photo to: \(fileURL.path)")
        print("💾 FileStorageService: Relative path stored: \(relativePath)")
        print("🔍 FileStorageService: Unique filename: \(fileName)")
        
        return (filePath: relativePath, fileName: fileName)
    }
    
    func loadImage(from filePath: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Convert relative path to absolute path
                let absolutePath = self.getAbsolutePath(from: filePath)
                print("🔍 FileStorageService: Converting relative path '\(filePath)' to absolute: '\(absolutePath)'")
                
                // Check if file exists
                let fileExists = FileManager.default.fileExists(atPath: absolutePath)
                print("🔍 FileStorageService: File exists at path: \(fileExists)")
                
                let image = UIImage(contentsOfFile: absolutePath)
                
                if let image = image {
                    print("✅ FileStorageService: Successfully loaded image from: \(absolutePath)")
                } else {
                    print("❌ FileStorageService: Failed to load image from: \(absolutePath)")
                }
                
                DispatchQueue.main.async {
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    func generateThumbnail(from filePath: String, maxSize: CGSize = CGSize(width: 200, height: 200)) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Convert relative path to absolute path
                let absolutePath = self.getAbsolutePath(from: filePath)
                print("🔍 FileStorageService: Generating thumbnail from relative path '\(filePath)' -> absolute: '\(absolutePath)'")
                
                guard let originalImage = UIImage(contentsOfFile: absolutePath) else {
                    print("❌ FileStorageService: Failed to load original image for thumbnail generation: \(absolutePath)")
                    DispatchQueue.main.async {
                        continuation.resume(returning: nil)
                    }
                    return
                }
                
                print("✅ FileStorageService: Original image loaded, generating thumbnail...")
                
                // Calculate thumbnail size while maintaining aspect ratio
                let aspectRatio = originalImage.size.width / originalImage.size.height
                var thumbnailSize = maxSize
                
                if aspectRatio > 1 {
                    // Landscape
                    thumbnailSize.height = maxSize.width / aspectRatio
                } else {
                    // Portrait or square
                    thumbnailSize.width = maxSize.height * aspectRatio
                }
                
                // Create thumbnail
                let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
                let thumbnail = renderer.image { _ in
                    originalImage.draw(in: CGRect(origin: .zero, size: thumbnailSize))
                }
                
                print("✅ FileStorageService: Thumbnail generated successfully")
                
                DispatchQueue.main.async {
                    continuation.resume(returning: thumbnail)
                }
            }
        }
    }
    
    func deletePhoto(at filePath: String) async throws {
        // Convert relative path to absolute path
        let absolutePath = getAbsolutePath(from: filePath)
        let fileURL = URL(fileURLWithPath: absolutePath)
        
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("🗑️ FileStorageService: Deleted photo at: \(absolutePath)")
                    continuation.resume()
                } catch {
                    print("❌ FileStorageService: Failed to delete photo: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func createNavUnitDirectory(for navUnitId: String) throws -> URL {
        let navUnitDirectory = photosBaseDirectory.appendingPathComponent(navUnitId)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: navUnitDirectory.path) {
            try FileManager.default.createDirectory(
                at: navUnitDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("📁 FileStorageService: Created directory for nav unit: \(navUnitId)")
        }
        
        return navUnitDirectory
    }
    
    // MARK: - Helper Methods
    
    private func getAbsolutePath(from relativePath: String) -> String {
        // If it's already an absolute path (starts with /), return as-is for backward compatibility
        if relativePath.hasPrefix("/") {
            return relativePath
        }
        
        // Otherwise, treat it as relative to Documents directory
        return documentsDirectory.appendingPathComponent(relativePath).path
    }
}

// Error types for file storage operations
enum FileStorageError: Error, LocalizedError {
    case imageConversionFailed
    case directoryCreationFailed
    case fileNotFound
    case deleteOperationFailed
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to file format"
        case .directoryCreationFailed:
            return "Failed to create photo directory"
        case .fileNotFound:
            return "Photo file not found"
        case .deleteOperationFailed:
            return "Failed to delete photo file"
        }
    }
}
