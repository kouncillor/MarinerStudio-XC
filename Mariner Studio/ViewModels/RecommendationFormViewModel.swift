//
//  RecommendationFormViewModel.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 6/1/25.
//


import Foundation
import SwiftUI
import Combine

class RecommendationFormViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var submissionSuccess: Bool = false
    
    // MARK: - Properties
    let navUnit: NavUnit
    private let recommendationService: RecommendationCloudService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(navUnit: NavUnit, recommendationService: RecommendationCloudService) {
        self.navUnit = navUnit
        self.recommendationService = recommendationService
        
        print("📝 RecommendationFormViewModel: Initialized for nav unit: \(navUnit.navUnitName)")
        
        // Monitor service state changes
        if let service = recommendationService as? RecommendationCloudServiceImpl {
            service.$isSubmitting
                .receive(on: DispatchQueue.main)
                .assign(to: \.isSubmitting, on: self)
                .store(in: &cancellables)
            
            service.$lastError
                .receive(on: DispatchQueue.main)
                .assign(to: \.errorMessage, on: self)
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Public Methods
    
    func submitRecommendation(
        category: RecommendationCategory,
        description: String,
        userEmail: String? = nil
    ) async -> Bool {
        print("🚀 RecommendationFormViewModel: Starting submission process")
        print("📝   Category: \(category.displayName)")
        print("📝   Nav Unit: \(navUnit.navUnitName) (\(navUnit.navUnitId))")
        print("📝   Description length: \(description.count) chars")
        print("📝   User email: \(userEmail ?? "none provided")")
        
        // Validate input
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else {
            await setError("Description cannot be empty")
            return false
        }
        
        guard trimmedDescription.count <= 500 else {
            await setError("Description must be 500 characters or less")
            return false
        }
        
        // Check account status first
        let accountStatus = await recommendationService.checkAccountStatus()
        guard accountStatus == .available else {
            await setError("iCloud account not available. Please sign in to iCloud and try again.")
            return false
        }
        
        await MainActor.run {
            isSubmitting = true
            errorMessage = nil
            submissionSuccess = false
        }
        
        do {
            // Create recommendation
            let recommendation = CloudRecommendation(
                navUnitId: navUnit.navUnitId,
                navUnitName: navUnit.navUnitName,
                category: category,
                description: trimmedDescription,
                userEmail: userEmail?.isEmpty == false ? userEmail : nil
            )
            
            print("☁️ RecommendationFormViewModel: Submitting to CloudKit...")
            let recordID = try await recommendationService.submitRecommendation(recommendation)
            
            print("🎉 RecommendationFormViewModel: Submission successful!")
            print("🎉   Record ID: \(recordID)")
            
            await MainActor.run {
                isSubmitting = false
                submissionSuccess = true
                errorMessage = nil
            }
            
            // Log successful submission for analytics/debugging
            logSuccessfulSubmission(category: category, navUnitId: navUnit.navUnitId)
            
            return true
            
        } catch {
            print("💥 RecommendationFormViewModel: Submission failed!")
            print("💥   Error: \(error.localizedDescription)")
            
            if let recommendationError = error as? RecommendationError {
                await setError(recommendationError.errorDescription ?? "Unknown error occurred")
            } else {
                await setError("Failed to submit recommendation. Please check your internet connection and try again.")
            }
            
            await MainActor.run {
                isSubmitting = false
                submissionSuccess = false
            }
            
            return false
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func resetForm() {
        isSubmitting = false
        errorMessage = nil
        submissionSuccess = false
    }
    
    // MARK: - Validation Helpers
    
    func isValidDescription(_ description: String) -> Bool {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 500
    }
    
    func isValidEmail(_ email: String) -> Bool {
        // If email is empty, it's considered valid (optional field)
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        
        // Basic email validation
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    func canSubmit(description: String, email: String) -> Bool {
        return isValidDescription(description) && 
               isValidEmail(email) && 
               !isSubmitting
    }
    
    // MARK: - UI Helper Methods
    
    func getDescriptionCountColor(for description: String) -> Color {
        let count = description.count
        if count > 500 {
            return .red
        } else if count > 450 {
            return .orange
        } else {
            return .secondary
        }
    }
    
    func getSubmitButtonText() -> String {
        if isSubmitting {
            return "Submitting..."
        } else {
            return "Submit Recommendation"
        }
    }
    
    // MARK: - Private Methods
    
    private func setError(_ message: String) async {
        await MainActor.run {
            errorMessage = message
            isSubmitting = false
            submissionSuccess = false
        }
    }
    
    private func logSuccessfulSubmission(category: RecommendationCategory, navUnitId: String) {
        print("📊 RecommendationFormViewModel: SUBMISSION ANALYTICS")
        print("📊   Nav Unit ID: \(navUnitId)")
        print("📊   Category: \(category.rawValue)")
        print("📊   Timestamp: \(Date().ISO8601Format())")
        
        // In a real app, you might send this to analytics service
        // Analytics.track("recommendation_submitted", properties: [
        //     "nav_unit_id": navUnitId,
        //     "category": category.rawValue
        // ])
    }
    
    deinit {
        print("🗑️ RecommendationFormViewModel: Deinitialized")
    }
}

// MARK: - Form State Helper

extension RecommendationFormViewModel {
    /// Convenience method to check if form can be submitted with current state
    func validateForm(description: String, email: String) -> (isValid: Bool, errorMessage: String?) {
        // Check description
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDescription.isEmpty {
            return (false, "Please enter a description")
        }
        
        if trimmedDescription.count > 500 {
            return (false, "Description must be 500 characters or less")
        }
        
        // Check email if provided
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEmail.isEmpty && !isValidEmail(trimmedEmail) {
            return (false, "Please enter a valid email address")
        }
        
        // Check if currently submitting
        if isSubmitting {
            return (false, "Submission in progress")
        }
        
        return (true, nil)
    }
}

// MARK: - Category Helper

extension RecommendationFormViewModel {
    /// Get recommended categories based on nav unit type
    func getRecommendedCategories() -> [RecommendationCategory] {
        // Could customize recommendations based on facility type
        guard let facilityType = navUnit.facilityType?.lowercased() else {
            return RecommendationCategory.allCases
        }
        
        var recommended: [RecommendationCategory] = []
        
        // Facility-specific recommendations
        if facilityType.contains("marina") || facilityType.contains("dock") {
            recommended.append(.facilityDetails)
            recommended.append(.contactInfo)
            recommended.append(.operatingStatus)
        }
        
        if facilityType.contains("terminal") || facilityType.contains("port") {
            recommended.append(.operatingStatus)
            recommended.append(.accessNavigation)
            recommended.append(.facilityDetails)
        }
        
        // Always include general info
        if !recommended.contains(.generalInfo) {
            recommended.append(.generalInfo)
        }
        
        // Add remaining categories
        for category in RecommendationCategory.allCases {
            if !recommended.contains(category) {
                recommended.append(category)
            }
        }
        
        return recommended
    }
    
    /// Get example text for a category
    func getExampleText(for category: RecommendationCategory) -> String {
        switch category {
        case .contactInfo:
            return "The phone number has changed to (555) 123-4567. The marina is now operated by Harbor Master Inc."
        case .facilityDetails:
            return "The dock name has changed from 'Old Harbor Marina' to 'Seaside Yacht Club'. The facility now has 50 slips instead of 30."
        case .operatingStatus:
            return "The dock is temporarily closed for repairs until March 2024. Contact the harbormaster for alternative docking."
        case .accessNavigation:
            return "Due to recent storms, the approach depth is now 8 feet at mean low water instead of 10 feet. Approach from the south."
        case .generalInfo:
            return "The facility now offers fuel services and has a new ship store. WiFi is available for boaters."
        }
    }
}