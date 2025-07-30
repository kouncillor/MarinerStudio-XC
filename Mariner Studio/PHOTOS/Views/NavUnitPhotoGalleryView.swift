//
//  NavUnitPhotoGalleryView.swift
//  Mariner Studio
//
//  Photo gallery view for nav unit photos with thumbnail grid and manual sync
//

import SwiftUI

struct NavUnitPhotoGalleryView: View {
    let navUnitId: String
    @StateObject private var viewModel: PhotoGalleryViewModel
    @State private var showingCamera = false
    @State private var showingPhotoViewer = false
    @State private var selectedPhoto: NavUnitPhoto?
    @State private var capturedImage: UIImage?
    @State private var showingDeleteAlert = false
    @State private var photoToDelete: NavUnitPhoto?

    // MARK: - Grid Configuration

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    // MARK: - Initialization

    init(navUnitId: String, photoService: PhotoService) {
        self.navUnitId = navUnitId
        self._viewModel = StateObject(wrappedValue: PhotoGalleryViewModel(
            navUnitId: navUnitId,
            photoService: photoService
        ))
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.photos.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    mainContentView
                }

                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    cameraButton
                }
            }
            .refreshable {
                await viewModel.refreshPhotos()
            }
            .alert("Delete Photo", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let photo = photoToDelete {
                        Task {
                            await viewModel.deletePhoto(photo)
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this photo? This action cannot be undone.")
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(capturedImage: $capturedImage, isPresented: $showingCamera)
            }
            .sheet(isPresented: $showingPhotoViewer) {
                if let selectedPhoto = selectedPhoto {
                    PhotoViewerView(
                        photos: viewModel.photos,
                        selectedPhoto: $selectedPhoto,
                        onDelete: { photo in
                            photoToDelete = photo
                            showingDeleteAlert = true
                        }
                    )
                }
            }
            .onChange(of: capturedImage) { _, newValue in
                if let image = newValue {
                    Task {
                        await viewModel.takePhoto(image)
                        capturedImage = nil
                    }
                }
            }
        }
    }

    // MARK: - View Components

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Show different icons based on whether photos are available for download
            Image(systemName: viewModel.syncStatus.photosToDownload > 0 ? "icloud.and.arrow.down" : "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(viewModel.syncStatus.photosToDownload > 0 ? .blue : .gray)

            Text(viewModel.syncStatus.photosToDownload > 0 ? "Photos Available" : "No Photos Yet")
                .font(.title2)
                .fontWeight(.semibold)

            // Show different messages based on sync status
            if viewModel.syncStatus.photosToDownload > 0 {
                Text("You have \(viewModel.syncStatus.photosToDownload) photo\(viewModel.syncStatus.photosToDownload == 1 ? "" : "s") stored in the cloud for this navigation unit. Tap download to sync them to this device.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Button(action: {
                    Task {
                        await viewModel.downloadPhotos()
                    }
                }) {
                    HStack {
                        if viewModel.isDownloading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.down")
                        }
                        Text("Download Photos")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isDownloading)

            } else {
                Text("Take your first photo of this navigation unit to get started.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Button("Take Photo") {
                    showingCamera = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canTakePhoto)
            }
        }
        .padding()
    }

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Status and sync controls
            statusHeaderView

            // Photo grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    // Take new photo button
                    takePhotoButton

                    // Photo thumbnails
                    ForEach(viewModel.photos, id: \.id) { photo in
                        PhotoThumbnailView(
                            photo: photo,
                            viewModel: viewModel,
                            onTap: {
                                selectedPhoto = photo
                                showingPhotoViewer = true
                            },
                            onDelete: {
                                photoToDelete = photo
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }

    private var statusHeaderView: some View {
        VStack(spacing: 12) {
            // Photo count and status
            HStack {
                Text(viewModel.photoCountText)
                    .font(.headline)

                Spacer()

                Text(viewModel.syncStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Sync buttons
            if viewModel.showUploadButton || viewModel.showDownloadButton {
                HStack(spacing: 12) {
                    if viewModel.showUploadButton {
                        Button(action: {
                            Task {
                                await viewModel.uploadPhotos()
                            }
                        }) {
                            HStack {
                                if viewModel.isUploading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "icloud.and.arrow.up")
                                }
                                Text("Upload")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isUploading)
                    }

                    if viewModel.showDownloadButton {
                        Button(action: {
                            Task {
                                await viewModel.downloadPhotos()
                            }
                        }) {
                            HStack {
                                if viewModel.isDownloading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "icloud.and.arrow.down")
                                }
                                Text("Download")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isDownloading)
                    }
                }
            }

            // Messages
            if !viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            if !viewModel.successMessage.isEmpty {
                Text(viewModel.successMessage)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private var takePhotoButton: some View {
        Button(action: {
            showingCamera = true
        }) {
            VStack {
                Image(systemName: "camera.fill")
                    .font(.title)
                    .foregroundColor(viewModel.canTakePhoto ? .blue : .gray)

                Text("Take Photo")
                    .font(.caption)
                    .foregroundColor(viewModel.canTakePhoto ? .blue : .gray)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
            )
        }
        .disabled(!viewModel.canTakePhoto)
    }

    private var cameraButton: some View {
        Button(action: {
            showingCamera = true
        }) {
            Image(systemName: "camera.fill")
        }
        .disabled(!viewModel.canTakePhoto)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)

                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
        }
    }
}

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let photo: NavUnitPhoto
    let viewModel: PhotoGalleryViewModel
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            // Image or placeholder
            Group {
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundColor(.gray)
                }
            }
            .frame(height: 120)
            .clipped()

            // Status overlay
            VStack {
                HStack {
                    Spacer()

                    Image(systemName: viewModel.getPhotoStatusIcon(photo))
                        .font(.caption)
                        .foregroundColor(Color(viewModel.getPhotoStatusColor(photo)))
                        .padding(4)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.8))
                        )
                }

                Spacer()
            }
            .padding(6)
        }
        .background(Color(.systemGray5))
        .cornerRadius(8)
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        isLoading = true
        thumbnailImage = await viewModel.loadThumbnail(for: photo)
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        NavUnitPhotoGalleryView(
            navUnitId: "sample_nav_unit",
            photoService: PreviewMockPhotoService()
        )
    }
}

// MARK: - Mock Service for Preview

private class PreviewMockPhotoService: PhotoService {
    func getPhotos(for navUnitId: String) async throws -> [NavUnitPhoto] {
        return []
    }

    func takePhoto(for navUnitId: String, image: UIImage) async throws -> NavUnitPhoto {
        return NavUnitPhoto(navUnitId: navUnitId, localFileName: "test.jpg")
    }

    func deletePhoto(_ photo: NavUnitPhoto) async throws {
        // Mock implementation
    }

    func getPhotoCount(for navUnitId: String) async throws -> Int {
        return 0
    }

    func uploadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus {
        return .empty
    }

    func downloadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus {
        return .empty
    }

    func getSyncStatus(for navUnitId: String) async throws -> PhotoSyncStatus {
        return .empty
    }

    func loadPhotoImage(_ photo: NavUnitPhoto) async throws -> UIImage {
        return UIImage(systemName: "photo") ?? UIImage()
    }

    func loadThumbnailImage(_ photo: NavUnitPhoto) async throws -> UIImage {
        return UIImage(systemName: "photo") ?? UIImage()
    }

    func isAtPhotoLimit(for navUnitId: String) async throws -> Bool {
        return false
    }
}
