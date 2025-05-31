//
//  PhotoGalleryView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/31/25.
//


import SwiftUI

struct PhotoGalleryView: View {
    @ObservedObject var viewModel: PhotoGalleryViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.photos.isEmpty {
                    VStack {
                        Image(systemName: "photo.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("No photos to display")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding(.top)
                    }
                } else {
                    VStack {
                        // Photo counter
                        HStack {
                            Text(viewModel.photoCountText)
                                .foregroundColor(.white)
                                .font(.caption)
                                .padding(.horizontal)
                            Spacer()
                        }
                        .padding(.top)
                        
                        // Main photo display with swipe navigation
                        TabView(selection: $viewModel.currentIndex) {
                            ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { index, photo in
                                FullScreenPhotoView(
                                    photo: photo,
                                    fileStorageService: viewModel.fileStorageService
                                )
                                .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .ignoresSafeArea()
                        
                        Spacer()
                    }
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                        
                        VStack {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                            Text("Processing...")
                                .foregroundColor(.white)
                                .padding(.top)
                        }
                    }
                }
                
                // Error message
                if !viewModel.errorMessage.isEmpty {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Text(viewModel.errorMessage)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(8)
                                .onTapGesture {
                                    viewModel.clearError()
                                }
                            
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Share button
                        Button(action: {
                            viewModel.shareCurrentPhoto()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }
                        .disabled(viewModel.currentPhoto == nil)
                        
                        // Delete button
                        Button(action: {
                            viewModel.deleteCurrentPhoto()
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .disabled(viewModel.currentPhoto == nil)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .alert("Delete Photo", isPresented: $viewModel.showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.confirmDelete()
                    
                    // If no photos left, dismiss gallery
                    if viewModel.photos.isEmpty {
                        isPresented = false
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this photo? This action cannot be undone.")
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
struct PhotoGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoGalleryView(
            viewModel: PhotoGalleryViewModel(
                photos: [
                    NavUnitPhoto(
                        id: 1,
                        navUnitId: "TEST001",
                        filePath: "/test/path/photo1.jpg",
                        fileName: "photo1.jpg",
                        description: "Test photo 1"
                    ),
                    NavUnitPhoto(
                        id: 2,
                        navUnitId: "TEST001", 
                        filePath: "/test/path/photo2.jpg",
                        fileName: "photo2.jpg",
                        description: "Test photo 2"
                    )
                ],
                startingIndex: 0,
                fileStorageService: try! FileStorageServiceImpl(),
                photoService: PhotoDatabaseService(databaseCore: DatabaseCore())
            ),
            isPresented: .constant(true)
        )
    }
}
#endif