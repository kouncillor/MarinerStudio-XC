//
//  CameraView.swift
//  Mariner Studio
//
//  Camera integration for capturing nav unit photos
//

import SwiftUI
import UIKit
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var isPresented: Bool
    
    // MARK: - UIViewControllerRepresentable
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        picker.cameraCaptureMode = .photo
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            // Try to get edited image first, then original
            if let editedImage = info[.editedImage] as? UIImage {
                parent.capturedImage = editedImage
                print("📸 CameraView: Captured edited image")
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.capturedImage = originalImage
                print("📸 CameraView: Captured original image")
            }
            
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("📸 CameraView: Camera cancelled")
            parent.isPresented = false
        }
    }
}

// MARK: - Camera Permission Helper

struct CameraPermissionView: View {
    @Binding var isPresented: Bool
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("To take photos of navigation units, please allow camera access in Settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button("Open Settings") {
                    showingSettings = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .onAppear {
            // Check camera permission
            checkCameraPermission()
        }
        .alert("Settings", isPresented: $showingSettings) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                openSettings()
            }
        } message: {
            Text("Go to Settings > Privacy & Security > Camera to enable camera access for Mariner Studio.")
        }
    }
    
    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            // Permission granted, close this view
            isPresented = false
        case .denied, .restricted:
            // Stay on permission view
            break
        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        isPresented = false
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Camera Availability Check

struct CameraAvailabilityCheck {
    static func isCameraAvailable() -> Bool {
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    static func getCameraAuthorizationStatus() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    static func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

// MARK: - Camera Button Helper

struct CameraButton: View {
    let action: () -> Void
    let isEnabled: Bool
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .resizable()
                .frame(width: 44, height: 44)
                .foregroundColor(isEnabled ? .blue : .gray.opacity(0.5))
        }
        .disabled(!isEnabled)
    }
}


// MARK: - Preview

#Preview {
    struct CameraPreview: View {
        @State private var capturedImage: UIImage?
        @State private var showingCamera = false
        @State private var showingPermission = false
        
        var body: some View {
            VStack(spacing: 20) {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(10)
                }
                
                Button("Take Photo") {
                    if CameraAvailabilityCheck.isCameraAvailable() {
                        let status = CameraAvailabilityCheck.getCameraAuthorizationStatus()
                        if status == .authorized {
                            showingCamera = true
                        } else {
                            showingPermission = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .sheet(isPresented: $showingCamera) {
                CameraView(capturedImage: $capturedImage, isPresented: $showingCamera)
            }
            .sheet(isPresented: $showingPermission) {
                CameraPermissionView(isPresented: $showingPermission)
            }
        }
    }
    
    return CameraPreview()
}