
import Foundation
import CloudKit
import SwiftUI

// Model representing a photo stored in CloudKit
struct CloudPhoto {
    let recordID: CKRecord.ID?
    let navUnitId: String
    let fileName: String
    let imageData: Data
    let description: String?
    let createdAt: Date
    let localPhotoId: Int
    
    // CloudKit record type name
    static let recordType = "NavUnitPhoto"
    
    // CloudKit field names
    struct FieldKeys {
        static let navUnitId = "navUnitId"
        static let fileName = "fileName"
        static let imageData = "imageData"
        static let description = "description"
        static let createdAt = "createdAt"
        static let localPhotoId = "localPhotoId"
    }
    
    // Initialize from local NavUnitPhoto
    init(from navUnitPhoto: NavUnitPhoto, imageData: Data) {
        self.recordID = nil
        self.navUnitId = navUnitPhoto.navUnitId
        self.fileName = navUnitPhoto.fileName
        self.imageData = imageData
        self.description = navUnitPhoto.description
        self.createdAt = navUnitPhoto.createdAt
        self.localPhotoId = navUnitPhoto.id
    }
    
    // Initialize from CloudKit record
    init?(from record: CKRecord) {
        guard let navUnitId = record[CloudPhoto.FieldKeys.navUnitId] as? String,
              let fileName = record[CloudPhoto.FieldKeys.fileName] as? String,
              let imageAsset = record[CloudPhoto.FieldKeys.imageData] as? CKAsset,
              let createdAt = record[CloudPhoto.FieldKeys.createdAt] as? Date,
              let localPhotoId = record[CloudPhoto.FieldKeys.localPhotoId] as? Int else {
            return nil
        }
        
        // Read image data from CKAsset
        guard let fileURL = imageAsset.fileURL,
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        self.recordID = record.recordID
        self.navUnitId = navUnitId
        self.fileName = fileName
        self.imageData = data
        self.description = record[CloudPhoto.FieldKeys.description] as? String
        self.createdAt = createdAt
        self.localPhotoId = localPhotoId
    }
    
    // Convert to CloudKit record
    func toCKRecord() -> CKRecord {
        print("🔄 CloudPhoto: toCKRecord() started")
        
        let record = CKRecord(recordType: CloudPhoto.recordType)
        print("✅ CloudPhoto: Created CKRecord with type: \(CloudPhoto.recordType)")
        
        // Set basic fields
        print("📝 CloudPhoto: Setting basic fields...")
        record[CloudPhoto.FieldKeys.navUnitId] = navUnitId
        print("📝   navUnitId: \(navUnitId)")
        
        record[CloudPhoto.FieldKeys.fileName] = fileName
        print("📝   fileName: \(fileName)")
        
        record[CloudPhoto.FieldKeys.description] = description
        print("📝   description: \(description ?? "nil")")
        
        record[CloudPhoto.FieldKeys.createdAt] = createdAt
        print("📝   createdAt: \(createdAt)")
        
        record[CloudPhoto.FieldKeys.localPhotoId] = localPhotoId
        print("📝   localPhotoId: \(localPhotoId)")
        
        print("🖼️ CloudPhoto: Processing image data...")
        print("🖼️   Image data size: \(imageData.count) bytes")
        
        // Create temporary file for image data
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        print("📁 CloudPhoto: Temp file URL: \(tempFileURL.path)")
        
        do {
            print("💾 CloudPhoto: Writing image data to temp file...")
            try imageData.write(to: tempFileURL)
            print("✅ CloudPhoto: Image data written successfully")
            
            // Verify file was written
            let fileExists = FileManager.default.fileExists(atPath: tempFileURL.path)
            print("🔍 CloudPhoto: Temp file exists after write: \(fileExists)")
            
            if fileExists {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: tempFileURL.path)
                    let fileSize = attributes[.size] as? NSNumber
                    print("🔍 CloudPhoto: Temp file size: \(fileSize?.intValue ?? 0) bytes")
                } catch {
                    print("⚠️ CloudPhoto: Could not read temp file attributes: \(error.localizedDescription)")
                }
            }
            
            print("🔗 CloudPhoto: Creating CKAsset...")
            let asset = CKAsset(fileURL: tempFileURL)
            print("✅ CloudPhoto: CKAsset created")
            print("🔍 CloudPhoto: CKAsset fileURL: \(asset.fileURL?.path ?? "nil")")
            
            record[CloudPhoto.FieldKeys.imageData] = asset
            print("✅ CloudPhoto: CKAsset assigned to record")
            
        } catch {
            print("💥 CloudPhoto: FAILED to create temporary file for image!")
            print("💥   Error: \(error.localizedDescription)")
            
            if let nsError = error as? NSError {
                print("💥   NSError domain: \(nsError.domain)")
                print("💥   NSError code: \(nsError.code)")
            }
            
            print("💥   Temp URL: \(tempFileURL.path)")
            print("💥   Image data size: \(imageData.count)")
            
            // Check if directory exists
            let dirExists = FileManager.default.fileExists(atPath: tempDirectory.path)
            print("💥   Temp directory exists: \(dirExists)")
            print("💥   Temp directory path: \(tempDirectory.path)")
            
            // Check if we can write to temp directory
            let isWritable = FileManager.default.isWritableFile(atPath: tempDirectory.path)
            print("💥   Temp directory writable: \(isWritable)")
            
            // Try to get directory attributes
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: tempDirectory.path)
                print("💥   Temp directory attributes: \(attributes)")
            } catch {
                print("💥   Could not read temp directory attributes: \(error.localizedDescription)")
            }
            
            // Check available space
            do {
                let resourceValues = try tempDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
                if let capacity = resourceValues.volumeAvailableCapacity {
                    print("💥   Available space: \(capacity) bytes")
                }
            } catch {
                print("💥   Could not check available space: \(error.localizedDescription)")
            }
        }
        
        print("✅ CloudPhoto: toCKRecord() completed")
        return record
    }
    
    // Convert CloudPhoto back to NavUnitPhoto for local storage
    func toNavUnitPhoto(filePath: String) -> NavUnitPhoto {
        return NavUnitPhoto(
            id: 0, // Will be assigned by database
            navUnitId: navUnitId,
            filePath: filePath,
            fileName: fileName,
            thumbPath: nil,
            description: description,
            createdAt: createdAt,
            cloudRecordID: recordID?.recordName // NEW: Include CloudKit record ID
        )
    }
    
    // NEW: Enhanced version that explicitly sets the CloudKit record ID
    func toNavUnitPhoto(filePath: String, recordID: String?) -> NavUnitPhoto {
        return NavUnitPhoto(
            id: 0, // Will be assigned by database
            navUnitId: navUnitId,
            filePath: filePath,
            fileName: fileName,
            thumbPath: nil,
            description: description,
            createdAt: createdAt,
            cloudRecordID: recordID ?? self.recordID?.recordName // Use provided recordID or fall back to self.recordID
        )
    }
    
    // NEW: Convenience method to check if this CloudPhoto has a valid record ID
    var hasValidRecordID: Bool {
        return recordID != nil && !(recordID?.recordName.isEmpty ?? true)
    }
    
    // NEW: Convenience method to get the record name safely
    var recordName: String? {
        return recordID?.recordName
    }
    
    // NEW: Create a copy with a new record ID (useful for updating after upload)
    func withRecordID(_ newRecordID: CKRecord.ID) -> CloudPhoto {
        var mutableSelf = self
        // Since this is a struct, we need to use a different approach
        return CloudPhoto(
            recordID: newRecordID,
            navUnitId: navUnitId,
            fileName: fileName,
            imageData: imageData,
            description: description,
            createdAt: createdAt,
            localPhotoId: localPhotoId
        )
    }
    
    // Private initializer for creating copies with new record IDs
    private init(
        recordID: CKRecord.ID?,
        navUnitId: String,
        fileName: String,
        imageData: Data,
        description: String?,
        createdAt: Date,
        localPhotoId: Int
    ) {
        self.recordID = recordID
        self.navUnitId = navUnitId
        self.fileName = fileName
        self.imageData = imageData
        self.description = description
        self.createdAt = createdAt
        self.localPhotoId = localPhotoId
    }
}

// Sync status for photos
enum PhotoSyncStatus {
    case notSynced      // Photo exists only locally
    case syncing        // Currently uploading/downloading
    case synced         // Successfully synced with iCloud
    case failed         // Sync failed
    
    var displayText: String {
        switch self {
        case .notSynced: return "Not synced"
        case .syncing: return "Syncing..."
        case .synced: return "Synced"
        case .failed: return "Sync failed"
        }
    }
    
    var iconName: String {
        switch self {
        case .notSynced: return "icloud"
        case .syncing: return "icloud.and.arrow.up"
        case .synced: return "icloud.fill"
        case .failed: return "icloud.slash"
        }
    }
    
    // NEW: Color for UI display
    var color: Color {
        switch self {
        case .notSynced: return .gray
        case .syncing: return .blue
        case .synced: return .green
        case .failed: return .red
        }
    }
    
    // NEW: Priority for sorting (higher number = higher priority)
    var priority: Int {
        switch self {
        case .failed: return 4      // Show failed syncs first
        case .syncing: return 3     // Then in-progress syncs
        case .notSynced: return 2   // Then unsynced photos
        case .synced: return 1      // Finally synced photos
        }
    }
}
