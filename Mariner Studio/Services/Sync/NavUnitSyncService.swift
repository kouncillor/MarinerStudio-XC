
import Foundation

// MARK: - Sync Result Types

enum SyncResult {
    case success(SyncStats)
    case failure(Error)
    case partialSuccess(SyncStats, [Error])
}

struct SyncStats {
    let totalOperations: Int
    let uploaded: Int
    let downloaded: Int
    let conflictsResolved: Int
    let duration: Double
    
    init(totalOperations: Int = 0, uploaded: Int = 0, downloaded: Int = 0, conflictsResolved: Int = 0, duration: Double = 0.0) {
        self.totalOperations = totalOperations
        self.uploaded = uploaded
        self.downloaded = downloaded
        self.conflictsResolved = conflictsResolved
        self.duration = duration
    }
}

// MARK: - NavUnitSyncService Stub Implementation

class NavUnitSyncService {
    
    // MARK: - Singleton
    static let shared = NavUnitSyncService()
    
    private init() {
        print("🔄 NAV_UNIT_SYNC_SERVICE: Initialized (STUB IMPLEMENTATION)")
    }
    
    // MARK: - Stub Sync Methods
    
    /// Stub implementation for syncing nav unit favorites
    /// Returns a successful result with zero operations to prevent errors during refactoring
    func syncNavUnitFavorites() async -> SyncResult {
        print("🔄 NAV_UNIT_SYNC_SERVICE: syncNavUnitFavorites() called (STUB - NO ACTUAL SYNC)")
        
        // Simulate a short delay to mimic real sync behavior
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let stubStats = SyncStats(
            totalOperations: 0,
            uploaded: 0,
            downloaded: 0,
            conflictsResolved: 0,
            duration: 0.5
        )
        
        print("✅ NAV_UNIT_SYNC_SERVICE: Returning successful stub result (no actual operations)")
        return .success(stubStats)
    }
    
    /// Stub method for manual sync operations
    func performManualSync() async -> SyncResult {
        print("🔄 NAV_UNIT_SYNC_SERVICE: performManualSync() called (STUB - NO ACTUAL SYNC)")
        
        // Simulate a short delay
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        let stubStats = SyncStats(
            totalOperations: 0,
            uploaded: 0,
            downloaded: 0,
            conflictsResolved: 0,
            duration: 0.3
        )
        
        print("✅ NAV_UNIT_SYNC_SERVICE: Manual sync stub completed")
        return .success(stubStats)
    }
    
    /// Stub method for checking sync status
    func getSyncStatus() async -> (isEnabled: Bool, lastSyncTime: Date?) {
        print("🔄 NAV_UNIT_SYNC_SERVICE: getSyncStatus() called (STUB)")
        
        // Return that sync is "enabled" but no last sync time since it's a stub
        return (isEnabled: true, lastSyncTime: nil)
    }
    
    /// Stub method for enabling/disabling sync
    func setSyncEnabled(_ enabled: Bool) async {
        print("🔄 NAV_UNIT_SYNC_SERVICE: setSyncEnabled(\(enabled)) called (STUB - NO EFFECT)")
    }
    
    // MARK: - Debugging / Development Methods
    
    /// Method to help identify when the real sync service should be implemented
    func isStubImplementation() -> Bool {
        return true
    }
    
    /// Method to log that stub is being used (helpful for debugging)
    func logStubUsage(from caller: String = #function) {
        print("⚠️ NAV_UNIT_SYNC_SERVICE: STUB METHOD CALLED from \(caller)")
        print("⚠️ NAV_UNIT_SYNC_SERVICE: Replace with real implementation when ready")
    }
}
