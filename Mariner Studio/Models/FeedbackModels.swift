import Foundation
import SwiftUI

// MARK: - Feedback Models

/// Type of feedback being submitted
enum FeedbackType: String, CaseIterable {
    case general = "general"
    case featureRequest = "feature_request"

    var displayName: String {
        switch self {
        case .general:
            return "General Feedback"
        case .featureRequest:
            return "Feature Request"
        }
    }

    var description: String {
        switch self {
        case .general:
            return "Share your thoughts, report issues, or provide general feedback"
        case .featureRequest:
            return "Suggest new features or improvements to the app"
        }
    }
}

/// Status of feedback submission (matches Supabase table)
enum FeedbackStatus: String, CaseIterable {
    case new = "new"
    case reviewing = "reviewing"
    case resolved = "resolved"
    case wontFix = "wont_fix"
    case implemented = "implemented"

    var displayName: String {
        switch self {
        case .new:
            return "New"
        case .reviewing:
            return "Under Review"
        case .resolved:
            return "Resolved"
        case .wontFix:
            return "Won't Fix"
        case .implemented:
            return "Implemented"
        }
    }
}

/// Data structure for submitting feedback to Supabase
struct FeedbackSubmission {
    let feedbackType: FeedbackType
    let message: String
    let contactInfo: String?
    let isAnonymous: Bool
    let sourceView: String
    let appVersion: String
    let iosVersion: String
    let deviceModel: String
    let featureImportance: String?

    /// Initialize feedback submission with device info automatically populated
    /// - Parameters:
    ///   - feedbackType: Type of feedback being submitted
    ///   - message: User's feedback message
    ///   - contactInfo: Optional contact information
    ///   - isAnonymous: Whether submission should be anonymous
    ///   - sourceView: View the user came from
    ///   - featureImportance: Importance explanation for feature requests
    init(
        feedbackType: FeedbackType,
        message: String,
        contactInfo: String? = nil,
        isAnonymous: Bool = false,
        sourceView: String,
        featureImportance: String? = nil
    ) {
        self.feedbackType = feedbackType
        self.message = message
        self.contactInfo = isAnonymous ? nil : contactInfo
        self.isAnonymous = isAnonymous
        self.sourceView = sourceView
        self.featureImportance = featureImportance

        // Auto-populate device info
        self.appVersion = DeviceInfoHelper.getFullAppVersion()
        self.iosVersion = DeviceInfoHelper.getIOSVersion()
        self.deviceModel = DeviceInfoHelper.getDeviceModel()
    }

    /// Validate the feedback submission
    /// - Returns: Array of validation error messages (empty if valid)
    func validate() -> [String] {
        var errors: [String] = []

        // Message validation
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMessage.isEmpty {
            errors.append("Message cannot be empty")
        }
        if trimmedMessage.count > 500 {
            errors.append("Message cannot exceed 500 characters")
        }

        // Feature request specific validation
        if feedbackType == .featureRequest {
            if let importance = featureImportance {
                let trimmedImportance = importance.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedImportance.isEmpty {
                    errors.append("Please explain why this feature is important")
                }
                if trimmedImportance.count > 300 {
                    errors.append("Feature importance cannot exceed 300 characters")
                }
            } else {
                errors.append("Feature importance is required for feature requests")
            }
        }

        // Contact info validation (if not anonymous)
        if !isAnonymous {
            if let contact = contactInfo {
                let trimmedContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedContact.count > 255 {
                    errors.append("Contact info cannot exceed 255 characters")
                }
            }
        }

        return errors
    }

    /// Check if the submission is valid
    var isValid: Bool {
        return validate().isEmpty
    }
}

/// Response from feedback submission
struct FeedbackResponse {
    let success: Bool
    let message: String
    let errorDetails: String?

    /// Create success response
    static func success(_ message: String = "Feedback submitted successfully") -> FeedbackResponse {
        return FeedbackResponse(success: true, message: message, errorDetails: nil)
    }

    /// Create error response
    static func error(_ message: String, details: String? = nil) -> FeedbackResponse {
        return FeedbackResponse(success: false, message: message, errorDetails: details)
    }
}

/// Retrieved feedback record from Supabase (for admin use)
struct FeedbackRecord: Codable, Identifiable {
    let id: UUID
    let feedbackType: String
    let message: String
    let contactInfo: String?
    let isAnonymous: Bool
    let sourceView: String
    let appVersion: String
    let iosVersion: String?
    let deviceModel: String?
    let featureImportance: String?
    let status: String
    let adminNotes: String?
    let createdAt: Date
    let resolvedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case feedbackType = "feedback_type"
        case message
        case contactInfo = "contact_info"
        case isAnonymous = "is_anonymous"
        case sourceView = "source_view"
        case appVersion = "app_version"
        case iosVersion = "ios_version"
        case deviceModel = "device_model"
        case featureImportance = "feature_importance"
        case status
        case adminNotes = "admin_notes"
        case createdAt = "created_at"
        case resolvedAt = "resolved_at"
    }

    /// Get typed feedback type
    var feedbackTypeEnum: FeedbackType? {
        return FeedbackType(rawValue: feedbackType)
    }

    /// Get typed status
    var statusEnum: FeedbackStatus? {
        return FeedbackStatus(rawValue: status)
    }

    /// Formatted creation date
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

// MARK: - Feedback Form State Management

/// State management for feedback forms
class FeedbackFormState: ObservableObject {
    @Published var message: String = ""
    @Published var contactInfo: String = ""
    @Published var isAnonymous: Bool = false
    @Published var featureImportance: String = ""
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var showSuccess: Bool = false

    let feedbackType: FeedbackType
    let sourceView: String

    init(feedbackType: FeedbackType, sourceView: String) {
        self.feedbackType = feedbackType
        self.sourceView = sourceView
    }

    /// Create feedback submission from current state
    var submission: FeedbackSubmission {
        return FeedbackSubmission(
            feedbackType: feedbackType,
            message: message,
            contactInfo: contactInfo,
            isAnonymous: isAnonymous,
            sourceView: sourceView,
            featureImportance: feedbackType == .featureRequest ? featureImportance : nil
        )
    }

    /// Get validation errors for current state
    var validationErrors: [String] {
        return submission.validate()
    }

    /// Check if form is valid
    var isValid: Bool {
        return validationErrors.isEmpty
    }

    /// Character count for message field
    var messageCharacterCount: String {
        return "\(message.count)/500"
    }

    /// Character count for feature importance field
    var featureImportanceCharacterCount: String {
        return "\(featureImportance.count)/300"
    }

    /// Reset form to initial state
    func reset() {
        message = ""
        contactInfo = ""
        isAnonymous = false
        featureImportance = ""
        isSubmitting = false
        errorMessage = nil
        showSuccess = false
    }

    /// Handle anonymous toggle
    func toggleAnonymous() {
        isAnonymous.toggle()
        if isAnonymous {
            contactInfo = ""
        }
    }
}

// MARK: - Feedback Options

/// Available feedback options for the main feedback view
enum FeedbackOption: String, CaseIterable {
    case email = "email"
    case forums = "forums"
    case submitForm = "submit_form"
    case featureRequest = "feature_request"

    var title: String {
        switch self {
        case .email:
            return "Email Us"
        case .forums:
            return "Visit Forums"
        case .submitForm:
            return "Submit Feedback Form"
        case .featureRequest:
            return "Request a Feature"
        }
    }

    var description: String {
        switch self {
        case .email:
            return "Send direct email feedback"
        case .forums:
            return "Join community discussions"
        case .submitForm:
            return "Quick anonymous option"
        case .featureRequest:
            return "Suggest improvements"
        }
    }

    var iconName: String {
        switch self {
        case .email:
            return "envelope.fill"
        case .forums:
            return "bubble.left.and.bubble.right.fill"
        case .submitForm:
            return "square.and.pencil"
        case .featureRequest:
            return "lightbulb.fill"
        }
    }

    var iconColor: String {
        switch self {
        case .email:
            return "green"
        case .forums:
            return "purple"
        case .submitForm:
            return "blue"
        case .featureRequest:
            return "orange"
        }
    }
}