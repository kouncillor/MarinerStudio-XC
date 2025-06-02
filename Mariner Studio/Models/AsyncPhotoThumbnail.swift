
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
                        VStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading...")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
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
            
            // Enhanced sync status overlay with progress indication
            if !isLoading && thumbnail != nil {
                VStack {
                    HStack {
                        enhancedSyncStatusOverlay
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
    
    // NEW: Enhanced sync status overlay with better visual feedback
    private var enhancedSyncStatusOverlay: some View {
        let status = viewModel.getSyncStatus(for: photo.id)
        
        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 24, height: 24)
            
            Group {
                if status == .syncing {
                    ZStack {
                        // Animated progress ring
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 16, height: 16)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 16, height: 16)
                            .rotationEffect(.degrees(-90))
                            .animation(
                                Animation.linear(duration: 1.0).repeatForever(autoreverses: false),
                                value: status == .syncing
                            )
                    }
                } else {
                    Image(systemName: status.iconName)
                        .foregroundColor(syncStatusColor(for: status))
                        .font(.system(size: 12, weight: .medium))
                }
            }
        }
        .onTapGesture {
            // Handle sync status tap (could show detailed info or retry)
            handleSyncStatusTap(status: status)
        }
        // NEW: Add subtle pulsing animation for syncing status
        .scaleEffect(status == .syncing ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: status == .syncing)
    }
    
    private func syncStatusColor(for status: PhotoSyncStatus) -> Color {
        switch status {
        case .notSynced: return .gray
        case .syncing, .uploading, .downloading: return .blue
        case .synced: return .green
        case .failed: return .red
        case .processing: return .orange
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
