import Foundation

/// Result of a tide sync operation
enum TideSyncResult {
    case success(TideSyncStats)
    case failure(TideSyncError)
    case partialSuccess(TideSyncStats, [TideSyncError])
}

/// Detailed statistics for tide sync operations
struct TideSyncStats {
    let operationId: String
    let startTime: Date
    let endTime: Date
    let localFavoritesFound: Int
    let remoteFavoritesFound: Int
    let uploaded: Int
    let downloaded: Int
    let conflictsResolved: Int
    let errors: Int

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var totalOperations: Int {
        uploaded + downloaded + conflictsResolved
    }
}

/// Tide sync operation errors
enum TideSyncError: Error, LocalizedError {
    case authenticationRequired
    case networkUnavailable
    case supabaseError(String)
    case databaseError(String)
    case conflictResolutionFailed(String)
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "User must be authenticated to sync favorites"
        case .networkUnavailable:
            return "Network connection is required for sync"
        case .supabaseError(let message):
            return "Supabase error: \(message)"
        case .databaseError(let message):
            return "Local database error: \(message)"
        case .conflictResolutionFailed(let message):
            return "Conflict resolution failed: \(message)"
        case .unknownError(let message):
            return "Unknown sync error: \(message)"
        }
    }
}
