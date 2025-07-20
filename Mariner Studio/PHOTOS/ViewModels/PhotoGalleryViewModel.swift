//
//  PhotoGalleryViewModel.swift
//  Mariner Studio
//
//  View model for nav unit photo gallery management
//

import Foundation
import UIKit
import Combine

@MainActor
class PhotoGalleryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var photos: [NavUnitPhoto] = []
    @Published var syncStatus: PhotoSyncStatus = .empty
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var isDownloading = false
    @Published var errorMessage = ""
    @Published var successMessage = ""
    
    // MARK: - Properties
    
    let navUnitId: String
    private let photoService: PhotoService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var canTakePhoto: Bool {
        return !syncStatus.isAtLimit && !isLoading
    }
    
    var photoCountText: String {
        return "\(photos.count)/10 photos"
    }
    
    var syncStatusText: String {
        if syncStatus.pendingUploads > 0 {
            return "\(syncStatus.pendingUploads) pending upload"
        } else if syncStatus.photosToDownload > 0 {
            return "\(syncStatus.photosToDownload) available to download"
        } else if photos.isEmpty {
            return "No photos yet"
        } else {
            return "All photos synced"
        }
    }
    
    var showUploadButton: Bool {
        return syncStatus.pendingUploads > 0 && !isUploading
    }
    
    var showDownloadButton: Bool {
        return syncStatus.photosToDownload > 0 && !isDownloading
    }
    
    // MARK: - Initialization
    
    init(navUnitId: String, photoService: PhotoService) {
        self.navUnitId = navUnitId
        self.photoService = photoService
        
        print("📸 PhotoGalleryViewModel: Initialized for nav unit \(navUnitId)")
        
        // Load initial data
        Task {
            await loadPhotos()
            await updateSyncStatus()
        }
    }
    
    // MARK: - Photo Loading
    
    func loadPhotos() async {
        isLoading = true
        errorMessage = ""
        
        do {
            let loadedPhotos = try await photoService.getPhotos(for: navUnitId)
            photos = loadedPhotos
            print("📸 PhotoGalleryViewModel: Loaded \(photos.count) photos")
        } catch {
            errorMessage = "Failed to load photos: \(error.localizedDescription)"
            print("❌ PhotoGalleryViewModel: Error loading photos: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshPhotos() async {
        await loadPhotos()
        await updateSyncStatus()
    }
    
    // MARK: - Photo Capture
    
    func takePhoto(_ image: UIImage) async {
        guard canTakePhoto else {
            errorMessage = "Cannot take photo: at limit or loading"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            let newPhoto = try await photoService.takePhoto(for: navUnitId, image: image)
            
            // Add to beginning of array (most recent first)
            photos.insert(newPhoto, at: 0)
            
            successMessage = "Photo captured successfully!"
            print("📸 PhotoGalleryViewModel: Successfully captured photo \(newPhoto.id)")
            
            // Clear success message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.successMessage = ""
            }
            
            await updateSyncStatus()
            
        } catch {
            errorMessage = "Failed to capture photo: \(error.localizedDescription)"
            print("❌ PhotoGalleryViewModel: Error capturing photo: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Photo Deletion
    
    func deletePhoto(_ photo: NavUnitPhoto) async {
        isLoading = true
        errorMessage = ""
        
        do {
            try await photoService.deletePhoto(photo)
            
            // Remove from array
            photos.removeAll { $0.id == photo.id }
            
            successMessage = "Photo deleted successfully!"
            print("📸 PhotoGalleryViewModel: Successfully deleted photo \(photo.id)")
            
            // Clear success message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.successMessage = ""
            }
            
            await updateSyncStatus()
            
        } catch {
            errorMessage = "Failed to delete photo: \(error.localizedDescription)"
            print("❌ PhotoGalleryViewModel: Error deleting photo: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Manual Sync Operations
    
    func uploadPhotos() async {
        guard !isUploading else { return }
        
        isUploading = true
        errorMessage = ""
        
        do {
            let result = try await photoService.uploadPhotos(for: navUnitId)
            syncStatus = result
            
            successMessage = "Photos uploaded successfully!"
            print("📸 PhotoGalleryViewModel: Upload completed")
            
            // Refresh photos to update upload status
            await loadPhotos()
            
            // Clear success message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.successMessage = ""
            }
            
        } catch {
            errorMessage = "Failed to upload photos: \(error.localizedDescription)"
            print("❌ PhotoGalleryViewModel: Error uploading photos: \(error)")
        }
        
        isUploading = false
    }
    
    func downloadPhotos() async {
        guard !isDownloading else { return }
        
        isDownloading = true
        errorMessage = ""
        
        do {
            let result = try await photoService.downloadPhotos(for: navUnitId)
            syncStatus = result
            
            successMessage = "Photos downloaded successfully!"
            print("📸 PhotoGalleryViewModel: Download completed")
            
            // Refresh photos to show downloaded ones
            await loadPhotos()
            
            // Clear success message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.successMessage = ""
            }
            
        } catch {
            errorMessage = "Failed to download photos: \(error.localizedDescription)"
            print("❌ PhotoGalleryViewModel: Error downloading photos: \(error)")
        }
        
        isDownloading = false
    }
    
    // MARK: - Sync Status Management
    
    func updateSyncStatus() async {
        do {
            syncStatus = try await photoService.getSyncStatus(for: navUnitId)
            print("📸 PhotoGalleryViewModel: Updated sync status - \(syncStatus.totalPhotos) total, \(syncStatus.pendingUploads) pending")
        } catch {
            print("❌ PhotoGalleryViewModel: Error updating sync status: \(error)")
        }
    }
    
    // MARK: - Image Loading
    
    func loadThumbnail(for photo: NavUnitPhoto) async -> UIImage? {
        do {
            return try await photoService.loadThumbnailImage(photo)
        } catch {
            print("❌ PhotoGalleryViewModel: Error loading thumbnail for \(photo.id): \(error)")
            return nil
        }
    }
    
    func loadFullImage(for photo: NavUnitPhoto) async -> UIImage? {
        do {
            return try await photoService.loadPhotoImage(photo)
        } catch {
            print("❌ PhotoGalleryViewModel: Error loading full image for \(photo.id): \(error)")
            return nil
        }
    }
    
    // MARK: - Utility Methods
    
    func clearMessages() {
        errorMessage = ""
        successMessage = ""
    }
    
    func getPhotoDisplayName(_ photo: NavUnitPhoto) -> String {
        return photo.displayName
    }
    
    func getPhotoStatusIcon(_ photo: NavUnitPhoto) -> String {
        if photo.isUploaded {
            return "cloud.fill"
        } else {
            return "cloud"
        }
    }
    
    func getPhotoStatusColor(_ photo: NavUnitPhoto) -> UIColor {
        if photo.isUploaded {
            return .systemGreen
        } else {
            return .systemOrange
        }
    }
}