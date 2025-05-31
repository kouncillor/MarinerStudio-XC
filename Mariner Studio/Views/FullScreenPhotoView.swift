
import SwiftUI

struct FullScreenPhotoView: View {
    let photo: NavUnitPhoto
    let fileStorageService: FileStorageService
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var hasError = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Zoom constraints
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else if hasError {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        Text("Failed to load image")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                } else if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            // Pinch to zoom
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value
                                    scale = min(max(newScale, minScale), maxScale)
                                }
                                .onEnded { value in
                                    lastScale = scale
                                    
                                    // If scale is less than minimum, reset to 1.0
                                    if scale < minScale {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            scale = minScale
                                            offset = .zero
                                        }
                                        lastScale = minScale
                                        lastOffset = .zero
                                    } else {
                                        // Constrain offset after zoom
                                        constrainOffset(in: geometry.size)
                                    }
                                }
                        )
                        // Only add pan gesture when zoomed in
                        .gesture(
                            scale > minScale ?
                            DragGesture()
                                .onChanged { value in
                                    let newOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    offset = constrainedOffset(newOffset, in: geometry.size)
                                }
                                .onEnded { value in
                                    lastOffset = offset
                                } : nil
                        )
                        .onTapGesture(count: 2) {
                            // Double tap to zoom
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if scale > minScale {
                                    // Reset to fit
                                    scale = minScale
                                    offset = .zero
                                } else {
                                    // Zoom to 2x
                                    scale = 2.0
                                    offset = .zero
                                }
                            }
                            lastScale = scale
                            lastOffset = offset
                        }
                }
            }
        }
        .task {
            await loadImage()
        }
        .onChange(of: photo.id) { _ in
            // Reset state when photo changes
            scale = minScale
            lastScale = minScale
            offset = .zero
            lastOffset = .zero
            isLoading = true
            hasError = false
            image = nil
            
            Task {
                await loadImage()
            }
        }
    }
    
    private func loadImage() async {
        print("🖼️ FullScreenPhotoView: Loading image from path: \(photo.filePath)")
        
        do {
            let loadedImage = await fileStorageService.loadImage(from: photo.filePath)
            await MainActor.run {
                if let loadedImage = loadedImage {
                    print("✅ FullScreenPhotoView: Successfully loaded image for photo \(photo.id)")
                    self.image = loadedImage
                    self.hasError = false
                } else {
                    print("❌ FullScreenPhotoView: Failed to load image for photo \(photo.id) - image is nil")
                    self.hasError = true
                }
                self.isLoading = false
            }
        } catch {
            print("❌ FullScreenPhotoView: Error loading image for photo \(photo.id): \(error.localizedDescription)")
            await MainActor.run {
                self.hasError = true
                self.isLoading = false
            }
        }
    }
    
    private func constrainOffset(in size: CGSize) {
        withAnimation(.easeOut(duration: 0.2)) {
            offset = constrainedOffset(offset, in: size)
        }
        lastOffset = offset
    }
    
    private func constrainedOffset(_ proposedOffset: CGSize, in size: CGSize) -> CGSize {
        guard let image = image else { return .zero }
        
        // Calculate the scaled image size
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        var scaledImageSize: CGSize
        if aspectRatio > size.width / size.height {
            // Image is wider than container
            scaledImageSize = CGSize(
                width: size.width,
                height: size.width / aspectRatio
            )
        } else {
            // Image is taller than container
            scaledImageSize = CGSize(
                width: size.height * aspectRatio,
                height: size.height
            )
        }
        
        // Apply scale
        scaledImageSize = CGSize(
            width: scaledImageSize.width * scale,
            height: scaledImageSize.height * scale
        )
        
        // Calculate maximum allowed offset
        let maxOffsetX = max(0, (scaledImageSize.width - size.width) / 2)
        let maxOffsetY = max(0, (scaledImageSize.height - size.height) / 2)
        
        return CGSize(
            width: min(max(proposedOffset.width, -maxOffsetX), maxOffsetX),
            height: min(max(proposedOffset.height, -maxOffsetY), maxOffsetY)
        )
    }
}
