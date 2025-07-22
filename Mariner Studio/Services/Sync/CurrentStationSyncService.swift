
//
//  CurrentStationSyncService.swift
//  Mariner
//
//  Created by Swift Developer on 2025-06-27.
//

import Foundation
import UIKit
import Supabase

final class CurrentStationSyncService {
    // MODIFICATION: The 'shared' instance is now a 'let' and will be configured once.
    static let shared = CurrentStationSyncService()
    
    // MODIFICATION: This is now a 'let' and will be injected.
    private let localDatabase: CurrentStationDatabaseService
    private let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"

    // MODIFICATION: The initializer now accepts the database service.
    // We also make it public so the ServiceProvider can call it.
    init(databaseService: CurrentStationDatabaseService = ServiceProvider().currentStationService) {
        print("🌊 CURRENT_SYNC_SERVICE: Initializing with injected database service.")
        self.localDatabase = databaseService
    }

    // ... The rest of the file (syncCurrentStationFavorites, etc.) remains exactly the same ...
    func syncCurrentStationFavorites() async -> Result<TideSyncStats, Error> {
        let startTime = Date()
        print("\n🟢🌊 SYNC START: Current Station Favorites Sync Initiated at \(startTime)")
        
        do {
            // STEP 1: Authentication
            print("🔐🌊 SYNC STEP 1: Authenticating user...")
            guard let session = try? await SupabaseManager.shared.getSession() else {
                print("❌🌊 SYNC FAILED: User not authenticated.")
                return .failure(TideSyncError.authenticationRequired)
            }
            let userId = session.user.id
            print("✅🌊 SYNC STEP 1: Authentication successful. User ID: \(userId)")

            // STEP 2: Fetch Local and Remote Data Concurrently
            print("📡🌊 SYNC STEP 2: Fetching local and remote data concurrently...")
            async let remoteFavoritesTask: () = print("☁️ Fetching remote favorites...")
            async let localFavoritesTask: () = print("📱 Fetching local favorites...")

            let (remoteFavorites, localFavorites) = try await (
                fetchRemoteFavorites(for: userId),
                self.localDatabase.getAllCurrentStationFavoritesForUser()
            )
            print("✅🌊 SYNC STEP 2: Data fetching complete. Local: \(localFavorites.count), Remote: \(remoteFavorites.count)")


            // STEP 3: Compare and Sync
            print("🔄🌊 SYNC STEP 3: Comparing local and remote data...")
            let result = await compareAndSync(
                local: localFavorites,
                remote: remoteFavorites,
                userId: userId,
                startTime: startTime
            )
            print("🏁🌊 SYNC COMPLETE: Process finished.")
            return result

        } catch {
            print("💥🌊 SYNC CATASTROPHIC ERROR: \(error.localizedDescription)")
            return .failure(TideSyncError.unknownError(error.localizedDescription))
        }
    }
    
    
    
    
    
    
    
    
    
    
    private func fetchRemoteFavorites(for userId: UUID) async throws -> [RemoteCurrentFavorite] {
        print("  ☁️ 1. Preparing to fetch remote favorites for user \(userId)...")
        do {
            let queryStartTime = Date()
            let response: [RemoteCurrentFavorite] = try await SupabaseManager.shared.from("user_current_favorites")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let duration = Date().timeIntervalSince(queryStartTime)
            print("  ✅☁️ 2. Remote fetch successful in \(String(format: "%.3f", duration))s. Found \(response.count) records.")
            if let first = response.first {
                print("  📄 Sample Remote Record: \(first.stationId), Bin: \(first.currentBin), Fav: \(first.isFavorite), Modified: \(first.lastModified)")
            }
            return response
        } catch {
            print("  ❌☁️ 2. Remote fetch FAILED. Error: \(error.localizedDescription)")
            // Re-throw the error to be caught by the main sync function
            throw error
        }
    }

    private func compareAndSync(local: [TidalCurrentFavoriteRecord], remote: [RemoteCurrentFavorite], userId: UUID, startTime: Date) async -> Result<TideSyncStats, Error> {
        let localSet = Set(local.map { "\($0.stationId):\($0.currentBin)" })
        let remoteSet = Set(remote.map { "\($0.stationId):\($0.currentBin)" })

        var uploadedCount = 0, downloadedCount = 0, conflictsUploaded = 0, conflictsDownloaded = 0, errorCount = 0

        do {
            // UPLOAD
            let toUploadIds = localSet.subtracting(remoteSet)
            if !toUploadIds.isEmpty {
                print("  📤 UPLOAD: Found \(toUploadIds.count) local-only records to upload.")
                let recordsToUpload = local.filter { toUploadIds.contains("\($0.stationId):\($0.currentBin)") }
                uploadedCount = try await uploadNewFavorites(recordsToUpload, userId: userId)
                 print("  ✅📤 UPLOAD: Successfully uploaded \(uploadedCount) records.")
            }

            // DOWNLOAD
            let toDownloadIds = remoteSet.subtracting(localSet)
            if !toDownloadIds.isEmpty {
                 print("  📥 DOWNLOAD: Found \(toDownloadIds.count) remote-only records to download.")
                let recordsToDownload = remote.filter { toDownloadIds.contains("\($0.stationId):\($0.currentBin)") }
                downloadedCount = await downloadNewFavorites(recordsToDownload)
                 print("  ✅📥 DOWNLOAD: Successfully downloaded \(downloadedCount) records.")
            }
            
            // CONFLICTS
            let toResolveIds = localSet.intersection(remoteSet)
            if !toResolveIds.isEmpty {
                 print("  ⚔️ CONFLICTS: Found \(toResolveIds.count) records existing in both places to resolve.")
                let localForConflict = local.filter { toResolveIds.contains("\($0.stationId):\($0.currentBin)") }
                let remoteForConflict = remote.filter { toResolveIds.contains("\($0.stationId):\($0.currentBin)") }
                let resolvedStats = await resolveConflicts(local: localForConflict, remote: remoteForConflict, userId: userId)
                conflictsUploaded = resolvedStats.uploaded
                conflictsDownloaded = resolvedStats.downloaded
                 print("  ✅⚔️ CONFLICTS: Resolution complete. Uploaded: \(conflictsUploaded), Downloaded: \(conflictsDownloaded).")
            }
            
            let stats = TideSyncStats(
                operationId: "current_sync_\(Date().timeIntervalSince1970)",
                startTime: startTime, endTime: Date(),
                localFavoritesFound: local.count, remoteFavoritesFound: remote.count,
                uploaded: uploadedCount + conflictsUploaded,
                downloaded: downloadedCount + conflictsDownloaded,
                conflictsResolved: conflictsUploaded + conflictsDownloaded,
                errors: errorCount
            )
            
            return .success(stats)

        } catch {
            print("  ❌ Compare/Sync Error: \(error.localizedDescription)")
            errorCount += 1
            return .failure(TideSyncError.supabaseError(error.localizedDescription))
        }
    }
        
    private func uploadNewFavorites(_ records: [TidalCurrentFavoriteRecord], userId: UUID) async throws -> Int {
        let remoteRecords = records.map {
            RemoteCurrentFavorite(
                userId: userId, stationId: $0.stationId, currentBin: $0.currentBin,
                isFavorite: $0.isFavorite, lastModified: $0.lastModified, deviceId: self.deviceId,
                stationName: $0.stationName, latitude: $0.latitude, longitude: $0.longitude,
                depth: $0.depth, depthType: $0.depthType
            )
        }
        try await SupabaseManager.shared.from("user_current_favorites").insert(remoteRecords).execute()
        return remoteRecords.count
    }

    private func downloadNewFavorites(_ records: [RemoteCurrentFavorite]) async -> Int {
        var downloadCount = 0
        for record in records {
            do {
                try await localDatabase.setCurrentStationFavorite(
                    stationId: record.stationId, currentBin: record.currentBin, isFavorite: record.isFavorite,
                    stationName: record.stationName, latitude: record.latitude, longitude: record.longitude,
                    depth: record.depth, depthType: record.depthType, lastModified: record.lastModified
                )
                downloadCount += 1
            } catch { print("  ❌ Download Error: Failed to save record \(record.stationId): \(error)") }
        }
        return downloadCount
    }
    
    private func resolveConflicts(local: [TidalCurrentFavoriteRecord], remote: [RemoteCurrentFavorite], userId: UUID) async -> (uploaded: Int, downloaded: Int) {
        var uploaded = 0, downloaded = 0
        let remoteDict: [String: RemoteCurrentFavorite] = Dictionary(uniqueKeysWithValues: remote.map { ("\($0.stationId):\($0.currentBin)", $0) })
        
        for localRecord in local {
            let key = "\(localRecord.stationId):\(localRecord.currentBin)"
            guard let remoteRecord = remoteDict[key] else { continue }
            
            let timeDiff = localRecord.lastModified.timeIntervalSince(remoteRecord.lastModified)
            print("🕒 TIMESTAMP CHECK: \(localRecord.stationId) - Local: \(localRecord.lastModified), Remote: \(remoteRecord.lastModified), Diff: \(timeDiff)s")
            
            let tolerance: TimeInterval = 0.01  // 10 millisecond tolerance
            
            if timeDiff > tolerance {
                print("⬆️ LOCAL NEWER: Uploading \(localRecord.stationId)")
                do {
                    let updatedRemoteRecord = RemoteCurrentFavorite(
                        userId: userId, stationId: localRecord.stationId, currentBin: localRecord.currentBin,
                        isFavorite: localRecord.isFavorite, lastModified: localRecord.lastModified, deviceId: self.deviceId,
                        stationName: localRecord.stationName, latitude: localRecord.latitude, longitude: localRecord.longitude,
                        depth: localRecord.depth, depthType: localRecord.depthType
                    )
                    try await SupabaseManager.shared.from("user_current_favorites")
                        .update(updatedRemoteRecord)
                        .eq("user_id", value: userId).eq("station_id", value: localRecord.stationId).eq("current_bin", value: localRecord.currentBin)
                        .execute()
                    uploaded += 1
                } catch { print("  ❌ Conflict Error (Upload): \(error)") }
            } else if timeDiff < -tolerance {
                print("⬇️ REMOTE NEWER: Downloading \(remoteRecord.stationId)")
                do {
                    try await localDatabase.setCurrentStationFavorite(
                        stationId: remoteRecord.stationId, currentBin: remoteRecord.currentBin, isFavorite: remoteRecord.isFavorite,
                        stationName: remoteRecord.stationName, latitude: remoteRecord.latitude, longitude: remoteRecord.longitude,
                        depth: remoteRecord.depth, depthType: remoteRecord.depthType, lastModified: remoteRecord.lastModified
                    )
                    downloaded += 1
                } catch { print("  ❌ Conflict Error (Download): \(error)") }
            } else {
                print("⏸️ TIMESTAMPS WITHIN TOLERANCE: Skipping \(localRecord.stationId) (diff: \(String(format: "%.6f", timeDiff))s)")
            }
        }
        return (uploaded, downloaded)
    }
}
