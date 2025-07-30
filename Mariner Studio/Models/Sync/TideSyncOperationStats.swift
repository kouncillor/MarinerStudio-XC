//
//  TideSyncOperationStats.swift
//  Mariner Studio
//
//  Shared statistics structure for all sync services
//  Used by TideStationSyncService, NavUnitSyncService, and other sync services
//

import Foundation

/// Performance statistics for sync operations
/// Used across all sync services for consistent tracking
struct TideSyncOperationStats {
    var totalCalls: Int
    var successCount: Int
    var failureCount: Int
    var totalDuration: TimeInterval
    var minDuration: TimeInterval
    var maxDuration: TimeInterval
    var lastExecution: Date

    /// Computed property for average duration
    var averageDuration: TimeInterval {
        guard totalCalls > 0 else { return 0 }
        return totalDuration / Double(totalCalls)
    }

    /// Computed property for success rate percentage
    var successRate: Double {
        guard totalCalls > 0 else { return 0 }
        return Double(successCount) / Double(totalCalls) * 100
    }

    /// Initialize with zero values
    init() {
        self.totalCalls = 0
        self.successCount = 0
        self.failureCount = 0
        self.totalDuration = 0
        self.minDuration = 0
        self.maxDuration = 0
        self.lastExecution = Date()
    }

    /// Initialize with specific values
    init(totalCalls: Int, successCount: Int, failureCount: Int,
         totalDuration: TimeInterval, minDuration: TimeInterval, maxDuration: TimeInterval) {
        self.totalCalls = totalCalls
        self.successCount = successCount
        self.failureCount = failureCount
        self.totalDuration = totalDuration
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.lastExecution = Date()
    }

    /// Initialize with specific values including lastExecution
    init(totalCalls: Int, successCount: Int, failureCount: Int,
         totalDuration: TimeInterval, minDuration: TimeInterval, maxDuration: TimeInterval,
         lastExecution: Date) {
        self.totalCalls = totalCalls
        self.successCount = successCount
        self.failureCount = failureCount
        self.totalDuration = totalDuration
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.lastExecution = lastExecution
    }
}
