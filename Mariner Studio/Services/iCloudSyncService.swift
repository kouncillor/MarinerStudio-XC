////
////  iCloudSyncService.swift
////  Mariner Studio
////
////  Created by Timothy Russell on 5/31/25.
////
//
//
//import Foundation
//import CloudKit
//
//// Protocol for iCloud sync operations
//protocol iCloudSyncService {
//    var isEnabled: Bool { get set }
//    var accountStatus: CKAccountStatus { get }
//    
//    func checkAccountStatus() async -> CKAccountStatus
//    func uploadPhoto(_ photo: NavUnitPhoto, imageData: Data) async throws -> String
//    func downloadPhotos(for navUnitId: String) async throws -> [CloudPhoto]
//    func deletePhoto(recordID: String) async throws
//    func syncAllLocalPhotos() async
//}
//
//// Implementation of iCloud sync service
//class iCloudSyncServiceImpl: ObservableObject, iCloudSyncService {
//    
//    // MARK: - Properties
//    @Published var isEnabled: Bool {
//        didSet {
//            UserDefaults.standard.set(isEnabled, forKey: "iCloudSyncEnabled")
//            if isEnabled {
//                Task {
//                    await syncAllLocalPhotos()
//                }
//            }
//        }
//    }
//    
//    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
//    
//    private let container: CKContainer
//    private let privateDatabase: CKDatabase
//    private let fileStorageService: FileStorageService
//    
//    // Track sync status for photos
//    private var photoSyncStatus: [Int: PhotoSyncStatus] = [:]
//    
//    // MARK: - Initialization
//    init(fileStorageService: FileStorageService) {
//        self.fileStorageService = fileStorageService
//        self.container = CKContainer.default()
//        self.privateDatabase = container.privateCloudDatabase
//        self.isEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
//        
//        print("☁️ iCloudSyncService: Initialized with sync enabled: \(isEnabled)")
//        
//        // Check account status on init
//        Task {
//            await checkAccountStatus()
//        }
//    }
//    
//    // MARK: - Account Management
//    @discardableResult
//    func checkAccountStatus() async -> CKAccountStatus {
//        do {
//            let status = try await container.accountStatus()
//            await MainActor.run {
//                self.accountStatus = status
//            }
//            
//            switch status {
//            case .available:
//                print("✅ iCloudSyncService: iCloud account is available")
//            case .noAccount:
//                print("❌ iCloudSyncService: No iCloud account signed in")
//            case .restricted:
//                print("⚠️ iCloudSyncService: iCloud account is restricted")
//            case .couldNotDetermine:
//                print("❓ iCloudSyncService: Could not determine iCloud account status")
//            case .temporarilyUnavailable:
//                print("⏳ iCloudSyncService: iCloud is temporarily unavailable")
//            @unknown default:
//                print("❓ iCloudSyncService: Unknown iCloud account status")
//            }
//            
//            return status
//        } catch {
//            print("❌ iCloudSyncService: Error checking account status: \(error.localizedDescription)")
//            await MainActor.run {
//                self.accountStatus = .couldNotDetermine
//            }
//            return .couldNotDetermine
//        }
//    }
//    
//    // MARK: - Upload Operations
//    func uploadPhoto(_ photo: NavUnitPhoto, imageData: Data) async throws -> String {
//        guard isEnabled else {
//            throw iCloudSyncError.syncDisabled
//        }
//        
//        guard accountStatus == .available else {
//            throw iCloudSyncError.accountNotAvailable
//        }
//        
//        print("☁️ iCloudSyncService: Uploading photo \(photo.id) to iCloud")
//        
//        // Update sync status
//        await MainActor.run {
//            photoSyncStatus[photo.id] = .syncing
//        }
//        
//        do {
//            let cloudPhoto = CloudPhoto(from: photo, imageData: imageData)
//            let record = cloudPhoto.toCKRecord()
//            
//            let savedRecord = try await privateDatabase.save(record)
//            let recordID = savedRecord.recordID.recordName
//            
//            await MainActor.run {
//                photoSyncStatus[photo.id] = .synced
//            }
//            
//            print("✅ iCloudSyncService: Successfully uploaded photo \(photo.id) with record ID: \(recordID)")
//            return recordID
//            
//        } catch {
//            await MainActor.run {
//                photoSyncStatus[photo.id] = .failed
//            }
//            print("❌ iCloudSyncService: Failed to upload photo \(photo.id): \(error.localizedDescription)")
//            throw iCloudSyncError.uploadFailed(error)
//        }
//    }
//    
//    // MARK: - Download Operations
//    func downloadPhotos(for navUnitId: String) async throws -> [CloudPhoto] {
//        guard isEnabled else {
//            throw iCloudSyncError.syncDisabled
//        }
//        
//        guard accountStatus == .available else {
//            throw iCloudSyncError.accountNotAvailable
//        }
//        
//        print("☁️ iCloudSyncService: Downloading photos for nav unit: \(navUnitId)")
//        
//        let predicate = NSPredicate(format: "navUnitId == %@", navUnitId)
//        let query = CKQuery(recordType: CloudPhoto.recordType, predicate: predicate)
//        
//        do {
//            let (matchResults, _) = try await privateDatabase.records(matching: query)
//            var cloudPhotos: [CloudPhoto] = []
//            
//            for (_, result) in matchResults {
//                switch result {
//                case .success(let record):
//                    if let cloudPhoto = CloudPhoto(from: record) {
//                        cloudPhotos.append(cloudPhoto)
//                    }
//                case .failure(let error):
//                    print("❌ iCloudSyncService: Failed to process record: \(error.localizedDescription)")
//                }
//            }
//            
//            print("✅ iCloudSyncService: Downloaded \(cloudPhotos.count) photos for nav unit: \(navUnitId)")
//            return cloudPhotos
//            
//        } catch {
//            print("❌ iCloudSyncService: Failed to download photos: \(error.localizedDescription)")
//            throw iCloudSyncError.downloadFailed(error)
//        }
//    }
//    
//    // MARK: - Delete Operations
//    func deletePhoto(recordID: String) async throws {
//        guard isEnabled else {
//            throw iCloudSyncError.syncDisabled
//        }
//        
//        guard accountStatus == .available else {
//            throw iCloudSyncError.accountNotAvailable
//        }
//        
//        print("☁️ iCloudSyncService: Deleting photo with record ID: \(recordID)")
//        
//        do {
//            let recordIDObj = CKRecord.ID(recordName: recordID)
//            _ = try await privateDatabase.deleteRecord(withID: recordIDObj)
//            print("✅ iCloudSyncService: Successfully deleted photo with record ID: \(recordID)")
//        } catch {
//            print("❌ iCloudSyncService: Failed to delete photo: \(error.localizedDescription)")
//            throw iCloudSyncError.deleteFailed(error)
//        }
//    }
//    
//    // MARK: - Bulk Operations
//    func syncAllLocalPhotos() async {
//        guard isEnabled else {
//            print("☁️ iCloudSyncService: Sync disabled, skipping bulk sync")
//            return
//        }
//        
//        guard accountStatus == .available else {
//            print("❌ iCloudSyncService: Account not available, skipping bulk sync")
//            return
//        }
//        
//        print("☁️ iCloudSyncService: Starting bulk sync of all local photos")
//        
//        // This would need to be implemented with access to PhotoDatabaseService
//        // For now, this is a placeholder that can be called when needed
//        print("⚠️ iCloudSyncService: Bulk sync not yet implemented - needs PhotoDatabaseService integration")
//    }
//    
//    // MARK: - Status Tracking
//    func getSyncStatus(for photoId: Int) -> PhotoSyncStatus {
//        return photoSyncStatus[photoId] ?? .notSynced
//    }
//    
//    func setSyncStatus(for photoId: Int, status: PhotoSyncStatus) {
//        photoSyncStatus[photoId] = status
//    }
//}
//
//// MARK: - Error Types
//enum iCloudSyncError: Error, LocalizedError {
//    case syncDisabled
//    case accountNotAvailable
//    case uploadFailed(Error)
//    case downloadFailed(Error)
//    case deleteFailed(Error)
//    
//    var errorDescription: String? {
//        switch self {
//        case .syncDisabled:
//            return "iCloud sync is disabled"
//        case .accountNotAvailable:
//            return "iCloud account is not available"
//        case .uploadFailed(let error):
//            return "Upload failed: \(error.localizedDescription)"
//        case .downloadFailed(let error):
//            return "Download failed: \(error.localizedDescription)"
//        case .deleteFailed(let error):
//            return "Delete failed: \(error.localizedDescription)"
//        }
//    }
//}









import Foundation
import CloudKit
import UIKit

// Protocol for iCloud sync operations
protocol iCloudSyncService {
    var isEnabled: Bool { get set }
    var accountStatus: CKAccountStatus { get }
    
    func checkAccountStatus() async -> CKAccountStatus
    func uploadPhoto(_ photo: NavUnitPhoto, imageData: Data) async throws -> String
    func downloadPhotos(for navUnitId: String) async throws -> [CloudPhoto]
    func deletePhoto(recordID: String) async throws
    func syncAllLocalPhotos() async
}

// Implementation of iCloud sync service
class iCloudSyncServiceImpl: ObservableObject, iCloudSyncService {
    
    // MARK: - Properties
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "iCloudSyncEnabled")
            if isEnabled {
                Task {
                    await syncAllLocalPhotos()
                }
            }
        }
    }
    
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let fileStorageService: FileStorageService
    
    // Track sync status for photos
    private var photoSyncStatus: [Int: PhotoSyncStatus] = [:]
    
    // MARK: - Initialization
    init(fileStorageService: FileStorageService) {
        self.fileStorageService = fileStorageService
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase
        self.isEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        
        print("☁️ iCloudSyncService: Initialized with sync enabled: \(isEnabled)")
        
        // Check account status on init
        Task {
            await checkAccountStatus()
        }
    }
    
    // MARK: - Account Management
    @discardableResult
    func checkAccountStatus() async -> CKAccountStatus {
        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                self.accountStatus = status
            }
            
            switch status {
            case .available:
                print("✅ iCloudSyncService: iCloud account is available")
            case .noAccount:
                print("❌ iCloudSyncService: No iCloud account signed in")
            case .restricted:
                print("⚠️ iCloudSyncService: iCloud account is restricted")
            case .couldNotDetermine:
                print("❓ iCloudSyncService: Could not determine iCloud account status")
            case .temporarilyUnavailable:
                print("⏳ iCloudSyncService: iCloud is temporarily unavailable")
            @unknown default:
                print("❓ iCloudSyncService: Unknown iCloud account status")
            }
            
            return status
        } catch {
            print("❌ iCloudSyncService: Error checking account status: \(error.localizedDescription)")
            await MainActor.run {
                self.accountStatus = .couldNotDetermine
            }
            return .couldNotDetermine
        }
    }
    
    // MARK: - Upload Operations
    func uploadPhoto(_ photo: NavUnitPhoto, imageData: Data) async throws -> String {
        print("🚀 iCloudSyncService: uploadPhoto() started for photo ID: \(photo.id)")
        
        guard isEnabled else {
            print("❌ iCloudSyncService: Sync is DISABLED")
            throw iCloudSyncError.syncDisabled
        }
        print("✅ iCloudSyncService: Sync is ENABLED")
        
        print("🔍 iCloudSyncService: Checking account status...")
        guard accountStatus == .available else {
            print("❌ iCloudSyncService: Account not available. Status: \(accountStatus)")
            throw iCloudSyncError.accountNotAvailable
        }
        print("✅ iCloudSyncService: Account is available")
        
        print("☁️ iCloudSyncService: Creating CloudPhoto object...")
        let cloudPhoto = CloudPhoto(from: photo, imageData: imageData)
        print("✅ iCloudSyncService: CloudPhoto created - navUnitId: \(cloudPhoto.navUnitId), fileName: \(cloudPhoto.fileName)")
        
        // Update sync status
        await MainActor.run {
            photoSyncStatus[photo.id] = .syncing
        }
        print("✅ iCloudSyncService: Set photo \(photo.id) status to .syncing")
        
        do {
            print("🔄 iCloudSyncService: Converting CloudPhoto to CKRecord...")
            let record = cloudPhoto.toCKRecord()
            print("✅ iCloudSyncService: CKRecord created with recordType: \(record.recordType)")
            
            // Log record fields
            print("📝 iCloudSyncService: Record fields:")
            for key in record.allKeys() {
                let value = record[key]
                if key == CloudPhoto.FieldKeys.imageData {
                    if let asset = value as? CKAsset {
                        print("📝   \(key): CKAsset with fileURL: \(asset.fileURL?.path ?? "nil")")
                    } else {
                        print("📝   \(key): \(type(of: value)) (not CKAsset)")
                    }
                } else {
                    print("📝   \(key): \(String(describing: value))")
                }
            }
            
            print("☁️ iCloudSyncService: Saving record to CloudKit...")
            let savedRecord = try await privateDatabase.save(record)
            let recordID = savedRecord.recordID.recordName
            print("🎉 iCloudSyncService: Record saved successfully!")
            print("✅ iCloudSyncService: Record ID: \(recordID)")
            print("✅ iCloudSyncService: Record Type: \(savedRecord.recordType)")
            
            await MainActor.run {
                photoSyncStatus[photo.id] = .synced
            }
            print("✅ iCloudSyncService: Set photo \(photo.id) status to .synced")
            
            return recordID
            
        } catch {
            print("💥 iCloudSyncService: Upload FAILED!")
            print("💥 iCloudSyncService: Error: \(error)")
            print("💥 iCloudSyncService: Error description: \(error.localizedDescription)")
            
            await MainActor.run {
                photoSyncStatus[photo.id] = .failed
            }
            print("✅ iCloudSyncService: Set photo \(photo.id) status to .failed")
            
            throw iCloudSyncError.uploadFailed(error)
        }
    }
    
    // MARK: - Download Operations
    func downloadPhotos(for navUnitId: String) async throws -> [CloudPhoto] {
        guard isEnabled else {
            throw iCloudSyncError.syncDisabled
        }
        
        guard accountStatus == .available else {
            throw iCloudSyncError.accountNotAvailable
        }
        
        print("☁️ iCloudSyncService: Downloading photos for nav unit: \(navUnitId)")
        
        let predicate = NSPredicate(format: "navUnitId == %@", navUnitId)
        let query = CKQuery(recordType: CloudPhoto.recordType, predicate: predicate)
        
        do {
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            var cloudPhotos: [CloudPhoto] = []
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let cloudPhoto = CloudPhoto(from: record) {
                        cloudPhotos.append(cloudPhoto)
                    }
                case .failure(let error):
                    print("❌ iCloudSyncService: Failed to process record: \(error.localizedDescription)")
                }
            }
            
            print("✅ iCloudSyncService: Downloaded \(cloudPhotos.count) photos for nav unit: \(navUnitId)")
            return cloudPhotos
            
        } catch {
            print("❌ iCloudSyncService: Failed to download photos: \(error.localizedDescription)")
            throw iCloudSyncError.downloadFailed(error)
        }
    }
    
    // MARK: - Delete Operations
    func deletePhoto(recordID: String) async throws {
        guard isEnabled else {
            throw iCloudSyncError.syncDisabled
        }
        
        guard accountStatus == .available else {
            throw iCloudSyncError.accountNotAvailable
        }
        
        print("☁️ iCloudSyncService: Deleting photo with record ID: \(recordID)")
        
        do {
            let recordIDObj = CKRecord.ID(recordName: recordID)
            _ = try await privateDatabase.deleteRecord(withID: recordIDObj)
            print("✅ iCloudSyncService: Successfully deleted photo with record ID: \(recordID)")
        } catch {
            print("❌ iCloudSyncService: Failed to delete photo: \(error.localizedDescription)")
            throw iCloudSyncError.deleteFailed(error)
        }
    }
    
    // MARK: - Bulk Operations
    func syncAllLocalPhotos() async {
        guard isEnabled else {
            print("☁️ iCloudSyncService: Sync disabled, skipping bulk sync")
            return
        }
        
        guard accountStatus == .available else {
            print("❌ iCloudSyncService: Account not available, skipping bulk sync")
            return
        }
        
        print("☁️ iCloudSyncService: Starting bulk sync of all local photos")
        
        // This would need to be implemented with access to PhotoDatabaseService
        // For now, this is a placeholder that can be called when needed
        print("⚠️ iCloudSyncService: Bulk sync not yet implemented - needs PhotoDatabaseService integration")
    }
    
    // MARK: - Status Tracking
    func getSyncStatus(for photoId: Int) -> PhotoSyncStatus {
        return photoSyncStatus[photoId] ?? .notSynced
    }
    
    func setSyncStatus(for photoId: Int, status: PhotoSyncStatus) {
        photoSyncStatus[photoId] = status
    }
}

// MARK: - Error Types
enum iCloudSyncError: Error, LocalizedError {
    case syncDisabled
    case accountNotAvailable
    case uploadFailed(Error)
    case downloadFailed(Error)
    case deleteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .syncDisabled:
            return "iCloud sync is disabled"
        case .accountNotAvailable:
            return "iCloud account is not available"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Delete failed: \(error.localizedDescription)"
        }
    }
}
