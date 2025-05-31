
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
    func syncPhotosForNavUnit(_ navUnitId: String) async
    func setPhotoService(_ photoService: PhotoDatabaseService)
    func setFileStorageService(_ fileStorageService: FileStorageService)
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
    
    // Service dependencies - will be injected after initialization
    private var photoService: PhotoDatabaseService?
    
    // Track sync status for photos
    private var photoSyncStatus: [Int: PhotoSyncStatus] = [:]
    
    // Track bulk sync progress
    @Published var syncProgress: SyncProgress = SyncProgress()
    
    // MARK: - Initialization
    init(fileStorageService: FileStorageService) {
        self.fileStorageService = fileStorageService
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase
        self.isEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        
        print("☁️ iCloudSyncService: Initialized with sync enabled: \(isEnabled)")
        
        // Check account status on init
        Task {
            await checkAccountStatus()
        }
    }
    
    // MARK: - Service Injection
    func setPhotoService(_ photoService: PhotoDatabaseService) {
        self.photoService = photoService
        print("☁️ iCloudSyncService: PhotoDatabaseService injected")
    }
    
    func setFileStorageService(_ fileStorageService: FileStorageService) {
        // Already set in init, but could be updated if needed
        print("☁️ iCloudSyncService: FileStorageService updated")
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
    
    // MARK: - Global Upload Serialization
    private let uploadSemaphore = DispatchSemaphore(value: 1) // Only 1 upload at a time, globally
    private var isAnyUploadInProgress = false
    
    // MARK: - Upload Operations
    func uploadPhoto(_ photo: NavUnitPhoto, imageData: Data) async throws -> String {
        print("🚀 iCloudSyncService: uploadPhoto() started for photo ID: \(photo.id) - waiting for upload slot...")
        
        // Wait for our turn (this blocks until no other upload is running)
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.uploadSemaphore.wait() // Block until semaphore is available
                continuation.resume()
            }
        }
        
        // Now we have exclusive access - no other upload can proceed
        await MainActor.run {
            isAnyUploadInProgress = true
        }
        
        print("🎯 iCloudSyncService: Got upload slot for photo ID: \(photo.id)")
        
        defer {
            // Always release the semaphore when done (even if error occurs)
            Task { @MainActor in
                isAnyUploadInProgress = false
            }
            uploadSemaphore.signal() // Release the lock
            print("🔓 iCloudSyncService: Released upload slot for photo ID: \(photo.id)")
        }
        
        guard isEnabled else {
            print("❌ iCloudSyncService: Sync is DISABLED")
            throw iCloudSyncError.syncDisabled
        }
        
        guard accountStatus == .available else {
            print("❌ iCloudSyncService: Account not available. Status: \(accountStatus)")
            throw iCloudSyncError.accountNotAvailable
        }
        
        await MainActor.run {
            photoSyncStatus[photo.id] = .syncing
        }
        
        do {
            print("☁️ iCloudSyncService: Creating CloudPhoto object for photo \(photo.id)...")
            let cloudPhoto = CloudPhoto(from: photo, imageData: imageData)
            
            print("🔄 iCloudSyncService: Converting CloudPhoto to CKRecord for photo \(photo.id)...")
            let record = cloudPhoto.toCKRecord()
            
            print("☁️ iCloudSyncService: Saving record to CloudKit for photo \(photo.id)...")
            let savedRecord = try await privateDatabase.save(record)
            let recordID = savedRecord.recordID.recordName
            
            print("🎉 iCloudSyncService: Upload successful for photo \(photo.id)! Record ID: \(recordID)")
            
            await MainActor.run {
                photoSyncStatus[photo.id] = .synced
            }
            
            return recordID
            
        } catch {
            print("💥 iCloudSyncService: Upload FAILED for photo \(photo.id)! Error: \(error.localizedDescription)")
            
            await MainActor.run {
                photoSyncStatus[photo.id] = .failed
            }
            
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
    
    // MARK: - Improved Sync Operations with Better Deduplication
    
    func syncAllLocalPhotos() async {
        guard isEnabled else {
            print("☁️ iCloudSyncService: Sync disabled, skipping bulk sync")
            return
        }
        
        guard accountStatus == .available else {
            print("❌ iCloudSyncService: Account not available, skipping bulk sync")
            return
        }
        
        guard let photoService = photoService else {
            print("❌ iCloudSyncService: PhotoDatabaseService not available")
            return
        }
        
        print("🚀 iCloudSyncService: Starting bulk sync of all local photos")
        
        await MainActor.run {
            syncProgress.isInProgress = true
            syncProgress.totalPhotos = 0
            syncProgress.processedPhotos = 0
            syncProgress.errorMessage = nil
        }
        
        do {
            // Get all photos from database
            let allPhotos = try await photoService.getAllNavUnitPhotosAsync()
            print("📊 iCloudSyncService: Found \(allPhotos.count) local photos to potentially sync")
            
            await MainActor.run {
                syncProgress.totalPhotos = allPhotos.count
            }
            
            // Get all existing photos from iCloud first to avoid redundant API calls
            let allCloudPhotos = try await getAllCloudPhotos()
            print("☁️ iCloudSyncService: Found \(allCloudPhotos.count) existing photos in iCloud")
            
            var successCount = 0
            var errorCount = 0
            var skippedCount = 0
            
            // Process photos individually to avoid overwhelming CloudKit
            for photo in allPhotos {
                do {
                    // Check if photo already exists in iCloud using improved logic
                    if isPhotoAlreadyInCloud(photo, cloudPhotos: allCloudPhotos) {
                        print("⏭️ iCloudSyncService: Photo \(photo.id) already exists in iCloud, skipping")
                        skippedCount += 1
                        
                        // Mark as synced if not already
                        await MainActor.run {
                            photoSyncStatus[photo.id] = .synced
                        }
                    } else {
                        // Load image data and upload
                        if let image = await fileStorageService.loadImage(from: photo.filePath),
                           let imageData = image.jpegData(compressionQuality: 0.8) {
                            
                            print("⬆️ iCloudSyncService: Uploading photo \(photo.id) to iCloud")
                            
                            await MainActor.run {
                                photoSyncStatus[photo.id] = .syncing
                            }
                            
                            _ = try await uploadPhoto(photo, imageData: imageData)
                            successCount += 1
                            print("✅ iCloudSyncService: Successfully uploaded photo \(photo.id)")
                            
                            await MainActor.run {
                                photoSyncStatus[photo.id] = .synced
                            }
                        } else {
                            print("❌ iCloudSyncService: Failed to load image data for photo \(photo.id)")
                            errorCount += 1
                            
                            await MainActor.run {
                                photoSyncStatus[photo.id] = .failed
                            }
                        }
                    }
                } catch {
                    print("❌ iCloudSyncService: Error syncing photo \(photo.id): \(error.localizedDescription)")
                    errorCount += 1
                    
                    await MainActor.run {
                        photoSyncStatus[photo.id] = .failed
                    }
                }
                
                await MainActor.run {
                    syncProgress.processedPhotos += 1
                }
            }
            
            await MainActor.run {
                syncProgress.isInProgress = false
                if errorCount > 0 {
                    syncProgress.errorMessage = "Synced \(successCount) photos, \(skippedCount) already synced, \(errorCount) failed"
                } else {
                    syncProgress.errorMessage = "Successfully synced \(successCount) photos, \(skippedCount) already synced"
                }
            }
            
            print("🎉 iCloudSyncService: Bulk sync completed - Success: \(successCount), Skipped: \(skippedCount), Errors: \(errorCount)")
            
        } catch {
            await MainActor.run {
                syncProgress.isInProgress = false
                syncProgress.errorMessage = "Sync failed: \(error.localizedDescription)"
            }
            print("❌ iCloudSyncService: Bulk sync failed: \(error.localizedDescription)")
        }
    }
    
    func syncPhotosForNavUnit(_ navUnitId: String) async {
        guard isEnabled else {
            print("☁️ iCloudSyncService: Sync disabled for nav unit \(navUnitId)")
            return
        }
        
        guard accountStatus == .available else {
            print("❌ iCloudSyncService: Account not available for nav unit sync")
            return
        }
        
        guard let photoService = photoService else {
            print("❌ iCloudSyncService: PhotoDatabaseService not available for nav unit sync")
            return
        }
        
        print("🔄 iCloudSyncService: Starting bidirectional sync for nav unit: \(navUnitId)")
        
        do {
            // 1. Download photos from iCloud for this nav unit
            let cloudPhotos = try await downloadPhotos(for: navUnitId)
            print("⬇️ iCloudSyncService: Found \(cloudPhotos.count) photos in iCloud for \(navUnitId)")
            
            // 2. Get local photos for this nav unit
            let localPhotos = try await photoService.getNavUnitPhotosAsync(navUnitId: navUnitId)
            print("📱 iCloudSyncService: Found \(localPhotos.count) local photos for \(navUnitId)")
            
            // 3. Download missing photos from iCloud
            for cloudPhoto in cloudPhotos {
                let existsLocally = localPhotos.contains { localPhoto in
                    // Improved matching logic
                    return localPhoto.fileName == cloudPhoto.fileName &&
                           abs(localPhoto.createdAt.timeIntervalSince(cloudPhoto.createdAt)) < 60 // Within 1 minute
                }
                
                if !existsLocally {
                    print("⬇️ iCloudSyncService: Downloading missing photo: \(cloudPhoto.fileName)")
                    
                    do {
                        // Save image to file system
                        let (filePath, fileName) = try await saveCloudPhotoToFile(cloudPhoto, navUnitId: navUnitId)
                        
                        // Create NavUnitPhoto and save to database
                        let navUnitPhoto = cloudPhoto.toNavUnitPhoto(filePath: filePath)
                        let photoId = try await photoService.addNavUnitPhotoAsync(photo: navUnitPhoto)
                        
                        await MainActor.run {
                            photoSyncStatus[photoId] = .synced
                        }
                        
                        print("✅ iCloudSyncService: Downloaded and saved photo \(cloudPhoto.fileName) with ID \(photoId)")
                        
                    } catch {
                        print("❌ iCloudSyncService: Failed to download photo \(cloudPhoto.fileName): \(error.localizedDescription)")
                    }
                }
            }
            
            // 4. Upload missing photos to iCloud (with improved deduplication)
            for localPhoto in localPhotos {
                if !isPhotoAlreadyInCloud(localPhoto, cloudPhotos: cloudPhotos) {
                    print("⬆️ iCloudSyncService: Uploading missing photo: \(localPhoto.fileName)")
                    
                    do {
                        if let image = await fileStorageService.loadImage(from: localPhoto.filePath),
                           let imageData = image.jpegData(compressionQuality: 0.8) {
                            
                            await MainActor.run {
                                photoSyncStatus[localPhoto.id] = .syncing
                            }
                            
                            _ = try await uploadPhoto(localPhoto, imageData: imageData)
                            print("✅ iCloudSyncService: Uploaded photo \(localPhoto.fileName)")
                            
                            await MainActor.run {
                                photoSyncStatus[localPhoto.id] = .synced
                            }
                        }
                    } catch {
                        print("❌ iCloudSyncService: Failed to upload photo \(localPhoto.fileName): \(error.localizedDescription)")
                        
                        await MainActor.run {
                            photoSyncStatus[localPhoto.id] = .failed
                        }
                    }
                } else {
                    // Mark as synced if already exists
                    await MainActor.run {
                        photoSyncStatus[localPhoto.id] = .synced
                    }
                }
            }
            
            print("🎉 iCloudSyncService: Bidirectional sync completed for nav unit: \(navUnitId)")
            
        } catch {
            print("❌ iCloudSyncService: Sync failed for nav unit \(navUnitId): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods for Improved Deduplication
    
    private func getAllCloudPhotos() async throws -> [CloudPhoto] {
        print("☁️ iCloudSyncService: Getting all photos from iCloud...")
        
        let query = CKQuery(recordType: CloudPhoto.recordType, predicate: NSPredicate(value: true))
        
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
                    print("❌ iCloudSyncService: Failed to process cloud record: \(error.localizedDescription)")
                }
            }
            
            print("✅ iCloudSyncService: Retrieved \(cloudPhotos.count) total photos from iCloud")
            return cloudPhotos
            
        } catch {
            print("❌ iCloudSyncService: Failed to get all cloud photos: \(error.localizedDescription)")
            throw iCloudSyncError.downloadFailed(error)
        }
    }
    
    private func isPhotoAlreadyInCloud(_ localPhoto: NavUnitPhoto, cloudPhotos: [CloudPhoto]) -> Bool {
        return cloudPhotos.contains { cloudPhoto in
            // Match by multiple criteria to avoid duplicates
            return cloudPhoto.navUnitId == localPhoto.navUnitId &&
                   cloudPhoto.fileName == localPhoto.fileName &&
                   abs(cloudPhoto.createdAt.timeIntervalSince(localPhoto.createdAt)) < 60 // Within 1 minute
        }
    }
    
    // Helper method to save cloud photo to file system
    private func saveCloudPhotoToFile(_ cloudPhoto: CloudPhoto, navUnitId: String) async throws -> (filePath: String, fileName: String) {
        // Create a UIImage from the cloud photo data
        guard let image = UIImage(data: cloudPhoto.imageData) else {
            throw iCloudSyncError.downloadFailed(NSError(domain: "iCloudSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"]))
        }
        
        // Save using file storage service
        return try await fileStorageService.savePhoto(image, for: navUnitId)
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

// MARK: - Supporting Types
struct SyncProgress {
    var isInProgress: Bool = false
    var totalPhotos: Int = 0
    var processedPhotos: Int = 0
    var errorMessage: String?
    
    var progressPercentage: Double {
        guard totalPhotos > 0 else { return 0 }
        return Double(processedPhotos) / Double(totalPhotos)
    }
}

// MARK: - Array Extension
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
