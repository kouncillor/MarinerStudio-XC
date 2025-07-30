//
//  DocumentPickerService.swift
//  Mariner Studio
//
//  Created for reusable document picker functionality.
//

import Foundation
import UIKit
import UniformTypeIdentifiers

class DocumentPickerService {

    // MARK: - Singleton
    static let shared = DocumentPickerService()
    private init() {}

    // MARK: - Document Picker for Import

    func presentDocumentPicker(fileTypes: [String]) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let documentPickerVC = UIDocumentPickerViewController(documentTypes: fileTypes, in: .import)

                // Create a delegate to handle the document picker
                let delegate = DocumentPickerImportDelegate { result in
                    switch result {
                    case .success(let url):
                        continuation.resume(returning: url)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }

                // Store the delegate to prevent it from being deallocated
                documentPickerVC.delegate = delegate

                // Present the document picker
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {

                    // Store delegate in a global reference to prevent deallocation
                    DocumentPickerService.currentDelegate = delegate

                    rootViewController.present(documentPickerVC, animated: true)
                } else {
                    continuation.resume(throwing: DocumentPickerImportError.presentationFailed)
                }
            }
        }
    }

    // MARK: - Convenience Methods

    func presentGpxFilePicker() async throws -> URL {
        return try await presentDocumentPicker(fileTypes: ["com.topografix.gpx", "public.xml"])
    }

    func presentMultiFormatFilePicker() async throws -> URL {
        return try await presentDocumentPicker(fileTypes: [
            "com.topografix.gpx",    // GPX files
            "public.xml",            // XML files
            "com.google.earth.kml",  // KML files
            "public.data"            // TCX, FIT, and other data files
        ])
    }

    // MARK: - Static delegate storage to prevent deallocation
    static var currentDelegate: DocumentPickerImportDelegate?
}

// MARK: - Document Picker Import Delegate

class DocumentPickerImportDelegate: NSObject, UIDocumentPickerDelegate {
    typealias CompletionHandler = (Result<URL, Error>) -> Void

    private let completion: CompletionHandler

    init(completion: @escaping CompletionHandler) {
        self.completion = completion
        super.init()
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("📁 PICKER: Document selected: \(urls)")

        guard let url = urls.first else {
            print("📁 PICKER: ❌ No document selected")
            completion(.failure(DocumentPickerImportError.noDocumentSelected))
            return
        }

        print("📁 PICKER: ✅ Selected file: \(url.lastPathComponent)")
        print("📁 PICKER: 📍 File path: \(url.path)")

        // Ensure we have access to the URL
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
                print("📁 PICKER: 🔓 Stopped accessing security-scoped resource")
            }
        }

        completion(.success(url))

        // Clear the delegate reference
        DocumentPickerService.currentDelegate = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("📁 PICKER: ⚠️ Document picker was cancelled")
        completion(.failure(DocumentPickerImportError.cancelled))

        // Clear the delegate reference
        DocumentPickerService.currentDelegate = nil
    }
}

// MARK: - Custom Errors

enum DocumentPickerImportError: Error, LocalizedError {
    case presentationFailed
    case noDocumentSelected
    case cancelled
    case fileAccessDenied

    var errorDescription: String? {
        switch self {
        case .presentationFailed:
            return "Unable to present document picker"
        case .noDocumentSelected:
            return "No document was selected"
        case .cancelled:
            return "Document selection was cancelled"
        case .fileAccessDenied:
            return "Access to the selected file was denied"
        }
    }
}
