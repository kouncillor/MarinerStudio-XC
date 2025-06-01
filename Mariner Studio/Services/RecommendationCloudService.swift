import Foundation
import CloudKit

// Protocol for recommendation cloud operations
protocol RecommendationCloudService {
    func submitRecommendation(_ recommendation: CloudRecommendation) async throws -> String
    func getUserRecommendations() async throws -> [CloudRecommendation]
    func getRecommendationsForNavUnit(_ navUnitId: String) async throws -> [CloudRecommendation]
    func setupNotificationSubscription() async throws
    func checkAccountStatus() async -> CKAccountStatus
}

// Implementation of recommendation cloud service
class RecommendationCloudServiceImpl: ObservableObject, RecommendationCloudService {
    
    // MARK: - Properties
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    
    // Track submission state
    @Published var isSubmitting: Bool = false
    @Published var lastError: String?
    
    // MARK: - Initialization
    init() {
        self.container = CKContainer.default()
        self.publicDatabase = container.publicCloudDatabase
        
        print("🔧 RecommendationCloudService: Initialized")
        
        // Check account status on init
        Task {
            await checkAccountStatus()
        }
    }
    
    // MARK: - Account Management
    @discardableResult
    func checkAccountStatus() async -> CKAccountStatus {
        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                self.accountStatus = status
            }
            
            switch status {
            case .available:
                print("✅ RecommendationCloudService: iCloud account is available")
                // Set up notification subscription when account is available
                Task {
                    try? await setupNotificationSubscription()
                }
            case .noAccount:
                print("❌ RecommendationCloudService: No iCloud account signed in")
            case .restricted:
                print("⚠️ RecommendationCloudService: iCloud account is restricted")
            case .couldNotDetermine:
                print("❓ RecommendationCloudService: Could not determine iCloud account status")
            case .temporarilyUnavailable:
                print("⏳ RecommendationCloudService: iCloud is temporarily unavailable")
            @unknown default:
                print("❓ RecommendationCloudService: Unknown iCloud account status")
            }
            
            return status
        } catch {
            print("❌ RecommendationCloudService: Error checking account status: \(error.localizedDescription)")
            await MainActor.run {
                self.accountStatus = .couldNotDetermine
            }
            return .couldNotDetermine
        }
    }
    
    // MARK: - Recommendation Operations
    
    func submitRecommendation(_ recommendation: CloudRecommendation) async throws -> String {
        print("🚀 RecommendationCloudService: Submitting recommendation for nav unit: \(recommendation.navUnitId)")
        
        guard accountStatus == .available else {
            print("❌ RecommendationCloudService: Account not available. Status: \(accountStatus)")
            throw RecommendationError.accountNotAvailable
        }
        
        await MainActor.run {
            isSubmitting = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isSubmitting = false
            }
        }
        
        do {
            let record = recommendation.toCKRecord()
            print("☁️ RecommendationCloudService: Converting recommendation to CloudKit record")
            
            let savedRecord = try await publicDatabase.save(record)
            let recordID = savedRecord.recordID.recordName
            
            print("🎉 RecommendationCloudService: Successfully submitted recommendation with ID: \(recordID)")
            print("📝 RecommendationCloudService: Category: \(recommendation.category.displayName)")
            print("📝 RecommendationCloudService: Nav Unit: \(recommendation.navUnitName)")
            
            return recordID
            
        } catch {
            print("💥 RecommendationCloudService: Failed to submit recommendation: \(error.localizedDescription)")
            
            await MainActor.run {
                lastError = "Failed to submit recommendation: \(error.localizedDescription)"
            }
            
            throw RecommendationError.submissionFailed(error)
        }
    }
    
    func getUserRecommendations() async throws -> [CloudRecommendation] {
        print("🔍 RecommendationCloudService: Fetching user recommendations...")
        
        guard accountStatus == .available else {
            throw RecommendationError.accountNotAvailable
        }
        
        // Query for recommendations created by this user
        // Note: CloudKit will automatically filter by the current user's records in public database
        let query = CKQuery(recordType: CloudRecommendation.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: CloudRecommendation.FieldKeys.createdAt, ascending: false)]
        
        do {
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            var recommendations: [CloudRecommendation] = []
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let recommendation = CloudRecommendation(from: record) {
                        recommendations.append(recommendation)
                        print("📋 RecommendationCloudService: Loaded recommendation: \(recommendation.category.displayName) for \(recommendation.navUnitName)")
                    }
                case .failure(let error):
                    print("❌ RecommendationCloudService: Failed to process recommendation record: \(error.localizedDescription)")
                }
            }
            
            print("✅ RecommendationCloudService: Retrieved \(recommendations.count) user recommendations")
            return recommendations
            
        } catch {
            print("❌ RecommendationCloudService: Failed to fetch user recommendations: \(error.localizedDescription)")
            throw RecommendationError.fetchFailed(error)
        }
    }
    
    func getRecommendationsForNavUnit(_ navUnitId: String) async throws -> [CloudRecommendation] {
        print("🔍 RecommendationCloudService: Fetching recommendations for nav unit: \(navUnitId)")
        
        guard accountStatus == .available else {
            throw RecommendationError.accountNotAvailable
        }
        
        let predicate = NSPredicate(format: "navUnitId == %@", navUnitId)
        let query = CKQuery(recordType: CloudRecommendation.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CloudRecommendation.FieldKeys.createdAt, ascending: false)]
        
        do {
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            var recommendations: [CloudRecommendation] = []
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let recommendation = CloudRecommendation(from: record) {
                        recommendations.append(recommendation)
                    }
                case .failure(let error):
                    print("❌ RecommendationCloudService: Failed to process nav unit recommendation record: \(error.localizedDescription)")
                }
            }
            
            print("✅ RecommendationCloudService: Retrieved \(recommendations.count) recommendations for nav unit: \(navUnitId)")
            return recommendations
            
        } catch {
            print("❌ RecommendationCloudService: Failed to fetch nav unit recommendations: \(error.localizedDescription)")
            throw RecommendationError.fetchFailed(error)
        }
    }
    
    // MARK: - Notification Setup
    
    func setupNotificationSubscription() async throws {
        print("🔔 RecommendationCloudService: Setting up notification subscription for new recommendations")
        
        guard accountStatus == .available else {
            print("❌ RecommendationCloudService: Cannot set up notifications - account not available")
            return
        }
        
        do {
            // Create subscription for new recommendations
            let predicate = NSPredicate(value: true) // All new recommendations
            let subscription = CKQuerySubscription(
                recordType: CloudRecommendation.recordType,
                predicate: predicate,
                subscriptionID: "new-recommendations",
                options: [.firesOnRecordCreation]
            )
            
            // Configure notification info (this will only notify the admin - you)
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.alertBody = "New navigation unit recommendation submitted"
            notificationInfo.soundName = "default"
            // Note: badge property not available on all iOS versions
            
            subscription.notificationInfo = notificationInfo
            
            // Save subscription
            let savedSubscription = try await publicDatabase.save(subscription)
            print("✅ RecommendationCloudService: Notification subscription created: \(savedSubscription.subscriptionID)")
            
        } catch {
            // If subscription already exists, that's okay
            if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
                print("ℹ️ RecommendationCloudService: Notification subscription already exists")
            } else {
                print("❌ RecommendationCloudService: Failed to set up notification subscription: \(error.localizedDescription)")
                // Don't throw - notifications are nice to have but not critical
            }
        }
    }
    
    // MARK: - Admin Helper Methods
    
    func getAllRecommendations() async throws -> [CloudRecommendation] {
        print("🔍 RecommendationCloudService: [ADMIN] Fetching ALL recommendations")
        
        guard accountStatus == .available else {
            throw RecommendationError.accountNotAvailable
        }
        
        let query = CKQuery(recordType: CloudRecommendation.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: CloudRecommendation.FieldKeys.createdAt, ascending: false)]
        
        do {
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            var recommendations: [CloudRecommendation] = []
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let recommendation = CloudRecommendation(from: record) {
                        recommendations.append(recommendation)
                    }
                case .failure(let error):
                    print("❌ RecommendationCloudService: Failed to process admin recommendation record: \(error.localizedDescription)")
                }
            }
            
            print("✅ RecommendationCloudService: [ADMIN] Retrieved \(recommendations.count) total recommendations")
            return recommendations
            
        } catch {
            print("❌ RecommendationCloudService: [ADMIN] Failed to fetch all recommendations: \(error.localizedDescription)")
            throw RecommendationError.fetchFailed(error)
        }
    }
    
    func updateRecommendationStatus(_ recommendation: CloudRecommendation, newStatus: RecommendationStatus, adminNotes: String? = nil) async throws -> CloudRecommendation {
        print("🔄 RecommendationCloudService: [ADMIN] Updating recommendation status to: \(newStatus.displayName)")
        
        guard accountStatus == .available else {
            throw RecommendationError.accountNotAvailable
        }
        
        let updatedRecommendation = recommendation.withStatus(newStatus, adminNotes: adminNotes)
        
        do {
            let record = updatedRecommendation.toCKRecord()
            let savedRecord = try await publicDatabase.save(record)
            
            if let finalRecommendation = CloudRecommendation(from: savedRecord) {
                print("✅ RecommendationCloudService: [ADMIN] Successfully updated recommendation status")
                return finalRecommendation
            } else {
                throw RecommendationError.updateFailed(NSError(domain: "RecommendationCloudService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse updated record"]))
            }
            
        } catch {
            print("❌ RecommendationCloudService: [ADMIN] Failed to update recommendation status: \(error.localizedDescription)")
            throw RecommendationError.updateFailed(error)
        }
    }
    
    // MARK: - Error Handling
    
    func clearLastError() {
        lastError = nil
    }
}

// MARK: - Error Types

enum RecommendationError: Error, LocalizedError {
    case accountNotAvailable
    case submissionFailed(Error)
    case fetchFailed(Error)
    case updateFailed(Error)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "iCloud account is not available. Please sign in to iCloud to submit recommendations."
        case .submissionFailed(let error):
            return "Failed to submit recommendation: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to load recommendations: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update recommendation: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid recommendation data"
        }
    }
}
