
import SwiftUI

// MARK: - AsyncPhotoThumbnail Component

struct AsyncPhotoThumbnail: View {
    let photo: NavUnitPhoto
    let viewModel: NavUnitDetailsViewModel
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    @State private var hasError = false
    
    var body: some View {
        ZStack {
            if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.red.opacity(0.3))
                    .overlay(
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text("Failed to load")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    )
            }
            
            // Sync status overlay
            if !isLoading && thumbnail != nil {
                VStack {
                    HStack {
                        syncStatusOverlay
                        Spacer()
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
        .task {
            await loadThumbnail()
        }
        .onChange(of: photo.id) { _ in
            // Reset state when photo changes
            isLoading = true
            hasError = false
            thumbnail = nil
            
            Task {
                await loadThumbnail()
            }
        }
    }
    
    private var syncStatusOverlay: some View {
        let status = viewModel.getSyncStatus(for: photo.id)
        
        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 20, height: 20)
            
            Group {
                if status == .syncing {
                    ProgressView()
                        .scaleEffect(0.5)
                        .tint(.white)
                } else {
                    Image(systemName: status.iconName)
                        .foregroundColor(syncStatusColor(for: status))
                        .font(.system(size: 10, weight: .medium))
                }
            }
        }
        .onTapGesture {
            // Handle sync status tap (could show detailed info or retry)
            handleSyncStatusTap(status: status)
        }
    }
    
    private func syncStatusColor(for status: PhotoSyncStatus) -> Color {
        switch status {
        case .notSynced: return .gray
        case .syncing: return .blue
        case .synced: return .green
        case .failed: return .red
        }
    }
    
    private func handleSyncStatusTap(status: PhotoSyncStatus) {
        switch status {
        case .failed:
            // Retry sync for failed photos
            Task {
                await viewModel.retrySyncForPhoto(photo.id)
            }
        case .notSynced:
            // Manually trigger sync for unsynced photos
            Task {
                await viewModel.manualSyncPhoto(photo.id)
            }
        default:
            break
        }
    }
    
    private func loadThumbnail() async {
        print("🖼️ AsyncPhotoThumbnail: Loading thumbnail for photo \(photo.id) from path: \(photo.filePath)")
        
        do {
            let loadedThumbnail = await viewModel.loadThumbnail(for: photo)
            await MainActor.run {
                if let loadedThumbnail = loadedThumbnail {
                    print("✅ AsyncPhotoThumbnail: Successfully loaded thumbnail for photo \(photo.id)")
                    self.thumbnail = loadedThumbnail
                    self.hasError = false
                } else {
                    print("❌ AsyncPhotoThumbnail: Failed to load thumbnail for photo \(photo.id) - thumbnail is nil")
                    self.hasError = true
                }
                self.isLoading = false
            }
        } catch {
            print("❌ AsyncPhotoThumbnail: Error loading thumbnail for photo \(photo.id): \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.hasError = true
            }
        }
    }
}
