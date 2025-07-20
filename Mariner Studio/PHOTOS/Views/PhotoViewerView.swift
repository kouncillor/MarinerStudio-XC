//
//  PhotoViewerView.swift
//  Mariner Studio
//
//  Full-screen photo viewer with swipe navigation and photo management
//

import SwiftUI

struct PhotoViewerView: View {
    let photos: [NavUnitPhoto]
    @Binding var selectedPhoto: NavUnitPhoto?
    let onDelete: (NavUnitPhoto) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var showingControls = true
    @State private var showingShareSheet = false
    @State private var imageToShare: UIImage?
    @State private var loadedImages: [UUID: UIImage] = [:]
    @State private var isLoading = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !photos.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        PhotoDisplayView(
                            photo: photo,
                            loadedImage: loadedImages[photo.id],
                            isLoading: isLoading,
                            onImageLoaded: { image in
                                loadedImages[photo.id] = image
                            }
                        )
                        .tag(index)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingControls.toggle()
                            }
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: currentIndex) { _, newIndex in
                    if newIndex < photos.count {
                        selectedPhoto = photos[newIndex]
                        loadImageIfNeeded(for: photos[newIndex])
                    }
                }
            }
            
            // Control overlays
            if showingControls {
                controlsOverlay
            }
        }
        .onAppear {
            setupInitialPhoto()
        }
        .gesture(
            // Dismiss on swipe down
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 && abs(value.translation.width) < 50 {
                        dismiss()
                    }
                }
        )
        .sheet(isPresented: $showingShareSheet) {
            if let imageToShare = imageToShare {
                ShareSheet(items: [imageToShare])
            }
        }
    }
    
    // MARK: - View Components
    
    private var controlsOverlay: some View {
        VStack {
            // Top controls
            HStack {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.white)
                .padding()
                
                Spacer()
                
                if photos.count > 1 {
                    Text("\(currentIndex + 1) of \(photos.count)")
                        .foregroundColor(.white)
                        .padding()
                }
                
                Spacer()
                
                Menu {
                    Button(action: sharePhoto) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: deleteCurrentPhoto) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            Spacer()
            
            // Bottom info
            if currentIndex < photos.count {
                photoInfoView(for: photos[currentIndex])
            }
        }
    }
    
    private func photoInfoView(for photo: NavUnitPhoto) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(photo.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Image(systemName: photo.isUploaded ? "cloud.fill" : "cloud")
                            .foregroundColor(photo.isUploaded ? .green : .orange)
                        
                        Text(photo.isUploaded ? "Synced" : "Local only")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialPhoto() {
        if let selectedPhoto = selectedPhoto,
           let index = photos.firstIndex(where: { $0.id == selectedPhoto.id }) {
            currentIndex = index
            loadImageIfNeeded(for: selectedPhoto)
        } else if !photos.isEmpty {
            currentIndex = 0
            self.selectedPhoto = photos[0]
            loadImageIfNeeded(for: photos[0])
        }
    }
    
    private func loadImageIfNeeded(for photo: NavUnitPhoto) {
        guard loadedImages[photo.id] == nil else { return }
        
        Task {
            isLoading = true
            
            // Load from cache service or photo service
            // This is a simplified version - you'd integrate with your PhotoService
            if let imageData = try? Data(contentsOf: photo.localURL),
               let image = UIImage(data: imageData) {
                await MainActor.run {
                    loadedImages[photo.id] = image
                }
            }
            
            isLoading = false
        }
    }
    
    private func sharePhoto() {
        guard currentIndex < photos.count else { return }
        let photo = photos[currentIndex]
        
        if let image = loadedImages[photo.id] {
            imageToShare = image
            showingShareSheet = true
        }
    }
    
    private func deleteCurrentPhoto() {
        guard currentIndex < photos.count else { return }
        let photo = photos[currentIndex]
        onDelete(photo)
        dismiss()
    }
}

// MARK: - Photo Display View

struct PhotoDisplayView: View {
    let photo: NavUnitPhoto
    let loadedImage: UIImage?
    let isLoading: Bool
    let onImageLoaded: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var isImageLoading = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = value
                                    }
                                    .onEnded { value in
                                        withAnimation(.spring()) {
                                            if scale < 1.0 {
                                                scale = 1.0
                                                offset = .zero
                                            } else if scale > 4.0 {
                                                scale = 4.0
                                            }
                                        }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = value.translation
                                    }
                                    .onEnded { value in
                                        withAnimation(.spring()) {
                                            if scale <= 1.0 {
                                                offset = .zero
                                            }
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                } else if isLoading || isImageLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .foregroundColor(.white)
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Failed to load image")
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                await loadImageIfNeeded()
            }
        }
    }
    
    private func loadImageIfNeeded() async {
        guard loadedImage == nil && !isImageLoading else { return }
        
        isImageLoading = true
        
        // Load image from local storage
        if let imageData = try? Data(contentsOf: photo.localURL),
           let image = UIImage(data: imageData) {
            await MainActor.run {
                onImageLoaded(image)
            }
        }
        
        isImageLoading = false
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

#Preview {
    struct PhotoViewerPreview: View {
        @State private var selectedPhoto: NavUnitPhoto? = NavUnitPhoto(
            navUnitId: "test",
            localFileName: "test.jpg"
        )
        
        let samplePhotos = [
            NavUnitPhoto(navUnitId: "test", localFileName: "test1.jpg"),
            NavUnitPhoto(navUnitId: "test", localFileName: "test2.jpg"),
            NavUnitPhoto(navUnitId: "test", localFileName: "test3.jpg")
        ]
        
        var body: some View {
            PhotoViewerView(
                photos: samplePhotos,
                selectedPhoto: $selectedPhoto,
                onDelete: { _ in }
            )
        }
    }
    
    return PhotoViewerPreview()
}