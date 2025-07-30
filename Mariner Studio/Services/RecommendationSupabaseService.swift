import Foundation
import Supabase

// Protocol for recommendation operations (maintaining existing interface)
protocol RecommendationCloudService {
    func submitRecommendation(_ recommendation: CloudRecommendation) async throws -> String
    func getUserRecommendations() async throws -> [CloudRecommendation]
    func getRecommendationsForNavUnit(_ navUnitId: String) async throws -> [CloudRecommendation]
    func setupNotificationSubscription() async throws
    func checkAccountStatus() async -> Bool
}

// Implementation of recommendation service using Supabase
class RecommendationSupabaseService: ObservableObject, RecommendationCloudService {

    // MARK: - Properties
    private let supabaseManager: SupabaseManager
    private static var operationCounter = 0

    @Published var isSubmitting: Bool = false
    @Published var lastError: String?

    // MARK: - Initialization
    init(supabaseManager: SupabaseManager = SupabaseManager.shared) {
        self.supabaseManager = supabaseManager
        print("🔧 RecommendationSupabaseService: Initialized")
    }

    // MARK: - Protocol Implementation

    func submitRecommendation(_ recommendation: CloudRecommendation) async throws -> String {
        let operationId = Self.getNextOperationId()
        print("🚀 RecommendationSupabaseService [\(operationId)]: Starting recommendation submission")
        print("📝 RecommendationSupabaseService [\(operationId)]: Nav Unit: \(recommendation.navUnitName)")
        print("📝 RecommendationSupabaseService [\(operationId)]: Category: \(recommendation.category.displayName)")

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
            // Get current session
            let session = try await supabaseManager.getSession()
            let userId = session.user.id

            print("✅ RecommendationSupabaseService [\(operationId)]: Authenticated user: \(userId)")

            // Create remote recommendation
            let remoteRecommendation = RemoteRecommendation(
                userId: userId,
                navUnitId: recommendation.navUnitId,
                navUnitName: recommendation.navUnitName,
                category: recommendation.category,
                description: recommendation.description,
                userEmail: recommendation.userEmail
            )

            print("📤 RecommendationSupabaseService [\(operationId)]: Submitting to Supabase...")

            // Submit to Supabase
            let response: [RemoteRecommendation] = try await supabaseManager
                .from("user_recommendations")
                .insert(remoteRecommendation)
                .select()
                .execute()
                .value

            guard let savedRecommendation = response.first,
                  let recommendationId = savedRecommendation.id else {
                throw RecommendationError.submissionFailed(
                    NSError(domain: "RecommendationSupabaseService", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "No ID returned from Supabase"])
                )
            }

            print("🎉 RecommendationSupabaseService [\(operationId)]: Successfully submitted recommendation")
            print("📝 RecommendationSupabaseService [\(operationId)]: ID: \(recommendationId)")

            return recommendationId.uuidString

        } catch {
            print("💥 RecommendationSupabaseService [\(operationId)]: Failed to submit recommendation: \(error.localizedDescription)")

            await MainActor.run {
                lastError = "Failed to submit recommendation: \(error.localizedDescription)"
            }

            throw RecommendationError.submissionFailed(error)
        }
    }

    func getUserRecommendations() async throws -> [CloudRecommendation] {
        let operationId = Self.getNextOperationId()
        print("🔍 RecommendationSupabaseService [\(operationId)]: Fetching user recommendations...")

        do {
            // Get current session
            let session = try await supabaseManager.getSession()
            let userId = session.user.id

            print("✅ RecommendationSupabaseService [\(operationId)]: Authenticated user: \(userId)")

            // Query user's recommendations
            let response: [RemoteRecommendation] = try await supabaseManager
                .from("user_recommendations")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            let recommendations = response.map { $0.toCloudRecommendation() }

            print("✅ RecommendationSupabaseService [\(operationId)]: Retrieved \(recommendations.count) recommendations")

            for recommendation in recommendations {
                print("📋 RecommendationSupabaseService [\(operationId)]: \(recommendation.category.displayName) for \(recommendation.navUnitName) - \(recommendation.status.displayName)")
            }

            return recommendations

        } catch {
            print("❌ RecommendationSupabaseService [\(operationId)]: Failed to fetch recommendations: \(error.localizedDescription)")
            throw RecommendationError.fetchFailed(error)
        }
    }

    func getRecommendationsForNavUnit(_ navUnitId: String) async throws -> [CloudRecommendation] {
        let operationId = Self.getNextOperationId()
        print("🔍 RecommendationSupabaseService [\(operationId)]: Fetching recommendations for nav unit: \(navUnitId)")

        do {
            // Query recommendations for specific nav unit
            let response: [RemoteRecommendation] = try await supabaseManager
                .from("user_recommendations")
                .select()
                .eq("nav_unit_id", value: navUnitId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let recommendations = response.map { $0.toCloudRecommendation() }

            print("✅ RecommendationSupabaseService [\(operationId)]: Retrieved \(recommendations.count) recommendations for nav unit: \(navUnitId)")

            return recommendations

        } catch {
            print("❌ RecommendationSupabaseService [\(operationId)]: Failed to fetch nav unit recommendations: \(error.localizedDescription)")
            throw RecommendationError.fetchFailed(error)
        }
    }

    func setupNotificationSubscription() async throws {
        // Note: Supabase real-time subscriptions would go here
        // For now, we'll implement login-time status checking instead
        print("ℹ️ RecommendationSupabaseService: Notification subscription not implemented (will use login-time checking)")
    }

    func checkAccountStatus() async -> Bool {
        do {
            let session = try await supabaseManager.getSession()
            print("✅ RecommendationSupabaseService: Account is authenticated")
            return true
        } catch {
            print("❌ RecommendationSupabaseService: Account not authenticated: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Additional Methods for Status Checking

    func checkForRecommendationStatusChanges(since lastCheck: Date) async throws -> [CloudRecommendation] {
        let operationId = Self.getNextOperationId()
        print("🔍 RecommendationSupabaseService [\(operationId)]: Checking for status changes since: \(lastCheck)")

        do {
            // Get current session
            let session = try await supabaseManager.getSession()
            let userId = session.user.id

            // Query recommendations updated since last check
            let response: [RemoteRecommendation] = try await supabaseManager
                .from("user_recommendations")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("updated_at", value: lastCheck.ISO8601Format())
                .neq("status", value: 0) // Only check reviewed recommendations
                .execute()
                .value

            let updatedRecommendations = response.map { $0.toCloudRecommendation() }

            print("✅ RecommendationSupabaseService [\(operationId)]: Found \(updatedRecommendations.count) status changes")

            return updatedRecommendations

        } catch {
            print("❌ RecommendationSupabaseService [\(operationId)]: Failed to check status changes: \(error.localizedDescription)")
            throw RecommendationError.fetchFailed(error)
        }
    }

    // MARK: - Admin Methods (for future use)

    func getAllRecommendations() async throws -> [CloudRecommendation] {
        let operationId = Self.getNextOperationId()
        print("🔍 RecommendationSupabaseService [\(operationId)]: [ADMIN] Fetching ALL recommendations")

        do {
            let response: [RemoteRecommendation] = try await supabaseManager
                .from("user_recommendations")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            let recommendations = response.map { $0.toCloudRecommendation() }

            print("✅ RecommendationSupabaseService [\(operationId)]: [ADMIN] Retrieved \(recommendations.count) total recommendations")

            return recommendations

        } catch {
            print("❌ RecommendationSupabaseService [\(operationId)]: [ADMIN] Failed to fetch all recommendations: \(error.localizedDescription)")
            throw RecommendationError.fetchFailed(error)
        }
    }

    func updateRecommendationStatus(_ recommendation: CloudRecommendation, newStatus: RecommendationStatus, adminNotes: String? = nil) async throws -> CloudRecommendation {
        let operationId = Self.getNextOperationId()
        print("🔄 RecommendationSupabaseService [\(operationId)]: [ADMIN] Updating recommendation status to: \(newStatus.displayName)")

        do {
            // Create an updated recommendation model for the update
            let updatedRecommendation = recommendation.withStatus(newStatus, adminNotes: adminNotes).toRemoteRecommendation()

            let response: [RemoteRecommendation] = try await supabaseManager
                .from("user_recommendations")
                .update(updatedRecommendation)
                .eq("id", value: recommendation.id.uuidString)
                .select()
                .execute()
                .value

            guard let updatedRecommendation = response.first else {
                throw RecommendationError.updateFailed(
                    NSError(domain: "RecommendationSupabaseService", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "No updated record returned"])
                )
            }

            print("✅ RecommendationSupabaseService [\(operationId)]: [ADMIN] Successfully updated recommendation status")

            return updatedRecommendation.toCloudRecommendation()

        } catch {
            print("❌ RecommendationSupabaseService [\(operationId)]: [ADMIN] Failed to update recommendation status: \(error.localizedDescription)")
            throw RecommendationError.updateFailed(error)
        }
    }

    // MARK: - Helper Methods

    private static func getNextOperationId() -> String {
        operationCounter += 1
        return "rec_op_\(operationCounter)"
    }

    func clearLastError() {
        lastError = nil
    }
}

// MARK: - Error Types

enum RecommendationError: Error, LocalizedError {
    case authenticationRequired
    case submissionFailed(Error)
    case fetchFailed(Error)
    case updateFailed(Error)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Authentication is required. Please sign in to submit recommendations."
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
