#if DEBUG

import Foundation
import SwiftUI
import Combine

@MainActor
class AdminDashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var recommendations: [CloudRecommendation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastRefreshTime: Date?
    
    // Statistics
    @Published var totalCount: Int = 0
    @Published var pendingCount: Int = 0
    @Published var approvedCount: Int = 0
    @Published var rejectedCount: Int = 0
    
    // MARK: - Private Properties
    private let recommendationService: RecommendationSupabaseService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(recommendationService: RecommendationSupabaseService = RecommendationSupabaseService()) {
        self.recommendationService = recommendationService
        print("🎛️ AdminDashboardViewModel: Initialized")
        
        // Monitor service state changes
        recommendationService.$isSubmitting
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        recommendationService.$lastError
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        // Update statistics when recommendations change
        $recommendations
            .sink { [weak self] recommendations in
                self?.updateStatistics(recommendations)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Load all recommendations from Supabase
    func loadAllRecommendations() {
        print("🎛️ AdminDashboardViewModel: Loading all recommendations...")
        
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                let allRecommendations = try await recommendationService.getAllRecommendations()
                
                await MainActor.run {
                    self.recommendations = allRecommendations
                    self.lastRefreshTime = Date()
                    self.isLoading = false
                    
                    print("🎛️ AdminDashboardViewModel: Loaded \(allRecommendations.count) recommendations")
                    print("📊 AdminDashboardViewModel: Pending: \(pendingCount), Approved: \(approvedCount), Rejected: \(rejectedCount)")
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load recommendations: \(error.localizedDescription)"
                    self.isLoading = false
                }
                
                print("❌ AdminDashboardViewModel: Failed to load recommendations: \(error.localizedDescription)")
            }
        }
    }
    
    /// Refresh recommendations with async/await
    func refreshRecommendations() async {
        print("🔄 AdminDashboardViewModel: Refreshing recommendations...")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let allRecommendations = try await recommendationService.getAllRecommendations()
            
            await MainActor.run {
                self.recommendations = allRecommendations
                self.lastRefreshTime = Date()
                self.isLoading = false
                
                print("🔄 AdminDashboardViewModel: Refreshed \(allRecommendations.count) recommendations")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to refresh recommendations: \(error.localizedDescription)"
                self.isLoading = false
            }
            
            print("❌ AdminDashboardViewModel: Failed to refresh recommendations: \(error.localizedDescription)")
        }
    }
    
    /// Update a single recommendation status
    func updateRecommendationStatus(
        _ recommendation: CloudRecommendation, 
        newStatus: RecommendationStatus, 
        adminNotes: String? = nil
    ) async {
        print("🎛️ AdminDashboardViewModel: Updating recommendation \(recommendation.id) to \(newStatus.displayName)")
        
        do {
            let updatedRecommendation = try await recommendationService.updateRecommendationStatus(
                recommendation, 
                newStatus: newStatus, 
                adminNotes: adminNotes
            )
            
            await MainActor.run {
                // Find and update the recommendation in our local array
                if let index = recommendations.firstIndex(where: { $0.id == recommendation.id }) {
                    recommendations[index] = updatedRecommendation
                }
                
                print("✅ AdminDashboardViewModel: Successfully updated recommendation status")
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update recommendation: \(error.localizedDescription)"
            }
            
            print("❌ AdminDashboardViewModel: Failed to update recommendation: \(error.localizedDescription)")
        }
    }
    
    /// Bulk update multiple recommendations
    func bulkUpdateStatus(
        _ recommendations: [CloudRecommendation], 
        newStatus: RecommendationStatus, 
        adminNotes: String? = nil
    ) async {
        print("🎛️ AdminDashboardViewModel: Bulk updating \(recommendations.count) recommendations to \(newStatus.displayName)")
        
        await MainActor.run {
            isLoading = true
        }
        
        var successCount = 0
        var failureCount = 0
        
        // Process recommendations in batches to avoid overwhelming the service
        for batch in recommendations.chunked(into: 5) {
            await withTaskGroup(of: Bool.self) { group in
                for recommendation in batch {
                    group.addTask {
                        do {
                            let updatedRecommendation = try await self.recommendationService.updateRecommendationStatus(
                                recommendation, 
                                newStatus: newStatus, 
                                adminNotes: adminNotes
                            )
                            
                            await MainActor.run {
                                if let index = self.recommendations.firstIndex(where: { $0.id == recommendation.id }) {
                                    self.recommendations[index] = updatedRecommendation
                                }
                            }
                            
                            return true
                        } catch {
                            print("❌ AdminDashboardViewModel: Failed to update recommendation \(recommendation.id): \(error.localizedDescription)")
                            return false
                        }
                    }
                }
                
                for await success in group {
                    if success {
                        successCount += 1
                    } else {
                        failureCount += 1
                    }
                }
            }
        }
        
        await MainActor.run {
            isLoading = false
            
            if failureCount > 0 {
                errorMessage = "Updated \(successCount) recommendations, \(failureCount) failed"
            }
            
            print("📊 AdminDashboardViewModel: Bulk update complete - Success: \(successCount), Failed: \(failureCount)")
        }
    }
    
    /// Get recommendations filtered by status
    func getRecommendations(byStatus status: RecommendationStatus) -> [CloudRecommendation] {
        return recommendations.filter { $0.status == status }
    }
    
    /// Get recommendations filtered by category
    func getRecommendations(byCategory category: RecommendationCategory) -> [CloudRecommendation] {
        return recommendations.filter { $0.category == category }
    }
    
    /// Get recent recommendations (within specified days)
    func getRecentRecommendations(withinDays days: Int = 7) -> [CloudRecommendation] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return recommendations.filter { $0.createdAt >= cutoffDate }
    }
    
    /// Get recommendations by nav unit
    func getRecommendations(forNavUnit navUnitId: String) -> [CloudRecommendation] {
        return recommendations.filter { $0.navUnitId == navUnitId }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Get category breakdown for statistics
    func getCategoryBreakdown() -> [RecommendationCategory: Int] {
        var breakdown: [RecommendationCategory: Int] = [:]
        
        for category in RecommendationCategory.allCases {
            breakdown[category] = recommendations.filter { $0.category == category }.count
        }
        
        return breakdown
    }
    
    /// Get recommendations that need attention (old pending recommendations)
    func getRecommendationsNeedingAttention(olderThanDays days: Int = 7) -> [CloudRecommendation] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return recommendations.filter { $0.status == .pending && $0.createdAt < cutoffDate }
    }
    
    // MARK: - Private Methods
    
    private func updateStatistics(_ recommendations: [CloudRecommendation]) {
        totalCount = recommendations.count
        pendingCount = recommendations.filter { $0.status == .pending }.count
        approvedCount = recommendations.filter { $0.status == .approved }.count
        rejectedCount = recommendations.filter { $0.status == .rejected }.count
    }
    
    // MARK: - Deinit
    deinit {
        print("🗑️ AdminDashboardViewModel: Deinitialized")
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Analytics and Reporting Extension

extension AdminDashboardViewModel {
    
    /// Generate a summary report for the admin dashboard
    func generateSummaryReport() -> AdminSummaryReport {
        let totalRecommendations = recommendations.count
        let categoryBreakdown = getCategoryBreakdown()
        let recentRecommendations = getRecentRecommendations()
        let needingAttention = getRecommendationsNeedingAttention()
        
        return AdminSummaryReport(
            totalRecommendations: totalRecommendations,
            pendingCount: pendingCount,
            approvedCount: approvedCount,
            rejectedCount: rejectedCount,
            categoryBreakdown: categoryBreakdown,
            recentActivityCount: recentRecommendations.count,
            needingAttentionCount: needingAttention.count,
            lastRefreshTime: lastRefreshTime ?? Date(),
            mostActiveNavUnits: getMostActiveNavUnits()
        )
    }
    
    /// Get the most active nav units by recommendation count
    private func getMostActiveNavUnits() -> [(navUnitName: String, count: Int)] {
        let navUnitCounts = Dictionary(grouping: recommendations) { $0.navUnitId }
            .mapValues { $0.count }
        
        return navUnitCounts
            .map { (navUnitId, count) in
                let navUnitName = recommendations.first { $0.navUnitId == navUnitId }?.navUnitName ?? navUnitId
                return (navUnitName: navUnitName, count: count)
            }
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0 }
    }
}

// MARK: - Supporting Models

struct AdminSummaryReport {
    let totalRecommendations: Int
    let pendingCount: Int
    let approvedCount: Int
    let rejectedCount: Int
    let categoryBreakdown: [RecommendationCategory: Int]
    let recentActivityCount: Int
    let needingAttentionCount: Int
    let lastRefreshTime: Date
    let mostActiveNavUnits: [(navUnitName: String, count: Int)]
    
    var approvalRate: Double {
        guard totalRecommendations > 0 else { return 0 }
        return Double(approvedCount) / Double(totalRecommendations) * 100
    }
    
    var rejectionRate: Double {
        guard totalRecommendations > 0 else { return 0 }
        return Double(rejectedCount) / Double(totalRecommendations) * 100
    }
}

#endif