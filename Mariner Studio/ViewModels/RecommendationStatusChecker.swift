import Foundation
import SwiftUI

// Service to check for recommendation status changes and notify users
class RecommendationStatusChecker: ObservableObject {

    // MARK: - Published Properties
    @Published var hasStatusChanges: Bool = false
    @Published var statusChangeMessage: String = ""
    @Published var updatedRecommendations: [CloudRecommendation] = []

    // MARK: - Private Properties
    private let recommendationService: RecommendationCloudService
    private let userDefaults = UserDefaults.standard
    private static let lastCheckKey = "last_recommendation_status_check"

    // MARK: - Initialization
    init(recommendationService: RecommendationCloudService) {
        self.recommendationService = recommendationService
        print("🔔 RecommendationStatusChecker: Initialized")
    }

    // MARK: - Public Methods

    func checkForStatusChanges() async {
        print("🔍 RecommendationStatusChecker: Checking for status changes...")

        do {
            let lastCheckDate = getLastCheckDate()
            print("🔍 RecommendationStatusChecker: Last check was: \(lastCheckDate)")

            // Only check if we have a service that supports status checking
            guard let supabaseService = recommendationService as? RecommendationSupabaseService else {
                print("⚠️ RecommendationStatusChecker: Service doesn't support status checking")
                return
            }

            let changedRecommendations = try await supabaseService.checkForRecommendationStatusChanges(since: lastCheckDate)

            await MainActor.run {
                if !changedRecommendations.isEmpty {
                    self.hasStatusChanges = true
                    self.updatedRecommendations = changedRecommendations
                    self.statusChangeMessage = self.generateStatusChangeMessage(for: changedRecommendations)

                    print("🔔 RecommendationStatusChecker: Found \(changedRecommendations.count) status changes")
                    print("🔔 RecommendationStatusChecker: Message: \(self.statusChangeMessage)")
                } else {
                    self.hasStatusChanges = false
                    self.updatedRecommendations = []
                    self.statusChangeMessage = ""
                    print("✅ RecommendationStatusChecker: No status changes found")
                }
            }

            // Update last check time
            updateLastCheckDate()

        } catch {
            print("❌ RecommendationStatusChecker: Failed to check status changes: \(error.localizedDescription)")
            await MainActor.run {
                self.hasStatusChanges = false
                self.updatedRecommendations = []
                self.statusChangeMessage = ""
            }
        }
    }

    func markStatusChangesAsViewed() {
        hasStatusChanges = false
        statusChangeMessage = ""
        updatedRecommendations = []
        print("👁️ RecommendationStatusChecker: Status changes marked as viewed")
    }

    func shouldCheckForChanges() -> Bool {
        let lastCheck = getLastCheckDate()
        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)

        // Check if it's been more than 1 hour since last check
        let shouldCheck = timeSinceLastCheck > 3600 // 1 hour in seconds

        print("🕐 RecommendationStatusChecker: Time since last check: \(timeSinceLastCheck / 60) minutes")
        print("🤔 RecommendationStatusChecker: Should check: \(shouldCheck)")

        return shouldCheck
    }

    // MARK: - Private Methods

    private func getLastCheckDate() -> Date {
        let timestamp = userDefaults.double(forKey: Self.lastCheckKey)
        if timestamp == 0 {
            // If no previous check, start from 7 days ago to avoid overwhelming users
            return Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func updateLastCheckDate() {
        userDefaults.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)
        print("💾 RecommendationStatusChecker: Updated last check timestamp")
    }

    private func generateStatusChangeMessage(for recommendations: [CloudRecommendation]) -> String {
        let approvedCount = recommendations.filter { $0.status == .approved }.count
        let rejectedCount = recommendations.filter { $0.status == .rejected }.count

        var messageParts: [String] = []

        if approvedCount > 0 {
            if approvedCount == 1 {
                messageParts.append("1 recommendation was approved")
            } else {
                messageParts.append("\(approvedCount) recommendations were approved")
            }
        }

        if rejectedCount > 0 {
            if rejectedCount == 1 {
                messageParts.append("1 recommendation was not applied")
            } else {
                messageParts.append("\(rejectedCount) recommendations were not applied")
            }
        }

        if messageParts.isEmpty {
            return "Your recommendations have been updated"
        } else if messageParts.count == 1 {
            return messageParts[0] + "."
        } else {
            return messageParts.joined(separator: " and ") + "."
        }
    }

    // MARK: - Helper Methods for UI

    func getStatusChangeSummary() -> (approved: Int, rejected: Int) {
        let approved = updatedRecommendations.filter { $0.status == .approved }.count
        let rejected = updatedRecommendations.filter { $0.status == .rejected }.count
        return (approved: approved, rejected: rejected)
    }

    func getStatusChangeDetails() -> [(String, RecommendationStatus)] {
        return updatedRecommendations.map { recommendation in
            return (recommendation.navUnitName, recommendation.status)
        }
    }

    // MARK: - Force Check (for debugging)

    func forceStatusCheck() async {
        print("🔧 RecommendationStatusChecker: Force checking status changes...")

        // Reset last check to force a check
        userDefaults.removeObject(forKey: Self.lastCheckKey)

        await checkForStatusChanges()
    }
}

// MARK: - View Extension for Easy Integration

extension View {
    func withRecommendationStatusChecker(_ checker: RecommendationStatusChecker) -> some View {
        self.onAppear {
            Task {
                if checker.shouldCheckForChanges() {
                    await checker.checkForStatusChanges()
                }
            }
        }
        .alert("Recommendation Updates", isPresented: .constant(checker.hasStatusChanges)) {
            Button("View Recommendations") {
                checker.markStatusChangesAsViewed()
                // Note: Navigation to recommendations view should be handled by the parent view
            }
            Button("Dismiss") {
                checker.markStatusChangesAsViewed()
            }
        } message: {
            Text(checker.statusChangeMessage)
        }
    }
}

// MARK: - Service Integration

extension ServiceProvider {
    func createRecommendationStatusChecker() -> RecommendationStatusChecker {
        return RecommendationStatusChecker(recommendationService: self.recommendationService)
    }
}
