import Foundation
import UIKit

// MARK: - Recommendation Category Enum
enum RecommendationCategory: String, CaseIterable {
    case contactInfo = "contact_info"
    case facilityDetails = "facility_details"
    case operatingStatus = "operating_status"
    case accessNavigation = "access_navigation"
    case generalInfo = "general_info"
    
    var displayName: String {
        switch self {
        case .contactInfo:
            return "Contact Information"
        case .facilityDetails:
            return "Facility Details"
        case .operatingStatus:
            return "Operating Status"
        case .accessNavigation:
            return "Access & Navigation"
        case .generalInfo:
            return "General Information"
        }
    }
    
    var description: String {
        switch self {
        case .contactInfo:
            return "Phone numbers, operators, owners"
        case .facilityDetails:
            return "Name, type, specifications"
        case .operatingStatus:
            return "Current operations, closures"
        case .accessNavigation:
            return "Approach, depths, restrictions"
        case .generalInfo:
            return "Other information updates"
        }
    }
    
    var iconName: String {
        switch self {
        case .contactInfo:
            return "phone.fill"
        case .facilityDetails:
            return "building.2.fill"
        case .operatingStatus:
            return "clock.fill"
        case .accessNavigation:
            return "location.fill"
        case .generalInfo:
            return "info.circle.fill"
        }
    }
}

// Model representing a recommendation stored in Supabase
struct RemoteRecommendation: Codable, Identifiable {
    let id: UUID?
    let userId: UUID
    let navUnitId: String
    let navUnitName: String
    let category: String
    let description: String
    let userEmail: String?
    let status: Int
    let createdAt: Date?
    let reviewedAt: Date?
    let adminNotes: String?
    let updatedAt: Date?
    let lastModified: Date
    let deviceId: String
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case navUnitId = "nav_unit_id"
        case navUnitName = "nav_unit_name"
        case category
        case description
        case userEmail = "user_email"
        case status
        case createdAt = "created_at"
        case reviewedAt = "reviewed_at"
        case adminNotes = "admin_notes"
        case updatedAt = "updated_at"
        case lastModified = "last_modified"
        case deviceId = "device_id"
    }
    
    // MARK: - Initializers
    
    // Initialize for new recommendation
    init(
        userId: UUID,
        navUnitId: String,
        navUnitName: String,
        category: RecommendationCategory,
        description: String,
        userEmail: String? = nil
    ) {
        self.id = nil // Let Supabase generate
        self.userId = userId
        self.navUnitId = navUnitId
        self.navUnitName = navUnitName
        self.category = category.rawValue
        self.description = description
        self.userEmail = userEmail
        self.status = RecommendationStatus.pending.rawValue
        self.createdAt = nil // Let Supabase generate
        self.reviewedAt = nil
        self.adminNotes = nil
        self.updatedAt = nil // Let Supabase generate
        self.lastModified = Date()
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
    
    // Initialize from existing data (for updates)
    init(
        id: UUID?,
        userId: UUID,
        navUnitId: String,
        navUnitName: String,
        category: String,
        description: String,
        userEmail: String?,
        status: Int,
        createdAt: Date?,
        reviewedAt: Date?,
        adminNotes: String?,
        updatedAt: Date?,
        lastModified: Date,
        deviceId: String
    ) {
        self.id = id
        self.userId = userId
        self.navUnitId = navUnitId
        self.navUnitName = navUnitName
        self.category = category
        self.description = description
        self.userEmail = userEmail
        self.status = status
        self.createdAt = createdAt
        self.reviewedAt = reviewedAt
        self.adminNotes = adminNotes
        self.updatedAt = updatedAt
        self.lastModified = lastModified
        self.deviceId = deviceId
    }
    
    // MARK: - Computed Properties
    
    var recommendationCategory: RecommendationCategory {
        return RecommendationCategory(rawValue: category) ?? .generalInfo
    }
    
    var recommendationStatus: RecommendationStatus {
        return RecommendationStatus(rawValue: status) ?? .pending
    }
    
    // MARK: - Helper Methods
    
    func withUpdatedStatus(_ newStatus: RecommendationStatus, adminNotes: String? = nil) -> RemoteRecommendation {
        return RemoteRecommendation(
            id: self.id,
            userId: self.userId,
            navUnitId: self.navUnitId,
            navUnitName: self.navUnitName,
            category: self.category,
            description: self.description,
            userEmail: self.userEmail,
            status: newStatus.rawValue,
            createdAt: self.createdAt,
            reviewedAt: Date(),
            adminNotes: adminNotes,
            updatedAt: Date(),
            lastModified: Date(),
            deviceId: self.deviceId
        )
    }
    
    // Convert to the CloudRecommendation interface for ViewModels
    func toCloudRecommendation() -> CloudRecommendation {
        return CloudRecommendation(
            id: self.id ?? UUID(),
            navUnitId: self.navUnitId,
            navUnitName: self.navUnitName,
            category: self.recommendationCategory,
            description: self.description,
            userEmail: self.userEmail,
            status: self.recommendationStatus,
            createdAt: self.createdAt ?? Date(),
            reviewedAt: self.reviewedAt,
            adminNotes: self.adminNotes
        )
    }
}

// MARK: - CloudRecommendation Bridge Model
// This maintains compatibility with existing ViewModels
struct CloudRecommendation: Identifiable {
    let id: UUID
    let navUnitId: String
    let navUnitName: String
    let category: RecommendationCategory
    let description: String
    let userEmail: String?
    let status: RecommendationStatus
    let createdAt: Date
    let reviewedAt: Date?
    let adminNotes: String?
    
    // Initialize from new recommendation
    init(
        navUnitId: String,
        navUnitName: String,
        category: RecommendationCategory,
        description: String,
        userEmail: String? = nil
    ) {
        self.id = UUID()
        self.navUnitId = navUnitId
        self.navUnitName = navUnitName
        self.category = category
        self.description = description
        self.userEmail = userEmail
        self.status = .pending
        self.createdAt = Date()
        self.reviewedAt = nil
        self.adminNotes = nil
    }
    
    // Initialize from existing data
    init(
        id: UUID,
        navUnitId: String,
        navUnitName: String,
        category: RecommendationCategory,
        description: String,
        userEmail: String?,
        status: RecommendationStatus,
        createdAt: Date,
        reviewedAt: Date?,
        adminNotes: String?
    ) {
        self.id = id
        self.navUnitId = navUnitId
        self.navUnitName = navUnitName
        self.category = category
        self.description = description
        self.userEmail = userEmail
        self.status = status
        self.createdAt = createdAt
        self.reviewedAt = reviewedAt
        self.adminNotes = adminNotes
    }
    
    // Helper method to create updated recommendation with new status
    func withStatus(_ newStatus: RecommendationStatus, adminNotes: String? = nil) -> CloudRecommendation {
        return CloudRecommendation(
            id: self.id,
            navUnitId: self.navUnitId,
            navUnitName: self.navUnitName,
            category: self.category,
            description: self.description,
            userEmail: self.userEmail,
            status: newStatus,
            createdAt: self.createdAt,
            reviewedAt: Date(),
            adminNotes: adminNotes
        )
    }
    
    // Convert to RemoteRecommendation for database operations
    func toRemoteRecommendation() -> RemoteRecommendation {
        return RemoteRecommendation(
            id: self.id,
            userId: UUID(), // This will be ignored in updates
            navUnitId: self.navUnitId,
            navUnitName: self.navUnitName,
            category: self.category.rawValue,
            description: self.description,
            userEmail: self.userEmail,
            status: self.status.rawValue,
            createdAt: self.createdAt,
            reviewedAt: self.reviewedAt,
            adminNotes: self.adminNotes,
            updatedAt: Date(),
            lastModified: Date(),
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        )
    }
}