//
//  DocumentPickerExportDelegate.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/25/25.
//

//
//  DocumentPickerExportDelegate.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/25/25.
//

import UIKit

class DocumentPickerExportDelegate: NSObject, UIDocumentPickerDelegate {
    typealias CompletionHandler = (Result<URL, Error>) -> Void

    private let completion: CompletionHandler

    init(completion: @escaping CompletionHandler) {
        self.completion = completion
        super.init()
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            completion(.failure(DocumentPickerError.noDocumentSelected))
            return
        }

        print("📄 DocumentPickerExportDelegate: Document saved to \(url.lastPathComponent)")
        completion(.success(url))
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("📄 DocumentPickerExportDelegate: Export cancelled by user")
        completion(.failure(DocumentPickerError.exportCancelled))
    }
}

// MARK: - Document Picker Errors

enum DocumentPickerError: Error, LocalizedError {
    case noDocumentSelected
    case exportCancelled
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .noDocumentSelected:
            return "No document location selected"
        case .exportCancelled:
            return "Export cancelled by user"
        case .exportFailed(let details):
            return "Export failed: \(details)"
        }
    }
}
