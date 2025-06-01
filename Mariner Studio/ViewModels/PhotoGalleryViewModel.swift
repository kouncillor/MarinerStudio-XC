
import Foundation
import SwiftUI
import UIKit

class PhotoGalleryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var photos: [NavUnitPhoto] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var showingDeleteAlert: Bool = false
    @Published var showingShareSheet: Bool = false
    
    // NEW: Enhanced deletion state
    @Published var isDeletingFromiCloud: Bool = false
    @Published var deletionStatusMessage: String = ""
    
    // MARK: - Properties
    let fileStorageService: FileStorageService // Made public for FullScreenPhotoView
    private let photoService: PhotoDatabaseService
    private let iCloudSyncService: iCloudSyncService? // NEW: iCloud sync service for deletion
    private var photoToDelete: NavUnitPhoto?
    
    // MARK: - Computed Properties
    var currentPhoto: NavUnitPhoto? {
        guard currentIndex >= 0 && currentIndex < photos.count else { return nil }
        return photos[currentIndex]
    }
    
    var photoCountText: String {
        guard !photos.isEmpty else { return "No photos" }
        return "\(currentIndex + 1) of \(photos.count)"
    }
    
    var hasPreviousPhoto: Bool {
        return currentIndex > 0
    }
    
    var hasNextPhoto: Bool {
        return currentIndex < photos.count - 1
    }
    
    // NEW: Check if current photo can be deleted from iCloud
    var currentPhotoHasiCloudRecord: Bool {
        guard let currentPhoto = currentPhoto else { return false }
        return currentPhoto.isSyncedToiCloud
    }
    
    // MARK: - Initialization
    init(photos: [NavUnitPhoto],
         startingIndex: Int = 0,
         fileStorageService: FileStorageService,
         photoService: PhotoDatabaseService,
         iCloudSyncService: iCloudSyncService? = nil) {
        self.photos = photos
        self.currentIndex = max(0, min(startingIndex, photos.count - 1))
        self.fileStorageService = fileStorageService
        self.photoService = photoService
        self.iCloudSyncService = iCloudSyncService
    }
    
    // MARK: - Navigation Methods
    func goToPrevious() {
        if hasPreviousPhoto {
            currentIndex -= 1
        }
    }
    
    func goToNext() {
        if hasNextPhoto {
            currentIndex += 1
        }
    }
    
    func goToPhoto(at index: Int) {
        guard index >= 0 && index < photos.count else { return }
        currentIndex = index
    }
    
    // MARK: - Photo Operations
    func loadFullImage(for photo: NavUnitPhoto) async -> UIImage? {
        return await fileStorageService.loadImage(from: photo.filePath)
    }
    
    func shareCurrentPhoto() {
        guard let currentPhoto = currentPhoto else { return }
        
        Task { @MainActor in
            if let image = await loadFullImage(for: currentPhoto) {
                // Create share items
                var shareItems: [Any] = [image]
                
                // Add text description if available
                if let description = currentPhoto.description, !description.isEmpty {
                    shareItems.append(description)
                }
                
                // Show share sheet
                showingShareSheet = true
                presentShareSheet(with: shareItems)
            } else {
                errorMessage = "Failed to load image for sharing"
            }
        }
    }
    
    func deleteCurrentPhoto() {
        guard let currentPhoto = currentPhoto else { return }
        photoToDelete = currentPhoto
        showingDeleteAlert = true
    }
    
    // MARK: - Enhanced Deletion with iCloud Support
    
    func confirmDelete() async {
        guard let photoToDelete = photoToDelete else { return }
        
        print("🗑️ PhotoGalleryViewModel: Starting enhanced deletion for photo ID: \(photoToDelete.id)")
        print("🗑️   File: \(photoToDelete.fileName)")
        print("🗑️   CloudRecordID: \(photoToDelete.cloudRecordID ?? "none")")
        print("🗑️   isSyncedToiCloud: \(photoToDelete.isSyncedToiCloud)")
        
        await MainActor.run {
            isLoading = true
            isDeletingFromiCloud = false
            errorMessage = ""
            deletionStatusMessage = "Preparing to delete photo..."
        }
        
        // Phase 1: Try to delete from iCloud first (if applicable)
        var iCloudDeletionAttempted = false
        var iCloudDeletionSucceeded = false
        var iCloudError: Error?
        
        if let iCloudSyncService = iCloudSyncService,
           photoToDelete.isSyncedToiCloud,
           iCloudSyncService.isEnabled {
            
            print("☁️ PhotoGalleryViewModel: Attempting iCloud deletion...")
            await MainActor.run {
                isDeletingFromiCloud = true
                deletionStatusMessage = "Deleting from iCloud..."
            }
            
            iCloudDeletionAttempted = true
            
            do {
                // Use the enhanced deletion method that handles both iCloud and local
                try await iCloudSyncService.deletePhotoByLocalID(photoToDelete.id)
                iCloudDeletionSucceeded = true
                print("✅ PhotoGalleryViewModel: iCloud deletion successful")
                
                await MainActor.run {
                    deletionStatusMessage = "Successfully deleted from iCloud and local storage"
                }
                
            } catch {
                iCloudError = error
                iCloudDeletionSucceeded = false
                print("❌ PhotoGalleryViewModel: iCloud deletion failed: \(error.localizedDescription)")
                
                await MainActor.run {
                    deletionStatusMessage = "Failed to delete from iCloud, trying local deletion..."
                }
            }
        } else {
            print("ℹ️ PhotoGalleryViewModel: Skipping iCloud deletion (not synced or sync disabled)")
            await MainActor.run {
                deletionStatusMessage = "Deleting photo..."
            }
        }
        
        // Phase 2: Handle local deletion if iCloud service didn't handle it
        var localDeletionSucceeded = false
        
        if !iCloudDeletionSucceeded || !iCloudDeletionAttempted {
            print("💾 PhotoGalleryViewModel: Performing local deletion...")
            
            do {
                // Delete from file system
                try await fileStorageService.deletePhoto(at: photoToDelete.filePath)
                print("✅ PhotoGalleryViewModel: File deleted successfully")
                
                // Delete from database
                let dbSuccess = try await photoService.deleteNavUnitPhotoAsync(photoId: photoToDelete.id)
                if dbSuccess {
                    print("✅ PhotoGalleryViewModel: Database deletion successful")
                    localDeletionSucceeded = true
                } else {
                    print("⚠️ PhotoGalleryViewModel: Database deletion returned false")
                }
                
            } catch {
                print("❌ PhotoGalleryViewModel: Local deletion failed: \(error.localizedDescription)")
                
                await MainActor.run {
                    if iCloudDeletionAttempted && !iCloudDeletionSucceeded {
                        errorMessage = "Failed to delete from both iCloud and local storage: \(error.localizedDescription)"
                    } else {
                        errorMessage = "Failed to delete photo: \(error.localizedDescription)"
                    }
                    isLoading = false
                    isDeletingFromiCloud = false
                    deletionStatusMessage = ""
                    self.photoToDelete = nil
                }
                return
            }
        } else {
            // iCloud service handled both iCloud and local deletion
            localDeletionSucceeded = true
        }
        
        // Phase 3: Update UI if deletion was successful
        if localDeletionSucceeded || iCloudDeletionSucceeded {
            await MainActor.run {
                // Remove photo from local array
                if let index = photos.firstIndex(where: { $0.id == photoToDelete.id }) {
                    photos.remove(at: index)
                    
                    // Adjust current index if necessary
                    if photos.isEmpty {
                        // No photos left - the gallery should be dismissed
                        currentIndex = 0
                    } else if currentIndex >= photos.count {
                        // Current index is beyond the array - move to last photo
                        currentIndex = photos.count - 1
                    }
                    // If currentIndex is still valid, keep it as is
                }
                
                // Set appropriate success message
                if iCloudDeletionSucceeded {
                    deletionStatusMessage = "Photo deleted from iCloud and device"
                } else if localDeletionSucceeded && iCloudDeletionAttempted {
                    deletionStatusMessage = "Photo deleted locally (iCloud deletion failed)"
                } else {
                    deletionStatusMessage = "Photo deleted successfully"
                }
                
                // Clear loading state
                isLoading = false
                isDeletingFromiCloud = false
                self.photoToDelete = nil
                
                // Clear status message after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.deletionStatusMessage = ""
                }
            }
            
            print("🎉 PhotoGalleryViewModel: Deletion completed successfully")
            
            // Log the final outcome
            if iCloudDeletionSucceeded {
                print("📊 PhotoGalleryViewModel: Final result - iCloud and local deletion successful")
            } else if localDeletionSucceeded && iCloudDeletionAttempted {
                print("📊 PhotoGalleryViewModel: Final result - Local deletion successful, iCloud failed")
                if let error = iCloudError {
                    print("📊   iCloud error was: \(error.localizedDescription)")
                }
            } else {
                print("📊 PhotoGalleryViewModel: Final result - Local-only deletion successful")
            }
            
        } else {
            // Both deletion methods failed
            await MainActor.run {
                if let iCloudError = iCloudError {
                    errorMessage = "Deletion failed: \(iCloudError.localizedDescription)"
                } else {
                    errorMessage = "Deletion failed for unknown reasons"
                }
                isLoading = false
                isDeletingFromiCloud = false
                deletionStatusMessage = ""
                self.photoToDelete = nil
            }
            
            print("💥 PhotoGalleryViewModel: All deletion methods failed")
        }
    }
    
    func cancelDelete() {
        photoToDelete = nil
        showingDeleteAlert = false
        
        // Clear any deletion status
        deletionStatusMessage = ""
        isDeletingFromiCloud = false
    }
    
    // MARK: - Share Sheet
    var currentShareItems: [Any] = []
    
    private func presentShareSheet(with items: [Any]) {
        currentShareItems = items
        showingShareSheet = true
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = ""
        deletionStatusMessage = ""
    }
    
    // MARK: - Status Methods
    
    // NEW: Get user-friendly deletion status for UI
    var deletionStatusForUI: String {
        if isDeletingFromiCloud && !deletionStatusMessage.isEmpty {
            return deletionStatusMessage
        } else if isLoading && !deletionStatusMessage.isEmpty {
            return deletionStatusMessage
        } else if !deletionStatusMessage.isEmpty {
            return deletionStatusMessage
        }
        return ""
    }
    
    // NEW: Check if any deletion operation is in progress
    var isDeletionInProgress: Bool {
        return isLoading || isDeletingFromiCloud
    }
    
    // NEW: Get appropriate delete button text based on sync status
    func deleteButtonText(for photo: NavUnitPhoto?) -> String {
        guard let photo = photo else { return "Delete Photo" }
        
        if photo.isSyncedToiCloud {
            return "Delete from iCloud & Device"
        } else {
            return "Delete Photo"
        }
    }
    
    // NEW: Get deletion confirmation message based on sync status
    func deletionConfirmationMessage(for photo: NavUnitPhoto?) -> String {
        guard let photo = photo else {
            return "Are you sure you want to delete this photo? This action cannot be undone."
        }
        
        if photo.isSyncedToiCloud {
            return "Are you sure you want to delete this photo from both iCloud and your device? This action cannot be undone."
        } else {
            return "Are you sure you want to delete this photo? This action cannot be undone."
        }
    }
}
