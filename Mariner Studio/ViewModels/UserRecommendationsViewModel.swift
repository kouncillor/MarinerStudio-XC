//
//  UserRecommendationsViewModel.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 6/1/25.
//


import Foundation
import SwiftUI
import Combine
import CloudKit

class UserRecommendationsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var recommendations: [CloudRecommendation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var lastRefreshTime: Date?
    
    // MARK: - Computed Properties
    var pendingCount: Int {
        recommendations.filter { $0.status == .pending }.count
    }
    
    var approvedCount: Int {
        recommendations.filter { $0.status == .approved }.count
    }
    
    var rejectedCount: Int {
        recommendations.filter { $0.status == .rejected }.count
    }
    
    var totalCount: Int {
        recommendations.count
    }
    
    var hasRecommendations: Bool {
        !recommendations.isEmpty
    }
    
    var mostRecentRecommendation: CloudRecommendation? {
        recommendations.max(by: { $0.createdAt < $1.createdAt })
    }
    
    var oldestPendingRecommendation: CloudRecommendation? {
        recommendations
            .filter { $0.status == .pending }
            .min(by: { $0.createdAt < $1.createdAt })
    }
    
    // MARK: - Private Properties
    private var recommendationService: RecommendationCloudService?
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    // MARK: - Initialization
    init() {
        print("📋 UserRecommendationsViewModel: Initialized")
        setupAutoRefresh()
    }
    
    // MARK: - Service Injection
    func initialize(recommendationService: RecommendationCloudService) {
        self.recommendationService = recommendationService
        print("📋 UserRecommendationsViewModel: RecommendationCloudService injected")
        
        // Monitor service state if it's the implementation class
        if let service = recommendationService as? RecommendationCloudServiceImpl {
            service.$accountStatus
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    self?.handleAccountStatusChange(status)
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Public Methods
    
    func loadRecommendations() async {
        print("🔄 UserRecommendationsViewModel: Loading user recommendations...")
        
        guard let service = recommendationService else {
            await setError("Recommendation service not available")
            return
        }
        
        await MainActor.run {
            if recommendations.isEmpty {
                isLoading = true
            }
            errorMessage = ""
        }
        
        do {
            let userRecommendations = try await service.getUserRecommendations()
            
            await MainActor.run {
                self.recommendations = userRecommendations.sorted { $0.createdAt > $1.createdAt }
                self.isLoading = false
                self.lastRefreshTime = Date()
                self.errorMessage = ""
                
                print("✅ UserRecommendationsViewModel: Loaded \(userRecommendations.count) recommendations")
                self.logRecommendationsStats()
            }
            
        } catch {
            print("❌ UserRecommendationsViewModel: Failed to load recommendations: \(error.localizedDescription)")
            
            await MainActor.run {
                self.isLoading = false
                if let recommendationError = error as? RecommendationError {
                    self.errorMessage = recommendationError.errorDescription ?? "Failed to load recommendations"
                } else {
                    self.errorMessage = "Unable to load recommendations. Please check your internet connection and try again."
                }
            }
        }
    }
    
    func refreshRecommendations() async {
        print("🔄 UserRecommendationsViewModel: Manual refresh triggered")
        await loadRecommendations()
    }
    
    func clearError() {
        errorMessage = ""
    }
    
    func retry() async {
        await loadRecommendations()
    }
    
    // MARK: - Filtering and Sorting
    
    func getRecommendations(for status: RecommendationStatus) -> [CloudRecommendation] {
        return recommendations
            .filter { $0.status == status }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    func getRecommendations(for category: RecommendationCategory) -> [CloudRecommendation] {
        return recommendations
            .filter { $0.category == category }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    func getRecommendationsForNavUnit(_ navUnitId: String) -> [CloudRecommendation] {
        return recommendations
            .filter { $0.navUnitId == navUnitId }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Analytics and Stats
    
    func getCategoryStats() -> [(category: RecommendationCategory, count: Int)] {
        let categoryGroups = Dictionary(grouping: recommendations) { $0.category }
        return categoryGroups.map { (category: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
    
    func getMonthlyStats() -> [(month: String, count: Int)] {
        let calendar = Calendar.current
        let monthGroups = Dictionary(grouping: recommendations) { recommendation in
            calendar.dateComponents([.year, .month], from: recommendation.createdAt)
        }
        
        return monthGroups.compactMap { components, recommendations in
            guard let year = components.year, let month = components.month else { return nil }
            let monthName = DateFormatter().monthSymbols[month - 1]
            return (month: "\(monthName) \(year)", count: recommendations.count)
        }
        .sorted { $0.month > $1.month }
    }
    
    func getAverageResponseTime() -> TimeInterval? {
        let reviewedRecommendations = recommendations.filter { $0.reviewedAt != nil }
        guard !reviewedRecommendations.isEmpty else { return nil }
        
        let totalResponseTime = reviewedRecommendations.reduce(0.0) { total, recommendation in
            guard let reviewedAt = recommendation.reviewedAt else { return total }
            return total + reviewedAt.timeIntervalSince(recommendation.createdAt)
        }
        
        return totalResponseTime / Double(reviewedRecommendations.count)
    }
    
    // MARK: - UI Helper Methods
    
    func getStatusText() -> String {
        if isLoading {
            return "Loading..."
        } else if hasRecommendations {
            return "Last updated \(formatLastRefreshTime())"
        } else {
            return "No recommendations"
        }
    }
    
    func getEmptyStateTitle() -> String {
        if isLoading {
            return "Loading Recommendations"
        } else if !errorMessage.isEmpty {
            return "Unable to Load"
        } else {
            return "No Recommendations Yet"
        }
    }
    
    func formatLastRefreshTime() -> String {
        guard let lastRefreshTime = lastRefreshTime else { return "never" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastRefreshTime, relativeTo: Date())
    }
    
    // MARK: - Auto Refresh
    
    private func setupAutoRefresh() {
        // Refresh every 5 minutes when app is active
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only auto-refresh if we have recommendations and no error
            if self.hasRecommendations && self.errorMessage.isEmpty {
                Task {
                    await self.loadRecommendations()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setError(_ message: String) async {
        await MainActor.run {
            errorMessage = message
            isLoading = false
        }
    }
    
    private func handleAccountStatusChange(_ status: CKAccountStatus) {
        print("📋 UserRecommendationsViewModel: Account status changed to: \(status)")
        
        if status == .available && recommendations.isEmpty && errorMessage.isEmpty {
            // Account became available and we don't have data yet
            Task {
                await loadRecommendations()
            }
        } else if status != .available && !errorMessage.isEmpty {
            // Account became unavailable
            Task {
                await setError("iCloud account not available. Please sign in to iCloud to view your recommendations.")
            }
        }
    }
    
    private func logRecommendationsStats() {
        print("📊 UserRecommendationsViewModel: RECOMMENDATIONS STATS")
        print("📊   Total: \(totalCount)")
        print("📊   Pending: \(pendingCount)")
        print("📊   Approved: \(approvedCount)")
        print("📊   Rejected: \(rejectedCount)")
        
        if let avgResponseTime = getAverageResponseTime() {
            let days = avgResponseTime / (24 * 60 * 60)
            print("📊   Avg Response Time: \(String(format: "%.1f", days)) days")
        }
        
        let categoryStats = getCategoryStats()
        print("📊   Category Breakdown:")
        for stat in categoryStats.prefix(3) {
            print("📊     \(stat.category.displayName): \(stat.count)")
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        refreshTimer?.invalidate()
        print("🗑️ UserRecommendationsViewModel: Deinitialized")
    }
}

// MARK: - Convenience Extensions

extension UserRecommendationsViewModel {
    /// Check if user has any recommendations for a specific nav unit
    func hasRecommendationForNavUnit(_ navUnitId: String) -> Bool {
        return recommendations.contains { $0.navUnitId == navUnitId }
    }
    
    /// Get the most recent recommendation for a nav unit
    func getLatestRecommendationForNavUnit(_ navUnitId: String) -> CloudRecommendation? {
        return recommendations
            .filter { $0.navUnitId == navUnitId }
            .max(by: { $0.createdAt < $1.createdAt })
    }
    
    /// Check if user has pending recommendations
    var hasPendingRecommendations: Bool {
        return pendingCount > 0
    }
    
    /// Get formatted summary text
    func getSummaryText() -> String {
        if totalCount == 0 {
            return "No recommendations submitted"
        } else if totalCount == 1 {
            return "1 recommendation submitted"
        } else {
            return "\(totalCount) recommendations submitted"
        }
    }
    
    /// Get status distribution as percentages
    func getStatusPercentages() -> (pending: Double, approved: Double, rejected: Double) {
        guard totalCount > 0 else { return (0, 0, 0) }
        
        let total = Double(totalCount)
        return (
            pending: Double(pendingCount) / total * 100,
            approved: Double(approvedCount) / total * 100,
            rejected: Double(rejectedCount) / total * 100
        )
    }
}
