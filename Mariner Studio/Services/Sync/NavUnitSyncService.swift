////
////  NavUnitSyncService.swift
////  Mariner Studio
////
////  Navigation Unit Favorites Synchronization Service
////  Handles bidirectional sync between local SQLite database and Supabase cloud storage
////  Implements last-write-wins conflict resolution using timestamp comparison
////  Uses dependency injection pattern for better testability and architectural consistency
////
//
//import Foundation
//import UIKit
//import Supabase
//
///// Service responsible for synchronizing navigation unit favorites between local and remote storage
///// Follows dependency injection pattern consistent with the app's architecture
///// Provides comprehensive logging and error handling for all sync operations
//class NavUnitSyncService: ObservableObject {
//    
//    // MARK: - Injected Dependencies
//    /// Local database service for nav unit operations - injected via constructor
//    private let navUnitService: NavUnitDatabaseService
//    
//    /// Supabase manager for remote operations - injected via constructor
//    private let supabaseManager: SupabaseManager
//    
//    // MARK: - Instance Properties
//    /// Flag to prevent concurrent sync operations on this instance - critical for data integrity
//    @Published var isSyncing = false
//    
//    /// Sync operation tracking for debugging race conditions
//    private var activeOperations: Set<String> = []
//    
//    /// Performance metrics for monitoring sync efficiency
//    private var syncStats = SyncStats()
//    
//    // MARK: - Sync Statistics Tracking
//    /// Internal structure to track sync performance and operation counts
//    private struct SyncStats {
//        var totalSyncs: Int = 0
//        var successfulSyncs: Int = 0
//        var failedSyncs: Int = 0
//        var averageDuration: TimeInterval = 0.0
//        var lastSyncTime: Date?
//        
//        /// Update statistics after a sync operation completes
//        mutating func recordSync(duration: TimeInterval, success: Bool) {
//            totalSyncs += 1
//            if success {
//                successfulSyncs += 1
//            } else {
//                failedSyncs += 1
//            }
//            
//            // Calculate rolling average duration
//            averageDuration = ((averageDuration * Double(totalSyncs - 1)) + duration) / Double(totalSyncs)
//            lastSyncTime = Date()
//        }
//    }
//    
//    // MARK: - Dependency Injection Initialization
//    /// Initializes the sync service with required dependencies
//    /// - Parameters:
//    ///   - navUnitService: Local database service for nav unit operations
//    ///   - supabaseManager: Remote database service for cloud operations
//    init(navUnitService: NavUnitDatabaseService, supabaseManager: SupabaseManager = SupabaseManager.shared) {
//        self.navUnitService = navUnitService
//        self.supabaseManager = supabaseManager
//        
//        print("🟢🧭 NAV_UNIT_SYNC: Service initialized with dependency injection")
//        print("🟢🧭 NAV_UNIT_SYNC: Dependencies injected:")
//        print("   - NavUnitService: \(type(of: navUnitService))")
//        print("   - SupabaseManager: \(type(of: supabaseManager))")
//    }
//    
//    // MARK: - Public Sync Interface
//    
//    /// Performs a full bidirectional sync of navigation unit favorites
//    /// This is the main entry point for manual sync operations triggered by the user
//    /// - Returns: Success/failure status - errors are logged but not thrown to UI
//    @MainActor
//    func performFullSync() async -> Bool {
//        // Generate unique operation ID for tracking this specific sync operation
//        let operationId = "nav_unit_full_sync_\(UUID().uuidString.prefix(8))"
//        let startTime = Date()
//        
//        print("🟢🧭 NAV_UNIT_SYNC_START: ===================================================")
//        print("🟢🧭 OPERATION_ID: \(operationId)")
//        print("🟢🧭 START_TIME: \(startTime)")
//        
//        // STEP 1: Prevent Concurrent Operations
//        // Check if another sync is already running on this instance to prevent data corruption
//        guard !isSyncing else {
//            print("⚠️🧭 CONCURRENT_SYNC_BLOCKED: Another sync operation is already in progress on this instance")
//            print("⚠️🧭 ACTIVE_OPERATIONS: \(activeOperations)")
//            return false
//        }
//        
//        // Mark sync as active and track the operation
//        isSyncing = true
//        activeOperations.insert(operationId)
//        
//        print("🔒🧭 SYNC_LOCK_ACQUIRED: Operation \(operationId) now has exclusive access")
//        print("📊🧭 ACTIVE_OPERATIONS_COUNT: \(activeOperations.count)")
//        
//        // STEP 2: Authentication Verification
//        // Ensure user is authenticated before attempting any remote operations
//        print("🔐🧭 AUTH_CHECK: Starting authentication verification...")
//        guard let session = await verifyAuthentication() else {
//            // Authentication failed - clean up and exit
//            await cleanupSyncOperation(operationId: operationId, startTime: startTime, success: false)
//            return false
//        }
//        
//        let userId = session.user.id
//        print("✅🔐🧭 AUTH_SUCCESS: User \(userId) authenticated successfully")
//        
//        // STEP 3: Local Data Retrieval
//        // Get all current local favorites with their sync metadata
//        print("📱🧭 LOCAL_DATA: Starting local favorites retrieval...")
//        guard let localFavorites = await getLocalFavorites() else {
//            // Local data retrieval failed - clean up and exit
//            await cleanupSyncOperation(operationId: operationId, startTime: startTime, success: false)
//            return false
//        }
//        
//        print("✅📱🧭 LOCAL_DATA_SUCCESS: Retrieved \(localFavorites.count) local favorites")
//        
//        // STEP 4: Remote Data Retrieval
//        // Fetch all user's nav unit favorites from Supabase
//        print("☁️🧭 REMOTE_DATA: Starting remote favorites retrieval...")
//        guard let remoteFavorites = await getRemoteFavorites(userId: userId) else {
//            // Remote data retrieval failed - clean up and exit
//            await cleanupSyncOperation(operationId: operationId, startTime: startTime, success: false)
//            return false
//        }
//        
//        print("✅☁️🧭 REMOTE_DATA_SUCCESS: Retrieved \(remoteFavorites.count) remote favorites")
//        
//        // STEP 5: Data Analysis and Sync Planning
//        // Compare local and remote data to determine what operations are needed
//        print("🔍🧭 ANALYSIS: Starting data comparison and sync planning...")
//        let syncPlan = analyzeSyncRequirements(local: localFavorites, remote: remoteFavorites)
//        
//        print("✅🔍🧭 ANALYSIS_COMPLETE:")
//        print("📤🧭 UPLOAD_NEEDED: \(syncPlan.toUpload.count) nav units")
//        print("📥🧭 DOWNLOAD_NEEDED: \(syncPlan.toDownload.count) nav units")
//        print("🔧🧭 CONFLICTS_TO_RESOLVE: \(syncPlan.conflicts.count) nav units")
//        
//        // STEP 6: Execute Sync Operations
//        var syncSuccess = true
//        
//        // Upload local-only favorites to remote
//        if !syncPlan.toUpload.isEmpty {
//            print("📤🧭 UPLOAD_PHASE: Starting upload of \(syncPlan.toUpload.count) nav units...")
//            let uploadSuccess = await uploadFavorites(syncPlan.toUpload, userId: userId)
//            if !uploadSuccess {
//                print("❌📤🧭 UPLOAD_FAILED: One or more uploads failed")
//                syncSuccess = false
//            } else {
//                print("✅📤🧭 UPLOAD_SUCCESS: All uploads completed successfully")
//            }
//        }
//        
//        // Download remote-only favorites to local
//        if !syncPlan.toDownload.isEmpty {
//            print("📥🧭 DOWNLOAD_PHASE: Starting download of \(syncPlan.toDownload.count) nav units...")
//            let downloadSuccess = await downloadFavorites(syncPlan.toDownload)
//            if !downloadSuccess {
//                print("❌📥🧭 DOWNLOAD_FAILED: One or more downloads failed")
//                syncSuccess = false
//            } else {
//                print("✅📥🧭 DOWNLOAD_SUCCESS: All downloads completed successfully")
//            }
//        }
//        
//        // Resolve conflicts using last-write-wins strategy
//        if !syncPlan.conflicts.isEmpty {
//            print("🔧🧭 CONFLICT_RESOLUTION: Starting resolution of \(syncPlan.conflicts.count) conflicts...")
//            let conflictSuccess = await resolveConflicts(syncPlan.conflicts)
//            if !conflictSuccess {
//                print("❌🔧🧭 CONFLICT_RESOLUTION_FAILED: One or more conflicts could not be resolved")
//                syncSuccess = false
//            } else {
//                print("✅🔧🧭 CONFLICT_RESOLUTION_SUCCESS: All conflicts resolved successfully")
//            }
//        }
//        
//        // STEP 7: Cleanup and Results
//        await cleanupSyncOperation(operationId: operationId, startTime: startTime, success: syncSuccess)
//        
//        return syncSuccess
//    }
//    
//    // MARK: - Authentication Management
//    
//    /// Verifies that the user is authenticated and has a valid session
//    /// Uses the injected SupabaseManager for authentication operations
//    /// - Returns: Valid session or nil if authentication fails
//    private func verifyAuthentication() async -> Session? {
//        do {
//            print("🔐🧭 AUTH_ATTEMPT: Requesting current session from injected SupabaseManager...")
//            let session = try await supabaseManager.getSession()
//            
//            print("✅🔐🧭 AUTH_SESSION_VALID:")
//            print("   User ID: \(session.user.id)")
//            print("   Email: \(session.user.email ?? "unknown")")
//            print("   Session expires: \(Date(timeIntervalSince1970: TimeInterval(session.expiresAt)))")
//            
//            return session
//        } catch {
//            print("❌🔐🧭 AUTH_FAILED: \(error.localizedDescription)")
//            print("❌🔐🧭 AUTH_ERROR_TYPE: \(type(of: error))")
//            return nil
//        }
//    }
//    
//    // MARK: - Local Data Operations
//    
//    /// Retrieves all navigation unit favorites from the local SQLite database
//    /// Uses the injected NavUnitDatabaseService for local operations
//    /// Includes sync metadata (user_id, device_id, last_modified) for comparison
//    /// - Returns: Array of local favorites or nil if retrieval fails
//    private func getLocalFavorites() async -> [RemoteNavUnitFavorite]? {
//        do {
//            print("📱🧭 LOCAL_QUERY: Executing getFavoriteNavUnitsAsync() on injected service...")
//            
//            // Get only favorited nav units with their complete data
//            // This method queries the database with WHERE isFavorite = true for efficiency
//            let localNavUnits = try await navUnitService.getFavoriteNavUnitsAsync()
//            
//            print("📱🧭 LOCAL_RAW_COUNT: Retrieved \(localNavUnits.count) favorite nav units from database")
//            
//            // Convert local nav units to RemoteNavUnitFavorite format for comparison
//            var remoteFavorites: [RemoteNavUnitFavorite] = []
//            
//            for navUnit in localNavUnits {
//                // Extract sync metadata that should be stored in the local database
//                // These fields are set when the user toggles favorites
//                guard let userIdString = navUnit.userId,
//                      let userId = UUID(uuidString: userIdString) else {
//                    print("⚠️📱🧭 LOCAL_SKIP: Nav unit \(navUnit.navUnitId) missing user_id, skipping...")
//                    continue
//                }
//                
//                let deviceId = navUnit.deviceId ?? UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
//                let lastModified = navUnit.lastModified ?? Date()
//                
//                // Create RemoteNavUnitFavorite from local data
//                let remoteFavorite = RemoteNavUnitFavorite(
//                    userId: userId,
//                    navUnitId: navUnit.navUnitId,
//                    isFavorite: navUnit.isFavorite,
//                    deviceId: deviceId,
//                    navUnitName: navUnit.navUnitName,
//                    latitude: navUnit.latitude,
//                    longitude: navUnit.longitude,
//                    facilityType: navUnit.facilityType
//                )
//                
//                remoteFavorites.append(remoteFavorite)
//                
//                print("📱🧭 LOCAL_FAVORITE_MAPPED:")
//                print("   Nav Unit: \(navUnit.navUnitId) - \(navUnit.navUnitName)")
//                print("   User ID: \(userId)")
//                print("   Is Favorite: \(navUnit.isFavorite)")
//                print("   Last Modified: \(lastModified)")
//                print("   Device ID: \(deviceId)")
//            }
//            
//            print("✅📱🧭 LOCAL_CONVERSION_SUCCESS: Converted \(remoteFavorites.count) nav units to sync format")
//            return remoteFavorites
//            
//        } catch {
//            print("❌📱🧭 LOCAL_ERROR: Failed to retrieve local favorites")
//            print("❌📱🧭 LOCAL_ERROR_DETAILS: \(error.localizedDescription)")
//            print("❌📱🧭 LOCAL_ERROR_TYPE: \(type(of: error))")
//            return nil
//        }
//    }
//    
//    // MARK: - Remote Data Operations
//    
//    /// Retrieves all navigation unit favorites for the specified user from Supabase
//    /// Uses the injected SupabaseManager for remote operations
//    /// - Parameter userId: The authenticated user's unique identifier
//    /// - Returns: Array of remote favorites or nil if retrieval fails
//    private func getRemoteFavorites(userId: UUID) async -> [RemoteNavUnitFavorite]? {
//        do {
//            print("☁️🧭 REMOTE_QUERY: Requesting nav unit favorites for user \(userId) via injected SupabaseManager...")
//            
//            // Call injected SupabaseManager to fetch all nav unit favorites for this user
//            // TODO: This method needs to be implemented in Phase 2 - SupabaseManager enhancement
//            // For now this will cause a compilation error that will be fixed in Phase 2
//            let remoteFavorites = try await supabaseManager.getNavUnitFavorites(userId: userId)
//            
//            print("✅☁️🧭 REMOTE_SUCCESS: Retrieved \(remoteFavorites.count) favorites from Supabase")
//            
//            // Log details of each remote favorite for debugging
//            for (index, favorite) in remoteFavorites.enumerated() {
//                print("☁️🧭 REMOTE_FAVORITE_\(index + 1):")
//                print("   ID: \(favorite.id?.uuidString ?? "nil")")
//                print("   Nav Unit: \(favorite.navUnitId)")
//                print("   Name: \(favorite.navUnitName ?? "unknown")")
//                print("   Is Favorite: \(favorite.isFavorite)")
//                print("   Last Modified: \(favorite.lastModified)")
//                print("   Device ID: \(favorite.deviceId)")
//            }
//            
//            return remoteFavorites
//            
//        } catch {
//            print("❌☁️🧭 REMOTE_ERROR: Failed to retrieve remote favorites")
//            print("❌☁️🧭 REMOTE_ERROR_DETAILS: \(error.localizedDescription)")
//            print("❌☁️🧭 REMOTE_ERROR_TYPE: \(type(of: error))")
//            return nil
//        }
//    }
//    
//    // MARK: - Sync Analysis
//    
//    /// Structure to hold the results of sync analysis
//    /// Determines what operations are needed to achieve data consistency
//    private struct SyncPlan {
//        let toUpload: [RemoteNavUnitFavorite]    // Local favorites not found remotely
//        let toDownload: [RemoteNavUnitFavorite]  // Remote favorites not found locally
//        let conflicts: [ConflictResolution]      // Nav units with different states that need resolution
//    }
//    
//    /// Structure to hold conflict resolution data
//    /// Contains both local and remote versions for timestamp comparison
//    private struct ConflictResolution {
//        let navUnitId: String
//        let localFavorite: RemoteNavUnitFavorite
//        let remoteFavorite: RemoteNavUnitFavorite
//        let winningFavorite: RemoteNavUnitFavorite  // The one with the latest timestamp
//        let resolution: String  // Human-readable description of what will happen
//    }
//    
//    /// Analyzes local and remote data to determine sync operations needed
//    /// Implements last-write-wins strategy for conflict resolution
//    /// - Parameters:
//    ///   - local: Array of local favorites in remote format
//    ///   - remote: Array of actual remote favorites
//    /// - Returns: SyncPlan containing all required operations
//    private func analyzeSyncRequirements(
//        local: [RemoteNavUnitFavorite],
//        remote: [RemoteNavUnitFavorite]
//    ) -> SyncPlan {
//        
//        print("🔍🧭 ANALYSIS_START: Comparing \(local.count) local vs \(remote.count) remote favorites")
//        
//        // Create lookup dictionaries for efficient comparison
//        let localByNavUnitId = Dictionary(uniqueKeysWithValues: local.map { ($0.navUnitId, $0) })
//        let remoteByNavUnitId = Dictionary(uniqueKeysWithValues: remote.map { ($0.navUnitId, $0) })
//        
//        print("🔍🧭 ANALYSIS_LOOKUP: Created lookup dictionaries")
//        print("   Local nav units: \(localByNavUnitId.keys.sorted())")
//        print("   Remote nav units: \(remoteByNavUnitId.keys.sorted())")
//        
//        // Find items that need to be uploaded (exist locally but not remotely)
//        var toUpload: [RemoteNavUnitFavorite] = []
//        for localFavorite in local {
//            if remoteByNavUnitId[localFavorite.navUnitId] == nil {
//                toUpload.append(localFavorite)
//                print("📤🧭 UPLOAD_IDENTIFIED: \(localFavorite.navUnitId) - \(localFavorite.navUnitName ?? "unknown")")
//            }
//        }
//        
//        // Find items that need to be downloaded (exist remotely but not locally)
//        var toDownload: [RemoteNavUnitFavorite] = []
//        for remoteFavorite in remote {
//            if localByNavUnitId[remoteFavorite.navUnitId] == nil {
//                toDownload.append(remoteFavorite)
//                print("📥🧭 DOWNLOAD_IDENTIFIED: \(remoteFavorite.navUnitId) - \(remoteFavorite.navUnitName ?? "unknown")")
//            }
//        }
//        
//        // Find conflicts (exist in both but with different states or timestamps)
//        var conflicts: [ConflictResolution] = []
//        for localFavorite in local {
//            if let remoteFavorite = remoteByNavUnitId[localFavorite.navUnitId] {
//                // Both exist - check if they're different
//                let statesMatch = localFavorite.isFavorite == remoteFavorite.isFavorite
//                
//                if !statesMatch {
//                    // States don't match - determine winner using last-write-wins
//                    let localWins = localFavorite.lastModified > remoteFavorite.lastModified
//                    let winningFavorite = localWins ? localFavorite : remoteFavorite
//                    let losingFavorite = localWins ? remoteFavorite : localFavorite
//                    
//                    let resolution = localWins ?
//                        "Local state (\(localFavorite.isFavorite)) wins over remote state (\(remoteFavorite.isFavorite))" :
//                        "Remote state (\(remoteFavorite.isFavorite)) wins over local state (\(localFavorite.isFavorite))"
//                    
//                    let conflict = ConflictResolution(
//                        navUnitId: localFavorite.navUnitId,
//                        localFavorite: localFavorite,
//                        remoteFavorite: remoteFavorite,
//                        winningFavorite: winningFavorite,
//                        resolution: resolution
//                    )
//                    
//                    conflicts.append(conflict)
//                    
//                    print("🔧🧭 CONFLICT_IDENTIFIED: \(localFavorite.navUnitId)")
//                    print("   Local: favorite=\(localFavorite.isFavorite), modified=\(localFavorite.lastModified)")
//                    print("   Remote: favorite=\(remoteFavorite.isFavorite), modified=\(remoteFavorite.lastModified)")
//                    print("   Winner: \(localWins ? "LOCAL" : "REMOTE") - \(resolution)")
//                }
//            }
//        }
//        
//        let syncPlan = SyncPlan(toUpload: toUpload, toDownload: toDownload, conflicts: conflicts)
//        
//        print("✅🔍🧭 ANALYSIS_COMPLETE:")
//        print("   Upload operations: \(toUpload.count)")
//        print("   Download operations: \(toDownload.count)")
//        print("   Conflict resolutions: \(conflicts.count)")
//        print("   Total operations planned: \(toUpload.count + toDownload.count + conflicts.count)")
//        
//        return syncPlan
//    }
//    
//    // MARK: - Upload Operations
//    
//    /// Uploads local favorites that don't exist remotely to Supabase
//    /// Uses the injected SupabaseManager for remote operations
//    /// - Parameters:
//    ///   - favorites: Array of local favorites to upload
//    ///   - userId: The authenticated user's ID
//    /// - Returns: Success status of all upload operations
//    private func uploadFavorites(_ favorites: [RemoteNavUnitFavorite], userId: UUID) async -> Bool {
//        print("📤🧭 UPLOAD_START: Beginning upload of \(favorites.count) favorites via injected SupabaseManager...")
//        
//        var successCount = 0
//        var failureCount = 0
//        
//        for (index, favorite) in favorites.enumerated() {
//            print("📤🧭 UPLOAD_ITEM_\(index + 1): Processing \(favorite.navUnitId)...")
//            
//            do {
//                // Upload this favorite to Supabase using injected manager
//                // TODO: This method needs to be implemented in Phase 2 - SupabaseManager enhancement
//                // For now this will cause a compilation error that will be fixed in Phase 2
//                try await supabaseManager.upsertNavUnitFavorite(favorite)
//                
//                successCount += 1
//                print("✅📤🧭 UPLOAD_SUCCESS_\(index + 1): \(favorite.navUnitId) uploaded successfully")
//                
//            } catch {
//                failureCount += 1
//                print("❌📤🧭 UPLOAD_FAILED_\(index + 1): \(favorite.navUnitId) upload failed")
//                print("❌📤🧭 UPLOAD_ERROR_DETAILS: \(error.localizedDescription)")
//            }
//        }
//        
//        let allSucceeded = failureCount == 0
//        print("🏁📤🧭 UPLOAD_COMPLETE: \(successCount) succeeded, \(failureCount) failed")
//        
//        return allSucceeded
//    }
//    
//    // MARK: - Download Operations
//    
//    /// Downloads remote favorites that don't exist locally and updates the local database
//    /// Uses the injected NavUnitDatabaseService for local operations
//    /// - Parameter favorites: Array of remote favorites to download
//    /// - Returns: Success status of all download operations
//    private func downloadFavorites(_ favorites: [RemoteNavUnitFavorite]) async -> Bool {
//        print("📥🧭 DOWNLOAD_START: Beginning download of \(favorites.count) favorites via injected NavUnitService...")
//        
//        var successCount = 0
//        var failureCount = 0
//        
//        for (index, favorite) in favorites.enumerated() {
//            print("📥🧭 DOWNLOAD_ITEM_\(index + 1): Processing \(favorite.navUnitId)...")
//            
//            do {
//                // Update local database with remote favorite data using injected service
//                // TODO: This method needs to be implemented in Phase 3 - NavUnitDatabaseService enhancement
//                // For now this will cause a compilation error that will be fixed in Phase 3
//                try await navUnitService.setNavUnitFavoriteWithSyncData(
//                    navUnitId: favorite.navUnitId,
//                    isFavorite: favorite.isFavorite,
//                    userId: favorite.userId.uuidString,
//                    deviceId: favorite.deviceId,
//                    lastModified: favorite.lastModified
//                )
//                
//                successCount += 1
//                print("✅📥🧭 DOWNLOAD_SUCCESS_\(index + 1): \(favorite.navUnitId) downloaded successfully")
//                
//            } catch {
//                failureCount += 1
//                print("❌📥🧭 DOWNLOAD_FAILED_\(index + 1): \(favorite.navUnitId) download failed")
//                print("❌📥🧭 DOWNLOAD_ERROR_DETAILS: \(error.localizedDescription)")
//            }
//        }
//        
//        let allSucceeded = failureCount == 0
//        print("🏁📥🧭 DOWNLOAD_COMPLETE: \(successCount) succeeded, \(failureCount) failed")
//        
//        return allSucceeded
//    }
//    
//    // MARK: - Conflict Resolution
//    
//    /// Resolves conflicts using last-write-wins strategy
//    /// Updates both local and remote data to match the winning version
//    /// Uses both injected services for local and remote operations
//    /// - Parameter conflicts: Array of conflicts that need resolution
//    /// - Returns: Success status of all conflict resolution operations
//    private func resolveConflicts(_ conflicts: [ConflictResolution]) async -> Bool {
//        print("🔧🧭 CONFLICT_START: Beginning resolution of \(conflicts.count) conflicts using injected services...")
//        
//        var successCount = 0
//        var failureCount = 0
//        
//        for (index, conflict) in conflicts.enumerated() {
//            print("🔧🧭 CONFLICT_ITEM_\(index + 1): Resolving \(conflict.navUnitId)...")
//            print("   Resolution: \(conflict.resolution)")
//            
//            do {
//                let winningFavorite = conflict.winningFavorite
//                
//                // Always update local database to match the winning version using injected service
//                // TODO: This method needs to be implemented in Phase 3 - NavUnitDatabaseService enhancement
//                // For now this will cause a compilation error that will be fixed in Phase 3
//                try await navUnitService.setNavUnitFavoriteWithSyncData(
//                    navUnitId: winningFavorite.navUnitId,
//                    isFavorite: winningFavorite.isFavorite,
//                    userId: winningFavorite.userId.uuidString,
//                    deviceId: winningFavorite.deviceId,
//                    lastModified: winningFavorite.lastModified
//                )
//                
//                // If local version won, also update remote to ensure consistency using injected manager
//                // TODO: This method needs to be implemented in Phase 2 - SupabaseManager enhancement
//                if winningFavorite.lastModified == conflict.localFavorite.lastModified {
//                    try await supabaseManager.upsertNavUnitFavorite(winningFavorite)
//                    print("🔧🧭 CONFLICT_REMOTE_UPDATE: Updated remote to match local winner")
//                }
//                
//                successCount += 1
//                print("✅🔧🧭 CONFLICT_SUCCESS_\(index + 1): \(conflict.navUnitId) resolved successfully")
//                
//            } catch {
//                failureCount += 1
//                print("❌🔧🧭 CONFLICT_FAILED_\(index + 1): \(conflict.navUnitId) resolution failed")
//                print("❌🔧🧭 CONFLICT_ERROR_DETAILS: \(error.localizedDescription)")
//            }
//        }
//        
//        let allSucceeded = failureCount == 0
//        print("🏁🔧🧭 CONFLICT_COMPLETE: \(successCount) succeeded, \(failureCount) failed")
//        
//        return allSucceeded
//    }
//    
//    // MARK: - Cleanup and Statistics
//    
//    /// Cleans up after a sync operation and records performance statistics
//    /// - Parameters:
//    ///   - operationId: Unique identifier for this sync operation
//    ///   - startTime: When the operation began
//    ///   - success: Whether the operation completed successfully
//    private func cleanupSyncOperation(operationId: String, startTime: Date, success: Bool) async {
//        let endTime = Date()
//        let duration = endTime.timeIntervalSince(startTime)
//        
//        // Remove this operation from active tracking
//        activeOperations.remove(operationId)
//        
//        // Release the sync lock for this instance
//        await MainActor.run {
//            isSyncing = false
//        }
//        
//        // Update performance statistics
//        syncStats.recordSync(duration: duration, success: success)
//        
//        // Log final results
//        if success {
//            print("✅🧭 SYNC_SUCCESS: Operation \(operationId) completed successfully")
//        } else {
//            print("❌🧭 SYNC_FAILED: Operation \(operationId) completed with errors")
//        }
//        
//        print("🏁🧭 SYNC_COMPLETE:")
//        print("   Operation ID: \(operationId)")
//        print("   Duration: \(String(format: "%.3f", duration))s")
//        print("   Success: \(success)")
//        print("   Active operations: \(activeOperations.count)")
//        
//        print("📊🧭 SYNC_STATS:")
//        print("   Total syncs: \(syncStats.totalSyncs)")
//        print("   Successful: \(syncStats.successfulSyncs)")
//        print("   Failed: \(syncStats.failedSyncs)")
//        print("   Average duration: \(String(format: "%.3f", syncStats.averageDuration))s")
//        print("   Last sync: \(syncStats.lastSyncTime?.description ?? "never")")
//        
//        print("🟢🧭 NAV_UNIT_SYNC_END: =====================================================")
//    }
//    
//    // MARK: - Public Utility Methods
//    
//    /// Returns current sync statistics for monitoring and debugging
//    /// - Returns: Dictionary containing sync performance metrics
//    func getSyncStats() -> [String: Any] {
//        return [
//            "totalSyncs": syncStats.totalSyncs,
//            "successfulSyncs": syncStats.successfulSyncs,
//            "failedSyncs": syncStats.failedSyncs,
//            "averageDuration": syncStats.averageDuration,
//            "lastSyncTime": syncStats.lastSyncTime?.description ?? "never",
//            "isSyncing": isSyncing,
//            "activeOperations": Array(activeOperations)
//        ]
//    }
//    
//    /// Prints current sync statistics to the debug console
//    func printSyncStats() {
//        print("📊🧭 NAV_UNIT_SYNC_STATISTICS:")
//        let stats = getSyncStats()
//        for (key, value) in stats {
//            print("   \(key): \(value)")
//        }
//    }
//}









//
//  NavUnitSyncService.swift
//  Mariner Studio
//
//  Navigation Unit Favorites Synchronization Service
//  Handles bidirectional sync between local SQLite database and Supabase cloud storage
//  Implements last-write-wins conflict resolution using timestamp comparison
//  Uses dependency injection pattern for better testability and architectural consistency
//

import Foundation
import UIKit
import Supabase

/// Service responsible for synchronizing navigation unit favorites between local and remote storage
/// Follows dependency injection pattern consistent with the app's architecture
/// Provides comprehensive logging and error handling for all sync operations
class NavUnitSyncService: ObservableObject {
    
    // MARK: - Injected Dependencies
    /// Local database service for nav unit operations - injected via constructor
    private let navUnitService: NavUnitDatabaseService
    
    /// Supabase manager for remote operations - injected via constructor
    private let supabaseManager: SupabaseManager
    
    // MARK: - Instance Properties
    /// Flag to prevent concurrent sync operations on this instance - critical for data integrity
    @Published var isSyncing = false
    
    /// Sync operation tracking for debugging race conditions
    private var activeOperations: Set<String> = []
    
    /// Performance metrics for monitoring sync efficiency
    private var syncStats = SyncStats()
    
    // MARK: - Sync Statistics Tracking
    /// Internal structure to track sync performance and operation counts
    private struct SyncStats {
        var totalSyncs: Int = 0
        var successfulSyncs: Int = 0
        var failedSyncs: Int = 0
        var averageDuration: TimeInterval = 0.0
        var lastSyncTime: Date?
        
        /// Update statistics after a sync operation completes
        mutating func recordSync(duration: TimeInterval, success: Bool) {
            totalSyncs += 1
            if success {
                successfulSyncs += 1
            } else {
                failedSyncs += 1
            }
            
            // Calculate rolling average duration
            averageDuration = ((averageDuration * Double(totalSyncs - 1)) + duration) / Double(totalSyncs)
            lastSyncTime = Date()
        }
    }
    
    // MARK: - Dependency Injection Initialization
    /// Initializes the sync service with required dependencies
    /// - Parameters:
    ///   - navUnitService: Local database service for nav unit operations
    ///   - supabaseManager: Remote database service for cloud operations
    init(navUnitService: NavUnitDatabaseService, supabaseManager: SupabaseManager = SupabaseManager.shared) {
        self.navUnitService = navUnitService
        self.supabaseManager = supabaseManager
        
        print("🟢🧭 NAV_UNIT_SYNC: Service initialized with dependency injection")
        print("🟢🧭 NAV_UNIT_SYNC: Dependencies injected:")
        print("   - NavUnitService: \(type(of: navUnitService))")
        print("   - SupabaseManager: \(type(of: supabaseManager))")
    }
    
    // MARK: - Public Sync Interface
    
    /// Performs a full bidirectional sync of navigation unit favorites
    /// This is the main entry point for manual sync operations triggered by the user
    /// - Returns: Success/failure status - errors are logged but not thrown to UI
    @MainActor
    func performFullSync() async -> Bool {
        // Generate unique operation ID for tracking this specific sync operation
        let operationId = "nav_unit_full_sync_\(UUID().uuidString.prefix(8))"
        let startTime = Date()
        
        print("🟢🧭 NAV_UNIT_SYNC_START: ===================================================")
        print("🟢🧭 OPERATION_ID: \(operationId)")
        print("🟢🧭 START_TIME: \(startTime)")
        
        // STEP 1: Prevent Concurrent Operations
        // Check if another sync is already running on this instance to prevent data corruption
        guard !isSyncing else {
            print("⚠️🧭 CONCURRENT_SYNC_BLOCKED: Another sync operation is already in progress on this instance")
            print("⚠️🧭 ACTIVE_OPERATIONS: \(activeOperations)")
            return false
        }
        
        // Mark sync as active and track the operation
        isSyncing = true
        activeOperations.insert(operationId)
        
        print("🔒🧭 SYNC_LOCK_ACQUIRED: Operation \(operationId) now has exclusive access")
        print("📊🧭 ACTIVE_OPERATIONS_COUNT: \(activeOperations.count)")
        
        // STEP 2: Authentication Verification
        // Ensure user is authenticated before attempting any remote operations
        print("🔐🧭 AUTH_CHECK: Starting authentication verification...")
        guard let session = await verifyAuthentication() else {
            // Authentication failed - clean up and exit
            await cleanupSyncOperation(operationId: operationId, startTime: startTime, success: false)
            return false
        }
        
        let userId = session.user.id
        print("✅🔐🧭 AUTH_SUCCESS: User \(userId) authenticated successfully")
        
        // STEP 3: Local Data Retrieval
        // Get all current local favorites with their sync metadata
        print("📱🧭 LOCAL_DATA: Starting local favorites retrieval...")
        guard let localFavorites = await getLocalFavorites() else {
            // Local data retrieval failed - clean up and exit
            await cleanupSyncOperation(operationId: operationId, startTime: startTime, success: false)
            return false
        }
        
        print("✅📱🧭 LOCAL_DATA_SUCCESS: Retrieved \(localFavorites.count) local favorites")
        
        // STEP 4: Remote Data Retrieval
        // Fetch all user's nav unit favorites from Supabase
        print("☁️🧭 REMOTE_DATA: Starting remote favorites retrieval...")
        guard let remoteFavorites = await getRemoteFavorites(userId: userId) else {
            // Remote data retrieval failed - clean up and exit
            await cleanupSyncOperation(operationId: operationId, startTime: startTime, success: false)
            return false
        }
        
        print("✅☁️🧭 REMOTE_DATA_SUCCESS: Retrieved \(remoteFavorites.count) remote favorites")
        
        // STEP 5: Data Analysis and Sync Planning
        // Compare local and remote data to determine what operations are needed
        print("🔍🧭 ANALYSIS: Starting data comparison and sync planning...")
        let syncPlan = analyzeSyncRequirements(local: localFavorites, remote: remoteFavorites)
        
        print("✅🔍🧭 ANALYSIS_COMPLETE:")
        print("📤🧭 UPLOAD_NEEDED: \(syncPlan.toUpload.count) nav units")
        print("📥🧭 DOWNLOAD_NEEDED: \(syncPlan.toDownload.count) nav units")
        print("🔧🧭 CONFLICTS_TO_RESOLVE: \(syncPlan.conflicts.count) nav units")
        
        // STEP 6: Execute Sync Operations
        var syncSuccess = true
        
        // Upload local-only favorites to remote
        if !syncPlan.toUpload.isEmpty {
            print("📤🧭 UPLOAD_PHASE: Starting upload of \(syncPlan.toUpload.count) nav units...")
            let uploadSuccess = await uploadFavorites(syncPlan.toUpload, userId: userId)
            if !uploadSuccess {
                print("❌📤🧭 UPLOAD_FAILED: One or more uploads failed")
                syncSuccess = false
            } else {
                print("✅📤🧭 UPLOAD_SUCCESS: All uploads completed successfully")
            }
        }
        
        // Download remote-only favorites to local
        if !syncPlan.toDownload.isEmpty {
            print("📥🧭 DOWNLOAD_PHASE: Starting download of \(syncPlan.toDownload.count) nav units...")
            let downloadSuccess = await downloadFavorites(syncPlan.toDownload)
            if !downloadSuccess {
                print("❌📥🧭 DOWNLOAD_FAILED: One or more downloads failed")
                syncSuccess = false
            } else {
                print("✅📥🧭 DOWNLOAD_SUCCESS: All downloads completed successfully")
            }
        }
        
        // Resolve conflicts using last-write-wins strategy
        if !syncPlan.conflicts.isEmpty {
            print("🔧🧭 CONFLICT_RESOLUTION: Starting resolution of \(syncPlan.conflicts.count) conflicts...")
            let conflictSuccess = await resolveConflicts(syncPlan.conflicts)
            if !conflictSuccess {
                print("❌🔧🧭 CONFLICT_RESOLUTION_FAILED: One or more conflicts could not be resolved")
                syncSuccess = false
            } else {
                print("✅🔧🧭 CONFLICT_RESOLUTION_SUCCESS: All conflicts resolved successfully")
            }
        }
        
        // STEP 7: Cleanup and Results
        await cleanupSyncOperation(operationId: operationId, startTime: startTime, success: syncSuccess)
        
        return syncSuccess
    }
    
    // MARK: - Authentication Management
    
    /// Verifies that the user is authenticated and has a valid session
    /// Uses the injected SupabaseManager for authentication operations
    /// - Returns: Valid session or nil if authentication fails
    private func verifyAuthentication() async -> Session? {
        do {
            print("🔐🧭 AUTH_ATTEMPT: Requesting current session from injected SupabaseManager...")
            let session = try await supabaseManager.getSession()
            
            print("✅🔐🧭 AUTH_SESSION_VALID:")
            print("   User ID: \(session.user.id)")
            print("   Email: \(session.user.email ?? "unknown")")
            print("   Session expires: \(Date(timeIntervalSince1970: TimeInterval(session.expiresAt)))")
            
            return session
        } catch {
            print("❌🔐🧭 AUTH_FAILED: \(error.localizedDescription)")
            print("❌🔐🧭 AUTH_ERROR_TYPE: \(type(of: error))")
            return nil
        }
    }
    
    // MARK: - Local Data Operations
    
    /// Retrieves all navigation unit favorites from the local SQLite database
    /// Uses the injected NavUnitDatabaseService for local operations
    /// Includes sync metadata (user_id, device_id, last_modified) for comparison
    /// - Returns: Array of local favorites or nil if retrieval fails
    private func getLocalFavorites() async -> [RemoteNavUnitFavorite]? {
        do {
            print("📱🧭 LOCAL_QUERY: Executing getFavoriteNavUnitsForSync() on injected service...")
            
            // Get only favorited nav units with their complete data and sync metadata
            // This method queries the database with WHERE isFavorite = true for efficiency
            let localNavUnits = try await navUnitService.getFavoriteNavUnitsForSync()
            
            print("📱🧭 LOCAL_RAW_COUNT: Retrieved \(localNavUnits.count) favorite nav units from database")
            
            // Convert local nav units to RemoteNavUnitFavorite format for comparison
            var remoteFavorites: [RemoteNavUnitFavorite] = []
            
            for navUnit in localNavUnits {
                // Extract sync metadata that should be stored in the local database
                // These fields are set when the user toggles favorites
                guard let userIdString = navUnit.userId,
                      let userId = UUID(uuidString: userIdString) else {
                    print("⚠️📱🧭 LOCAL_SKIP: Nav unit \(navUnit.navUnitId) missing user_id, skipping...")
                    continue
                }
                
                let deviceId = navUnit.deviceId ?? UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
                let lastModified = navUnit.lastModified ?? Date()
                
                // Create RemoteNavUnitFavorite from local data
                let remoteFavorite = RemoteNavUnitFavorite(
                    userId: userId,
                    navUnitId: navUnit.navUnitId,
                    isFavorite: navUnit.isFavorite,
                    deviceId: deviceId,
                    navUnitName: navUnit.navUnitName,
                    latitude: navUnit.latitude,
                    longitude: navUnit.longitude,
                    facilityType: navUnit.facilityType
                )
                
                remoteFavorites.append(remoteFavorite)
                
                print("📱🧭 LOCAL_FAVORITE_MAPPED:")
                print("   Nav Unit: \(navUnit.navUnitId) - \(navUnit.navUnitName)")
                print("   User ID: \(userId)")
                print("   Is Favorite: \(navUnit.isFavorite)")
                print("   Last Modified: \(lastModified)")
                print("   Device ID: \(deviceId)")
            }
            
            print("✅📱🧭 LOCAL_CONVERSION_SUCCESS: Converted \(remoteFavorites.count) nav units to sync format")
            return remoteFavorites
            
        } catch {
            print("❌📱🧭 LOCAL_ERROR: Failed to retrieve local favorites")
            print("❌📱🧭 LOCAL_ERROR_DETAILS: \(error.localizedDescription)")
            print("❌📱🧭 LOCAL_ERROR_TYPE: \(type(of: error))")
            return nil
        }
    }
    
    // MARK: - Remote Data Operations
    
    /// Retrieves all navigation unit favorites for the specified user from Supabase
    /// Uses the injected SupabaseManager for remote operations
    /// - Parameter userId: The authenticated user's unique identifier
    /// - Returns: Array of remote favorites or nil if retrieval fails
    private func getRemoteFavorites(userId: UUID) async -> [RemoteNavUnitFavorite]? {
        do {
            print("☁️🧭 REMOTE_QUERY: Requesting nav unit favorites for user \(userId) via injected SupabaseManager...")
            
            // Call injected SupabaseManager to fetch all nav unit favorites for this user
            let remoteFavorites = try await supabaseManager.getNavUnitFavorites(userId: userId)
            
            print("✅☁️🧭 REMOTE_SUCCESS: Retrieved \(remoteFavorites.count) favorites from Supabase")
            
            // Log details of each remote favorite for debugging
            for (index, favorite) in remoteFavorites.enumerated() {
                print("☁️🧭 REMOTE_FAVORITE_\(index + 1):")
                print("   ID: \(favorite.id?.uuidString ?? "nil")")
                print("   Nav Unit: \(favorite.navUnitId)")
                print("   Name: \(favorite.navUnitName ?? "unknown")")
                print("   Is Favorite: \(favorite.isFavorite)")
                print("   Last Modified: \(favorite.lastModified)")
                print("   Device ID: \(favorite.deviceId)")
            }
            
            return remoteFavorites
            
        } catch {
            print("❌☁️🧭 REMOTE_ERROR: Failed to retrieve remote favorites")
            print("❌☁️🧭 REMOTE_ERROR_DETAILS: \(error.localizedDescription)")
            print("❌☁️🧭 REMOTE_ERROR_TYPE: \(type(of: error))")
            return nil
        }
    }
    
    // MARK: - Sync Analysis
    
    /// Structure to hold the results of sync analysis
    /// Determines what operations are needed to achieve data consistency
    private struct SyncPlan {
        let toUpload: [RemoteNavUnitFavorite]    // Local favorites not found remotely
        let toDownload: [RemoteNavUnitFavorite]  // Remote favorites not found locally
        let conflicts: [ConflictResolution]      // Nav units with different states that need resolution
    }
    
    /// Structure to hold conflict resolution data
    /// Contains both local and remote versions for timestamp comparison
    private struct ConflictResolution {
        let navUnitId: String
        let localFavorite: RemoteNavUnitFavorite
        let remoteFavorite: RemoteNavUnitFavorite
        let winningFavorite: RemoteNavUnitFavorite  // The one with the latest timestamp
        let resolution: String  // Human-readable description of what will happen
    }
    
    /// Analyzes local and remote data to determine sync operations needed
    /// Implements last-write-wins strategy for conflict resolution
    /// - Parameters:
    ///   - local: Array of local favorites in remote format
    ///   - remote: Array of actual remote favorites
    /// - Returns: SyncPlan containing all required operations
    private func analyzeSyncRequirements(
        local: [RemoteNavUnitFavorite],
        remote: [RemoteNavUnitFavorite]
    ) -> SyncPlan {
        
        print("🔍🧭 ANALYSIS_START: Comparing \(local.count) local vs \(remote.count) remote favorites")
        
        // Create lookup dictionaries for efficient comparison
        let localByNavUnitId = Dictionary(uniqueKeysWithValues: local.map { ($0.navUnitId, $0) })
        let remoteByNavUnitId = Dictionary(uniqueKeysWithValues: remote.map { ($0.navUnitId, $0) })
        
        print("🔍🧭 ANALYSIS_LOOKUP: Created lookup dictionaries")
        print("   Local nav units: \(localByNavUnitId.keys.sorted())")
        print("   Remote nav units: \(remoteByNavUnitId.keys.sorted())")
        
        // Find items that need to be uploaded (exist locally but not remotely)
        var toUpload: [RemoteNavUnitFavorite] = []
        for localFavorite in local {
            if remoteByNavUnitId[localFavorite.navUnitId] == nil {
                toUpload.append(localFavorite)
                print("📤🧭 UPLOAD_IDENTIFIED: \(localFavorite.navUnitId) - \(localFavorite.navUnitName ?? "unknown")")
            }
        }
        
        // Find items that need to be downloaded (exist remotely but not locally)
        var toDownload: [RemoteNavUnitFavorite] = []
        for remoteFavorite in remote {
            if localByNavUnitId[remoteFavorite.navUnitId] == nil {
                toDownload.append(remoteFavorite)
                print("📥🧭 DOWNLOAD_IDENTIFIED: \(remoteFavorite.navUnitId) - \(remoteFavorite.navUnitName ?? "unknown")")
            }
        }
        
        // Find conflicts (exist in both but with different states or timestamps)
        var conflicts: [ConflictResolution] = []
        for localFavorite in local {
            if let remoteFavorite = remoteByNavUnitId[localFavorite.navUnitId] {
                // Both exist - check if they're different
                let statesMatch = localFavorite.isFavorite == remoteFavorite.isFavorite
                
                if !statesMatch {
                    // States don't match - determine winner using last-write-wins
                    let localWins = localFavorite.lastModified > remoteFavorite.lastModified
                    let winningFavorite = localWins ? localFavorite : remoteFavorite
                    let losingFavorite = localWins ? remoteFavorite : localFavorite
                    
                    let resolution = localWins ?
                        "Local state (\(localFavorite.isFavorite)) wins over remote state (\(remoteFavorite.isFavorite))" :
                        "Remote state (\(remoteFavorite.isFavorite)) wins over local state (\(localFavorite.isFavorite))"
                    
                    let conflict = ConflictResolution(
                        navUnitId: localFavorite.navUnitId,
                        localFavorite: localFavorite,
                        remoteFavorite: remoteFavorite,
                        winningFavorite: winningFavorite,
                        resolution: resolution
                    )
                    
                    conflicts.append(conflict)
                    
                    print("🔧🧭 CONFLICT_IDENTIFIED: \(localFavorite.navUnitId)")
                    print("   Local: favorite=\(localFavorite.isFavorite), modified=\(localFavorite.lastModified)")
                    print("   Remote: favorite=\(remoteFavorite.isFavorite), modified=\(remoteFavorite.lastModified)")
                    print("   Winner: \(localWins ? "LOCAL" : "REMOTE") - \(resolution)")
                }
            }
        }
        
        let syncPlan = SyncPlan(toUpload: toUpload, toDownload: toDownload, conflicts: conflicts)
        
        print("✅🔍🧭 ANALYSIS_COMPLETE:")
        print("   Upload operations: \(toUpload.count)")
        print("   Download operations: \(toDownload.count)")
        print("   Conflict resolutions: \(conflicts.count)")
        print("   Total operations planned: \(toUpload.count + toDownload.count + conflicts.count)")
        
        return syncPlan
    }
    
    // MARK: - Upload Operations
    
    /// Uploads local favorites that don't exist remotely to Supabase
    /// Uses the injected SupabaseManager for remote operations
    /// - Parameters:
    ///   - favorites: Array of local favorites to upload
    ///   - userId: The authenticated user's ID
    /// - Returns: Success status of all upload operations
    private func uploadFavorites(_ favorites: [RemoteNavUnitFavorite], userId: UUID) async -> Bool {
        print("📤🧭 UPLOAD_START: Beginning upload of \(favorites.count) favorites via injected SupabaseManager...")
        
        var successCount = 0
        var failureCount = 0
        
        for (index, favorite) in favorites.enumerated() {
            print("📤🧭 UPLOAD_ITEM_\(index + 1): Processing \(favorite.navUnitId)...")
            
            do {
                // Upload this favorite to Supabase using injected manager
                try await supabaseManager.upsertNavUnitFavorite(favorite)
                
                successCount += 1
                print("✅📤🧭 UPLOAD_SUCCESS_\(index + 1): \(favorite.navUnitId) uploaded successfully")
                
            } catch {
                failureCount += 1
                print("❌📤🧭 UPLOAD_FAILED_\(index + 1): \(favorite.navUnitId) upload failed")
                print("❌📤🧭 UPLOAD_ERROR_DETAILS: \(error.localizedDescription)")
            }
        }
        
        let allSucceeded = failureCount == 0
        print("🏁📤🧭 UPLOAD_COMPLETE: \(successCount) succeeded, \(failureCount) failed")
        
        return allSucceeded
    }
    
    // MARK: - Download Operations
    
    /// Downloads remote favorites that don't exist locally and updates the local database
    /// Uses the injected NavUnitDatabaseService for local operations
    /// - Parameter favorites: Array of remote favorites to download
    /// - Returns: Success status of all download operations
    private func downloadFavorites(_ favorites: [RemoteNavUnitFavorite]) async -> Bool {
        print("📥🧭 DOWNLOAD_START: Beginning download of \(favorites.count) favorites via injected NavUnitService...")
        
        var successCount = 0
        var failureCount = 0
        
        for (index, favorite) in favorites.enumerated() {
            print("📥🧭 DOWNLOAD_ITEM_\(index + 1): Processing \(favorite.navUnitId)...")
            
            do {
                // Update local database with remote favorite data using injected service
                try await navUnitService.setNavUnitFavoriteWithSyncData(
                    navUnitId: favorite.navUnitId,
                    isFavorite: favorite.isFavorite,
                    userId: favorite.userId.uuidString,
                    deviceId: favorite.deviceId,
                    lastModified: favorite.lastModified
                )
                
                successCount += 1
                print("✅📥🧭 DOWNLOAD_SUCCESS_\(index + 1): \(favorite.navUnitId) downloaded successfully")
                
            } catch {
                failureCount += 1
                print("❌📥🧭 DOWNLOAD_FAILED_\(index + 1): \(favorite.navUnitId) download failed")
                print("❌📥🧭 DOWNLOAD_ERROR_DETAILS: \(error.localizedDescription)")
            }
        }
        
        let allSucceeded = failureCount == 0
        print("🏁📥🧭 DOWNLOAD_COMPLETE: \(successCount) succeeded, \(failureCount) failed")
        
        return allSucceeded
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolves conflicts using last-write-wins strategy
    /// Updates both local and remote data to match the winning version
    /// Uses both injected services for local and remote operations
    /// - Parameter conflicts: Array of conflicts that need resolution
    /// - Returns: Success status of all conflict resolution operations
    private func resolveConflicts(_ conflicts: [ConflictResolution]) async -> Bool {
        print("🔧🧭 CONFLICT_START: Beginning resolution of \(conflicts.count) conflicts using injected services...")
        
        var successCount = 0
        var failureCount = 0
        
        for (index, conflict) in conflicts.enumerated() {
            print("🔧🧭 CONFLICT_ITEM_\(index + 1): Resolving \(conflict.navUnitId)...")
            print("   Resolution: \(conflict.resolution)")
            
            do {
                let winningFavorite = conflict.winningFavorite
                
                // Always update local database to match the winning version using injected service
                try await navUnitService.setNavUnitFavoriteWithSyncData(
                    navUnitId: winningFavorite.navUnitId,
                    isFavorite: winningFavorite.isFavorite,
                    userId: winningFavorite.userId.uuidString,
                    deviceId: winningFavorite.deviceId,
                    lastModified: winningFavorite.lastModified
                )
                
                // If local version won, also update remote to ensure consistency using injected manager
                if winningFavorite.lastModified == conflict.localFavorite.lastModified {
                    try await supabaseManager.upsertNavUnitFavorite(winningFavorite)
                    print("🔧🧭 CONFLICT_REMOTE_UPDATE: Updated remote to match local winner")
                }
                
                successCount += 1
                print("✅🔧🧭 CONFLICT_SUCCESS_\(index + 1): \(conflict.navUnitId) resolved successfully")
                
            } catch {
                failureCount += 1
                print("❌🔧🧭 CONFLICT_FAILED_\(index + 1): \(conflict.navUnitId) resolution failed")
                print("❌🔧🧭 CONFLICT_ERROR_DETAILS: \(error.localizedDescription)")
            }
        }
        
        let allSucceeded = failureCount == 0
        print("🏁🔧🧭 CONFLICT_COMPLETE: \(successCount) succeeded, \(failureCount) failed")
        
        return allSucceeded
    }
    
    // MARK: - Cleanup and Statistics
    
    /// Cleans up after a sync operation and records performance statistics
    /// - Parameters:
    ///   - operationId: Unique identifier for this sync operation
    ///   - startTime: When the operation began
    ///   - success: Whether the operation completed successfully
    private func cleanupSyncOperation(operationId: String, startTime: Date, success: Bool) async {
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Remove this operation from active tracking
        activeOperations.remove(operationId)
        
        // Release the sync lock for this instance
        await MainActor.run {
            isSyncing = false
        }
        
        // Update performance statistics
        syncStats.recordSync(duration: duration, success: success)
        
        // Log final results
        if success {
            print("✅🧭 SYNC_SUCCESS: Operation \(operationId) completed successfully")
        } else {
            print("❌🧭 SYNC_FAILED: Operation \(operationId) completed with errors")
        }
        
        print("🏁🧭 SYNC_COMPLETE:")
        print("   Operation ID: \(operationId)")
        print("   Duration: \(String(format: "%.3f", duration))s")
        print("   Success: \(success)")
        print("   Active operations: \(activeOperations.count)")
        
        print("📊🧭 SYNC_STATS:")
        print("   Total syncs: \(syncStats.totalSyncs)")
        print("   Successful: \(syncStats.successfulSyncs)")
        print("   Failed: \(syncStats.failedSyncs)")
        print("   Average duration: \(String(format: "%.3f", syncStats.averageDuration))s")
        print("   Last sync: \(syncStats.lastSyncTime?.description ?? "never")")
        
        print("🟢🧭 NAV_UNIT_SYNC_END: =====================================================")
    }
    
    // MARK: - Public Utility Methods
    
    /// Returns current sync statistics for monitoring and debugging
    /// - Returns: Dictionary containing sync performance metrics
    func getSyncStats() -> [String: Any] {
        return [
            "totalSyncs": syncStats.totalSyncs,
            "successfulSyncs": syncStats.successfulSyncs,
            "failedSyncs": syncStats.failedSyncs,
            "averageDuration": syncStats.averageDuration,
            "lastSyncTime": syncStats.lastSyncTime?.description ?? "never",
            "isSyncing": isSyncing,
            "activeOperations": Array(activeOperations)
        ]
    }
    
    /// Prints current sync statistics to the debug console
    func printSyncStats() {
        print("📊🧭 NAV_UNIT_SYNC_STATISTICS:")
        let stats = getSyncStats()
        for (key, value) in stats {
            print("   \(key): \(value)")
        }
    }
}
