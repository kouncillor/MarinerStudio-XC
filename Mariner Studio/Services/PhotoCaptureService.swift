//import Foundation
//import UIKit
//import PhotosUI
//import SwiftUI
//import AVFoundation
//
//// Protocol for photo capture service
//protocol PhotoCaptureService {
//    func requestPhotoLibraryPermission() async -> Bool
//    func requestCameraPermission() async -> Bool
//    func presentPhotoPicker() -> PhotoPickerView
//}
//
//// Implementation of photo capture service
//class PhotoCaptureServiceImpl: PhotoCaptureService {
//    
//    func requestPhotoLibraryPermission() async -> Bool {
//        return await withCheckedContinuation { continuation in
//            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
//            
//            switch status {
//            case .authorized, .limited:
//                continuation.resume(returning: true)
//            case .denied, .restricted:
//                continuation.resume(returning: false)
//            case .notDetermined:
//                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
//                    DispatchQueue.main.async {
//                        continuation.resume(returning: newStatus == .authorized || newStatus == .limited)
//                    }
//                }
//            @unknown default:
//                continuation.resume(returning: false)
//            }
//        }
//    }
//    
//    func requestCameraPermission() async -> Bool {
//        return await withCheckedContinuation { continuation in
//            switch AVCaptureDevice.authorizationStatus(for: .video) {
//            case .authorized:
//                continuation.resume(returning: true)
//            case .denied, .restricted:
//                continuation.resume(returning: false)
//            case .notDetermined:
//                AVCaptureDevice.requestAccess(for: .video) { granted in
//                    DispatchQueue.main.async {
//                        continuation.resume(returning: granted)
//                    }
//                }
//            @unknown default:
//                continuation.resume(returning: false)
//            }
//        }
//    }
//    
//    func presentPhotoPicker() -> PhotoPickerView {
//        return PhotoPickerView()
//    }
//}
//
//// SwiftUI wrapper for PHPickerViewController
//struct PhotoPickerView: UIViewControllerRepresentable {
//    @Environment(\.presentationMode) var presentationMode
//    
//    // Callback for when photo is selected
//    var onPhotoSelected: ((UIImage) -> Void)?
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
//        let parent: PhotoPickerView
//        
//        init(_ parent: PhotoPickerView) {
//            self.parent = parent
//        }
//        
//        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
//            parent.presentationMode.wrappedValue.dismiss()
//            
//            guard let result = results.first else { return }
//            
//            // Load the image from the picker result
//            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
//                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
//                    if let error = error {
//                        print("❌ PhotoPickerView: Error loading image: \(error.localizedDescription)")
//                        return
//                    }
//                    
//                    guard let image = object as? UIImage else {
//                        print("❌ PhotoPickerView: Failed to convert object to UIImage")
//                        return
//                    }
//                    
//                    DispatchQueue.main.async {
//                        self?.parent.onPhotoSelected?(image)
//                    }
//                }
//            }
//        }
//    }
//}
//
//// Extension to add convenience initializer with callback
//extension PhotoPickerView {
//    func onPhotoSelected(_ callback: @escaping (UIImage) -> Void) -> PhotoPickerView {
//        var view = self
//        view.onPhotoSelected = callback
//        return view
//    }
//}





import Foundation
import UIKit
import PhotosUI
import SwiftUI
import AVFoundation

// Protocol for photo capture service
protocol PhotoCaptureService {
    func requestPhotoLibraryPermission() async -> Bool
    func requestCameraPermission() async -> Bool
    func presentBasicPhotoPicker() -> BasicPhotoPickerView
}

// Implementation of photo capture service
class PhotoCaptureServiceImpl: PhotoCaptureService {
    
    func requestPhotoLibraryPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            
            switch status {
            case .authorized, .limited:
                continuation.resume(returning: true)
            case .denied, .restricted:
                continuation.resume(returning: false)
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                    DispatchQueue.main.async {
                        continuation.resume(returning: newStatus == .authorized || newStatus == .limited)
                    }
                }
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }
    
    func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                continuation.resume(returning: true)
            case .denied, .restricted:
                continuation.resume(returning: false)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }
    
    func presentBasicPhotoPicker() -> BasicPhotoPickerView {
        return BasicPhotoPickerView()
    }
}

// SwiftUI wrapper for PHPickerViewController (Basic version)
struct BasicPhotoPickerView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    
    // Callback for when photo is selected
    var onPhotoSelected: ((UIImage) -> Void)?
    
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
        let parent: BasicPhotoPickerView
        
        init(_ parent: BasicPhotoPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let result = results.first else { return }
            
            // Load the image from the picker result
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    if let error = error {
                        print("❌ BasicPhotoPickerView: Error loading image: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let image = object as? UIImage else {
                        print("❌ BasicPhotoPickerView: Failed to convert object to UIImage")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self?.parent.onPhotoSelected?(image)
                    }
                }
            }
        }
    }
}

// Extension to add convenience initializer with callback
extension BasicPhotoPickerView {
    func onPhotoSelected(_ callback: @escaping (UIImage) -> Void) -> BasicPhotoPickerView {
        var view = self
        view.onPhotoSelected = callback
        return view
    }
}
