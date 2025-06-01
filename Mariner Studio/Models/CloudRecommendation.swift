import Foundation
import CloudKit

// Model representing a recommendation stored in CloudKit
struct CloudRecommendation: Identifiable {
    let id: UUID
    let recordID: CKRecord.ID?
    let navUnitId: String
    let navUnitName: String
    let category: RecommendationCategory
    let description: String
    let userEmail: String? // Optional user contact
    let status: RecommendationStatus
    let createdAt: Date
    let reviewedAt: Date?
    let adminNotes: String?
    
    // CloudKit record type name
    static let recordType = "NavUnitRecommendation"
    
    // CloudKit field names
    struct FieldKeys {
        static let id = "id"
        static let navUnitId = "navUnitId"
        static let navUnitName = "navUnitName"
        static let category = "category"
        static let description = "description"
        static let userEmail = "userEmail"
        static let status = "status"
        static let createdAt = "createdAt"
        static let reviewedAt = "reviewedAt"
        static let adminNotes = "adminNotes"
    }
    
    // Initialize for new recommendation
    init(
        navUnitId: String,
        navUnitName: String,
        category: RecommendationCategory,
        description: String,
        userEmail: String? = nil
    ) {
        self.id = UUID()
        self.recordID = nil
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
    
    // Initialize from CloudKit record
    init?(from record: CKRecord) {
        guard let idString = record[CloudRecommendation.FieldKeys.id] as? String,
              let id = UUID(uuidString: idString),
              let navUnitId = record[CloudRecommendation.FieldKeys.navUnitId] as? String,
              let navUnitName = record[CloudRecommendation.FieldKeys.navUnitName] as? String,
              let categoryRaw = record[CloudRecommendation.FieldKeys.category] as? String,
              let category = RecommendationCategory(rawValue: categoryRaw),
              let description = record[CloudRecommendation.FieldKeys.description] as? String,
              let statusRaw = record[CloudRecommendation.FieldKeys.status] as? Int,
              let status = RecommendationStatus(rawValue: statusRaw),
              let createdAt = record[CloudRecommendation.FieldKeys.createdAt] as? Date else {
            return nil
        }
        
        self.id = id
        self.recordID = record.recordID
        self.navUnitId = navUnitId
        self.navUnitName = navUnitName
        self.category = category
        self.description = description
        self.userEmail = record[CloudRecommendation.FieldKeys.userEmail] as? String
        self.status = status
        self.createdAt = createdAt
        self.reviewedAt = record[CloudRecommendation.FieldKeys.reviewedAt] as? Date
        self.adminNotes = record[CloudRecommendation.FieldKeys.adminNotes] as? String
    }
    
    // Convert to CloudKit record
    func toCKRecord() -> CKRecord {
        let record: CKRecord
        
        if let recordID = recordID {
            record = CKRecord(recordType: CloudRecommendation.recordType, recordID: recordID)
        } else {
            record = CKRecord(recordType: CloudRecommendation.recordType)
        }
        
        record[CloudRecommendation.FieldKeys.id] = id.uuidString
        record[CloudRecommendation.FieldKeys.navUnitId] = navUnitId
        record[CloudRecommendation.FieldKeys.navUnitName] = navUnitName
        record[CloudRecommendation.FieldKeys.category] = category.rawValue
        record[CloudRecommendation.FieldKeys.description] = description
        record[CloudRecommendation.FieldKeys.userEmail] = userEmail
        record[CloudRecommendation.FieldKeys.status] = status.rawValue
        record[CloudRecommendation.FieldKeys.createdAt] = createdAt
        record[CloudRecommendation.FieldKeys.reviewedAt] = reviewedAt
        record[CloudRecommendation.FieldKeys.adminNotes] = adminNotes
        
        return record
    }
    
    // Helper method to create updated recommendation with new status
    func withStatus(_ newStatus: RecommendationStatus, adminNotes: String? = nil) -> CloudRecommendation {
        return CloudRecommendation(
            id: self.id,
            recordID: self.recordID,
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
    
    // Private initializer for creating updated recommendations
    private init(
        id: UUID,
        recordID: CKRecord.ID?,
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
        self.recordID = recordID
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
}

// Recommendation categories
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

// Note: RecommendationStatus extensions are in ServiceExtensions.swift to avoid conflicts with CaseIterable
