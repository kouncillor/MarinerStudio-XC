//
//  NavUnitSyncService.swift
//  Mariner Studio
//
//  Navigation Unit Favorites Synchronization Service - Complete Rewrite
//  Singleton service for syncing nav unit favorites between local SQLite and Supabase
//  Follows exact TideStationSyncService pattern with last-write-wins conflict resolution
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
                
                if localFavorites.isEmpty {
                    print("⚠️📱🌊⚖️ LOCAL DATA WARNING: No local favorites found")
                } else {
                    print("📱🌊⚖️ LOCAL DATA: First 5 nav units = \(Array(localFavorites.prefix(5)))")
                }
            }
            
            // STEP 4: Get Remote Favorites with heavy logging
            logQueue.async {
                print("\n☁️🌊⚖️ REMOTE DATA: Starting remote nav unit favorites retrieval...")
                print("☁️🌊⚖️ REMOTE DATA: Querying user_nav_unit_favorites table")
                print("☁️🌊⚖️ REMOTE DATA: User ID filter = \(session.user.id)")
                print("☁️🌊⚖️ REMOTE DATA: Using SupabaseManager.shared")
                print("☁️🌊⚖️ REMOTE DATA: Timestamp = \(Date())")
            }
            
            let remoteStartTime = Date()
            let remoteFavorites = await getRemoteNavUnitFavorites(userId: session.user.id)
            let remoteDuration = Date().timeIntervalSince(remoteStartTime)
            
            logQueue.async {
                print("\n✅☁️🌊⚖️ REMOTE DATA SUCCESS: Retrieved remote nav unit favorites")
                print("✅☁️🌊⚖️ REMOTE DATA: Count = \(remoteFavorites.count)")
                print("✅☁️🌊⚖️ REMOTE DATA: Duration = \(String(format: "%.3f", remoteDuration))s")
                
                if remoteFavorites.isEmpty {
                    print("⚠️☁️🌊⚖️ REMOTE DATA WARNING: No remote favorites found")
                } else {
                    print("☁️🌊⚖️ REMOTE DATA: Remote nav units breakdown:")
                    let favoriteRemotes = remoteFavorites.filter { $0.isFavorite }
                    let unfavoriteRemotes = remoteFavorites.filter { !$0.isFavorite }
                    print("☁️🌊⚖️ REMOTE DATA: - Favorites (true): \(favoriteRemotes.count)")
                    print("☁️🌊⚖️ REMOTE DATA: - Unfavorites (false): \(unfavoriteRemotes.count)")
                    
                    for (index, remote) in remoteFavorites.prefix(5).enumerated() {
                        print("☁️🌊⚖️ REMOTE DATA: [\(index)] Nav Unit: \(remote.navUnitId), Favorite: \(remote.isFavorite), Modified: \(remote.lastModified), Device: \(remote.deviceId)")
                    }
                }
            }
            
            // STEP 5: Data Analysis and Comparison
            logQueue.async {
                print("\n🔍🌊⚖️ ANALYSIS: Starting data comparison...")
                print("🔍🌊⚖️ ANALYSIS: Local favorites count = \(localFavorites.count)")
                print("🔍🌊⚖️ ANALYSIS: Remote records count = \(remoteFavorites.count)")
            }
            
            let analysisStartTime = Date()
            let (localOnlyNavUnits, remoteOnlyNavUnits, conflictingNavUnits) = analyzeNavUnitData(
                localFavorites: localFavorites,
                remoteFavorites: remoteFavorites
            )
            let analysisDuration = Date().timeIntervalSince(analysisStartTime)
            
            logQueue.async {
                print("\n✅🔍🌊⚖️ ANALYSIS SUCCESS: Data comparison completed")
                print("✅🔍🌊⚖️ ANALYSIS: Duration = \(String(format: "%.3f", analysisDuration))s")
                print("✅🔍🌊⚖️ ANALYSIS: Local-only nav units = \(localOnlyNavUnits.count)")
                print("✅🔍🌊⚖️ ANALYSIS: Remote-only nav units = \(remoteOnlyNavUnits.count)")
                print("✅🔍🌊⚖️ ANALYSIS: Conflicting nav units = \(conflictingNavUnits.count)")
                
                if !localOnlyNavUnits.isEmpty {
                    print("🔍🌊⚖️ ANALYSIS: Local-only IDs = \(Array(localOnlyNavUnits).sorted())")
                }
                if !remoteOnlyNavUnits.isEmpty {
                    print("🔍🌊⚖️ ANALYSIS: Remote-only IDs = \(remoteOnlyNavUnits.map { $0.navUnitId }.sorted())")
                }
                if !conflictingNavUnits.isEmpty {
                    print("🔍🌊⚖️ ANALYSIS: Conflicting IDs = \(Array(conflictingNavUnits).sorted())")
                }
            }
            
            // STEP 6: Upload Phase - Local-only nav units to Supabase
            var uploadResults = (uploaded: 0, errors: [TideSyncError]())
            if !localOnlyNavUnits.isEmpty {
                logQueue.async {
                    print("\n📤🌊⚖️ UPLOAD PHASE: Starting upload of local-only nav units...")
                    print("📤🌊⚖️ UPLOAD PHASE: Nav units to upload = \(localOnlyNavUnits.count)")
                }
                
                let uploadStartTime = Date()
                uploadResults = await uploadLocalNavUnits(
                    localOnlyNavUnits: localOnlyNavUnits,
                    userId: session.user.id,
                    databaseService: databaseService
                )
                let uploadDuration = Date().timeIntervalSince(uploadStartTime)
                
                logQueue.async {
                    print("\n✅📤🌊⚖️ UPLOAD PHASE COMPLETE:")
                    print("✅📤🌊⚖️ UPLOAD: Duration = \(String(format: "%.3f", uploadDuration))s")
                    print("✅📤🌊⚖️ UPLOAD: Successfully uploaded = \(uploadResults.uploaded)")
                    print("✅📤🌊⚖️ UPLOAD: Upload errors = \(uploadResults.errors.count)")
                    if uploadResults.uploaded > 0 {
                        print("✅📤🌊⚖️ UPLOAD: Success rate = \(String(format: "%.1f", Double(uploadResults.uploaded) / Double(localOnlyNavUnits.count) * 100))%")
                    }
                }
            } else {
                logQueue.async {
                    print("\n⏭️📤🌊⚖️ UPLOAD PHASE: Skipped - No local-only nav units to upload")
                }
            }
            
            // STEP 7: Download Phase - Remote-only nav units to local
            var downloadResults = (downloaded: 0, errors: [TideSyncError]())
            if !remoteOnlyNavUnits.isEmpty {
                logQueue.async {
                    print("\n📥🌊⚖️ DOWNLOAD PHASE: Starting download of remote-only nav units...")
                    print("📥🌊⚖️ DOWNLOAD PHASE: Nav units to download = \(remoteOnlyNavUnits.count)")
                }
                
                let downloadStartTime = Date()
                downloadResults = await downloadRemoteNavUnits(
                    remoteOnlyNavUnits: remoteOnlyNavUnits,
                    databaseService: databaseService
                )
                let downloadDuration = Date().timeIntervalSince(downloadStartTime)
                
                logQueue.async {
                    print("\n✅📥🌊⚖️ DOWNLOAD PHASE COMPLETE:")
                    print("✅📥🌊⚖️ DOWNLOAD: Duration = \(String(format: "%.3f", downloadDuration))s")
                    print("✅📥🌊⚖️ DOWNLOAD: Successfully downloaded = \(downloadResults.downloaded)")
                    print("✅📥🌊⚖️ DOWNLOAD: Download errors = \(downloadResults.errors.count)")
                    if downloadResults.downloaded > 0 {
                        print("✅📥🌊⚖️ DOWNLOAD: Success rate = \(String(format: "%.1f", Double(downloadResults.downloaded) / Double(remoteOnlyNavUnits.count) * 100))%")
                    }
                }
            } else {
                logQueue.async {
                    print("\n⏭️📥🌊⚖️ DOWNLOAD PHASE: Skipped - No remote-only nav units to download")
                }
            }
            
            // STEP 8: Conflict Resolution Phase - Last-Write-Wins
            var conflictResults = (resolved: 0, errors: [TideSyncError]())
            if !conflictingNavUnits.isEmpty {
                logQueue.async {
                    print("\n🔧🌊⚖️ CONFLICT PHASE: Starting last-write-wins conflict resolution...")
                    print("🔧🌊⚖️ CONFLICT PHASE: Conflicting nav units = \(conflictingNavUnits.count)")
                    print("🔧🌊⚖️ CONFLICT PHASE: Strategy = Last-Write-Wins (based on last_modified timestamp)")
                }
                
                let conflictStartTime = Date()
                conflictResults = await resolveNavUnitConflicts(
                    conflictingNavUnits: conflictingNavUnits,
                    localFavorites: localFavorites,
                    remoteFavorites: remoteFavorites,
                    databaseService: databaseService
                )
                let conflictDuration = Date().timeIntervalSince(conflictStartTime)
                
                logQueue.async {
                    print("\n✅🔧🌊⚖️ CONFLICT PHASE COMPLETE:")
                    print("✅🔧🌊⚖️ CONFLICT: Duration = \(String(format: "%.3f", conflictDuration))s")
                    print("✅🔧🌊⚖️ CONFLICT: Successfully resolved = \(conflictResults.resolved)")
                    print("✅🔧🌊⚖️ CONFLICT: Resolution errors = \(conflictResults.errors.count)")
                    if conflictResults.resolved > 0 {
                        print("✅🔧🌊⚖️ CONFLICT: Success rate = \(String(format: "%.1f", Double(conflictResults.resolved) / Double(conflictingNavUnits.count) * 100))%")
                    }
                }
            } else {
                logQueue.async {
                    print("\n⏭️🔧🌊⚖️ CONFLICT PHASE: Skipped - No conflicting nav units to resolve")
                }
            }
            
            // STEP 9: Final Results and Statistics
            let endTime = Date()
            let totalDuration = endTime.timeIntervalSince(startTime)
            let allErrors = uploadResults.errors + downloadResults.errors + conflictResults.errors
            
            let stats = TideSyncStats(
                operationId: operationId,
                startTime: startTime,
                endTime: endTime,
                localFavoritesFound: localFavorites.count,
                remoteFavoritesFound: remoteFavorites.count,
                uploaded: uploadResults.uploaded,
                downloaded: downloadResults.downloaded,
                conflictsResolved: conflictResults.resolved,
                errors: allErrors.count
            )
            
            updateOperationStats("fullNavUnitSync", success: allErrors.isEmpty, duration: totalDuration)
            endSyncOperation(operationId, success: allErrors.isEmpty)
            
            logQueue.async {
                print("\n🏁🌊⚖️ NAV UNIT SYNC COMPLETE: =========================================")
                print("🏁🌊⚖️ FINAL RESULTS:")
                print("🏁🌊⚖️ - Operation ID: \(operationId)")
                print("🏁🌊⚖️ - Total Duration: \(String(format: "%.3f", totalDuration))s")
                print("🏁🌊⚖️ - Local Favorites Found: \(localFavorites.count)")
                print("🏁🌊⚖️ - Remote Favorites Found: \(remoteFavorites.count)")
                print("🏁🌊⚖️ - Nav Units Uploaded: \(uploadResults.uploaded)")
                print("🏁🌊⚖️ - Nav Units Downloaded: \(downloadResults.downloaded)")
                print("🏁🌊⚖️ - Conflicts Resolved: \(conflictResults.resolved)")
                print("🏁🌊⚖️ - Total Operations: \(stats.totalOperations)")
                print("🏁🌊⚖️ - Total Errors: \(allErrors.count)")
                
                if allErrors.isEmpty {
                    print("🏁🌊⚖️ SYNC STATUS: ✅ COMPLETE SUCCESS")
                } else if stats.totalOperations > 0 {
                    print("🏁🌊⚖️ SYNC STATUS: ⚠️ PARTIAL SUCCESS (\(allErrors.count) errors)")
                } else {
                    print("🏁🌊⚖️ SYNC STATUS: ❌ FAILED")
                }
                print("🏁🌊⚖️ NAV UNIT SYNC COMPLETE: =========================================\n")
            }
            
            // Return appropriate result
            if allErrors.isEmpty {
                return .success(stats)
            } else if stats.totalOperations > 0 {
                return .partialSuccess(stats, allErrors)
            } else {
                return .failure(allErrors.first ?? TideSyncError.unknownError("Sync failed with no operations completed"))
            }
            
        } catch {
            let syncError = TideSyncError.unknownError(error.localizedDescription)
            endSyncOperation(operationId, success: false, error: syncError)
            
            logQueue.async {
                print("\n💥🌊⚖️ SYNC CATASTROPHIC ERROR: =============================")
                print("💥🌊⚖️ SYNC ERROR: \(error)")
                print("💥🌊⚖️ SYNC ERROR TYPE: \(type(of: error))")
                print("💥🌊⚖️ SYNC ERROR DESCRIPTION: \(error.localizedDescription)")
                print("💥🌊⚖️ OPERATION ID: \(operationId)")
                print("💥🌊⚖️ TIMESTAMP: \(Date())")
                print("💥🌊⚖️ NAV UNIT SYNC CATASTROPHIC ERROR: =============================\n")
            }
            
            return .failure(syncError)
        }
    }
    
    // MARK: - Private Sync Implementation Methods
    
    /// Analyze nav unit data to determine what needs syncing
    private func analyzeNavUnitData(
        localFavorites: Set<String>,
        remoteFavorites: [RemoteNavUnitFavorite]
    ) -> (localOnly: Set<String>, remoteOnly: [RemoteNavUnitFavorite], conflicting: Set<String>) {
        
        let remoteFavoriteIds = Set(remoteFavorites.filter { $0.isFavorite }.map { $0.navUnitId })
        let remoteUnfavoriteIds = Set(remoteFavorites.filter { !$0.isFavorite }.map { $0.navUnitId })
        let allRemoteIds = Set(remoteFavorites.map { $0.navUnitId })
        
        // Local-only: in local but not in remote at all
        let localOnlyNavUnits = localFavorites.subtracting(allRemoteIds)
        
        // Remote-only: in remote favorites but not in local favorites
        let remoteOnlyNavUnits = remoteFavorites.filter { remote in
            remote.isFavorite && !localFavorites.contains(remote.navUnitId)
        }
        
        // Conflicting: exist in both but with different states
        // Local favorite but remote unfavorite, OR local unfavorite but remote favorite
        let conflictingNavUnits = localFavorites.intersection(remoteUnfavoriteIds)
            .union(remoteFavoriteIds.subtracting(localFavorites))
        
        return (localOnlyNavUnits, remoteOnlyNavUnits, conflictingNavUnits)
    }
    
    /// Upload local-only nav units to Supabase
    private func uploadLocalNavUnits(
        localOnlyNavUnits: Set<String>,
        userId: UUID,
        databaseService: NavUnitDatabaseService
    ) async -> (uploaded: Int, errors: [TideSyncError]) {
        
        logQueue.async {
            print("\n📤🌊⚖️ UPLOAD IMPLEMENTATION: Starting detailed upload process...")
            print("📤🌊⚖️ UPLOAD: Local-only nav unit favorites = \(localOnlyNavUnits)")
            print("📤🌊⚖️ UPLOAD: User ID = \(userId)")
            print("📤🌊⚖️ UPLOAD: Count to process = \(localOnlyNavUnits.count)")
        }
        
        var uploaded = 0
        var errors: [TideSyncError] = []
        
        // Get all local nav unit favorites with metadata
        do {
            let allLocalFavoritesWithDetails = try await databaseService.getAllNavUnitFavoritesForUser()
            let localNavUnitsMap = Dictionary(uniqueKeysWithValues: allLocalFavoritesWithDetails.map { ($0.navUnitId, $0) })
            
            for (index, navUnitId) in localOnlyNavUnits.enumerated() {
                logQueue.async {
                    print("\n📤🌊⚖️ UPLOAD ITEM [\(index + 1)/\(localOnlyNavUnits.count)]: Processing nav unit \(navUnitId)")
                    print("📤🌊⚖️ UPLOAD ITEM: Getting nav unit details from local database...")
                }
                
                // Get nav unit details from local database
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
                
                // Create RemoteNavUnitFavorite record
                let remoteRecord = RemoteNavUnitFavorite(
                    userId: userId,
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
                
                // Upload to Supabase
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
                print("❌📤🌊⚖️ UPLOAD PHASE ERROR: Could not retrieve local nav unit details")
                print("❌📤🌊⚖️ UPLOAD ERROR: \(error.localizedDescription)")
            }
        }
        
        logQueue.async {
            print("\n📤🌊⚖️ UPLOAD PHASE SUMMARY:")
            print("📤🌊⚖️ UPLOAD: Total processed = \(localOnlyNavUnits.count)")
            print("📤🌊⚖️ UPLOAD: Successfully uploaded = \(uploaded)")
            print("📤🌊⚖️ UPLOAD: Failed uploads = \(errors.count)")
            if !localOnlyNavUnits.isEmpty {
                print("📤🌊⚖️ UPLOAD: Success rate = \(String(format: "%.1f", Double(uploaded) / Double(localOnlyNavUnits.count) * 100))%")
            }
        }
        
        return (uploaded, errors)
    }
    
    /// Download remote-only nav units to local database
    private func downloadRemoteNavUnits(
        remoteOnlyNavUnits: [RemoteNavUnitFavorite],
        databaseService: NavUnitDatabaseService
    ) async -> (downloaded: Int, errors: [TideSyncError]) {
        
        logQueue.async {
            print("\n📥🌊⚖️ DOWNLOAD IMPLEMENTATION: Starting detailed download process...")
            print("📥🌊⚖️ DOWNLOAD: Remote-only nav unit favorites = \(remoteOnlyNavUnits.count)")
        }
        
        var downloaded = 0
        var errors: [TideSyncError] = []
        
        for (index, remoteFavorite) in remoteOnlyNavUnits.enumerated() {
            logQueue.async {
                print("\n📥🌊⚖️ DOWNLOAD ITEM [\(index + 1)/\(remoteOnlyNavUnits.count)]: Processing nav unit \(remoteFavorite.navUnitId)")
                print("📥🌊⚖️ DOWNLOAD ITEM: Remote details:")
                print("📥🌊⚖️ DOWNLOAD ITEM: - Name: '\(remoteFavorite.navUnitName ?? "nil")'")
                print("📥🌊⚖️ DOWNLOAD ITEM: - Favorite: \(remoteFavorite.isFavorite)")
                print("📥🌊⚖️ DOWNLOAD ITEM: - Last Modified: \(remoteFavorite.lastModified)")
                print("📥🌊⚖️ DOWNLOAD ITEM: - Device: \(remoteFavorite.deviceId)")
            }
            
            do {
                let downloadItemStartTime = Date()
                
                // Set nav unit as favorite in local database
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
        
        logQueue.async {
            print("\n📥🌊⚖️ DOWNLOAD PHASE SUMMARY:")
            print("📥🌊⚖️ DOWNLOAD: Total processed = \(remoteOnlyNavUnits.count)")
            print("📥🌊⚖️ DOWNLOAD: Successfully downloaded = \(downloaded)")
            print("📥🌊⚖️ DOWNLOAD: Failed downloads = \(errors.count)")
            if !remoteOnlyNavUnits.isEmpty {
                print("📥🌊⚖️ DOWNLOAD: Success rate = \(String(format: "%.1f", Double(downloaded) / Double(remoteOnlyNavUnits.count) * 100))%")
            }
        }
        
        return (downloaded, errors)
    }
    
    /// Resolve conflicts using last-write-wins strategy
    private func resolveNavUnitConflicts(
        conflictingNavUnits: Set<String>,
        localFavorites: Set<String>,
        remoteFavorites: [RemoteNavUnitFavorite],
        databaseService: NavUnitDatabaseService
    ) async -> (resolved: Int, errors: [TideSyncError]) {
        
        logQueue.async {
            print("\n🔧🌊⚖️ CONFLICT IMPLEMENTATION: Starting last-write-wins resolution...")
            print("🔧🌊⚖️ CONFLICT: Conflicting nav units = \(conflictingNavUnits)")
            print("🔧🌊⚖️ CONFLICT: Strategy = Last-Write-Wins (newest timestamp wins)")
        }
        
        var resolved = 0
        var errors: [TideSyncError] = []
        
        // Get local last modified timestamps for comparison
        var localLastModifiedMap: [String: Date] = [:]
        do {
            let localFavoritesWithDetails = try await databaseService.getAllNavUnitFavoritesForUser()
            localLastModifiedMap = Dictionary(uniqueKeysWithValues: localFavoritesWithDetails.map { ($0.navUnitId, $0.lastModified) })
        } catch {
            let conflictError = TideSyncError.conflictResolutionFailed("Failed to get local timestamps: \(error.localizedDescription)")
            errors.append(conflictError)
            return (0, [conflictError])
        }
        
        for (index, navUnitId) in conflictingNavUnits.enumerated() {
            logQueue.async {
                print("\n🔧🌊⚖️ CONFLICT ITEM [\(index + 1)/\(conflictingNavUnits.count)]: Resolving \(navUnitId)")
            }
            
            // Get remote record
            guard let remoteRecord = remoteFavorites.first(where: { $0.navUnitId == navUnitId }) else {
                let conflictError = TideSyncError.conflictResolutionFailed("No remote record found for conflicting nav unit \(navUnitId)")
                errors.append(conflictError)
                
                logQueue.async {
                    print("❌🔧🌊⚖️ CONFLICT ITEM FAILED: No remote record for \(navUnitId)")
                }
                continue
            }
            
            // Get local last modified timestamp
            let localLastModified = localLastModifiedMap[navUnitId]
            let remoteLastModified = remoteRecord.lastModified
            
            logQueue.async {
                print("🔧🌊⚖️ CONFLICT ITEM: Timestamp comparison for \(navUnitId):")
                print("🔧🌊⚖️ CONFLICT ITEM: - Local last modified: \(localLastModified?.description ?? "nil")")
                print("🔧🌊⚖️ CONFLICT ITEM: - Remote last modified: \(remoteLastModified)")
                print("🔧🌊⚖️ CONFLICT ITEM: - Local is favorite: \(localFavorites.contains(navUnitId))")
                print("🔧🌊⚖️ CONFLICT ITEM: - Remote is favorite: \(remoteRecord.isFavorite)")
            }
            
            // Last-Write-Wins: Compare timestamps
            let shouldUseRemote: Bool
            if let localTime = localLastModified {
                shouldUseRemote = remoteLastModified > localTime
                
                logQueue.async {
                    if shouldUseRemote {
                        print("🔧🌊⚖️ CONFLICT ITEM: Remote wins (newer timestamp)")
                    } else {
                        print("🔧🌊⚖️ CONFLICT ITEM: Local wins (newer or equal timestamp)")
                    }
                }
            } else {
                // No local timestamp, remote wins
                shouldUseRemote = true
                
                logQueue.async {
                    print("🔧🌊⚖️ CONFLICT ITEM: Remote wins (no local timestamp)")
                }
            }
            
            // Apply the winning state
            if shouldUseRemote {
                // Remote wins - update local to match remote
                do {
                    let conflictStartTime = Date()
                    
                    let success = try await databaseService.setNavUnitFavorite(
                        navUnitId: remoteRecord.navUnitId,
                        isFavorite: remoteRecord.isFavorite,
                        navUnitName: remoteRecord.navUnitName,
                        latitude: remoteRecord.latitude,
                        longitude: remoteRecord.longitude,
                        facilityType: remoteRecord.facilityType
                    )
                    
                    let conflictDuration = Date().timeIntervalSince(conflictStartTime)
                    
                    if success {
                        resolved += 1
                        
                        logQueue.async {
                            print("✅🔧🌊⚖️ CONFLICT ITEM SUCCESS: \(navUnitId) resolved (remote wins)")
                            print("✅🔧🌊⚖️ CONFLICT ITEM: Updated local to favorite=\(remoteRecord.isFavorite)")
                            print("✅🔧🌊⚖️ CONFLICT ITEM: Duration = \(String(format: "%.3f", conflictDuration))s")
                        }
                    } else {
                        let conflictError = TideSyncError.conflictResolutionFailed("Failed to update local nav unit \(navUnitId)")
                        errors.append(conflictError)
                        
                        logQueue.async {
                            print("❌🔧🌊⚖️ CONFLICT ITEM FAILED: \(navUnitId) (database update failed)")
                        }
                    }
                    
                } catch {
                    let conflictError = TideSyncError.conflictResolutionFailed("Error updating nav unit \(navUnitId): \(error.localizedDescription)")
                    errors.append(conflictError)
                    
                    logQueue.async {
                        print("❌🔧🌊⚖️ CONFLICT ITEM FAILED: \(navUnitId)")
                        print("❌🔧🌊⚖️ CONFLICT ITEM ERROR: \(error.localizedDescription)")
                    }
                }
            } else {
                // Local wins - no action needed locally, but we could update remote timestamp
                resolved += 1
                
                logQueue.async {
                    print("✅🔧🌊⚖️ CONFLICT ITEM SUCCESS: \(navUnitId) resolved (local wins, no action needed)")
                }
            }
        }
        
        logQueue.async {
            print("\n🔧🌊⚖️ CONFLICT PHASE SUMMARY:")
            print("🔧🌊⚖️ CONFLICT: Total processed = \(conflictingNavUnits.count)")
            print("🔧🌊⚖️ CONFLICT: Successfully resolved = \(resolved)")
            print("🔧🌊⚖️ CONFLICT: Failed resolutions = \(errors.count)")
            if !conflictingNavUnits.isEmpty {
                print("🔧🌊⚖️ CONFLICT: Success rate = \(String(format: "%.1f", Double(resolved) / Double(conflictingNavUnits.count) * 100))%")
            }
        }
        
        return (resolved, errors)
    }
    
    /// Get remote nav unit favorites from Supabase
    private func getRemoteNavUnitFavorites(userId: UUID) async -> [RemoteNavUnitFavorite] {
        logQueue.async {
            print("\n☁️🌊⚖️ REMOTE FETCH: Starting Supabase query for nav unit favorites...")
            print("☁️🌊⚖️ REMOTE FETCH: User ID = \(userId)")
            print("☁️🌊⚖️ REMOTE FETCH: Table = user_nav_unit_favorites")
        }
        
        do {
            let queryStartTime = Date()
            let response: [RemoteNavUnitFavorite] = try await SupabaseManager.shared
                .from("user_nav_unit_favorites")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            let queryDuration = Date().timeIntervalSince(queryStartTime)
            
            logQueue.async {
                print("\n✅☁️🌊⚖️ REMOTE FETCH SUCCESS: Retrieved \(response.count) nav unit favorites")
                print("✅☁️🌊⚖️ REMOTE FETCH: Duration = \(String(format: "%.3f", queryDuration))s")
                
                if !response.isEmpty {
                    print("✅☁️🌊⚖️ REMOTE FETCH: Sample records:")
                    for (index, record) in response.prefix(3).enumerated() {
                        print("✅☁️🌊⚖️ REMOTE FETCH: [\(index)] ID=\(record.navUnitId), Name='\(record.navUnitName ?? "nil")', Favorite=\(record.isFavorite)")
                    }
                }
            }
            
            return response
        } catch {
            logQueue.async {
                print("\n❌☁️🌊⚖️ REMOTE FETCH ERROR: Query failed")
                print("❌☁️🌊⚖️ REMOTE FETCH ERROR: \(error)")
                print("❌☁️🌊⚖️ REMOTE FETCH ERROR: Type = \(type(of: error))")
                print("❌☁️🌊⚖️ REMOTE FETCH ERROR: Description = \(error.localizedDescription)")
                print("❌☁️🌊⚖️ REMOTE FETCH ERROR: Returning empty array")
            }
            return []
        }
    }
    
    /// Get NavUnitDatabaseService from ServiceProvider (matches TideStationSyncService pattern)
    private func getNavUnitDatabaseService() -> NavUnitDatabaseService? {
        logQueue.async {
            print("\n💾🌊⚖️ SERVICE PROVIDER: Attempting to get NavUnitDatabaseService...")
            print("💾🌊⚖️ SERVICE PROVIDER: Creating ServiceProvider instance")
        }
        
        let serviceProvider = ServiceProvider()
        let service = serviceProvider.navUnitService
        
        logQueue.async {
            if service != nil {
                print("✅💾🌊⚖️ SERVICE PROVIDER: Successfully obtained NavUnitDatabaseService")
            } else {
                print("❌💾🌊⚖️ SERVICE PROVIDER: Failed to obtain NavUnitDatabaseService")
                print("❌💾🌊⚖️ SERVICE PROVIDER: ServiceProvider may not be properly initialized")
            }
        }
        
        return service
    }
    
    // MARK: - Public Utility Methods
    
    /// Check if user is authenticated for sync operations
    func canSync() async -> Bool {
        let operationId = startSyncOperation("authCheck")
        
        logQueue.async {
            print("\n🔐🌊⚖️ AUTH CHECK: Starting authentication verification...")
            print("🔐🌊⚖️ AUTH CHECK: Operation ID = \(operationId)")
        }
        
        do {
            let session = try await SupabaseManager.shared.getSession()
            endSyncOperation(operationId, success: true)
            
            logQueue.async {
                print("✅🔐🌊⚖️ AUTH CHECK SUCCESS: User is authenticated")
                print("✅🔐🌊⚖️ AUTH CHECK: User ID = \(session.user.id)")
                print("✅🔐🌊⚖️ AUTH CHECK: User email = \(session.user.email ?? "NO EMAIL")")
            }
            
            return true
        } catch {
            endSyncOperation(operationId, success: false, error: TideSyncError.authenticationRequired)
            
            logQueue.async {
                print("❌🔐🌊⚖️ AUTH CHECK FAILED: User not authenticated")
                print("❌🔐🌊⚖️ AUTH CHECK FAILED: Error = \(error)")
                print("❌🔐🌊⚖️ AUTH CHECK FAILED: Description = \(error.localizedDescription)")
            }
            
            return false
        }
    }
    
    /// Get current active sync operations (for debugging)
    func getCurrentSyncOperations() -> [String] {
        operationsLock.lock()
        defer { operationsLock.unlock() }
        return Array(activeSyncOperations.keys)
    }
    
    /// Print sync performance statistics
    func printSyncStats() {
        statsLock.lock()
        let stats = operationStats
        statsLock.unlock()
        
        logQueue.async {
            print("\n📊🌊⚖️ NAV UNIT SYNC SERVICE STATISTICS: ========================================")
            print("📊🌊⚖️ STATISTICS TIMESTAMP: \(Date())")
            
            if stats.isEmpty {
                print("📊🌊⚖️ No nav unit sync operations performed yet")
            } else {
                for (operation, stat) in stats.sorted(by: { $0.key < $1.key }) {
                    let avgDuration = stat.totalDuration / Double(stat.totalCalls)
                    let successRate = Double(stat.successCount) / Double(stat.totalCalls) * 100
                    
                    print("📊🌊⚖️ Operation: \(operation)")
                    print("📊🌊⚖️ - Total calls: \(stat.totalCalls)")
                    print("📊🌊⚖️ - Successes: \(stat.successCount)")
                    print("📊🌊⚖️ - Failures: \(stat.failureCount)")
                    print("📊🌊⚖️ - Success rate: \(String(format: "%.1f", successRate))%")
                    print("📊🌊⚖️ - Average duration: \(String(format: "%.3f", avgDuration))s")
                    print("📊🌊⚖️ - Min duration: \(String(format: "%.3f", stat.minDuration))s")
                    print("📊🌊⚖️ - Max duration: \(String(format: "%.3f", stat.maxDuration))s")
                    print("📊🌊⚖️ - Last execution: \(stat.lastExecution)")
                    print("📊🌊⚖️")
                }
            }
            print("📊🌊⚖️ NAV UNIT SYNC SERVICE STATISTICS: ========================================\n")
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
            print("\n🟢🌊⚖️ OPERATION START: ============================================")
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
            
            print("🟢🌊⚖️ OPERATION START: ============================================")
        }
        
        return operationId
    }
    
    private func endSyncOperation(_ operationId: String, success: Bool, error: TideSyncError? = nil) {
        operationsLock.lock()
        let startTime = activeSyncOperations.removeValue(forKey: operationId)
        operationsLock.unlock()
        
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0.0
        
        logQueue.async {
            if success {
                print("\n✅🌊⚖️ OPERATION SUCCESS: \(operationId)")
                print("✅🌊⚖️ DURATION: \(String(format: "%.3f", duration))s")
                print("✅🌊⚖️ REMAINING ACTIVE: \(self.activeSyncOperations.count)")
                if !self.activeSyncOperations.isEmpty {
                    print("⚠️🌊⚖️ STILL RUNNING: \(Array(self.activeSyncOperations.keys))")
                }
            } else {
                print("\n❌🌊⚖️ OPERATION FAILED: \(operationId)")
                print("❌🌊⚖️ DURATION: \(String(format: "%.3f", duration))s")
                if let error = error {
                    print("❌🌊⚖️ ERROR: \(error)")
                    print("❌🌊⚖️ ERROR TYPE: \(type(of: error))")
                    print("❌🌊⚖️ ERROR DESCRIPTION: \(error.localizedDescription)")
                }
                print("❌🌊⚖️ REMAINING ACTIVE: \(self.activeSyncOperations.count)")
            }
        }
    }
    
    private func updateOperationStats(_ operationType: String, success: Bool, duration: TimeInterval) {
        statsLock.lock()
        defer { statsLock.unlock() }
        
        if var existingStats = operationStats[operationType] {
            existingStats.totalCalls += 1
            existingStats.successCount += success ? 1 : 0
            existingStats.failureCount += success ? 0 : 1
            existingStats.totalDuration += duration
            existingStats.minDuration = min(existingStats.minDuration, duration)
            existingStats.maxDuration = max(existingStats.maxDuration, duration)
            existingStats.lastExecution = Date()
            operationStats[operationType] = existingStats
        } else {
            operationStats[operationType] = TideSyncOperationStats(
                totalCalls: 1,
                successCount: success ? 1 : 0,
                failureCount: success ? 0 : 1,
                totalDuration: duration,
                minDuration: duration,
                maxDuration: duration,
                lastExecution: Date()
            )
        }
        
        logQueue.async {
            if let stats = self.operationStats[operationType] {
                let avgDuration = stats.totalDuration / Double(stats.totalCalls)
                let successRate = Double(stats.successCount) / Double(stats.totalCalls) * 100
                print("📊🌊⚖️ STATS UPDATE: \(operationType) now has \(stats.totalCalls) calls, \(String(format: "%.1f", successRate))% success, \(String(format: "%.3f", avgDuration))s avg")
            }
        }
    }
}
