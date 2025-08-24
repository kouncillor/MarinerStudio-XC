//
//  PhotoSyncStatus.swift
//  Mariner Studio
//
//  Sync status model for nav unit photo operations
//

import Foundation

struct PhotoSyncStatus {
    let totalPhotos: Int
    let uploadedPhotos: Int
    let pendingUploads: Int
    let downloadedPhotos: Int
    let cloudPhotos: Int
    let isAtLimit: Bool
    let lastSyncDate: Date?

    // MARK: - Computed Properties

    /// Photos available for upload
    var photosToUpload: Int {
        return pendingUploads
    }

    /// Photos available for download
    var photosToDownload: Int {
        return cloudPhotos - downloadedPhotos
    }

    /// Sync completion percentage (0.0 to 1.0)
    var syncProgress: Double {
        guard totalPhotos > 0 else { return 1.0 }
        return Double(uploadedPhotos) / Double(totalPhotos)
    }

    /// Check if sync is in progress
    var isSyncing: Bool {
        return pendingUploads > 0
    }

    /// Check if all local photos are uploaded
    var isFullyUploaded: Bool {
        return pendingUploads == 0 && totalPhotos > 0
    }

    /// Check if all cloud photos are downloaded
    var isFullyDownloaded: Bool {
        return photosToDownload == 0 && cloudPhotos > 0
    }

    /// No photo limit with CloudKit - always unlimited
    var remainingSlots: Int {
        return Int.max
    }

    // MARK: - Initializers

    init(
        totalPhotos: Int = 0,
        uploadedPhotos: Int = 0,
        pendingUploads: Int = 0,
        downloadedPhotos: Int = 0,
        cloudPhotos: Int = 0,
        isAtLimit: Bool = false,
        lastSyncDate: Date? = nil
    ) {
        self.totalPhotos = totalPhotos
        self.uploadedPhotos = uploadedPhotos
        self.pendingUploads = pendingUploads
        self.downloadedPhotos = downloadedPhotos
        self.cloudPhotos = cloudPhotos
        self.isAtLimit = isAtLimit
        self.lastSyncDate = lastSyncDate
    }

    // MARK: - Factory Methods

    /// Empty status for nav units with no photos
    static var empty: PhotoSyncStatus {
        return PhotoSyncStatus()
    }

    /// Status for nav units at the 10 photo limit
    static func atLimit(totalPhotos: Int, uploadedPhotos: Int) -> PhotoSyncStatus {
        return PhotoSyncStatus(
            totalPhotos: totalPhotos,
            uploadedPhotos: uploadedPhotos,
            pendingUploads: max(0, totalPhotos - uploadedPhotos),
            isAtLimit: true
        )
    }
}

// MARK: - Photo Sync Operation Result

enum PhotoSyncResult {
    case success(PhotoSyncStatus)
    case failure(PhotoSyncError)
    case partialSuccess(PhotoSyncStatus, [PhotoSyncError])
}

// MARK: - Photo Sync Errors

enum PhotoSyncError: Error, LocalizedError {
    case noInternetConnection
    case authenticationFailed
    case photoLimitExceeded
    case fileNotFound(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case compressionFailed
    case invalidImageData
    case supabaseError(String)
    case storageQuotaExceeded

    var errorDescription: String? {
        switch self {
        case .noInternetConnection:
            return "No internet connection available"
        case .authenticationFailed:
            return "Authentication failed - please sign in again"
        case .photoLimitExceeded:
            return "Photo limit exceeded (this should not occur with CloudKit)"
        case .fileNotFound(let fileName):
            return "Photo file not found: \(fileName)"
        case .uploadFailed(let fileName):
            return "Failed to upload photo: \(fileName)"
        case .downloadFailed(let fileName):
            return "Failed to download photo: \(fileName)"
        case .compressionFailed:
            return "Failed to compress photo for upload"
        case .invalidImageData:
            return "Invalid image data"
        case .supabaseError(let message):
            return "Supabase error: \(message)"
        case .storageQuotaExceeded:
            return "Storage quota exceeded"
        }
    }
}

// MARK: - Remote Photo Model

struct RemotePhoto: Codable {
    let id: String
    let navUnitId: String
    let fileName: String
    let userId: String
    let storagePath: String
    let fileSize: Int?
    let mimeType: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case navUnitId = "nav_unit_id"
        case fileName = "file_name"
        case userId = "user_id"
        case storagePath = "storage_path"
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
