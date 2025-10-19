import Foundation
import Supabase

/// Data structure for submitting feedback to Supabase
/// Codable structure that matches the database schema
private struct FeedbackSubmissionData: Codable {
    let feedbackType: String
    let message: String
    let isAnonymous: Bool
    let sourceView: String
    let appVersion: String
    let iosVersion: String
    let deviceModel: String
    let contactInfo: String?
    let featureImportance: String?

    enum CodingKeys: String, CodingKey {
        case feedbackType = "feedback_type"
        case message
        case isAnonymous = "is_anonymous"
        case sourceView = "source_view"
        case appVersion = "app_version"
        case iosVersion = "ios_version"
        case deviceModel = "device_model"
        case contactInfo = "contact_info"
        case featureImportance = "feature_importance"
    }
}

/// Supabase manager for public route downloads and feedback submissions
/// No authentication functionality - only public data access
final class SupabaseManager {
    
    // MARK: - Shared Instance
    static let shared = SupabaseManager()
    
    // MARK: - Private Properties  
    private let client: SupabaseClient
    
    // MARK: - Initialization
    private init() {
        // Get secure configuration
        let config = AppConfiguration.shared
        
        // Validate Supabase configuration
        guard !config.supabaseURL.isEmpty else {
            fatalError("❌ SUPABASE: Missing SUPABASE_URL configuration")
        }
        
        guard !config.supabaseAnonKey.isEmpty else {
            fatalError("❌ SUPABASE: Missing SUPABASE_ANON_KEY configuration")
        }
        
        guard let url = URL(string: config.supabaseURL) else {
            fatalError("❌ SUPABASE: Invalid SUPABASE_URL: \(config.supabaseURL)")
        }
        
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: config.supabaseAnonKey)
        DebugLogger.shared.log("✅ SUPABASE: Initialized for routes and feedback", category: "SUPABASE_INIT")
    }
    
    // MARK: - Public Routes Access
    
    /// Retrieve all embedded routes from the public Supabase table
    /// Used for browsing available routes from the cloud database
    /// - Parameter limit: Optional limit on number of routes to fetch (default: no limit)
    /// - Returns: Array of all embedded routes
    /// - Throws: Database errors or network issues
    func getEmbeddedRoutes(limit: Int? = nil) async throws -> [RemoteEmbeddedRoute] {
        DebugLogger.shared.log("📥🛣️ ROUTES: Fetching public embedded routes", category: "SUPABASE_ROUTES")
        
        do {
            var query = client
                .from("embedded_routes")
                .select("*")
                .eq("is_active", value: true) // Only fetch active routes
                .order("created_at", ascending: false)
            
            if let limit = limit {
                query = query.limit(limit)
            }
            
            let response: PostgrestResponse<[RemoteEmbeddedRoute]> = try await query.execute()
            
            DebugLogger.shared.log("✅ ROUTES: Fetched \(response.value.count) embedded routes", category: "SUPABASE_ROUTES")
            return response.value
            
        } catch {
            DebugLogger.shared.log("❌ ROUTES: Failed to fetch embedded routes: \(error)", category: "SUPABASE_ROUTES")
            throw error
        }
    }

    // MARK: - Feedback Submission

    /// Submit user feedback to Supabase
    /// Matches Android SupabaseService.submitFeedback() functionality
    /// - Parameters:
    ///   - feedbackType: "general" or "feature_request"
    ///   - message: User's feedback message
    ///   - contactInfo: Optional email/name for followup
    ///   - isAnonymous: Whether to hide contact info
    ///   - sourceView: The view user came from
    ///   - appVersion: App version string
    ///   - iosVersion: iOS version
    ///   - deviceModel: Device manufacturer and model
    ///   - featureImportance: Only for feature requests
    /// - Returns: Result with success message or error
    func submitFeedback(
        feedbackType: String,
        message: String,
        contactInfo: String?,
        isAnonymous: Bool,
        sourceView: String,
        appVersion: String,
        iosVersion: String,
        deviceModel: String,
        featureImportance: String? = nil
    ) async -> Result<String, Error> {

        DebugLogger.shared.log("📝 FEEDBACK: Submitting \(feedbackType) feedback from \(sourceView)", category: "SUPABASE_FEEDBACK")

        do {
            // Build feedback data structure
            let feedbackData = FeedbackSubmissionData(
                feedbackType: feedbackType,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                isAnonymous: isAnonymous,
                sourceView: sourceView,
                appVersion: appVersion,
                iosVersion: iosVersion,
                deviceModel: deviceModel,
                contactInfo: isAnonymous ? nil : contactInfo?.trimmingCharacters(in: .whitespacesAndNewlines),
                featureImportance: feedbackType == "feature_request" ? featureImportance?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
            )

            // Submit to Supabase
            try await client
                .from("feedback")
                .insert(feedbackData)
                .execute()

            DebugLogger.shared.log("✅ FEEDBACK: Feedback submitted successfully", category: "SUPABASE_FEEDBACK")
            return .success("Feedback submitted successfully")

        } catch {
            DebugLogger.shared.log("❌ FEEDBACK: Failed to submit feedback: \(error)", category: "SUPABASE_FEEDBACK")
            return .failure(error)
        }
    }

    // MARK: - Admin Functions (Future Implementation)

    /// Retrieve all feedback submissions (for future admin use)
    /// This method is not implemented yet - will be added when admin functionality is needed
    /// - Returns: Error indicating not implemented
    func getAllFeedback() async throws -> [String] {
        DebugLogger.shared.log("📥 FEEDBACK: Admin feedback retrieval not yet implemented", category: "SUPABASE_FEEDBACK")
        throw NSError(domain: "FeedbackError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Admin feedback retrieval will be implemented in future updates"])
    }
}