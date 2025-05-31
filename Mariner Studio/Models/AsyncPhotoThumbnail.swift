
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
        }
        .task {
            await loadThumbnail()
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
