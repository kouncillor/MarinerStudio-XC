//
//  NavUnitSyncService.swift
//  Mariner Studio
//
//  Navigation Unit Favorites Synchronization Service
//  Singleton service for syncing nav unit favorites between local SQLite and Supabase
//

import Foundation
import Supabase
import UIKit

/// Singleton service for syncing navigation unit favorites between local SQLite and Supabase
final class NavUnitSyncService {
    
    // MARK: - Shared Instance
    static let shared = NavUnitSyncService()
    
    // MARK: - Private Properties
    private let syncQueue = DispatchQueue(label: "navUnitSync.operations", qos: .utility)
    private let logQueue = DispatchQueue(label: "navUnitSync.logging", qos: .background)
    private var activeSyncOperations: [String: Date] = [:]
    private let operationsLock = NSLock()
    private var syncCounter: Int = 0
    private let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
    
    // MARK: - Performance Tracking
    private var operationStats: [String: TideSyncOperationStats] = [:]
    private let statsLock = NSLock()
    
    // MARK: - Initialization
    private init() {
        logQueue.async {
            print("\n🌊⚖️ NAV_UNIT_SYNC_SERVICE: Initializing comprehensive nav unit sync system")
            print("🌊⚖️ NAV_UNIT_SYNC_SERVICE: Thread = \(Thread.current)")
            print("🌊⚖️ NAV_UNIT_SYNC_SERVICE: Timestamp = \(Date())")
            print("🌊⚖️ NAV_UNIT_SYNC_SERVICE: Device ID = \(self.deviceId)")
            print("🌊⚖️ NAV_UNIT_SYNC_SERVICE: Ready for nav unit sync operations\n")
        }
    }
    
    // MARK: - Public Sync Methods
    
    /// Main bidirectional sync method with HEAVY LOGGING
    func syncNavUnitFavorites() async -> TideSyncResult {
        let operationId = startSyncOperation("fullNavUnitSync")
        let startTime = Date()
        
        logQueue.async {
            print("\n🟢🌊⚖️ FULL NAV UNIT SYNC START: ===============================================")
            print("🟢🌊⚖️ FULL SYNC: Operation ID = \(operationId)")
            print("🟢🌊⚖️ FULL SYNC: Start timestamp = \(startTime)")
            print("🟢🌊⚖️ FULL SYNC: Thread = \(Thread.current)")
            print("🟢🌊⚖️ FULL SYNC: Process ID = \(ProcessInfo.processInfo.processIdentifier)")
        }
        
        do {
            // STEP 1: Authentication Check with heavy logging
            logQueue.async {
                print("\n🔐🌊⚖️ AUTH CHECK: Starting authentication verification...")
                print("🔐🌊⚖️ AUTH CHECK: Using SupabaseManager.shared for session retrieval")
            }
            
            guard let session = try? await SupabaseManager.shared.getSession() else {
                logQueue.async {
                    print("\n❌🔐🌊⚖️ AUTH FAILED: No valid session found")
                    print("❌🔐🌊⚖️ AUTH FAILED: User must be authenticated to sync nav units")
                    print("❌🔐🌊⚖️ AUTH FAILED: Terminating sync operation")
                }
                endSyncOperation(operationId, success: false, error: TideSyncError.authenticationRequired)
                return .failure(.authenticationRequired)
            }
            
            logQueue.async {
                print("\n✅🔐🌊⚖️ AUTH SUCCESS: Session retrieved successfully")
                print("✅🔐🌊⚖️ AUTH SUCCESS: User ID = \(session.user.id)")
                print("✅🔐🌊⚖️ AUTH SUCCESS: User email = \(session.user.email ?? "NO EMAIL")")
                print("✅🔐🌊⚖️ AUTH SUCCESS: Session expires at = \(Date(timeIntervalSince1970: TimeInterval(session.expiresAt)))")
            }
            
            // STEP 2: Database Service Access with heavy logging
            logQueue.async {
                print("\n💾🌊⚖️ DATABASE: Attempting to get nav unit database service...")
                print("💾🌊⚖️ DATABASE: Using ServiceProvider pattern")
            }
            
            guard let databaseService = getNavUnitDatabaseService() else {
                logQueue.async {
                    print("\n❌💾🌊⚖️ DATABASE FAILED: Could not access NavUnitDatabaseService")
                    print("❌💾🌊⚖️ DATABASE FAILED: ServiceProvider may not be initialized")
                    print("❌💾🌊⚖️ DATABASE FAILED: Terminating sync operation")
                }
                let error = TideSyncError.databaseError("Could not access nav unit database service")
                endSyncOperation(operationId, success: false, error: error)
                return .failure(error)
            }
            
            logQueue.async {
                print("\n✅💾🌊⚖️ DATABASE SUCCESS: NavUnitDatabaseService acquired")
                print("✅💾🌊⚖️ DATABASE SUCCESS: Ready for local nav unit data operations")
            }
            
            // STEP 3: Get Local Favorites with heavy logging
            logQueue.async {
                print("\n📱🌊⚖️ LOCAL DATA: Starting local nav unit favorites retrieval...")
                print("📱🌊⚖️ LOCAL DATA: Calling getAllFavoriteNavUnitIds()")
                print("📱🌊⚖️ LOCAL DATA: Timestamp = \(Date())")
            }
            
            let localStartTime = Date()
            let localFavorites = await databaseService.getAllFavoriteNavUnitIds()
            let localDuration = Date().timeIntervalSince(localStartTime)
            
            logQueue.async {
                print("\n✅📱🌊⚖️ LOCAL DATA SUCCESS: Retrieved local nav unit favorites")
                print("✅📱🌊⚖️ LOCAL DATA: Count = \(localFavorites.count)")
                print("✅📱🌊⚖️ LOCAL DATA: Duration = \(String(format: "%.3f", localDuration))s")
                print("✅📱🌊⚖️ LOCAL DATA: Nav Unit IDs = \(Array(localFavorites).sorted())")
            }
            
            // STEP 4: Get Remote Favorites with heavy logging
            logQueue.async {
                print("\n☁️🌊⚖️ REMOTE DATA: Starting remote nav unit favorites retrieval...")
                print("☁️🌊⚖️ REMOTE DATA: Calling fetchRemoteNavUnitFavorites()")
                print("☁️🌊⚖️ REMOTE DATA: User ID = \(session.user.id)")
                print("☁️🌊⚖️ REMOTE DATA: Timestamp = \(Date())")
            }
            
            let remoteStartTime = Date()
            let remoteFavorites = try await fetchRemoteNavUnitFavorites(for: session.user.id)
            let remoteDuration = Date().timeIntervalSince(remoteStartTime)
            
            logQueue.async {
                print("\n✅☁️🌊⚖️ REMOTE DATA SUCCESS: Retrieved remote nav unit favorites")
                print("✅☁️🌊⚖️ REMOTE DATA: Count = \(remoteFavorites.count)")
                print("✅☁️🌊⚖️ REMOTE DATA: Duration = \(String(format: "%.3f", remoteDuration))s")
                let remoteIds = remoteFavorites.map { $0.navUnitId }
                print("✅☁️🌊⚖️ REMOTE DATA: Nav Unit IDs = \(remoteIds.sorted())")
            }
            
            // STEP 5: Analyze Differences with heavy logging
            let remoteNavUnitIds = Set(remoteFavorites.map { $0.navUnitId })
            let localOnlyFavorites = localFavorites.subtracting(remoteNavUnitIds)
            let remoteOnlyFavorites = remoteNavUnitIds.subtracting(localFavorites)
            let commonFavorites = localFavorites.intersection(remoteNavUnitIds)
            
            logQueue.async {
                print("\n🔍🌊⚖️ ANALYSIS: Analyzing sync differences...")
                print("🔍🌊⚖️ ANALYSIS: Local-only favorites = \(localOnlyFavorites.count) items")
                print("🔍🌊⚖️ ANALYSIS: Remote-only favorites = \(remoteOnlyFavorites.count) items")
                print("🔍🌊⚖️ ANALYSIS: Common favorites = \(commonFavorites.count) items")
                
                if !localOnlyFavorites.isEmpty {
                    print("🔍🌊⚖️ ANALYSIS: Local-only IDs = \(Array(localOnlyFavorites).sorted())")
                }
                if !remoteOnlyFavorites.isEmpty {
                    print("🔍🌊⚖️ ANALYSIS: Remote-only IDs = \(Array(remoteOnlyFavorites).sorted())")
                }
            }
            
            var errors: [TideSyncError] = []
            var uploadCount = 0
            var downloadCount = 0
            var conflictCount = 0
            
            // STEP 6: Upload Local-Only Favorites
            if !localOnlyFavorites.isEmpty {
                logQueue.async {
                    print("\n📤🌊⚖️ UPLOAD PHASE: Starting upload of local-only nav unit favorites...")
                }
                
                let uploadStartTime = Date()
                let uploadResult = await uploadLocalChanges(
                    localOnlyFavorites: localOnlyFavorites,
                    userId: session.user.id,
                    databaseService: databaseService
                )
                let uploadDuration = Date().timeIntervalSince(uploadStartTime)
                
                uploadCount = uploadResult.uploaded
                errors.append(contentsOf: uploadResult.errors)
                
                logQueue.async {
                    print("\n✅📤🌊⚖️ UPLOAD COMPLETE: Uploaded \(uploadResult.uploaded) nav unit favorites")
                    print("✅📤🌊⚖️ UPLOAD: Duration = \(String(format: "%.3f", uploadDuration))s")
                    print("✅📤🌊⚖️ UPLOAD: Errors = \(uploadResult.errors.count)")
                    if !uploadResult.errors.isEmpty {
                        for (index, error) in uploadResult.errors.enumerated() {
                            print("❌📤🌊⚖️ UPLOAD ERROR [\(index)]: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            // STEP 7: Download Remote-Only Favorites
            if !remoteOnlyFavorites.isEmpty {
                logQueue.async {
                    print("\n📥🌊⚖️ DOWNLOAD PHASE: Starting download of remote-only nav unit favorites...")
                }
                
                let downloadStartTime = Date()
                let remoteOnlyRecords = remoteFavorites.filter { remoteOnlyFavorites.contains($0.navUnitId) }
                let downloadResult = await downloadRemoteChanges(
                    remoteOnlyFavorites: remoteOnlyRecords,
                    databaseService: databaseService
                )
                let downloadDuration = Date().timeIntervalSince(downloadStartTime)
                
                downloadCount = downloadResult.downloaded
                errors.append(contentsOf: downloadResult.errors)
                
                logQueue.async {
                    print("\n✅📥🌊⚖️ DOWNLOAD COMPLETE: Downloaded \(downloadResult.downloaded) nav unit favorites")
                    print("✅📥🌊⚖️ DOWNLOAD: Duration = \(String(format: "%.3f", downloadDuration))s")
                    print("✅📥🌊⚖️ DOWNLOAD: Errors = \(downloadResult.errors.count)")
                    if !downloadResult.errors.isEmpty {
                        for (index, error) in downloadResult.errors.enumerated() {
                            print("❌📥🌊⚖️ DOWNLOAD ERROR [\(index)]: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            // STEP 8: Handle Conflicts (Future Enhancement - For now, log that no conflicts need resolution)
            logQueue.async {
                print("\n🔧🌊⚖️ CONFLICT RESOLUTION: Checking for conflicts in common nav unit favorites...")
                print("🔧🌊⚖️ CONFLICT: Common favorites count = \(commonFavorites.count)")
                print("🔧🌊⚖️ CONFLICT: Using 'last write wins' strategy (future implementation)")
                print("🔧🌊⚖️ CONFLICT: No conflict resolution needed for boolean favorites")
            }
            
            // STEP 9: Create Final Result with heavy logging
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
                print("\n🏁🌊⚖️ NAV UNIT SYNC COMPLETE: =========================================")
                print("🏁🌊⚖️ SYNC RESULT: Operation ID = \(operationId)")
                print("🏁🌊⚖️ SYNC RESULT: Total duration = \(String(format: "%.3f", stats.duration))s")
                print("🏁🌊⚖️ SYNC RESULT: Total operations = \(stats.totalOperations)")
                print("🏁🌊⚖️ SYNC RESULT: Uploaded = \(uploadCount)")
                print("🏁🌊⚖️ SYNC RESULT: Downloaded = \(downloadCount)")
                print("🏁🌊⚖️ SYNC RESULT: Conflicts resolved = \(conflictCount)")
                print("🏁🌊⚖️ SYNC RESULT: Errors = \(errors.count)")
                print("🏁🌊⚖️ SYNC RESULT: Success = \(errors.isEmpty)")
                print("🏁🌊⚖️ SYNC RESULT: End timestamp = \(endTime)")
                print("🏁🌊⚖️ NAV UNIT SYNC COMPLETE: =========================================\n")
            }
            
            if errors.isEmpty {
                return .success(stats)
            } else {
                return .partialSuccess(stats, errors)
            }
            
        } catch {
            logQueue.async {
                print("\n💥🌊⚖️ NAV UNIT SYNC CATASTROPHIC ERROR: =============================")
                print("💥🌊⚖️ UNEXPECTED ERROR: \(error)")
                print("💥🌊⚖️ ERROR TYPE: \(type(of: error))")
                print("💥🌊⚖️ ERROR DESCRIPTION: \(error.localizedDescription)")
                print("💥🌊⚖️ OPERATION ID: \(operationId)")
                print("💥🌊⚖️ TIMESTAMP: \(Date())")
                print("💥🌊⚖️ NAV UNIT SYNC CATASTROPHIC ERROR: =============================\n")
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
        databaseService: NavUnitDatabaseService
    ) async -> (uploaded: Int, errors: [TideSyncError]) {
        
        logQueue.async {
            print("\n📤🌊⚖️ UPLOAD IMPLEMENTATION: Starting detailed upload process...")
            print("📤🌊⚖️ UPLOAD: Local-only nav unit favorites = \(localOnlyFavorites)")
            print("📤🌊⚖️ UPLOAD: User ID = \(userId)")
            print("📤🌊⚖️ UPLOAD: Count to process = \(localOnlyFavorites.count)")
        }
        
        var uploaded = 0
        var errors: [TideSyncError] = []
        
        // STEP 1: Get all favorite nav units with details from local database
        do {
            let allLocalFavoritesWithDetails = try await databaseService.getAllNavUnitFavoritesForUser()
            let localNavUnitsMap = Dictionary(uniqueKeysWithValues: allLocalFavoritesWithDetails.map { ($0.navUnitId, $0) })
            
            for (index, navUnitId) in localOnlyFavorites.enumerated() {
                logQueue.async {
                    print("\n📤🌊⚖️ UPLOAD ITEM [\(index + 1)/\(localOnlyFavorites.count)]: Processing nav unit \(navUnitId)")
                    print("📤🌊⚖️ UPLOAD ITEM: Getting nav unit details from local database...")
                }
                
                // STEP 2: Get nav unit details from local database
                let navUnitDetails = localNavUnitsMap[navUnitId]
                let navUnitName = navUnitDetails?.navUnitName ?? "Nav Unit \(navUnitId)"
                let latitude = navUnitDetails?.latitude
                let longitude = navUnitDetails?.longitude
                let facilityType = navUnitDetails?.facilityType
                
                logQueue.async {
                    print("📤🌊⚖️ UPLOAD ITEM: Nav unit details retrieved:")
                    print("📤🌊⚖️ UPLOAD ITEM: - Name: '\(navUnitName)'")
                    print("📤🌊⚖️ UPLOAD ITEM: - Latitude: \(latitude?.description ?? "nil")")
                    print("📤🌊⚖️ UPLOAD ITEM: - Longitude: \(longitude?.description ?? "nil")")
                    print("📤🌊⚖️ UPLOAD ITEM: - Facility Type: '\(facilityType ?? "nil")'")
                }
                
                // STEP 3: Create RemoteNavUnitFavorite record
                let remoteRecord = RemoteNavUnitFavorite(
                    userId: userId.uuidString,
                    navUnitId: navUnitId,
                    isFavorite: true,
                    deviceId: deviceId,
                    navUnitName: navUnitName,
                    latitude: latitude,
                    longitude: longitude,
                    facilityType: facilityType
                )
                
                logQueue.async {
                    print("📤🌊⚖️ UPLOAD ITEM: Created RemoteNavUnitFavorite record")
                    print("📤🌊⚖️ UPLOAD ITEM: Attempting Supabase insert...")
                }
                
                // STEP 4: Upload to Supabase
                do {
                    let uploadItemStartTime = Date()
                    try await SupabaseManager.shared.from("user_nav_unit_favorites").insert(remoteRecord).execute()
                    let uploadItemDuration = Date().timeIntervalSince(uploadItemStartTime)
                    
                    uploaded += 1
                    
                    logQueue.async {
                        print("✅📤🌊⚖️ UPLOAD ITEM SUCCESS: Nav unit \(navUnitId) uploaded")
                        print("✅📤🌊⚖️ UPLOAD ITEM: Duration = \(String(format: "%.3f", uploadItemDuration))s")
                        print("✅📤🌊⚖️ UPLOAD ITEM: Total uploaded so far = \(uploaded)")
                    }
                    
                } catch {
                    let uploadError = TideSyncError.supabaseError("Failed to upload nav unit \(navUnitId): \(error.localizedDescription)")
                    errors.append(uploadError)
                    
                    logQueue.async {
                        print("❌📤🌊⚖️ UPLOAD ITEM FAILED: Nav unit \(navUnitId)")
                        print("❌📤🌊⚖️ UPLOAD ITEM: Error = \(error.localizedDescription)")
                        print("❌📤🌊⚖️ UPLOAD ITEM: Total errors so far = \(errors.count)")
                    }
                }
            }
            
        } catch {
            let dbError = TideSyncError.databaseError("Failed to get local nav unit favorites: \(error.localizedDescription)")
            errors.append(dbError)
            
            logQueue.async {
                print("❌📤🌊⚖️ UPLOAD FAILED: Could not retrieve local nav unit favorites")
                print("❌📤🌊⚖️ UPLOAD FAILED: Error = \(error.localizedDescription)")
            }
        }
        
        return (uploaded: uploaded, errors: errors)
    }
    
    private func downloadRemoteChanges(
        remoteOnlyFavorites: [RemoteNavUnitFavorite],
        databaseService: NavUnitDatabaseService
    ) async -> (downloaded: Int, errors: [TideSyncError]) {
        
        logQueue.async {
            print("\n📥🌊⚖️ DOWNLOAD IMPLEMENTATION: Starting detailed download process...")
            print("📥🌊⚖️ DOWNLOAD: Remote-only nav unit favorites = \(remoteOnlyFavorites.count)")
        }
        
        var downloaded = 0
        var errors: [TideSyncError] = []
        
        for (index, remoteFavorite) in remoteOnlyFavorites.enumerated() {
            logQueue.async {
                print("\n📥🌊⚖️ DOWNLOAD ITEM [\(index + 1)/\(remoteOnlyFavorites.count)]: Processing nav unit \(remoteFavorite.navUnitId)")
                print("📥🌊⚖️ DOWNLOAD ITEM: Remote details:")
                print("📥🌊⚖️ DOWNLOAD ITEM: - Name: '\(remoteFavorite.navUnitName ?? "Unknown")'")
                print("📥🌊⚖️ DOWNLOAD ITEM: - Is Favorite: \(remoteFavorite.isFavorite)")
                print("📥🌊⚖️ DOWNLOAD ITEM: - Last Modified: \(remoteFavorite.lastModified)")
                print("📥🌊⚖️ DOWNLOAD ITEM: - Device ID: \(remoteFavorite.deviceId)")
            }
            
            do {
                let downloadItemStartTime = Date()
                
                // Set nav unit favorite status in local database
                let success = try await databaseService.setNavUnitFavorite(
                    navUnitId: remoteFavorite.navUnitId,
                    isFavorite: remoteFavorite.isFavorite,
                    navUnitName: remoteFavorite.navUnitName,
                    latitude: remoteFavorite.latitude,
                    longitude: remoteFavorite.longitude,
                    facilityType: remoteFavorite.facilityType
                )
                
                let downloadItemDuration = Date().timeIntervalSince(downloadItemStartTime)
                
                if success {
                    downloaded += 1
                    
                    logQueue.async {
                        print("✅📥🌊⚖️ DOWNLOAD ITEM SUCCESS: Nav unit \(remoteFavorite.navUnitId) downloaded")
                        print("✅📥🌊⚖️ DOWNLOAD ITEM: Duration = \(String(format: "%.3f", downloadItemDuration))s")
                        print("✅📥🌊⚖️ DOWNLOAD ITEM: Total downloaded so far = \(downloaded)")
                    }
                } else {
                    let downloadError = TideSyncError.databaseError("Failed to set nav unit favorite for \(remoteFavorite.navUnitId)")
                    errors.append(downloadError)
                    
                    logQueue.async {
                        print("❌📥🌊⚖️ DOWNLOAD ITEM FAILED: Nav unit \(remoteFavorite.navUnitId)")
                        print("❌📥🌊⚖️ DOWNLOAD ITEM: setNavUnitFavorite returned false")
                    }
                }
                
            } catch {
                let downloadError = TideSyncError.databaseError("Failed to download nav unit \(remoteFavorite.navUnitId): \(error.localizedDescription)")
                errors.append(downloadError)
                
                logQueue.async {
                    print("❌📥🌊⚖️ DOWNLOAD ITEM FAILED: Nav unit \(remoteFavorite.navUnitId)")
                    print("❌📥🌊⚖️ DOWNLOAD ITEM: Error = \(error.localizedDescription)")
                    print("❌📥🌊⚖️ DOWNLOAD ITEM: Total errors so far = \(errors.count)")
                }
            }
        }
        
        return (downloaded: downloaded, errors: errors)
    }
    
    private func fetchRemoteNavUnitFavorites(for userId: UUID) async throws -> [RemoteNavUnitFavorite] {
        logQueue.async {
            print("\n☁️🌊⚖️ REMOTE FETCH: Starting Supabase query for nav unit favorites...")
            print("☁️🌊⚖️ REMOTE FETCH: User ID = \(userId)")
            print("☁️🌊⚖️ REMOTE FETCH: Table = user_nav_unit_favorites")
        }
        
        let startTime = Date()
        
        do {
            let response: [RemoteNavUnitFavorite] = try await SupabaseManager.shared
                .from("user_nav_unit_favorites")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            
            let duration = Date().timeIntervalSince(startTime)
            
            logQueue.async {
                print("\n✅☁️🌊⚖️ REMOTE FETCH SUCCESS: Retrieved \(response.count) nav unit favorites")
                print("✅☁️🌊⚖️ REMOTE FETCH: Duration = \(String(format: "%.3f", duration))s")
                
                if !response.isEmpty {
                    print("✅☁️🌊⚖️ REMOTE FETCH: Sample records:")
                    for (index, record) in response.prefix(3).enumerated() {
                        print("✅☁️🌊⚖️ REMOTE FETCH: [\(index)] ID=\(record.navUnitId), Name='\(record.navUnitName ?? "Unknown")', Favorite=\(record.isFavorite)")
                    }
                    if response.count > 3 {
                        print("✅☁️🌊⚖️ REMOTE FETCH: ... and \(response.count - 3) more records")
                    }
                }
            }
            
            return response
            
        } catch {
            logQueue.async {
                print("\n❌☁️🌊⚖️ REMOTE FETCH FAILED: Supabase query error")
                print("❌☁️🌊⚖️ REMOTE FETCH: Error = \(error.localizedDescription)")
                print("❌☁️🌊⚖️ REMOTE FETCH: Error type = \(type(of: error))")
            }
            
            throw TideSyncError.supabaseError("Failed to fetch remote nav unit favorites: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Check if sync is available (user authenticated and services accessible)
    func canSync() async -> Bool {
        logQueue.async {
            print("\n🔍🌊⚖️ CAN_SYNC_CHECK: Verifying sync availability...")
        }
        
        // Check authentication
        guard let _ = try? await SupabaseManager.shared.getSession() else {
            logQueue.async {
                print("❌🔍🌊⚖️ CAN_SYNC_CHECK: Authentication failed")
            }
            return false
        }
        
        // Check database service
        guard let _ = getNavUnitDatabaseService() else {
            logQueue.async {
                print("❌🔍🌊⚖️ CAN_SYNC_CHECK: Database service unavailable")
            }
            return false
        }
        
        logQueue.async {
            print("✅🔍🌊⚖️ CAN_SYNC_CHECK: Sync is available")
        }
        
        return true
    }
    
    /// Get current active sync operations (for debugging)
    func getCurrentSyncOperations() -> [String: Date] {
        operationsLock.lock()
        defer { operationsLock.unlock() }
        return activeSyncOperations
    }
    
    /// Print sync performance statistics
    func printSyncStats() {
        statsLock.lock()
        defer { statsLock.unlock() }
        
        logQueue.async {
            print("\n📊🌊⚖️ NAV UNIT SYNC STATS: ========================================")
            print("📊🌊⚖️ Total operations tracked: \(self.operationStats.count)")
            
            if self.operationStats.isEmpty {
                print("📊🌊⚖️ No sync operations recorded yet")
            } else {
                for (operation, stats) in self.operationStats {
                    print("📊🌊⚖️ Operation: \(operation)")
                    print("📊🌊⚖️ - Count: \(stats.count)")
                    print("📊🌊⚖️ - Total duration: \(String(format: "%.3f", stats.totalDuration))s")
                    print("📊🌊⚖️ - Average duration: \(String(format: "%.3f", stats.averageDuration))s")
                    print("📊🌊⚖️ - Last execution: \(stats.lastExecution)")
                }
            }
            print("📊🌊⚖️ NAV UNIT SYNC STATS: ========================================\n")
        }
    }
    
    // MARK: - Database Service Access
    
    private func getNavUnitDatabaseService() -> NavUnitDatabaseService? {
        do {
            let serviceProvider = ServiceProvider()
            return serviceProvider.navUnitService
        } catch {
            logQueue.async {
                print("❌💾🌊⚖️ DATABASE SERVICE: Failed to get NavUnitDatabaseService from ServiceProvider")
                print("❌💾🌊⚖️ DATABASE SERVICE: Error = \(error.localizedDescription)")
            }
            return nil
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
            print("\n🟢🌊⚖️ OPERATION START: ==========================================")
            print("🟢🌊⚖️ OPERATION: \(operation)")
            print("🟢🌊⚖️ OPERATION ID: \(operationId)")
            if !details.isEmpty {
                print("🟢🌊⚖️ OPERATION DETAILS: \(details)")
            }
            print("🟢🌊⚖️ START TIME: \(startTime)")
            print("🟢🌊⚖️ THREAD: \(Thread.current)")
            print("🟢🌊⚖️ PROCESS ID: \(ProcessInfo.processInfo.processIdentifier)")
            print("🟢🌊⚖️ ACTIVE SYNC OPS: \(self.activeSyncOperations.count)")
            print("🟢🌊⚖️ CONCURRENT SYNC OPS: \(Array(self.activeSyncOperations.keys))")
            
            if self.activeSyncOperations.count > 1 {
                print("⚠️🌊⚖️ RACE CONDITION WARNING: Multiple nav unit sync operations active!")
                for (opId, opStartTime) in self.activeSyncOperations {
                    let opDuration = Date().timeIntervalSince(opStartTime)
                    print("⚠️🌊⚖️ ACTIVE OP: \(opId) running for \(String(format: "%.3f", opDuration))s")
                }
            }
            
            print("🟢🌊⚖️ OPERATION START: ==========================================")
        }
        
        return operationId
    }
    
    private func endSyncOperation(_ operationId: String, success: Bool, error: TideSyncError? = nil) {
        operationsLock.lock()
        let startTime = activeSyncOperations.removeValue(forKey: operationId)
        operationsLock.unlock()
        
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        // Track performance statistics
        statsLock.lock()
        let operationType = String(operationId.prefix(while: { $0 != "_" }))
        if operationStats[operationType] == nil {
            operationStats[operationType] = TideSyncOperationStats()
        }
        operationStats[operationType]?.addExecution(duration: duration, success: success)
        statsLock.unlock()
        
        logQueue.async {
            print("\n🔴🌊⚖️ OPERATION END: ============================================")
            print("🔴🌊⚖️ OPERATION ID: \(operationId)")
            print("🔴🌊⚖️ DURATION: \(String(format: "%.3f", duration))s")
            print("🔴🌊⚖️ SUCCESS: \(success)")
            print("🔴🌊⚖️ END TIME: \(Date())")
            
            if let error = error {
                print("🔴🌊⚖️ ERROR: \(error.localizedDescription)")
                print("🔴🌊⚖️ ERROR TYPE: \(type(of: error))")
            }
            
            print("🔴🌊⚖️ REMAINING ACTIVE OPS: \(self.activeSyncOperations.count)")
            if !self.activeSyncOperations.isEmpty {
                for (opId, opStartTime) in self.activeSyncOperations {
                    let opDuration = Date().timeIntervalSince(opStartTime)
                    print("🔴🌊⚖️ STILL ACTIVE: \(opId) running for \(String(format: "%.3f", opDuration))s")
                }
            }
            print("🔴🌊⚖️ OPERATION END: ============================================\n")
        }
    }
}

// MARK: - Supporting Types

/// Performance statistics for sync operations
private struct TideSyncOperationStats {
    private(set) var count: Int = 0
    private(set) var totalDuration: TimeInterval = 0
    private(set) var successCount: Int = 0
    private(set) var lastExecution: Date = Date()
    
    var averageDuration: TimeInterval {
        guard count > 0 else { return 0 }
        return totalDuration / Double(count)
    }
    
    var successRate: Double {
        guard count > 0 else { return 0 }
        return Double(successCount) / Double(count)
    }
    
    mutating func addExecution(duration: TimeInterval, success: Bool) {
        count += 1
        totalDuration += duration
        if success {
            successCount += 1
        }
        lastExecution = Date()
    }
}
