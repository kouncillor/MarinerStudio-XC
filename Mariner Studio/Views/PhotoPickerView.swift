import SwiftUI
import PhotosUI
import AVFoundation

// Enhanced photo picker with camera and library options
struct PhotoPickerView: View {
    @Binding var isPresented: Bool
    let onPhotoSelected: (UIImage) -> Void
    
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Photo")
                .font(.title2)
                .fontWeight(.semibold)
                .padding()
            
            VStack(spacing: 16) {
                // Camera Button
                Button(action: {
                    Task {
                        await requestCameraPermissionAndPresent()
                    }
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Take Photo")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                
                // Photo Library Button
                Button(action: {
                    Task {
                        await requestPhotoLibraryPermissionAndPresent()
                    }
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                        Text("Choose from Library")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
                }
                
                // Cancel Button
                Button(action: {
                    isPresented = false
                }) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PHPickerWrapper(onPhotoSelected: { image in
                onPhotoSelected(image)
                isPresented = false
            })
        }
        .sheet(isPresented: $showingCamera) {
            CameraWrapper(onPhotoSelected: { image in
                onPhotoSelected(image)
                isPresented = false
            })
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionAlertMessage)
        }
    }
    
    private func requestCameraPermissionAndPresent() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await MainActor.run {
                showingCamera = true
            }
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                if granted {
                    showingCamera = true
                } else {
                    permissionAlertMessage = "Camera access is required to take photos. Please enable it in Settings."
                    showingPermissionAlert = true
                }
            }
        case .denied, .restricted:
            await MainActor.run {
                permissionAlertMessage = "Camera access is currently denied. Please enable it in Settings to take photos."
                showingPermissionAlert = true
            }
        @unknown default:
            break
        }
    }
    
    private func requestPhotoLibraryPermissionAndPresent() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            await MainActor.run {
                showingPhotoPicker = true
            }
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                if newStatus == .authorized || newStatus == .limited {
                    showingPhotoPicker = true
                } else {
                    permissionAlertMessage = "Photo library access is required to select photos. Please enable it in Settings."
                    showingPermissionAlert = true
                }
            }
        case .denied, .restricted:
            await MainActor.run {
                permissionAlertMessage = "Photo library access is currently denied. Please enable it in Settings to select photos."
                showingPermissionAlert = true
            }
        @unknown default:
            break
        }
    }
}

// Wrapper for PHPickerViewController
struct PHPickerWrapper: UIViewControllerRepresentable {
    let onPhotoSelected: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerWrapper
        
        init(_ parent: PHPickerWrapper) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let result = results.first else { return }
            
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    if let error = error {
                        print("❌ PHPickerWrapper: Error loading image: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let image = object as? UIImage else {
                        print("❌ PHPickerWrapper: Failed to convert object to UIImage")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self?.parent.onPhotoSelected(image)
                    }
                }
            }
        }
    }
}

// Wrapper for UIImagePickerController (Camera)
struct CameraWrapper: UIViewControllerRepresentable {
    let onPhotoSelected: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraWrapper
        
        init(_ parent: CameraWrapper) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let image = info[.originalImage] as? UIImage else {
                print("❌ CameraWrapper: Failed to get image from camera")
                return
            }
            
            parent.onPhotoSelected(image)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
