
import Foundation
import Supabase

/// Singleton service for syncing tide station favorites between local SQLite and Supabase
final class TideStationSyncService {
    
    // MARK: - Shared Instance
    static let shared = TideStationSyncService()
    
    // MARK: - Private Properties
    private let syncQueue = DispatchQueue(label: "tideSync.operations", qos: .utility)
    private let logQueue = DispatchQueue(label: "tideSync.logging", qos: .background)
    private var activeSyncOperations: [String: Date] = [:]
    private let operationsLock = NSLock()
    private var syncCounter: Int = 0
    
    // MARK: - Performance Tracking
    private var operationStats: [String: TideSyncOperationStats] = [:]
    private let statsLock = NSLock()
    
    // MARK: - Initialization
    private init() {
        logQueue.async {
            print("\n🌊 TIDE SYNC SERVICE: Initializing comprehensive sync system")
            print("🌊 TIDE SYNC SERVICE: Thread = \(Thread.current)")
            print("🌊 TIDE SYNC SERVICE: Timestamp = \(Date())")
            print("🌊 TIDE SYNC SERVICE: Ready for sync operations\n")
        }
    }
    
    // MARK: - Public Sync Methods
    
    /// Main bidirectional sync method with HEAVY LOGGING
    func syncTideStationFavorites() async -> TideSyncResult {
        let operationId = startSyncOperation("fullSync")
        let startTime = Date()
        
        logQueue.async {
            print("\n🟢🌊 FULL SYNC START: ===================================================")
            print("🟢🌊 FULL SYNC: Operation ID = \(operationId)")
            print("🟢🌊 FULL SYNC: Start timestamp = \(startTime)")
            print("🟢🌊 FULL SYNC: Thread = \(Thread.current)")
            print("🟢🌊 FULL SYNC: Process ID = \(ProcessInfo.processInfo.processIdentifier)")
        }
        
        do {
            // STEP 1: Authentication Check with heavy logging
            logQueue.async {
                print("\n🔐🌊 AUTH CHECK: Starting authentication verification...")
                print("🔐🌊 AUTH CHECK: Using SupabaseManager.shared for session retrieval")
            }
            
            guard let session = try? await SupabaseManager.shared.getSession() else {
                logQueue.async {
                    print("\n❌🔐🌊 AUTH FAILED: No valid session found")
                    print("❌🔐🌊 AUTH FAILED: User must be authenticated to sync")
                    print("❌🔐🌊 AUTH FAILED: Terminating sync operation")
                }
                endSyncOperation(operationId, success: false, error: TideSyncError.authenticationRequired)
                return .failure(.authenticationRequired)
            }
            
            logQueue.async {
                print("\n✅🔐🌊 AUTH SUCCESS: Session retrieved successfully")
                print("✅🔐🌊 AUTH SUCCESS: User ID = \(session.user.id)")
                print("✅🔐🌊 AUTH SUCCESS: User email = \(session.user.email ?? "NO EMAIL")")
                print("✅🔐🌊 AUTH SUCCESS: Session expires at = \(Date(timeIntervalSince1970: TimeInterval(session.expiresAt)))")
            }
            
            // STEP 2: Database Service Access with heavy logging
            logQueue.async {
                print("\n💾🌊 DATABASE: Attempting to get database service...")
                print("💾🌊 DATABASE: Using ServiceProvider pattern")
            }
            
            guard let databaseService = getTideStationDatabaseService() else {
                logQueue.async {
                    print("\n❌💾🌊 DATABASE FAILED: Could not access TideStationDatabaseService")
                    print("❌💾🌊 DATABASE FAILED: ServiceProvider may not be initialized")
                    print("❌💾🌊 DATABASE FAILED: Terminating sync operation")
                }
                let error = TideSyncError.databaseError("Could not access database service")
                endSyncOperation(operationId, success: false, error: error)
                return .failure(error)
            }
            
            logQueue.async {
                print("\n✅💾🌊 DATABASE SUCCESS: TideStationDatabaseService acquired")
                print("✅💾🌊 DATABASE SUCCESS: Ready for local data operations")
            }
            
            // STEP 3: Get Local Favorites with heavy logging
            logQueue.async {
                print("\n📱🌊 LOCAL DATA: Starting local favorites retrieval...")
                print("📱🌊 LOCAL DATA: Calling getAllFavoriteStationIds()")
                print("📱🌊 LOCAL DATA: Timestamp = \(Date())")
            }
            
            let localStartTime = Date()
            let localFavorites = await databaseService.getAllFavoriteStationIds()
            let localDuration = Date().timeIntervalSince(localStartTime)
            
            logQueue.async {
                print("\n✅📱🌊 LOCAL DATA SUCCESS: Retrieved local favorites")
                print("✅📱🌊 LOCAL DATA: Count = \(localFavorites.count)")
                print("✅📱🌊 LOCAL DATA: Duration = \(String(format: "%.3f", localDuration))s")
                print("✅📱🌊 LOCAL DATA: Station IDs = \(Array(localFavorites).sorted())")
                
                if localFavorites.isEmpty {
                    print("⚠️📱🌊 LOCAL DATA WARNING: No local favorites found")
                } else {
                    print("📱🌊 LOCAL DATA: First 5 stations = \(Array(localFavorites.prefix(5)))")
                }
            }
            
            // STEP 4: Get Remote Favorites with heavy logging
            logQueue.async {
                print("\n☁️🌊 REMOTE DATA: Starting remote favorites retrieval...")
                print("☁️🌊 REMOTE DATA: Querying user_tide_favorites table")
                print("☁️🌊 REMOTE DATA: User ID filter = \(session.user.id)")
                print("☁️🌊 REMOTE DATA: Using SupabaseManager.shared")
                print("☁️🌊 REMOTE DATA: Timestamp = \(Date())")
            }
            
            let remoteStartTime = Date()
            let remoteFavorites = await getRemoteFavorites(userId: session.user.id)
            let remoteDuration = Date().timeIntervalSince(remoteStartTime)
            
            logQueue.async {
                print("\n✅☁️🌊 REMOTE DATA SUCCESS: Retrieved remote favorites")
                print("✅☁️🌊 REMOTE DATA: Count = \(remoteFavorites.count)")
                print("✅☁️🌊 REMOTE DATA: Duration = \(String(format: "%.3f", remoteDuration))s")
                
                if remoteFavorites.isEmpty {
                    print("⚠️☁️🌊 REMOTE DATA WARNING: No remote favorites found")
                } else {
                    print("☁️🌊 REMOTE DATA: Remote stations breakdown:")
                    let favoriteRemotes = remoteFavorites.filter { $0.isFavorite }
                    let unfavoriteRemotes = remoteFavorites.filter { !$0.isFavorite }
                    print("☁️🌊 REMOTE DATA: - Favorites (true): \(favoriteRemotes.count)")
                    print("☁️🌊 REMOTE DATA: - Unfavorites (false): \(unfavoriteRemotes.count)")
                    
                    for (index, remote) in remoteFavorites.prefix(5).enumerated() {
                        print("☁️🌊 REMOTE DATA: [\(index)] Station: \(remote.stationId), Favorite: \(remote.isFavorite), Modified: \(remote.lastModified), Device: \(remote.deviceId)")
                    }
                    
                    if remoteFavorites.count > 5 {
                        print("☁️🌊 REMOTE DATA: ... and \(remoteFavorites.count - 5) more")
                    }
                }
            }
            
            // STEP 5: Data Analysis Phase with heavy logging
            logQueue.async {
                print("\n🔍🌊 ANALYSIS: Starting data comparison analysis...")
                print("🔍🌊 ANALYSIS: Local favorites count = \(localFavorites.count)")
                print("🔍🌊 ANALYSIS: Remote records count = \(remoteFavorites.count)")
                print("🔍🌊 ANALYSIS: Timestamp = \(Date())")
            }
            
            let remoteStationIds = Set(remoteFavorites.map { $0.stationId })
            let remoteFavoriteIds = Set(remoteFavorites.filter { $0.isFavorite }.map { $0.stationId })
            let remoteUnfavoriteIds = Set(remoteFavorites.filter { !$0.isFavorite }.map { $0.stationId })
            
            logQueue.async {
                print("\n🔍🌊 ANALYSIS BREAKDOWN:")
                print("🔍🌊 ANALYSIS: Remote station IDs (all) = \(remoteStationIds.count)")
                print("🔍🌊 ANALYSIS: Remote favorite IDs (true) = \(remoteFavoriteIds.count)")
                print("🔍🌊 ANALYSIS: Remote unfavorite IDs (false) = \(remoteUnfavoriteIds.count)")
                print("🔍🌊 ANALYSIS: Local favorites = \(localFavorites)")
                print("🔍🌊 ANALYSIS: Remote favorites = \(remoteFavoriteIds)")
                print("🔍🌊 ANALYSIS: Remote unfavorites = \(remoteUnfavoriteIds)")
            }
            
            let localOnlyFavorites = localFavorites.subtracting(remoteStationIds)
            let remoteOnlyFavorites = remoteFavoriteIds.subtracting(localFavorites)
            let conflictingStations = localFavorites.intersection(remoteStationIds)
            
            logQueue.async {
                print("\n🔍🌊 SYNC OPERATIONS NEEDED:")
                print("🔍🌊 UPLOAD (local only): \(localOnlyFavorites.count) stations")
                print("🔍🌊 UPLOAD: \(localOnlyFavorites)")
                print("🔍🌊 DOWNLOAD (remote only): \(remoteOnlyFavorites.count) stations")
                print("🔍🌊 DOWNLOAD: \(remoteOnlyFavorites)")
                print("🔍🌊 CONFLICTS (both exist): \(conflictingStations.count) stations")
                print("🔍🌊 CONFLICTS: \(conflictingStations)")
            }
            
            // STEP 6: Perform Sync Operations with heavy logging
            var uploadCount = 0
            var downloadCount = 0
            var conflictCount = 0
            var errors: [TideSyncError] = []
            
            // UPLOAD PHASE
            logQueue.async {
                print("\n📤🌊 UPLOAD PHASE: Starting upload of local-only favorites...")
                print("📤🌊 UPLOAD PHASE: Stations to upload = \(localOnlyFavorites.count)")
                print("📤🌊 UPLOAD PHASE: Timestamp = \(Date())")
            }
            
            let uploadStartTime = Date()
            let (uploaded, uploadErrors) = await uploadLocalChanges(
                localOnlyFavorites: localOnlyFavorites,
                userId: session.user.id,
                databaseService: databaseService
            )
            let uploadDuration = Date().timeIntervalSince(uploadStartTime)
            
            uploadCount = uploaded
            errors.append(contentsOf: uploadErrors)
            
            logQueue.async {
                print("\n✅📤🌊 UPLOAD PHASE COMPLETE:")
                print("✅📤🌊 UPLOAD: Successfully uploaded = \(uploadCount)")
                print("✅📤🌊 UPLOAD: Errors encountered = \(uploadErrors.count)")
                print("✅📤🌊 UPLOAD: Duration = \(String(format: "%.3f", uploadDuration))s")
                if !uploadErrors.isEmpty {
                    for (index, error) in uploadErrors.enumerated() {
                        print("❌📤🌊 UPLOAD ERROR [\(index)]: \(error.localizedDescription)")
                    }
                }
            }
            
            // DOWNLOAD PHASE
            logQueue.async {
                print("\n📥🌊 DOWNLOAD PHASE: Starting download of remote-only favorites...")
                print("📥🌊 DOWNLOAD PHASE: Stations to download = \(remoteOnlyFavorites.count)")
                print("📥🌊 DOWNLOAD PHASE: Timestamp = \(Date())")
            }
            
            let downloadStartTime = Date()
            let (downloaded, downloadErrors) = await downloadRemoteChanges(
                remoteOnlyFavorites: remoteOnlyFavorites,
                remoteFavorites: remoteFavorites,
                databaseService: databaseService
            )
            let downloadDuration = Date().timeIntervalSince(downloadStartTime)
            
            downloadCount = downloaded
            errors.append(contentsOf: downloadErrors)
            
            logQueue.async {
                print("\n✅📥🌊 DOWNLOAD PHASE COMPLETE:")
                print("✅📥🌊 DOWNLOAD: Successfully downloaded = \(downloadCount)")
                print("✅📥🌊 DOWNLOAD: Errors encountered = \(downloadErrors.count)")
                print("✅📥🌊 DOWNLOAD: Duration = \(String(format: "%.3f", downloadDuration))s")
                if !downloadErrors.isEmpty {
                    for (index, error) in downloadErrors.enumerated() {
                        print("❌📥🌊 DOWNLOAD ERROR [\(index)]: \(error.localizedDescription)")
                    }
                }
            }
            
            // CONFLICT RESOLUTION PHASE
            logQueue.async {
                print("\n🔧🌊 CONFLICT PHASE: Starting conflict resolution...")
                print("🔧🌊 CONFLICT PHASE: Conflicts to resolve = \(conflictingStations.count)")
                print("🔧🌊 CONFLICT PHASE: Strategy = last_modified wins")
                print("🔧🌊 CONFLICT PHASE: Timestamp = \(Date())")
            }
            
            let conflictStartTime = Date()
            let (resolved, conflictErrors) = await resolveConflicts(
                conflictingStations: conflictingStations,
                remoteFavorites: remoteFavorites,
                databaseService: databaseService
            )
            let conflictDuration = Date().timeIntervalSince(conflictStartTime)
            
            conflictCount = resolved
            errors.append(contentsOf: conflictErrors)
            
            logQueue.async {
                print("\n✅🔧🌊 CONFLICT PHASE COMPLETE:")
                print("✅🔧🌊 CONFLICT: Successfully resolved = \(conflictCount)")
                print("✅🔧🌊 CONFLICT: Errors encountered = \(conflictErrors.count)")
                print("✅🔧🌊 CONFLICT: Duration = \(String(format: "%.3f", conflictDuration))s")
                if !conflictErrors.isEmpty {
                    for (index, error) in conflictErrors.enumerated() {
                        print("❌🔧🌊 CONFLICT ERROR [\(index)]: \(error.localizedDescription)")
                    }
                }
            }
            
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
                print("\n🏁🌊 SYNC COMPLETE: ===================================================")
                print("🏁🌊 SYNC RESULT: Operation ID = \(operationId)")
                print("🏁🌊 SYNC RESULT: Total duration = \(String(format: "%.3f", stats.duration))s")
                print("🏁🌊 SYNC RESULT: Total operations = \(stats.totalOperations)")
                print("🏁🌊 SYNC RESULT: Uploaded = \(uploadCount)")
                print("🏁🌊 SYNC RESULT: Downloaded = \(downloadCount)")
                print("🏁🌊 SYNC RESULT: Conflicts resolved = \(conflictCount)")
                print("🏁🌊 SYNC RESULT: Errors = \(errors.count)")
                print("🏁🌊 SYNC RESULT: Success = \(errors.isEmpty)")
                print("🏁🌊 SYNC RESULT: End timestamp = \(endTime)")
                print("🏁🌊 SYNC COMPLETE: ===================================================\n")
            }
            
            if errors.isEmpty {
                return .success(stats)
            } else {
                return .partialSuccess(stats, errors)
            }
            
        } catch {
            logQueue.async {
                print("\n💥🌊 SYNC CATASTROPHIC ERROR: ===================================")
                print("💥🌊 UNEXPECTED ERROR: \(error)")
                print("💥🌊 ERROR TYPE: \(type(of: error))")
                print("💥🌊 ERROR DESCRIPTION: \(error.localizedDescription)")
                print("💥🌊 OPERATION ID: \(operationId)")
                print("💥🌊 TIMESTAMP: \(Date())")
                print("💥🌊 SYNC CATASTROPHIC ERROR: ===================================\n")
            }
            
            let syncError = TideSyncError.unknownError(error.localizedDescription)
            endSyncOperation(operationId, success: false, error: syncError)
            return .failure(syncError)
        }
    }
    
    // MARK: - Private Sync Implementation Methods
    private func uploadLocalChanges(
        localOnlyFavorites: Set<String>,
        userId: UUID,
        databaseService: TideStationDatabaseService
    ) async -> (uploaded: Int, errors: [TideSyncError]) {
        
        logQueue.async {
            print("\n📤🌊 UPLOAD IMPLEMENTATION: Starting detailed upload process...")
            print("📤🌊 UPLOAD: Local-only favorites = \(localOnlyFavorites)")
            print("📤🌊 UPLOAD: User ID = \(userId)")
            print("📤🌊 UPLOAD: Count to process = \(localOnlyFavorites.count)")
        }
        
        var uploaded = 0
        var errors: [TideSyncError] = []
        
        // STEP 1: Get all favorite stations with details from local database
        let allLocalFavoritesWithDetails = await databaseService.getAllFavoriteStationsWithDetails()
        let localStationsMap = Dictionary(uniqueKeysWithValues: allLocalFavoritesWithDetails.map { ($0.id, $0) })
        
        for (index, stationId) in localOnlyFavorites.enumerated() {
            logQueue.async {
                print("\n📤🌊 UPLOAD ITEM [\(index + 1)/\(localOnlyFavorites.count)]: Processing station \(stationId)")
                print("📤🌊 UPLOAD ITEM: Getting station details from local database...")
            }
            
            // STEP 2: Get station details from local database
            let stationDetails = localStationsMap[stationId]
            let stationName = stationDetails?.name ?? "Station \(stationId)"
            let latitude = stationDetails?.latitude
            let longitude = stationDetails?.longitude
            
            logQueue.async {
                print("📤🌊 UPLOAD ITEM: Station details retrieved:")
                print("📤🌊 UPLOAD ITEM: - Name: '\(stationName)'")
                print("📤🌊 UPLOAD ITEM: - Latitude: \(latitude?.description ?? "nil")")
                print("📤🌊 UPLOAD ITEM: - Longitude: \(longitude?.description ?? "nil")")
                print("📤🌊 UPLOAD ITEM: Creating RemoteTideFavorite record with full details...")
            }
            
            // STEP 3: Create RemoteTideFavorite with complete station data
            let remoteFavorite = RemoteTideFavorite.fromLocal(
                userId: userId,
                stationId: stationId,
                isFavorite: true,
                stationName: stationName,
                latitude: latitude,
                longitude: longitude
            )
            
            logQueue.async {
                print("📤🌊 UPLOAD ITEM: Created record with complete data:")
                print("📤🌊 UPLOAD ITEM: - Station: \(remoteFavorite.stationId)")
                print("📤🌊 UPLOAD ITEM: - Name: '\(remoteFavorite.stationName ?? "nil")'")
                print("📤🌊 UPLOAD ITEM: - Coordinates: (\(remoteFavorite.latitude?.description ?? "nil"), \(remoteFavorite.longitude?.description ?? "nil"))")
                print("📤🌊 UPLOAD ITEM: - User ID: \(remoteFavorite.userId)")
                print("📤🌊 UPLOAD ITEM: - Is Favorite: \(remoteFavorite.isFavorite)")
                print("📤🌊 UPLOAD ITEM: - Device ID: \(remoteFavorite.deviceId)")
                print("📤🌊 UPLOAD ITEM: - Last Modified: \(remoteFavorite.lastModified)")
                print("📤🌊 UPLOAD ITEM: Sending to Supabase...")
            }
            
            do {
                let insertStartTime = Date()
                
                let response: PostgrestResponse<[RemoteTideFavorite]> = try await SupabaseManager.shared
                    .from("user_tide_favorites")
                    .insert(remoteFavorite)
                    .select()
                    .execute()
                
                
                let insertDuration = Date().timeIntervalSince(insertStartTime)
                
                uploaded += 1
                
                logQueue.async {
                    print("✅📤🌊 UPLOAD SUCCESS: Station \(stationId)")
                    print("✅📤🌊 UPLOAD SUCCESS: Uploaded with complete station data")
                    print("✅📤🌊 UPLOAD SUCCESS: Duration = \(String(format: "%.3f", insertDuration))s")
                    print("✅📤🌊 UPLOAD SUCCESS: Response count = \(response.value.count)")
                    print("✅📤🌊 UPLOAD SUCCESS: Total uploaded so far = \(uploaded)")
                }
                
            } catch {
                let syncError = TideSyncError.supabaseError("Failed to upload \(stationId): \(error.localizedDescription)")
                errors.append(syncError)
                
                logQueue.async {
                    print("❌📤🌊 UPLOAD FAILED: Station \(stationId)")
                    print("❌📤🌊 UPLOAD FAILED: Error = \(error)")
                    print("❌📤🌊 UPLOAD FAILED: Error type = \(type(of: error))")
                    print("❌📤🌊 UPLOAD FAILED: Description = \(error.localizedDescription)")
                    print("❌📤🌊 UPLOAD FAILED: Total errors so far = \(errors.count)")
                }
            }
        }
        
        logQueue.async {
            print("\n📤🌊 UPLOAD SUMMARY:")
            print("📤🌊 UPLOAD: Processed \(localOnlyFavorites.count) stations")
            print("📤🌊 UPLOAD: Successfully uploaded = \(uploaded)")
            print("📤🌊 UPLOAD: Failed uploads = \(errors.count)")
            if localOnlyFavorites.count > 0 {
                print("📤🌊 UPLOAD: Success rate = \(String(format: "%.1f", Double(uploaded) / Double(localOnlyFavorites.count) * 100))%")
            }
            print("📤🌊 UPLOAD: All stations uploaded with complete details (name, lat, lon)")
        }
        
        return (uploaded, errors)
    }
    
    private func downloadRemoteChanges(
        remoteOnlyFavorites: Set<String>,
        remoteFavorites: [RemoteTideFavorite],
        databaseService: TideStationDatabaseService
    ) async -> (downloaded: Int, errors: [TideSyncError]) {
        
        logQueue.async {
            print("\n📥🌊 DOWNLOAD IMPLEMENTATION: Starting detailed download process...")
            print("📥🌊 DOWNLOAD: Remote-only favorites = \(remoteOnlyFavorites)")
            print("📥🌊 DOWNLOAD: Count to process = \(remoteOnlyFavorites.count)")
        }
        
        let remoteFavoritesDict = Dictionary(uniqueKeysWithValues: remoteFavorites.map { ($0.stationId, $0) })
        
        logQueue.async {
            print("📥🌊 DOWNLOAD: Created lookup dictionary with \(remoteFavoritesDict.count) remote favorites")
            print("📥🌊 DOWNLOAD: Available remote station IDs = \(Array(remoteFavoritesDict.keys).sorted())")
        }
        
        var downloaded = 0
        var errors: [TideSyncError] = []
        
        for (index, stationId) in remoteOnlyFavorites.enumerated() {
            logQueue.async {
                print("\n📥🌊 DOWNLOAD ITEM [\(index + 1)/\(remoteOnlyFavorites.count)]: Processing station \(stationId)")
            }
            
            guard let remoteFavorite = remoteFavoritesDict[stationId] else {
                logQueue.async {
                    print("⚠️📥🌊 DOWNLOAD WARNING: No remote data found for station \(stationId)")
                    print("📥🌊 DOWNLOAD ITEM: Falling back to basic setTideStationFavorite method")
                }
                
                // Fallback to basic method if no details available
                let setStartTime = Date()
                let success = await databaseService.setTideStationFavorite(id: stationId, isFavorite: true)
                let setDuration = Date().timeIntervalSince(setStartTime)
                
                if success {
                    downloaded += 1
                    logQueue.async {
                        print("✅📥🌊 DOWNLOAD SUCCESS (basic): Station \(stationId)")
                        print("✅📥🌊 DOWNLOAD SUCCESS: Duration = \(String(format: "%.3f", setDuration))s")
                        print("✅📥🌊 DOWNLOAD SUCCESS: Total downloaded so far = \(downloaded)")
                    }
                } else {
                    let error = TideSyncError.databaseError("Failed to save station \(stationId)")
                    errors.append(error)
                    logQueue.async {
                        print("❌📥🌊 DOWNLOAD FAILED: Station \(stationId)")
                        print("❌📥🌊 DOWNLOAD FAILED: Database operation returned false")
                        print("❌📥🌊 DOWNLOAD FAILED: Duration = \(String(format: "%.3f", setDuration))s")
                        print("❌📥🌊 DOWNLOAD FAILED: Total errors so far = \(errors.count)")
                    }
                }
                continue
            }
            
            // Use the enhanced method with complete station details
            let stationName = remoteFavorite.stationName ?? "Station \(remoteFavorite.stationId)"
            
            logQueue.async {
                print("📥🌊 DOWNLOAD ITEM: Found complete remote data for station \(stationId)")
                print("📥🌊 DOWNLOAD ITEM: - Station Name: \(stationName)")
                print("📥🌊 DOWNLOAD ITEM: - Latitude: \(remoteFavorite.latitude?.description ?? "nil")")
                print("📥🌊 DOWNLOAD ITEM: - Longitude: \(remoteFavorite.longitude?.description ?? "nil")") // Corrected this line
                print("📥🌊 DOWNLOAD ITEM: - Is Favorite: \(remoteFavorite.isFavorite)")
                print("📥🌊 DOWNLOAD ITEM: - Last Modified: \(remoteFavorite.lastModified)")
                print("📥🌊 DOWNLOAD ITEM: - Device ID: \(remoteFavorite.deviceId)")
                print("📥🌊 DOWNLOAD ITEM: Calling enhanced setTideStationFavorite with complete details...")
            }
            
            let setStartTime = Date()
            let success = await databaseService.setTideStationFavorite(
                id: remoteFavorite.stationId,
                isFavorite: remoteFavorite.isFavorite,
                name: stationName,
                latitude: remoteFavorite.latitude,
                longitude: remoteFavorite.longitude // Corrected this line
            )
            let setDuration = Date().timeIntervalSince(setStartTime)
            
            if success {
                downloaded += 1
                logQueue.async {
                    print("✅📥🌊 DOWNLOAD SUCCESS (enhanced): Station \(stationId)")
                    print("✅📥🌊 DOWNLOAD SUCCESS: Saved with complete details:")
                    print("✅📥🌊 DOWNLOAD SUCCESS: - Name: \(stationName)")
                    print("✅📥🌊 DOWNLOAD SUCCESS: - Coordinates: \(remoteFavorite.latitude?.description ?? "nil"), \(remoteFavorite.longitude?.description ?? "nil")")
                    print("✅📥🌊 DOWNLOAD SUCCESS: Duration = \(String(format: "%.3f", setDuration))s")
                    print("✅📥🌊 DOWNLOAD SUCCESS: Total downloaded so far = \(downloaded)")
                }
            } else {
                let error = TideSyncError.databaseError("Failed to save station \(stationId) with details")
                errors.append(error)
                logQueue.async {
                    print("❌📥🌊 DOWNLOAD FAILED: Station \(stationId)")
                    print("❌📥🌊 DOWNLOAD FAILED: Enhanced database operation returned false")
                    print("❌📥🌊 DOWNLOAD FAILED: Duration = \(String(format: "%.3f", setDuration))s")
                    print("❌📥🌊 DOWNLOAD FAILED: Total errors so far = \(errors.count)")
                }
            }
        } // End of for loop
        
        // Ensure these summary logs and return are ONLY AFTER the for loop
        logQueue.async {
            print("\n📥🌊 DOWNLOAD SUMMARY:")
            print("📥🌊 DOWNLOAD: Processed \(remoteOnlyFavorites.count) stations")
            print("📥🌊 DOWNLOAD: Successfully downloaded = \(downloaded)")
            print("📥🌊 DOWNLOAD: Failed downloads = \(errors.count)")
            if !remoteOnlyFavorites.isEmpty {
                print("📥🌊 DOWNLOAD: Success rate = \(String(format: "%.1f", Double(downloaded) / Double(remoteOnlyFavorites.count) * 100))%")
            }
            print("📥🌊 DOWNLOAD: Enhanced downloads (with details) = \(downloaded)")
        }
        
        logQueue.async {
            print("\n✅📥🌊 DOWNLOAD PHASE COMPLETE:")
            print("✅📥🌊 DOWNLOAD: Successfully downloaded = \(downloaded)")
            print("✅📥🌊 DOWNLOAD: Errors encountered = \(errors.count)")
            print("✅📥🌊 DOWNLOAD: Duration = \(String(format: "%.3f", Date().timeIntervalSince(Date())))s")
        }
        
        return (downloaded, errors)
    }
    
    private func resolveConflicts(
        conflictingStations: Set<String>,
        remoteFavorites: [RemoteTideFavorite],
        databaseService: TideStationDatabaseService
    ) async -> (resolved: Int, errors: [TideSyncError]) {
        
        logQueue.async {
            print("\n🔧🌊 CONFLICT IMPLEMENTATION: Starting detailed conflict resolution...")
            print("🔧🌊 CONFLICT: Conflicting stations = \(conflictingStations)")
            print("🔧🌊 CONFLICT: Count to process = \(conflictingStations.count)")
            print("🔧🌊 CONFLICT: Strategy = Last Modified Wins")
        }
        
        var resolved = 0
        var errors: [TideSyncError] = []
        
        // Get local favorites with timestamps for comparison
        let localFavorites = await databaseService.getAllFavoriteStationsWithTimestamps()
        let localFavoritesDict = Dictionary(uniqueKeysWithValues: localFavorites.map { ($0.stationId, $0) })
        
        for (index, stationId) in conflictingStations.enumerated() {
            logQueue.async {
                print("\n🔧🌊 CONFLICT ITEM [\(index + 1)/\(conflictingStations.count)]: Processing station \(stationId)")
                print("🔧🌊 CONFLICT ITEM: Looking for remote record...")
            }
            
            guard let remoteFavorite = remoteFavorites.first(where: { $0.stationId == stationId }) else {
                logQueue.async {
                    print("❌🔧🌊 CONFLICT ERROR: No remote record found for station \(stationId)")
                    print("❌🔧🌊 CONFLICT ERROR: This should not happen - conflicting station without remote record")
                }
                continue
            }
            
            // Get local record for timestamp comparison
            guard let localFavorite = localFavoritesDict[stationId] else {
                logQueue.async {
                    print("❌🔧🌊 CONFLICT ERROR: No local record found for station \(stationId)")
                    print("❌🔧🌊 CONFLICT ERROR: This should not happen - conflicting station without local record")
                }
                continue
            }
            
            logQueue.async {
                print("🔧🌊 CONFLICT ITEM: Found both records for comparison:")
                print("🔧🌊 CONFLICT ITEM: Local - Station: \(localFavorite.stationId), Favorite: \(localFavorite.isFavorite), Modified: \(localFavorite.lastModified)")
                print("🔧🌊 CONFLICT ITEM: Remote - Station: \(remoteFavorite.stationId), Favorite: \(remoteFavorite.isFavorite), Modified: \(remoteFavorite.lastModified)")
            }
            
            let resolveStartTime = Date()
            let success: Bool
            
            // Implement "Last Modified Wins" strategy
            if localFavorite.lastModified > remoteFavorite.lastModified {
                // Local is newer - upload local to remote
                logQueue.async {
                    print("🔧🌊 CONFLICT: Local record is newer - uploading to remote")
                    print("🔧🌊 CONFLICT: Local modified: \(localFavorite.lastModified)")
                    print("🔧🌊 CONFLICT: Remote modified: \(remoteFavorite.lastModified)")
                }
                
                do {
                    // Create properly typed update record preserving the local timestamp
                    struct UpdateRecord: Codable {
                        let stationId: String
                        let isFavorite: Bool
                        let lastModified: Date
                        let deviceId: String
                        let stationName: String?
                        let latitude: Double?
                        let longitude: Double?
                        
                        enum CodingKeys: String, CodingKey {
                            case stationId = "station_id"
                            case isFavorite = "is_favorite"
                            case lastModified = "last_modified"
                            case deviceId = "device_id"
                            case stationName = "station_name"
                            case latitude
                            case longitude
                        }
                    }
                    
                    let uploadData = UpdateRecord(
                        stationId: localFavorite.stationId,
                        isFavorite: localFavorite.isFavorite,
                        lastModified: localFavorite.lastModified,
                        deviceId: localFavorite.deviceId,
                        stationName: localFavorite.stationName,
                        latitude: localFavorite.latitude,
                        longitude: localFavorite.longitude
                    )
                    
                    try await SupabaseManager.shared
                        .from("user_tide_favorites")
                        .update(uploadData)
                        .eq("id", value: remoteFavorite.id!)
                        .execute()
                    
                    success = true
                    logQueue.async {
                        print("✅🔧🌊 CONFLICT: Successfully uploaded local record to remote")
                    }
                } catch {
                    success = false
                    logQueue.async {
                        print("❌🔧🌊 CONFLICT: Failed to upload local record: \(error)")
                    }
                }
            } else if remoteFavorite.lastModified > localFavorite.lastModified {
                // Remote is newer - download remote to local
                logQueue.async {
                    print("🔧🌊 CONFLICT: Remote record is newer - downloading to local")
                    print("🔧🌊 CONFLICT: Local modified: \(localFavorite.lastModified)")
                    print("🔧🌊 CONFLICT: Remote modified: \(remoteFavorite.lastModified)")
                }
                
                success = await databaseService.setTideStationFavorite(
                    id: stationId,
                    isFavorite: remoteFavorite.isFavorite,
                    name: remoteFavorite.stationName,
                    latitude: remoteFavorite.latitude,
                    longitude: remoteFavorite.longitude
                )
                
                if success {
                    logQueue.async {
                        print("✅🔧🌊 CONFLICT: Successfully downloaded remote record to local")
                    }
                }
            } else {
                // Same timestamp - no action needed
                logQueue.async {
                    print("🔧🌊 CONFLICT: Records have same timestamp - no action needed")
                    print("🔧🌊 CONFLICT: Both modified: \(localFavorite.lastModified)")
                }
                success = true
            }
            
            let resolveDuration = Date().timeIntervalSince(resolveStartTime)
            
            if success {
                resolved += 1
                logQueue.async {
                    print("✅🔧🌊 CONFLICT RESOLVED: Station \(stationId)")
                    print("✅🔧🌊 CONFLICT RESOLVED: Local now matches remote (isFavorite = \(remoteFavorite.isFavorite))")
                    print("✅🔧🌊 CONFLICT RESOLVED: Duration = \(String(format: "%.3f", resolveDuration))s")
                    print("✅🔧🌊 CONFLICT RESOLVED: Total resolved so far = \(resolved)")
                }
            } else {
                let error = TideSyncError.conflictResolutionFailed("Could not update local favorite for \(stationId)")
                errors.append(error)
                logQueue.async {
                    print("❌🔧🌊 CONFLICT FAILED: Station \(stationId)")
                    print("❌🔧🌊 CONFLICT FAILED: Database operation returned false")
                    print("❌🔧🌊 CONFLICT FAILED: Duration = \(String(format: "%.3f", resolveDuration))s")
                    print("❌🔧🌊 CONFLICT FAILED: Total errors so far = \(errors.count)")
                }
            }
        }
        
        logQueue.async {
            print("\n🔧🌊 CONFLICT SUMMARY:")
            print("🔧🌊 CONFLICT: Processed \(conflictingStations.count) conflicts")
            print("🔧🌊 CONFLICT: Successfully resolved = \(resolved)")
            print("🔧🌊 CONFLICT: Failed resolutions = \(errors.count)")
            if !conflictingStations.isEmpty {
                print("🔧🌊 CONFLICT: Success rate = \(String(format: "%.1f", Double(resolved) / Double(conflictingStations.count) * 100))%")
            }
        }
        
        return (resolved, errors)
    }
    
    // MARK: - Helper Methods
    
    private func getRemoteFavorites(userId: UUID) async -> [RemoteTideFavorite] {
        logQueue.async {
            print("\n☁️🌊 REMOTE FETCH: Starting Supabase query...")
            print("☁️🌊 REMOTE FETCH: Table = user_tide_favorites")
            print("☁️🌊 REMOTE FETCH: Filter = user_id eq \(userId)")
        }
        
        do {
            let queryStartTime = Date()
            let response: PostgrestResponse<[RemoteTideFavorite]> = try await SupabaseManager.shared
                .from("user_tide_favorites")
                .select("*")
                .eq("user_id", value: userId.uuidString)
                .execute()
            let queryDuration = Date().timeIntervalSince(queryStartTime)
            
            logQueue.async {
                print("\n✅☁️🌊 REMOTE FETCH SUCCESS: Query completed")
                print("✅☁️🌊 REMOTE FETCH: Retrieved \(response.value.count) records")
                print("✅☁️🌊 REMOTE FETCH: Duration = \(String(format: "%.3f", queryDuration))s")
                print("✅☁️🌊 REMOTE FETCH: Response status = success")
                
                if response.value.isEmpty {
                    print("⚠️☁️🌊 REMOTE FETCH: No remote favorites found for user")
                } else {
                    print("☁️🌊 REMOTE FETCH: Sample records:")
                    for (index, favorite) in response.value.prefix(3).enumerated() {
                        print("☁️🌊 REMOTE FETCH: [\(index)] ID: \(favorite.id?.uuidString ?? "nil"), Station: \(favorite.stationId), Favorite: \(favorite.isFavorite)")
                    }
                }
            }
            
            return response.value
        } catch {
            logQueue.async {
                print("\n❌☁️🌊 REMOTE FETCH ERROR: Query failed")
                print("❌☁️🌊 REMOTE FETCH ERROR: \(error)")
                print("❌☁️🌊 REMOTE FETCH ERROR: Type = \(type(of: error))")
                print("❌☁️🌊 REMOTE FETCH ERROR: Description = \(error.localizedDescription)")
                print("❌☁️🌊 REMOTE FETCH ERROR: Returning empty array")
            }
            return []
        }
    }
    
    private func getTideStationDatabaseService() -> TideStationDatabaseService? {
        logQueue.async {
            print("\n💾🌊 SERVICE PROVIDER: Attempting to get TideStationDatabaseService...")
            print("💾🌊 SERVICE PROVIDER: Creating ServiceProvider instance")
        }
        
        let serviceProvider = ServiceProvider()
        let service = serviceProvider.tideStationService
        
        logQueue.async {
            if service != nil {
                print("✅💾🌊 SERVICE PROVIDER: Successfully obtained TideStationDatabaseService")
            } else {
                print("❌💾🌊 SERVICE PROVIDER: Failed to obtain TideStationDatabaseService")
                print("❌💾🌊 SERVICE PROVIDER: ServiceProvider may not be properly initialized")
            }
        }
        
        return service
    }
    
    /// Check if user is authenticated for sync operations
    func canSync() async -> Bool {
        let operationId = startSyncOperation("authCheck")
        
        logQueue.async {
            print("\n🔐🌊 AUTH CHECK: Starting authentication verification...")
            print("🔐🌊 AUTH CHECK: Operation ID = \(operationId)")
        }
        
        do {
            let session = try await SupabaseManager.shared.getSession()
            endSyncOperation(operationId, success: true)
            
            logQueue.async {
                print("✅🔐🌊 AUTH CHECK SUCCESS: User is authenticated")
                print("✅🔐🌊 AUTH CHECK: User ID = \(session.user.id)")
                print("✅🔐🌊 AUTH CHECK: User email = \(session.user.email ?? "NO EMAIL")")
            }
            
            return true
        } catch {
            endSyncOperation(operationId, success: false, error: TideSyncError.authenticationRequired)
            
            logQueue.async {
                print("❌🔐🌊 AUTH CHECK FAILED: User not authenticated")
                print("❌🔐🌊 AUTH CHECK FAILED: Error = \(error)")
                print("❌🔐🌊 AUTH CHECK FAILED: Description = \(error.localizedDescription)")
            }
            
            return false
        }
    }
    
    // MARK: - Operation Tracking (Matches SupabaseManager Pattern)
    
    private func startSyncOperation(_ operation: String, details: String = "") -> String {
        operationsLock.lock()
        defer { operationsLock.unlock() }
        
        syncCounter += 1
        let operationId = "\(operation)_\(syncCounter)"
        let startTime = Date()
        activeSyncOperations[operationId] = startTime
        
        logQueue.async {
            print("\n🟢🌊 OPERATION START: ============================================")
            print("🟢🌊 OPERATION: \(operation)")
            print("🟢🌊 OPERATION ID: \(operationId)")
            if !details.isEmpty {
                print("🟢🌊 OPERATION DETAILS: \(details)")
            }
            print("🟢🌊 START TIME: \(startTime)")
            print("🟢🌊 THREAD: \(Thread.current)")
            print("🟢🌊 PROCESS ID: \(ProcessInfo.processInfo.processIdentifier)")
            print("🟢🌊 ACTIVE SYNC OPS: \(self.activeSyncOperations.count)")
            print("🟢🌊 CONCURRENT SYNC OPS: \(Array(self.activeSyncOperations.keys))")
            
            if self.activeSyncOperations.count > 1 {
                print("⚠️🌊 RACE CONDITION WARNING: Multiple sync operations active!")
                for (opId, opStartTime) in self.activeSyncOperations {
                    let opDuration = Date().timeIntervalSince(opStartTime)
                    print("⚠️🌊 ACTIVE OP: \(opId) running for \(String(format: "%.3f", opDuration))s")
                }
            }
            
            print("🟢🌊 OPERATION START: ============================================")
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
            print("\n🔚🌊 OPERATION END: ============================================")
            print("🔚🌊 OPERATION ID: \(operationId)")
            print("🔚🌊 DURATION: \(String(format: "%.3f", duration))s")
            print("🔚🌊 END TIME: \(Date())")
            
            if success {
                print("✅🔚🌊 RESULT: SUCCESS")
            } else {
                print("❌🔚🌊 RESULT: FAILURE")
                if let error = error {
                    print("❌🔚🌊 ERROR: \(error.localizedDescription)")
                    print("❌🔚🌊 ERROR TYPE: \(type(of: error))")
                }
            }
            
            print("🔚🌊 REMAINING SYNC OPS: \(self.activeSyncOperations.count)")
            if !self.activeSyncOperations.isEmpty {
                print("🔚🌊 STILL ACTIVE: \(Array(self.activeSyncOperations.keys))")
            }
            print("🔚🌊 OPERATION END: ============================================\n")
        }
    }
    
    private func updateOperationStats(operationId: String, success: Bool, duration: TimeInterval) {
        statsLock.lock()
        defer { statsLock.unlock() }
        
        let operationType = String(operationId.split(separator: "_").first ?? "unknown")
        
        logQueue.async {
            print("📊🌊 STATS UPDATE: Updating statistics for \(operationType)")
            print("📊🌊 STATS UPDATE: Success = \(success), Duration = \(String(format: "%.3f", duration))s")
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
                print("📊🌊 STATS UPDATE: \(operationType) now has \(stats.totalCalls) calls, \(String(format: "%.1f", successRate))% success, \(String(format: "%.3f", avgDuration))s avg")
            }
        }
    }
    
    // MARK: - Public Monitoring (Matches SupabaseManager Pattern)
    
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
            print("\n📊🌊 TIDE SYNC SERVICE STATISTICS: ========================================")
            print("📊🌊 STATISTICS TIMESTAMP: \(Date())")
            
            if stats.isEmpty {
                print("📊🌊 No sync operations performed yet")
            } else {
                for (operation, stat) in stats.sorted(by: { $0.key < $1.key }) {
                    let avgDuration = stat.totalDuration / Double(stat.totalCalls)
                    let successRate = Double(stat.successCount) / Double(stat.totalCalls) * 100
                    
                    print("📊🌊 \(operation.uppercased()):")
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
            
            print("📊🌊 Current active operations: \(self.activeSyncOperations.count)")
            if !self.activeSyncOperations.isEmpty {
                for (opId, startTime) in self.activeSyncOperations {
                    let duration = Date().timeIntervalSince(startTime)
                    print("   \(opId): running for \(String(format: "%.1f", duration))s")
                }
            }
            print("📊🌊 STATISTICS END: ========================================\n")
        }
    }
    
    func enableVerboseLogging() {
        logQueue.async {
            print("🔍🌊 TIDE SYNC SERVICE: Verbose logging ENABLED")
            print("🔍🌊 Note: This service already has comprehensive logging by default")
        }
    }
    
    func logCurrentState() {
        let operations = getCurrentSyncOperations()
        
        logQueue.async {
            print("\n🔍🌊 TIDE SYNC SERVICE STATE: =====================================")
            print("🔍🌊 STATE TIMESTAMP: \(Date())")
            print("🔍🌊 Active sync operations: \(operations.count)")
            print("🔍🌊 Operations: \(operations)")
            print("🔍🌊 Thread: \(Thread.current)")
            print("🔍🌊 Process ID: \(ProcessInfo.processInfo.processIdentifier)")
            print("🔍🌊 Memory usage: \(ProcessInfo.processInfo.physicalMemory / 1024 / 1024) MB")
            
            // Print operation details
            if !operations.isEmpty {
                for opId in operations {
                    if let startTime = self.activeSyncOperations[opId] {
                        let duration = Date().timeIntervalSince(startTime)
                        print("🔍🌊 - \(opId): running for \(String(format: "%.3f", duration))s")
                    }
                }
            }
            
            print("🔍🌊 STATE END: =====================================\n")
        }
    }
}

