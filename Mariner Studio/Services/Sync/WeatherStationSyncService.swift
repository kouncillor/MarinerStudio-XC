import Foundation
import Supabase
import UIKit

// MARK: - Date Extensions for Supabase
extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

/// Singleton service for syncing weather location favorites between local SQLite and Supabase
final class WeatherStationSyncService {
    
    // MARK: - Shared Instance
    static let shared = WeatherStationSyncService()
    
    // MARK: - Private Properties
    private let syncQueue = DispatchQueue(label: "weatherSync.operations", qos: .utility)
    private let logQueue = DispatchQueue(label: "weatherSync.logging", qos: .background)
    private var activeSyncOperations: [String: Date] = [:]
    private let operationsLock = NSLock()
    private var syncCounter: Int = 0
    
    // MARK: - Performance Tracking
    private var operationStats: [String: TideSyncOperationStats] = [:]
    private let statsLock = NSLock()
    
    // MARK: - Initialization
    private init() {
        logQueue.async {
            print("\n🌤️ WEATHER SYNC SERVICE: Initializing comprehensive sync system")
            print("🌤️ WEATHER SYNC SERVICE: Thread = \(Thread.current)")
            print("🌤️ WEATHER SYNC SERVICE: Timestamp = \(Date())")
            print("🌤️ WEATHER SYNC SERVICE: Ready for sync operations\n")
        }
    }
    
    // MARK: - Public Sync Methods
    
    /// Main bidirectional sync method with HEAVY LOGGING
    func syncWeatherLocationFavorites() async -> TideSyncResult {
        let operationId = startSyncOperation("fullSync")
        let startTime = Date()
        
        logQueue.async {
            print("\n🟢🌤️ FULL SYNC START: ===================================================")
            print("🟢🌤️ FULL SYNC: Operation ID = \(operationId)")
            print("🟢🌤️ FULL SYNC: Start timestamp = \(startTime)")
            print("🟢🌤️ FULL SYNC: Thread = \(Thread.current)")
            print("🟢🌤️ FULL SYNC: Process ID = \(ProcessInfo.processInfo.processIdentifier)")
        }
        
        do {
            // STEP 1: Authentication Check with heavy logging
            logQueue.async {
                print("\n🔐🌤️ AUTH CHECK: Starting authentication verification...")
                print("🔐🌤️ AUTH CHECK: Using SupabaseManager.shared for session retrieval")
            }
            
            guard let session = try? await SupabaseManager.shared.getSession() else {
                logQueue.async {
                    print("\n❌🔐🌤️ AUTH FAILED: No valid session found")
                    print("❌🔐🌤️ AUTH FAILED: User must be authenticated to sync")
                    print("❌🔐🌤️ AUTH FAILED: Terminating sync operation")
                }
                endSyncOperation(operationId, success: false, error: TideSyncError.authenticationRequired)
                return .failure(.authenticationRequired)
            }
            
            logQueue.async {
                print("\n✅🔐🌤️ AUTH SUCCESS: Session retrieved successfully")
                print("✅🔐🌤️ AUTH SUCCESS: User ID = \(session.user.id)")
                print("✅🔐🌤️ AUTH SUCCESS: User email = \(session.user.email ?? "NO EMAIL")")
                print("✅🔐🌤️ AUTH SUCCESS: Session expires at = \(Date(timeIntervalSince1970: TimeInterval(session.expiresAt)))")
            }
            
            // STEP 2: Database Service Access with heavy logging
            logQueue.async {
                print("\n💾🌤️ DATABASE: Attempting to get database service...")
                print("💾🌤️ DATABASE: Using ServiceProvider pattern")
            }
            
            guard let databaseService = getWeatherDatabaseService() else {
                logQueue.async {
                    print("\n❌💾🌤️ DATABASE FAILED: Could not access WeatherDatabaseService")
                    print("❌💾🌤️ DATABASE FAILED: ServiceProvider may not be initialized")
                    print("❌💾🌤️ DATABASE FAILED: Terminating sync operation")
                }
                let error = TideSyncError.databaseError("Could not access database service")
                endSyncOperation(operationId, success: false, error: error)
                return .failure(error)
            }
            
            logQueue.async {
                print("\n✅💾🌤️ DATABASE SUCCESS: WeatherDatabaseService acquired")
                print("✅💾🌤️ DATABASE SUCCESS: Ready for local data operations")
            }
            
            // STEP 3: Get Local Favorites with heavy logging
            logQueue.async {
                print("\n📱🌤️ LOCAL DATA: Starting local favorites retrieval...")
                print("📱🌤️ LOCAL DATA: Calling getFavoriteWeatherLocationsForSync()")
                print("📱🌤️ LOCAL DATA: Timestamp = \(Date())")
            }
            
            let localStartTime = Date()
            let localFavorites = await getLocalFavorites(databaseService: databaseService, userId: session.user.id)
            let localDuration = Date().timeIntervalSince(localStartTime)
            
            logQueue.async {
                print("\n✅📱🌤️ LOCAL DATA SUCCESS: Retrieved local favorites")
                print("✅📱🌤️ LOCAL DATA: Count = \(localFavorites.count)")
                print("✅📱🌤️ LOCAL DATA: Duration = \(String(format: "%.3f", localDuration))s")
                
                if localFavorites.isEmpty {
                    print("⚠️📱🌤️ LOCAL DATA WARNING: No local favorites found")
                } else {
                    print("📱🌤️ LOCAL DATA: First 5 locations = \(localFavorites.prefix(5).map { "\($0.latitude),\($0.longitude)" })")
                }
            }
            
            // STEP 4: Get Remote Favorites with heavy logging
            logQueue.async {
                print("\n☁️🌤️ REMOTE DATA: Starting remote favorites retrieval...")
                print("☁️🌤️ REMOTE DATA: Querying user_weather_favorites table")
                print("☁️🌤️ REMOTE DATA: User ID filter = \(session.user.id)")
                print("☁️🌤️ REMOTE DATA: Using SupabaseManager.shared")
                print("☁️🌤️ REMOTE DATA: Timestamp = \(Date())")
            }
            
            let remoteStartTime = Date()
            let remoteFavorites = await getRemoteFavorites(userId: session.user.id)
            let remoteDuration = Date().timeIntervalSince(remoteStartTime)
            
            logQueue.async {
                print("\n✅☁️🌤️ REMOTE DATA SUCCESS: Retrieved remote favorites")
                print("✅☁️🌤️ REMOTE DATA: Count = \(remoteFavorites.count)")
                print("✅☁️🌤️ REMOTE DATA: Duration = \(String(format: "%.3f", remoteDuration))s")
                
                if remoteFavorites.isEmpty {
                    print("⚠️☁️🌤️ REMOTE DATA WARNING: No remote favorites found")
                } else {
                    print("☁️🌤️ REMOTE DATA: Remote locations breakdown:")
                    let favoriteRemotes = remoteFavorites.filter { $0.isFavorite }
                    let unfavoriteRemotes = remoteFavorites.filter { !$0.isFavorite }
                    print("☁️🌤️ REMOTE DATA: - Favorites (true): \(favoriteRemotes.count)")
                    print("☁️🌤️ REMOTE DATA: - Unfavorites (false): \(unfavoriteRemotes.count)")
                    
                    for (index, remote) in remoteFavorites.prefix(5).enumerated() {
                        print("☁️🌤️ REMOTE DATA: [\(index)] Location: \(remote.latitude),\(remote.longitude), Favorite: \(remote.isFavorite), Modified: \(remote.lastModified), Device: \(remote.deviceId)")
                    }
                    
                    if remoteFavorites.count > 5 {
                        print("☁️🌤️ REMOTE DATA: ... and \(remoteFavorites.count - 5) more")
                    }
                }
            }
            
            // STEP 5: ID-Based Analysis Phase with heavy logging
            logQueue.async {
                print("\n🔍🌤️ ANALYSIS: Starting ID-based sync analysis...")
                print("🔍🌤️ ANALYSIS: Local favorites count = \(localFavorites.count)")
                print("🔍🌤️ ANALYSIS: Remote records count = \(remoteFavorites.count)")
                print("🔍🌤️ ANALYSIS: Timestamp = \(Date())")
            }
            
            // Create ID sets for tracking what needs syncing
            let localRemoteIds = Set(localFavorites.compactMap { $0.remoteId }) // remoteId is String?
            let remoteIds = Set(remoteFavorites.compactMap { $0.id?.uuidString })
            
            logQueue.async {
                print("\n🔍🌤️ ID-BASED ANALYSIS:")
                print("🔍🌤️ ANALYSIS: Local remote IDs count = \(localRemoteIds.count)")
                print("🔍🌤️ ANALYSIS: Remote IDs count = \(remoteIds.count)")
                print("🔍🌤️ ANALYSIS: Local remote IDs = \(Array(localRemoteIds).prefix(5))")
                print("🔍🌤️ ANALYSIS: Remote IDs = \(Array(remoteIds).prefix(5))")
            }
            
            // Find records that need uploading (local records without remote IDs)
            let localRecordsToUpload = localFavorites.filter { local in
                return local.remoteId == nil // Upload if no remote ID
            }
            
            // Find records that need downloading (remote records not in local)
            let remoteRecordsToDownload = remoteFavorites.filter { remote in
                guard let remoteId = remote.id?.uuidString else { return false }
                return !localRemoteIds.contains(remoteId)
            }
            
            // Find records that exist in both but may need updating
            let recordsToUpdate = localFavorites.compactMap { local -> (WeatherLocationFavorite, RemoteWeatherFavorite)? in
                guard let localRemoteId = local.remoteId,
                      let remote = remoteFavorites.first(where: { $0.id?.uuidString == localRemoteId }) else {
                    return nil
                }
                
                // Check if they differ (last_modified, is_favorite, location_name)
                if local.lastModified != remote.lastModified ||
                   local.isFavorite != remote.isFavorite ||
                   local.locationName != remote.locationName {
                    return (local, remote)
                }
                return nil
            }
            
            logQueue.async {
                print("\n🔍🌤️ SYNC OPERATIONS NEEDED:")
                print("🔍🌤️ UPLOAD (new local records): \(localRecordsToUpload.count) records")
                print("🔍🌤️ DOWNLOAD (new remote records): \(remoteRecordsToDownload.count) records")
                print("🔍🌤️ UPDATE (conflicting records): \(recordsToUpdate.count) records")
            }
            
            // STEP 6: Perform Sync Operations with heavy logging
            var uploadCount = 0
            var downloadCount = 0
            var conflictCount = 0
            var errors: [TideSyncError] = []
            
            // UPLOAD PHASE
            logQueue.async {
                print("\n📤🌤️ UPLOAD PHASE: Starting upload of new local records...")
                print("📤🌤️ UPLOAD PHASE: Records to upload = \(localRecordsToUpload.count)")
                print("📤🌤️ UPLOAD PHASE: Timestamp = \(Date())")
            }
            
            let uploadStartTime = Date()
            let (uploaded, uploadErrors) = await uploadNewLocalRecords(
                localRecords: localRecordsToUpload,
                userId: session.user.id
            )
            let uploadDuration = Date().timeIntervalSince(uploadStartTime)
            
            uploadCount = uploaded
            errors.append(contentsOf: uploadErrors)
            
            logQueue.async {
                print("\n✅📤🌤️ UPLOAD PHASE COMPLETE:")
                print("✅📤🌤️ UPLOAD: Successfully uploaded = \(uploadCount)")
                print("✅📤🌤️ UPLOAD: Errors encountered = \(uploadErrors.count)")
                print("✅📤🌤️ UPLOAD: Duration = \(String(format: "%.3f", uploadDuration))s")
                if !uploadErrors.isEmpty {
                    for (index, error) in uploadErrors.enumerated() {
                        print("❌📤🌤️ UPLOAD ERROR [\(index)]: \(error.localizedDescription)")
                    }
                }
            }
            
            // DOWNLOAD PHASE
            logQueue.async {
                print("\n📥🌤️ DOWNLOAD PHASE: Starting download of new remote records...")
                print("📥🌤️ DOWNLOAD PHASE: Records to download = \(remoteRecordsToDownload.count)")
                print("📥🌤️ DOWNLOAD PHASE: Timestamp = \(Date())")
            }
            
            let downloadStartTime = Date()
            let (downloaded, downloadErrors) = await downloadNewRemoteRecords(
                remoteRecords: remoteRecordsToDownload,
                databaseService: databaseService
            )
            let downloadDuration = Date().timeIntervalSince(downloadStartTime)
            
            downloadCount = downloaded
            errors.append(contentsOf: downloadErrors)
            
            logQueue.async {
                print("\n✅📥🌤️ DOWNLOAD PHASE COMPLETE:")
                print("✅📥🌤️ DOWNLOAD: Successfully downloaded = \(downloadCount)")
                print("✅📥🌤️ DOWNLOAD: Errors encountered = \(downloadErrors.count)")
                print("✅📥🌤️ DOWNLOAD: Duration = \(String(format: "%.3f", downloadDuration))s")
                if !downloadErrors.isEmpty {
                    for (index, error) in downloadErrors.enumerated() {
                        print("❌📥🌤️ DOWNLOAD ERROR [\(index)]: \(error.localizedDescription)")
                    }
                }
            }
            
            // UPDATE PHASE
            logQueue.async {
                print("\n🔧🌤️ UPDATE PHASE: Starting record updates...")
                print("🔧🌤️ UPDATE PHASE: Records to update = \(recordsToUpdate.count)")
                print("🔧🌤️ UPDATE PHASE: Strategy = last_modified wins")
                print("🔧🌤️ UPDATE PHASE: Timestamp = \(Date())")
            }
            
            let updateStartTime = Date()
            let (updated, updateErrors) = await updateConflictingRecords(
                recordsToUpdate: recordsToUpdate,
                databaseService: databaseService
            )
            let updateDuration = Date().timeIntervalSince(updateStartTime)
            
            conflictCount = updated
            errors.append(contentsOf: updateErrors)
            
            logQueue.async {
                print("\n✅🔧🌤️ UPDATE PHASE COMPLETE:")
                print("✅🔧🌤️ UPDATE: Successfully updated = \(conflictCount)")
                print("✅🔧🌤️ UPDATE: Errors encountered = \(updateErrors.count)")
                print("✅🔧🌤️ UPDATE: Duration = \(String(format: "%.3f", updateDuration))s")
                if !updateErrors.isEmpty {
                    for (index, error) in updateErrors.enumerated() {
                        print("❌🔧🌤️ UPDATE ERROR [\(index)]: \(error.localizedDescription)")
                    }
                }
            }
            
            // Note: No longer need unfavorite sync phase since we're using ID-based tracking
            // Each record is independent and managed by its own ID
            
            // STEP 7: Create Final Result with heavy logging
            let endTime = Date()
            let stats = TideSyncStats(
                operationId: operationId,
                startTime: startTime,
                endTime: endTime,
                localFavoritesFound: localFavorites.count,
                remoteFavoritesFound: remoteFavorites.count,
                uploaded: uploadCount,
                downloaded: downloadCount,
                conflictsResolved: conflictCount,
                errors: errors.count
            )
            
            endSyncOperation(operationId, success: errors.isEmpty)
            
            logQueue.async {
                print("\n🏁🌤️ SYNC COMPLETE: ===================================================")
                print("🏁🌤️ SYNC RESULT: Operation ID = \(operationId)")
                print("🏁🌤️ SYNC RESULT: Total duration = \(String(format: "%.3f", stats.duration))s")
                print("🏁🌤️ SYNC RESULT: Total operations = \(stats.totalOperations)")
                print("🏁🌤️ SYNC RESULT: Uploaded = \(uploadCount)")
                print("🏁🌤️ SYNC RESULT: Downloaded = \(downloadCount)")
                print("🏁🌤️ SYNC RESULT: Conflicts resolved = \(conflictCount)")
                print("🏁🌤️ SYNC RESULT: Errors = \(errors.count)")
                print("🏁🌤️ SYNC RESULT: Success = \(errors.isEmpty)")
                print("🏁🌤️ SYNC RESULT: End timestamp = \(endTime)")
                print("🏁🌤️ SYNC COMPLETE: ===================================================\n")
            }
            
            if errors.isEmpty {
                return .success(stats)
            } else {
                return .partialSuccess(stats, errors)
            }
            
        } catch {
            logQueue.async {
                print("\n💥🌤️ SYNC CATASTROPHIC ERROR: ===================================")
                print("💥🌤️ UNEXPECTED ERROR: \(error)")
                print("💥🌤️ ERROR TYPE: \(type(of: error))")
                print("💥🌤️ ERROR DESCRIPTION: \(error.localizedDescription)")
                print("💥🌤️ OPERATION ID: \(operationId)")
                print("💥🌤️ TIMESTAMP: \(Date())")
                print("💥🌤️ SYNC CATASTROPHIC ERROR: ===================================\n")
            }
            
            let syncError = TideSyncError.unknownError(error.localizedDescription)
            endSyncOperation(operationId, success: false, error: syncError)
            return .failure(syncError)
        }
    }
    
    // MARK: - Private Sync Implementation Methods
    private func getLocalFavorites(databaseService: WeatherDatabaseService, userId: UUID) async -> [WeatherLocationFavorite] {
        do {
            let localWeatherFavorites = try await databaseService.getFavoriteWeatherLocationsForSync()
            return localWeatherFavorites
        } catch {
            logQueue.async {
                print("❌📱🌤️ LOCAL ERROR: Failed to get local favorites: \(error.localizedDescription)")
            }
            return []
        }
    }
    
    private func uploadNewLocalRecords(
        localRecords: [WeatherLocationFavorite],
        userId: UUID
    ) async -> (uploaded: Int, errors: [TideSyncError]) {
        
        logQueue.async {
            print("\n📤🌤️ UPLOAD IMPLEMENTATION: Starting upload of new local records...")
            print("📤🌤️ UPLOAD: Records to upload = \(localRecords.count)")
            print("📤🌤️ UPLOAD: User ID = \(userId)")
        }
        
        var uploaded = 0
        var errors: [TideSyncError] = []
        
        for (index, localRecord) in localRecords.enumerated() {
            logQueue.async {
                print("\n📤🌤️ UPLOAD RECORD [\(index + 1)/\(localRecords.count)]: Processing record")
                print("📤🌤️ UPLOAD: - Name: '\(localRecord.locationName)'")
                print("📤🌤️ UPLOAD: - Latitude: \(localRecord.latitude)")
                print("📤🌤️ UPLOAD: - Longitude: \(localRecord.longitude)")
                print("📤🌤️ UPLOAD: - Is Favorite: \(localRecord.isFavorite)")
            }
            
            do {
                let insertStartTime = Date()
                
                // Create a new record without local ID so Supabase generates new UUID
                let deviceId = localRecord.deviceId ?? UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
                let uploadRecord = RemoteWeatherFavorite(
                    userId: userId,
                    latitude: localRecord.latitude,
                    longitude: localRecord.longitude,
                    locationName: localRecord.locationName,
                    isFavorite: localRecord.isFavorite,
                    deviceId: deviceId
                )
                
                let response: PostgrestResponse<[RemoteWeatherFavorite]> = try await SupabaseManager.shared
                    .from("user_weather_favorites")
                    .insert(uploadRecord)
                    .select()
                    .execute()
                
                let insertDuration = Date().timeIntervalSince(insertStartTime)
                
                // CRITICAL: Update local record with the new remote ID
                if let newRemoteRecord = response.value.first,
                   let remoteId = newRemoteRecord.id?.uuidString,
                   let databaseService = getWeatherDatabaseService() {
                    
                    logQueue.async {
                        print("🔄📤🌤️ UPLOAD: Updating local record with remote ID \(remoteId)")
                    }
                    
                    // Update the local record with the remote ID using the local record's ID
                    let updateSuccess = await databaseService.updateLocalRecordWithRemoteId(
                        localId: localRecord.id,
                        remoteId: remoteId
                    )
                    
                    if !updateSuccess {
                        logQueue.async {
                            print("⚠️📤🌤️ UPLOAD WARNING: Failed to update local record with remote ID")
                        }
                    } else {
                        logQueue.async {
                            print("✅📤🌤️ UPLOAD: Local record updated with remote ID")
                        }
                    }
                }
                
                uploaded += 1
                
                logQueue.async {
                    print("✅📤🌤️ UPLOAD SUCCESS: Record uploaded")
                    print("✅📤🌤️ UPLOAD SUCCESS: Duration = \(String(format: "%.3f", insertDuration))s")
                    print("✅📤🌤️ UPLOAD SUCCESS: Response count = \(response.value.count)")
                    if let newRecord = response.value.first {
                        print("✅📤🌤️ UPLOAD SUCCESS: New remote ID = \(newRecord.id?.uuidString ?? "nil")")
                    }
                    print("✅📤🌤️ UPLOAD SUCCESS: Total uploaded so far = \(uploaded)")
                }
                
            } catch {
                let syncError = TideSyncError.supabaseError("Failed to upload record: \(error.localizedDescription)")
                errors.append(syncError)
                
                logQueue.async {
                    print("❌📤🌤️ UPLOAD FAILED: Record upload failed")
                    print("❌📤🌤️ UPLOAD FAILED: Error = \(error)")
                    print("❌📤🌤️ UPLOAD FAILED: Description = \(error.localizedDescription)")
                    print("❌📤🌤️ UPLOAD FAILED: Total errors so far = \(errors.count)")
                }
            }
        }
        
        logQueue.async {
            print("\n📤🌤️ UPLOAD SUMMARY:")
            print("📤🌤️ UPLOAD: Processed \(localRecords.count) records")
            print("📤🌤️ UPLOAD: Successfully uploaded = \(uploaded)")
            print("📤🌤️ UPLOAD: Failed uploads = \(errors.count)")
            if localRecords.count > 0 {
                print("📤🌤️ UPLOAD: Success rate = \(String(format: "%.1f", Double(uploaded) / Double(localRecords.count) * 100))%")
            }
        }
        
        return (uploaded, errors)
    }
    
    private func downloadNewRemoteRecords(
        remoteRecords: [RemoteWeatherFavorite],
        databaseService: WeatherDatabaseService
    ) async -> (downloaded: Int, errors: [TideSyncError]) {
        
        logQueue.async {
            print("\n📥🌤️ DOWNLOAD IMPLEMENTATION: Starting download of new remote records...")
            print("📥🌤️ DOWNLOAD: Records to download = \(remoteRecords.count)")
        }
        
        var downloaded = 0
        var errors: [TideSyncError] = []
        
        for (index, remoteRecord) in remoteRecords.enumerated() {
            logQueue.async {
                print("\n📥🌤️ DOWNLOAD RECORD [\(index + 1)/\(remoteRecords.count)]: Processing record")
                print("📥🌤️ DOWNLOAD: - Remote ID: \(remoteRecord.id?.uuidString ?? "nil")")
                print("📥🌤️ DOWNLOAD: - Location Name: \(remoteRecord.locationName)")
                print("📥🌤️ DOWNLOAD: - Latitude: \(remoteRecord.latitude)")
                print("📥🌤️ DOWNLOAD: - Longitude: \(remoteRecord.longitude)")
                print("📥🌤️ DOWNLOAD: - Is Favorite: \(remoteRecord.isFavorite)")
                print("📥🌤️ DOWNLOAD: - Last Modified: \(remoteRecord.lastModified)")
                print("📥🌤️ DOWNLOAD: - Device ID: \(remoteRecord.deviceId)")
            }
            
            let setStartTime = Date()
            let success = await databaseService.setWeatherLocationFavoriteWithSyncData(
                latitude: remoteRecord.latitude,
                longitude: remoteRecord.longitude,
                locationName: remoteRecord.locationName,
                isFavorite: remoteRecord.isFavorite,
                userId: remoteRecord.userId.uuidString,
                deviceId: remoteRecord.deviceId,
                lastModified: remoteRecord.lastModified,
                remoteId: remoteRecord.id?.uuidString // Pass the remote ID to store locally
            )
            let setDuration = Date().timeIntervalSince(setStartTime)
            
            if success {
                downloaded += 1
                logQueue.async {
                    print("✅📥🌤️ DOWNLOAD SUCCESS: Record downloaded")
                    print("✅📥🌤️ DOWNLOAD SUCCESS: Saved with remote ID tracking")
                    print("✅📥🌤️ DOWNLOAD SUCCESS: Duration = \(String(format: "%.3f", setDuration))s")
                    print("✅📥🌤️ DOWNLOAD SUCCESS: Total downloaded so far = \(downloaded)")
                }
            } else {
                let error = TideSyncError.databaseError("Failed to save remote record")
                errors.append(error)
                logQueue.async {
                    print("❌📥🌤️ DOWNLOAD FAILED: Record save failed")
                    print("❌📥🌤️ DOWNLOAD FAILED: Database operation returned false")
                    print("❌📥🌤️ DOWNLOAD FAILED: Duration = \(String(format: "%.3f", setDuration))s")
                    print("❌📥🌤️ DOWNLOAD FAILED: Total errors so far = \(errors.count)")
                }
            }
        }
        
        logQueue.async {
            print("\n📥🌤️ DOWNLOAD SUMMARY:")
            print("📥🌤️ DOWNLOAD: Processed \(remoteRecords.count) records")
            print("📥🌤️ DOWNLOAD: Successfully downloaded = \(downloaded)")
            print("📥🌤️ DOWNLOAD: Failed downloads = \(errors.count)")
            if !remoteRecords.isEmpty {
                print("📥🌤️ DOWNLOAD: Success rate = \(String(format: "%.1f", Double(downloaded) / Double(remoteRecords.count) * 100))%")
            }
        }
        
        return (downloaded, errors)
    }
    
    private func updateConflictingRecords(
        recordsToUpdate: [(WeatherLocationFavorite, RemoteWeatherFavorite)],
        databaseService: WeatherDatabaseService
    ) async -> (updated: Int, errors: [TideSyncError]) {
        
        logQueue.async {
            print("\n🔧🌤️ UPDATE IMPLEMENTATION: Starting record updates...")
            print("🔧🌤️ UPDATE: Records to update = \(recordsToUpdate.count)")
            print("🔧🌤️ UPDATE: Strategy = last_modified wins")
        }
        
        var updated = 0
        var errors: [TideSyncError] = []
        
        for (index, (localRecord, remoteRecord)) in recordsToUpdate.enumerated() {
            logQueue.async {
                print("\n🔧🌤️ UPDATE RECORD [\(index + 1)/\(recordsToUpdate.count)]: Processing record")
                print("🔧🌤️ UPDATE: - Local ID: \(localRecord.id)")
                print("🔧🌤️ UPDATE: - Local: favorite=\(localRecord.isFavorite), modified=\(localRecord.lastModified?.description ?? "nil")")
                print("🔧🌤️ UPDATE: - Remote: favorite=\(remoteRecord.isFavorite), modified=\(remoteRecord.lastModified)")
            }
            
            // Use last-write-wins to determine which version to keep
            let localLastModified = localRecord.lastModified ?? Date.distantPast
            let localWins = localLastModified > remoteRecord.lastModified
            
            logQueue.async {
                print("🔧🌤️ UPDATE: Winner = \(localWins ? "LOCAL" : "REMOTE")")
                print("🔧🌤️ UPDATE: Applying winning state...")
            }
            
            let updateStartTime = Date()
            
            if localWins {
                // Local wins - update remote record
                do {
                    logQueue.async {
                        print("🔧🌤️ UPDATE: BEFORE remote update - Local timestamp: \(localLastModified)")
                        print("🔧🌤️ UPDATE: About to set remote record to local timestamp: \(localLastModified)")
                    }
                    
                    // Create update record with local winning data
                    let updateRecord = RemoteWeatherFavorite(
                        id: remoteRecord.id,
                        userId: remoteRecord.userId,
                        latitude: localRecord.latitude,
                        longitude: localRecord.longitude,
                        locationName: localRecord.locationName,
                        isFavorite: localRecord.isFavorite,
                        lastModified: localLastModified,
                        deviceId: localRecord.deviceId ?? remoteRecord.deviceId,
                        createdAt: remoteRecord.createdAt,
                        updatedAt: Date()
                    )
                    
                    let _ = try await SupabaseManager.shared
                        .from("user_weather_favorites")
                        .update(updateRecord)
                        .eq("id", value: remoteRecord.id!.uuidString)
                        .execute()
                    
                    updated += 1
                    
                    logQueue.async {
                        print("✅🔧🌤️ UPDATE SUCCESS: Remote record updated with local data")
                        print("🔍🔧🌤️ UPDATE: Local timestamp was: \(localLastModified)")
                        print("🔍🔧🌤️ UPDATE: Remote should now have timestamp: \(localLastModified)")
                        print("⚠️🔧🌤️ UPDATE: Note - updatedAt was set to current time, not lastModified")
                    }
                } catch {
                    let syncError = TideSyncError.supabaseError("Failed to update remote record: \(error.localizedDescription)")
                    errors.append(syncError)
                    
                    logQueue.async {
                        print("❌🔧🌤️ UPDATE FAILED: Could not update remote record")
                        print("❌🔧🌤️ UPDATE FAILED: \(error.localizedDescription)")
                    }
                }
            } else {
                // Remote wins - update local record
                logQueue.async {
                    print("🔧🌤️ UPDATE: BEFORE local update - Remote timestamp: \(remoteRecord.lastModified)")
                    print("🔧🌤️ UPDATE: About to set local record to remote timestamp: \(remoteRecord.lastModified)")
                }
                
                let success = await databaseService.setWeatherLocationFavoriteWithSyncData(
                    latitude: remoteRecord.latitude,
                    longitude: remoteRecord.longitude,
                    locationName: remoteRecord.locationName,
                    isFavorite: remoteRecord.isFavorite,
                    userId: remoteRecord.userId.uuidString,
                    deviceId: remoteRecord.deviceId,
                    lastModified: remoteRecord.lastModified,
                    remoteId: remoteRecord.id?.uuidString
                )
                
                if success {
                    updated += 1
                    
                    // CRITICAL: Verify the local record timestamp after update
                    if let databaseService = getWeatherDatabaseService() {
                        do {
                            let updatedLocalRecords = try await databaseService.getFavoriteWeatherLocationsForSync()
                            if let updatedRecord = updatedLocalRecords.first(where: { $0.remoteId == remoteRecord.id?.uuidString }) {
                                logQueue.async {
                                    print("✅🔧🌤️ UPDATE SUCCESS: Local record updated with remote data")
                                    print("🔍🔧🌤️ UPDATE VERIFICATION: Remote timestamp was: \(remoteRecord.lastModified)")
                                    print("🔍🔧🌤️ UPDATE VERIFICATION: Local timestamp now is: \(updatedRecord.lastModified?.description ?? "nil")")
                                    
                                    if let localTimestamp = updatedRecord.lastModified {
                                        let timeDifference = abs(localTimestamp.timeIntervalSince(remoteRecord.lastModified))
                                        if timeDifference < 1.0 {
                                            print("✅🔧🌤️ UPDATE VERIFICATION: Timestamps match (diff: \(timeDifference)s) - NO LOOP")
                                        } else {
                                            print("⚠️🔧🌤️ UPDATE VERIFICATION: Timestamps differ by \(timeDifference)s - POTENTIAL LOOP!")
                                            print("⚠️🔧🌤️ UPDATE VERIFICATION: This could cause infinite update cycles!")
                                        }
                                    }
                                }
                            } else {
                                logQueue.async {
                                    print("⚠️🔧🌤️ UPDATE VERIFICATION: Could not find updated local record for verification")
                                }
                            }
                        } catch {
                            logQueue.async {
                                print("❌🔧🌤️ UPDATE VERIFICATION: Failed to fetch updated record: \(error)")
                            }
                        }
                    }
                } else {
                    let error = TideSyncError.databaseError("Could not update local record")
                    errors.append(error)
                    
                    logQueue.async {
                        print("❌🔧🌤️ UPDATE FAILED: Could not update local record")
                    }
                }
            }
            
            let updateDuration = Date().timeIntervalSince(updateStartTime)
            
            logQueue.async {
                print("🔧🌤️ UPDATE: Duration = \(String(format: "%.3f", updateDuration))s")
                print("🔧🌤️ UPDATE: Total updated so far = \(updated)")
            }
        }
        
        logQueue.async {
            print("\n🔧🌤️ UPDATE SUMMARY:")
            print("🔧🌤️ UPDATE: Processed \(recordsToUpdate.count) records")
            print("🔧🌤️ UPDATE: Successfully updated = \(updated)")
            print("🔧🌤️ UPDATE: Failed updates = \(errors.count)")
            if !recordsToUpdate.isEmpty {
                print("🔧🌤️ UPDATE: Success rate = \(String(format: "%.1f", Double(updated) / Double(recordsToUpdate.count) * 100))%")
            }
        }
        
        return (updated, errors)
    }
    
    
    // MARK: - Helper Methods
    
    private func getRemoteFavorites(userId: UUID) async -> [RemoteWeatherFavorite] {
        logQueue.async {
            print("\n☁️🌤️ REMOTE FETCH: Starting Supabase query...")
            print("☁️🌤️ REMOTE FETCH: Table = user_weather_favorites")
            print("☁️🌤️ REMOTE FETCH: Filter = user_id eq \(userId)")
        }
        
        do {
            let queryStartTime = Date()
            let response: PostgrestResponse<[RemoteWeatherFavorite]> = try await SupabaseManager.shared
                .from("user_weather_favorites")
                .select("*")
                .eq("user_id", value: userId.uuidString)
                .execute()
            let queryDuration = Date().timeIntervalSince(queryStartTime)
            
            logQueue.async {
                print("\n✅☁️🌤️ REMOTE FETCH SUCCESS: Query completed")
                print("✅☁️🌤️ REMOTE FETCH: Retrieved \(response.value.count) records")
                print("✅☁️🌤️ REMOTE FETCH: Duration = \(String(format: "%.3f", queryDuration))s")
                print("✅☁️🌤️ REMOTE FETCH: Response status = success")
                
                if response.value.isEmpty {
                    print("⚠️☁️🌤️ REMOTE FETCH: No remote favorites found for user")
                } else {
                    print("☁️🌤️ REMOTE FETCH: Sample records:")
                    for (index, favorite) in response.value.prefix(3).enumerated() {
                        print("☁️🌤️ REMOTE FETCH: [\(index)] ID: \(favorite.id?.uuidString ?? "nil"), Location: \(favorite.latitude),\(favorite.longitude), Favorite: \(favorite.isFavorite)")
                    }
                }
            }
            
            return response.value
        } catch {
            logQueue.async {
                print("\n❌☁️🌤️ REMOTE FETCH ERROR: Query failed")
                print("❌☁️🌤️ REMOTE FETCH ERROR: \(error)")
                print("❌☁️🌤️ REMOTE FETCH ERROR: Type = \(type(of: error))")
                print("❌☁️🌤️ REMOTE FETCH ERROR: Description = \(error.localizedDescription)")
                print("❌☁️🌤️ REMOTE FETCH ERROR: Returning empty array")
            }
            return []
        }
    }
    
    private func getWeatherDatabaseService() -> WeatherDatabaseService? {
        logQueue.async {
            print("\n💾🌤️ SERVICE PROVIDER: Attempting to get WeatherDatabaseService...")
            print("💾🌤️ SERVICE PROVIDER: Creating ServiceProvider instance")
        }
        
        let serviceProvider = ServiceProvider()
        let service = serviceProvider.weatherService
        
        logQueue.async {
            if service != nil {
                print("✅💾🌤️ SERVICE PROVIDER: Successfully obtained WeatherDatabaseService")
            } else {
                print("❌💾🌤️ SERVICE PROVIDER: Failed to obtain WeatherDatabaseService")
                print("❌💾🌤️ SERVICE PROVIDER: ServiceProvider may not be properly initialized")
            }
        }
        
        return service
    }
    
    /// Check if user is authenticated for sync operations
    func canSync() async -> Bool {
        let operationId = startSyncOperation("authCheck")
        
        logQueue.async {
            print("\n🔐🌤️ AUTH CHECK: Starting authentication verification...")
            print("🔐🌤️ AUTH CHECK: Operation ID = \(operationId)")
        }
        
        do {
            let session = try await SupabaseManager.shared.getSession()
            endSyncOperation(operationId, success: true)
            
            logQueue.async {
                print("✅🔐🌤️ AUTH CHECK SUCCESS: User is authenticated")
                print("✅🔐🌤️ AUTH CHECK: User ID = \(session.user.id)")
                print("✅🔐🌤️ AUTH CHECK: User email = \(session.user.email ?? "NO EMAIL")")
            }
            
            return true
        } catch {
            endSyncOperation(operationId, success: false, error: TideSyncError.authenticationRequired)
            
            logQueue.async {
                print("❌🔐🌤️ AUTH CHECK FAILED: User not authenticated")
                print("❌🔐🌤️ AUTH CHECK FAILED: Error = \(error)")
                print("❌🔐🌤️ AUTH CHECK FAILED: Description = \(error.localizedDescription)")
            }
            
            return false
        }
    }
    
    // MARK: - Operation Tracking (Matches TideStationSyncService Pattern)
    
    private func startSyncOperation(_ operation: String, details: String = "") -> String {
        operationsLock.lock()
        defer { operationsLock.unlock() }
        
        syncCounter += 1
        let operationId = "\(operation)_\(syncCounter)"
        let startTime = Date()
        activeSyncOperations[operationId] = startTime
        
        logQueue.async {
            print("\n🟢🌤️ OPERATION START: ============================================")
            print("🟢🌤️ OPERATION: \(operation)")
            print("🟢🌤️ OPERATION ID: \(operationId)")
            if !details.isEmpty {
                print("🟢🌤️ OPERATION DETAILS: \(details)")
            }
            print("🟢🌤️ START TIME: \(startTime)")
            print("🟢🌤️ THREAD: \(Thread.current)")
            print("🟢🌤️ PROCESS ID: \(ProcessInfo.processInfo.processIdentifier)")
            print("🟢🌤️ ACTIVE SYNC OPS: \(self.activeSyncOperations.count)")
            print("🟢🌤️ CONCURRENT SYNC OPS: \(Array(self.activeSyncOperations.keys))")
            
            if self.activeSyncOperations.count > 1 {
                print("⚠️🌤️ RACE CONDITION WARNING: Multiple sync operations active!")
                for (opId, opStartTime) in self.activeSyncOperations {
                    let opDuration = Date().timeIntervalSince(opStartTime)
                    print("⚠️🌤️ ACTIVE OP: \(opId) running for \(String(format: "%.3f", opDuration))s")
                }
            }
            
            print("🟢🌤️ OPERATION START: ============================================")
        }
        
        return operationId
    }
    
    private func endSyncOperation(_ operationId: String, success: Bool, error: TideSyncError? = nil) {
        operationsLock.lock()
        let startTime = activeSyncOperations.removeValue(forKey: operationId)
        operationsLock.unlock()
        
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        // Update operation statistics
        updateOperationStats(operationId: operationId, success: success, duration: duration)
        
        logQueue.async {
            print("\n🔚🌤️ OPERATION END: ============================================")
            print("🔚🌤️ OPERATION ID: \(operationId)")
            print("🔚🌤️ DURATION: \(String(format: "%.3f", duration))s")
            print("🔚🌤️ END TIME: \(Date())")
            
            if success {
                print("✅🔚🌤️ RESULT: SUCCESS")
            } else {
                print("❌🔚🌤️ RESULT: FAILURE")
                if let error = error {
                    print("❌🔚🌤️ ERROR: \(error.localizedDescription)")
                    print("❌🔚🌤️ ERROR TYPE: \(type(of: error))")
                }
            }
            
            print("🔚🌤️ REMAINING SYNC OPS: \(self.activeSyncOperations.count)")
            if !self.activeSyncOperations.isEmpty {
                print("🔚🌤️ STILL ACTIVE: \(Array(self.activeSyncOperations.keys))")
            }
            print("🔚🌤️ OPERATION END: ============================================\n")
        }
    }
    
    private func updateOperationStats(operationId: String, success: Bool, duration: TimeInterval) {
        statsLock.lock()
        defer { statsLock.unlock() }
        
        let operationType = String(operationId.split(separator: "_").first ?? "unknown")
        
        logQueue.async {
            print("📊🌤️ STATS UPDATE: Updating statistics for \(operationType)")
            print("📊🌤️ STATS UPDATE: Success = \(success), Duration = \(String(format: "%.3f", duration))s")
        }
        
        if var stats = operationStats[operationType] {
            stats.totalCalls += 1
            stats.totalDuration += duration
            stats.minDuration = min(stats.minDuration, duration)
            stats.maxDuration = max(stats.maxDuration, duration)
            
            if success {
                stats.successCount += 1
            } else {
                stats.failureCount += 1
            }
            
            operationStats[operationType] = stats
        } else {
            operationStats[operationType] = TideSyncOperationStats(
                totalCalls: 1,
                successCount: success ? 1 : 0,
                failureCount: success ? 0 : 1,
                totalDuration: duration,
                minDuration: duration,
                maxDuration: duration
            )
        }
        
        logQueue.async {
            if let stats = self.operationStats[operationType] {
                let avgDuration = stats.totalDuration / Double(stats.totalCalls)
                let successRate = Double(stats.successCount) / Double(stats.totalCalls) * 100
                print("📊🌤️ STATS UPDATE: \(operationType) now has \(stats.totalCalls) calls, \(String(format: "%.1f", successRate))% success, \(String(format: "%.3f", avgDuration))s avg")
            }
        }
    }
    
    // MARK: - Public Monitoring (Matches TideStationSyncService Pattern)
    
    func getCurrentSyncOperations() -> [String] {
        operationsLock.lock()
        defer { operationsLock.unlock() }
        return Array(activeSyncOperations.keys)
    }
    
    func printSyncStats() {
        statsLock.lock()
        let stats = operationStats
        statsLock.unlock()
        
        logQueue.async {
            print("\n📊🌤️ WEATHER SYNC SERVICE STATISTICS: ========================================")
            print("📊🌤️ STATISTICS TIMESTAMP: \(Date())")
            
            if stats.isEmpty {
                print("📊🌤️ No sync operations performed yet")
            } else {
                for (operation, stat) in stats.sorted(by: { $0.key < $1.key }) {
                    let avgDuration = stat.totalDuration / Double(stat.totalCalls)
                    let successRate = Double(stat.successCount) / Double(stat.totalCalls) * 100
                    
                    print("📊🌤️ \(operation.uppercased()):")
                    print("   Total calls: \(stat.totalCalls)")
                    print("   Success rate: \(String(format: "%.1f", successRate))%")
                    print("   Success count: \(stat.successCount)")
                    print("   Failure count: \(stat.failureCount)")
                    print("   Avg duration: \(String(format: "%.3f", avgDuration))s")
                    print("   Min duration: \(String(format: "%.3f", stat.minDuration))s")
                    print("   Max duration: \(String(format: "%.3f", stat.maxDuration))s")
                    print("   Total duration: \(String(format: "%.3f", stat.totalDuration))s")
                    print("")
                }
            }
            
            print("📊🌤️ Current active operations: \(self.activeSyncOperations.count)")
            if !self.activeSyncOperations.isEmpty {
                for (opId, startTime) in self.activeSyncOperations {
                    let duration = Date().timeIntervalSince(startTime)
                    print("   \(opId): running for \(String(format: "%.1f", duration))s")
                }
            }
            print("📊🌤️ STATISTICS END: ========================================\n")
        }
    }
    
    func enableVerboseLogging() {
        logQueue.async {
            print("🔍🌤️ WEATHER SYNC SERVICE: Verbose logging ENABLED")
            print("🔍🌤️ Note: This service already has comprehensive logging by default")
        }
    }
    
    func logCurrentState() {
        let operations = getCurrentSyncOperations()
        
        logQueue.async {
            print("\n🔍🌤️ WEATHER SYNC SERVICE STATE: =====================================")
            print("🔍🌤️ STATE TIMESTAMP: \(Date())")
            print("🔍🌤️ Active sync operations: \(operations.count)")
            print("🔍🌤️ Operations: \(operations)")
            print("🔍🌤️ Thread: \(Thread.current)")
            print("🔍🌤️ Process ID: \(ProcessInfo.processInfo.processIdentifier)")
            print("🔍🌤️ Memory usage: \(ProcessInfo.processInfo.physicalMemory / 1024 / 1024) MB")
            
            // Print operation details
            if !operations.isEmpty {
                for opId in operations {
                    if let startTime = self.activeSyncOperations[opId] {
                        let duration = Date().timeIntervalSince(startTime)
                        print("🔍🌤️ - \(opId): running for \(String(format: "%.3f", duration))s")
                    }
                }
            }
            
            print("🔍🌤️ STATE END: =====================================\n")
        }
    }
}