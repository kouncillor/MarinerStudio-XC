//
//  PhotoService.swift
//  Mariner Studio
//
//  Main photo service protocol for nav unit photo management
//

import Foundation
import UIKit

// MARK: - Photo Service Protocol

protocol PhotoService {
    // MARK: - Local Photo Operations

    /// Get all photos for a specific nav unit
    func getPhotos(for navUnitId: String) async throws -> [NavUnitPhoto]

    /// Take a new photo for a nav unit
    func takePhoto(for navUnitId: String, image: UIImage) async throws -> NavUnitPhoto

    /// Delete a photo (local and remote if uploaded)
    func deletePhoto(_ photo: NavUnitPhoto) async throws

    /// Get photo count for a nav unit
    func getPhotoCount(for navUnitId: String) async throws -> Int

    // MARK: - Manual Sync Operations

    /// Upload all pending photos for a nav unit (manual trigger only)
    func uploadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus

    /// Download all available photos for a nav unit (manual trigger only)
    func downloadPhotos(for navUnitId: String) async throws -> PhotoSyncStatus

    /// Get current sync status for a nav unit
    func getSyncStatus(for navUnitId: String) async throws -> PhotoSyncStatus

    // MARK: - Photo Data Operations

    /// Load photo image data
    func loadPhotoImage(_ photo: NavUnitPhoto) async throws -> UIImage

    /// Load thumbnail image data
    func loadThumbnailImage(_ photo: NavUnitPhoto) async throws -> UIImage

    /// Check if nav unit is at photo limit (no longer applies with CloudKit)
    func isAtPhotoLimit(for navUnitId: String) async throws -> Bool
}
