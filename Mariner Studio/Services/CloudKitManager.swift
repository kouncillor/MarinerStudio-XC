import Foundation
import CloudKit
import Combine

/// CloudKit manager for advanced CloudKit operations
/// Handles account status, notifications, and manual sync triggers
/// Works alongside PersistenceController for Core Data + CloudKit integration
final class CloudKitManager: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = CloudKitManager()
    
    // MARK: - Published Properties
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var isNetworkAvailable = true
    @Published var lastSyncDate: Date?
    
    // MARK: - Private Properties
    private let container: CKContainer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        self.container = CKContainer(identifier: "iCloud.com.ospreyapplications.Mariner-Studio")
        
        DebugLogger.shared.log("☁️ CLOUDKIT_MANAGER: Initializing CloudKit manager", category: "CLOUDKIT_INIT")
        
        setupNotificationObservers()
        
        Task {
            await checkAccountStatus()
        }
    }
    
    // MARK: - Setup
    private func setupNotificationObservers() {
        // Listen for CloudKit account changes
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                DebugLogger.shared.log("📱 CLOUDKIT: Account status changed", category: "CLOUDKIT_ACCOUNT")
                Task {
                    await self?.checkAccountStatus()
                }
            }
            .store(in: &cancellables)
        
        // Listen for remote CloudKit changes
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DebugLogger.shared.log("🔄 CLOUDKIT: Remote changes detected", category: "CLOUDKIT_SYNC")
                self?.lastSyncDate = Date()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Account Status
    func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            
            await MainActor.run {
                self.accountStatus = status
                
                switch status {
                case .available:
                    DebugLogger.shared.log("✅ CLOUDKIT: Account available and ready", category: "CLOUDKIT_ACCOUNT")
                case .noAccount:
                    DebugLogger.shared.log("⚠️ CLOUDKIT: No iCloud account signed in", category: "CLOUDKIT_ACCOUNT")
                case .restricted:
                    DebugLogger.shared.log("⚠️ CLOUDKIT: iCloud account is restricted", category: "CLOUDKIT_ACCOUNT")
                case .couldNotDetermine:
                    DebugLogger.shared.log("⚠️ CLOUDKIT: Could not determine account status", category: "CLOUDKIT_ACCOUNT")
                @unknown default:
                    DebugLogger.shared.log("⚠️ CLOUDKIT: Unknown account status", category: "CLOUDKIT_ACCOUNT")
                }
            }
        } catch {
            DebugLogger.shared.log("❌ CLOUDKIT: Account status check failed - \(error)", category: "CLOUDKIT_ACCOUNT")
            
            await MainActor.run {
                self.accountStatus = .couldNotDetermine
            }
        }
    }
    
    // MARK: - Sync Status
    var isCloudKitAvailable: Bool {
        accountStatus == .available
    }
    
    func getAccountStatusMessage() -> String {
        switch accountStatus {
        case .available:
            return "✅ iCloud sync is active"
        case .noAccount:
            return "⚠️ Sign in to iCloud in Settings to sync favorites across devices"
        case .restricted:
            return "⚠️ iCloud is restricted on this device"
        case .couldNotDetermine:
            return "⚠️ Unable to determine iCloud status"
        @unknown default:
            return "⚠️ Unknown iCloud status"
        }
    }
    
    // MARK: - Manual Sync
    func triggerSync() async {
        guard isCloudKitAvailable else {
            DebugLogger.shared.log("⚠️ CLOUDKIT: Cannot sync - account not available", category: "CLOUDKIT_SYNC")
            return
        }
        
        DebugLogger.shared.log("🔄 CLOUDKIT: Triggering manual sync", category: "CLOUDKIT_SYNC")
        
        // Core Data + CloudKit handles sync automatically
        // This just updates our last sync date for UI purposes
        await MainActor.run {
            self.lastSyncDate = Date()
        }
        
        DebugLogger.shared.log("✅ CLOUDKIT: Manual sync triggered", category: "CLOUDKIT_SYNC")
    }
    
    // MARK: - CloudKit Setup Verification
    func verifyCloudKitSetup() async -> Bool {
        guard isCloudKitAvailable else {
            DebugLogger.shared.log("❌ CLOUDKIT_VERIFY: Account not available", category: "CLOUDKIT_VERIFY")
            return false
        }
        
        do {
            // Test database access
            let privateDatabase = container.privateCloudDatabase
            
            // Try to fetch a small amount of data to verify connection
            let query = CKQuery(recordType: "CD_TideFavorite", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            _ = try await privateDatabase.records(matching: query, resultsLimit: 1)
            
            DebugLogger.shared.log("✅ CLOUDKIT_VERIFY: Setup verified successfully", category: "CLOUDKIT_VERIFY")
            return true
            
        } catch {
            // This might fail if schema isn't set up yet, which is expected initially
            DebugLogger.shared.log("⚠️ CLOUDKIT_VERIFY: Setup verification failed - \(error)", category: "CLOUDKIT_VERIFY")
            return false
        }
    }
    
    // MARK: - Error Handling
    func handleCloudKitError(_ error: Error) -> String {
        guard let ckError = error as? CKError else {
            return "Unknown CloudKit error: \(error.localizedDescription)"
        }
        
        switch ckError.code {
        case .notAuthenticated:
            return "Please sign in to iCloud in Settings"
        case .networkUnavailable, .networkFailure:
            return "Check your internet connection"
        case .quotaExceeded:
            return "iCloud storage is full"
        case .requestRateLimited:
            return "Too many requests, please try again later"
        case .zoneBusy:
            return "CloudKit is busy, trying again..."
        default:
            return "CloudKit error: \(ckError.localizedDescription)"
        }
    }
    
    // MARK: - Development Helpers
    func printCloudKitStatus() {
        DebugLogger.shared.log("🔍 CLOUDKIT_STATUS: Account Status = \(accountStatus)", category: "CLOUDKIT_DEBUG")
        DebugLogger.shared.log("🔍 CLOUDKIT_STATUS: Available = \(isCloudKitAvailable)", category: "CLOUDKIT_DEBUG")
        DebugLogger.shared.log("🔍 CLOUDKIT_STATUS: Last Sync = \(lastSyncDate?.description ?? "Never")", category: "CLOUDKIT_DEBUG")
        DebugLogger.shared.log("🔍 CLOUDKIT_STATUS: Network = \(isNetworkAvailable)", category: "CLOUDKIT_DEBUG")
    }
}