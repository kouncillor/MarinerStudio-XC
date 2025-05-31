
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
    
    // MARK: - Properties
    let fileStorageService: FileStorageService // Made public for FullScreenPhotoView
    private let photoService: PhotoDatabaseService
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
    
    // MARK: - Initialization
    init(photos: [NavUnitPhoto],
         startingIndex: Int = 0,
         fileStorageService: FileStorageService,
         photoService: PhotoDatabaseService) {
        self.photos = photos
        self.currentIndex = max(0, min(startingIndex, photos.count - 1))
        self.fileStorageService = fileStorageService
        self.photoService = photoService
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
    
    func confirmDelete() async {
        guard let photoToDelete = photoToDelete else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            // Delete from file system
            try await fileStorageService.deletePhoto(at: photoToDelete.filePath)
            
            // Delete from database
            _ = try await photoService.deleteNavUnitPhotoAsync(photoId: photoToDelete.id)
            
            // Update local array
            await MainActor.run {
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
                
                isLoading = false
                self.photoToDelete = nil
            }
            
            print("📸 PhotoGalleryViewModel: Successfully deleted photo \(photoToDelete.id)")
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete photo: \(error.localizedDescription)"
                isLoading = false
                self.photoToDelete = nil
            }
            print("❌ PhotoGalleryViewModel: Error deleting photo: \(error.localizedDescription)")
        }
    }
    
    func cancelDelete() {
        photoToDelete = nil
        showingDeleteAlert = false
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
    }
}
