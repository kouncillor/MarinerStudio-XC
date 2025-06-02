//import SwiftUI
//import PhotosUI
//import AVFoundation
//
//// Enhanced photo picker with camera and library options
//struct PhotoPickerView: View {
//    @Binding var isPresented: Bool
//    let onPhotoSelected: (UIImage) -> Void
//    
//    @State private var showingPhotoPicker = false
//    @State private var showingCamera = false
//    @State private var showingPermissionAlert = false
//    @State private var permissionAlertMessage = ""
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            Text("Add Photo")
//                .font(.title2)
//                .fontWeight(.semibold)
//                .padding()
//            
//            VStack(spacing: 16) {
//                // Camera Button
//                Button(action: {
//                    Task {
//                        await requestCameraPermissionAndPresent()
//                    }
//                }) {
//                    HStack {
//                        Image(systemName: "camera.fill")
//                            .font(.title2)
//                        Text("Take Photo")
//                            .font(.headline)
//                    }
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color.blue)
//                    .cornerRadius(10)
//                }
//                
//                // Photo Library Button
//                Button(action: {
//                    Task {
//                        await requestPhotoLibraryPermissionAndPresent()
//                    }
//                }) {
//                    HStack {
//                        Image(systemName: "photo.on.rectangle")
//                            .font(.title2)
//                        Text("Choose from Library")
//                            .font(.headline)
//                    }
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color.green)
//                    .cornerRadius(10)
//                }
//                
//                // Cancel Button
//                Button(action: {
//                    isPresented = false
//                }) {
//                    Text("Cancel")
//                        .font(.headline)
//                        .foregroundColor(.secondary)
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color(UIColor.systemGray6))
//                        .cornerRadius(10)
//                }
//            }
//            .padding(.horizontal)
//            
//            Spacer()
//        }
//        .sheet(isPresented: $showingPhotoPicker) {
//            PHPickerWrapper(onPhotoSelected: { image in
//                onPhotoSelected(image)
//                isPresented = false
//            })
//        }
//        .sheet(isPresented: $showingCamera) {
//            CameraWrapper(onPhotoSelected: { image in
//                onPhotoSelected(image)
//                isPresented = false
//            })
//        }
//        .alert("Permission Required", isPresented: $showingPermissionAlert) {
//            Button("Settings") {
//                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
//                    UIApplication.shared.open(settingsURL)
//                }
//            }
//            Button("Cancel", role: .cancel) { }
//        } message: {
//            Text(permissionAlertMessage)
//        }
//    }
//    
//    private func requestCameraPermissionAndPresent() async {
//        switch AVCaptureDevice.authorizationStatus(for: .video) {
//        case .authorized:
//            await MainActor.run {
//                showingCamera = true
//            }
//        case .notDetermined:
//            let granted = await AVCaptureDevice.requestAccess(for: .video)
//            await MainActor.run {
//                if granted {
//                    showingCamera = true
//                } else {
//                    permissionAlertMessage = "Camera access is required to take photos. Please enable it in Settings."
//                    showingPermissionAlert = true
//                }
//            }
//        case .denied, .restricted:
//            await MainActor.run {
//                permissionAlertMessage = "Camera access is currently denied. Please enable it in Settings to take photos."
//                showingPermissionAlert = true
//            }
//        @unknown default:
//            break
//        }
//    }
//    
//    private func requestPhotoLibraryPermissionAndPresent() async {
//        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
//        
//        switch status {
//        case .authorized, .limited:
//            await MainActor.run {
//                showingPhotoPicker = true
//            }
//        case .notDetermined:
//            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
//            await MainActor.run {
//                if newStatus == .authorized || newStatus == .limited {
//                    showingPhotoPicker = true
//                } else {
//                    permissionAlertMessage = "Photo library access is required to select photos. Please enable it in Settings."
//                    showingPermissionAlert = true
//                }
//            }
//        case .denied, .restricted:
//            await MainActor.run {
//                permissionAlertMessage = "Photo library access is currently denied. Please enable it in Settings to select photos."
//                showingPermissionAlert = true
//            }
//        @unknown default:
//            break
//        }
//    }
//}
//
//// Wrapper for PHPickerViewController
//struct PHPickerWrapper: UIViewControllerRepresentable {
//    let onPhotoSelected: (UIImage) -> Void
//    @Environment(\.presentationMode) var presentationMode
//    
//    func makeUIViewController(context: Context) -> PHPickerViewController {
//        var config = PHPickerConfiguration()
//        config.filter = .images
//        config.selectionLimit = 1
//        config.preferredAssetRepresentationMode = .current
//        
//        let picker = PHPickerViewController(configuration: config)
//        picker.delegate = context.coordinator
//        return picker
//    }
//    
//    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
//        // No updates needed
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//    
//    class Coordinator: NSObject, PHPickerViewControllerDelegate {
//        let parent: PHPickerWrapper
//        
//        init(_ parent: PHPickerWrapper) {
//            self.parent = parent
//        }
//        
//        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
//            parent.presentationMode.wrappedValue.dismiss()
//            
//            guard let result = results.first else { return }
//            
//            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
//                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
//                    if let error = error {
//                        print("❌ PHPickerWrapper: Error loading image: \(error.localizedDescription)")
//                        return
//                    }
//                    
//                    guard let image = object as? UIImage else {
//                        print("❌ PHPickerWrapper: Failed to convert object to UIImage")
//                        return
//                    }
//                    
//                    DispatchQueue.main.async {
//                        self?.parent.onPhotoSelected(image)
//                    }
//                }
//            }
//        }
//    }
//}
//
//// Wrapper for UIImagePickerController (Camera)
//struct CameraWrapper: UIViewControllerRepresentable {
//    let onPhotoSelected: (UIImage) -> Void
//    @Environment(\.presentationMode) var presentationMode
//    
//    func makeUIViewController(context: Context) -> UIImagePickerController {
//        let picker = UIImagePickerController()
//        picker.sourceType = .camera
//        picker.cameraCaptureMode = .photo
//        picker.delegate = context.coordinator
//        return picker
//    }
//    
//    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
//        // No updates needed
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//    
//    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
//        let parent: CameraWrapper
//        
//        init(_ parent: CameraWrapper) {
//            self.parent = parent
//        }
//        
//        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//            parent.presentationMode.wrappedValue.dismiss()
//            
//            guard let image = info[.originalImage] as? UIImage else {
//                print("❌ CameraWrapper: Failed to get image from camera")
//                return
//            }
//            
//            parent.onPhotoSelected(image)
//        }
//        
//        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//            parent.presentationMode.wrappedValue.dismiss()
//        }
//    }
//}












import SwiftUI
import PhotosUI
import AVFoundation

// Enhanced photo picker with loading states and progress feedback
struct PhotoPickerView: View {
    @Binding var isPresented: Bool
    let onPhotoSelected: (UIImage) -> Void
    
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    // NEW: Processing states
    @State private var isProcessingPhoto = false
    @State private var processingMessage = "Processing photo..."
    @State private var selectedImage: UIImage?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Photo")
                .font(.title2)
                .fontWeight(.semibold)
                .padding()
            
            // NEW: Processing overlay
            if isProcessingPhoto {
                processingView
            } else {
                selectionView
            }
            
            Spacer()
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PHPickerWrapper(onPhotoSelected: { image in
                handlePhotoSelection(image)
            })
        }
        .sheet(isPresented: $showingCamera) {
            CameraWrapper(onPhotoSelected: { image in
                handlePhotoSelection(image)
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
    
    // NEW: Photo selection buttons view
    private var selectionView: some View {
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
    }
    
    // NEW: Processing view with progress feedback
    private var processingView: some View {
        VStack(spacing: 24) {
            // Preview of selected photo
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Processing indicator
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.blue)
                
                Text(processingMessage)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Please wait while we save and sync your photo...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Status indicators
            VStack(alignment: .leading, spacing: 8) {
                ProcessingStepView(
                    title: "Saving to device",
                    isCompleted: true,
                    isActive: false
                )
                
                ProcessingStepView(
                    title: "Syncing to iCloud",
                    isCompleted: false,
                    isActive: true
                )
                
                ProcessingStepView(
                    title: "Complete",
                    isCompleted: false,
                    isActive: false
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.systemGray6))
            )
        }
        .padding(.horizontal)
    }
    
    // NEW: Handle photo selection with processing feedback
    private func handlePhotoSelection(_ image: UIImage) {
        selectedImage = image
        isProcessingPhoto = true
        processingMessage = "Preparing photo..."
        
        // Start the save process
        Task {
            // Update processing message
            await MainActor.run {
                processingMessage = "Saving photo..."
            }
            
            // Brief delay to show the processing UI
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Call the completion handler
            onPhotoSelected(image)
            
            // The view model will handle the actual saving and syncing
            // We'll monitor for completion through other means
            
            // Brief delay to ensure the photo picker dismisses smoothly
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                isPresented = false
            }
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

// NEW: Processing step indicator view
struct ProcessingStepView: View {
    let title: String
    let isCompleted: Bool
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(stepColor)
                    .frame(width: 20, height: 20)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                } else if isActive {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                }
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(isCompleted ? .primary : (isActive ? .primary : .secondary))
            
            Spacer()
        }
    }
    
    private var stepColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .blue
        } else {
            return .gray
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
