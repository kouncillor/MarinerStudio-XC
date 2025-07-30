//
//  UserRecommendationsView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/31/25.
//

import SwiftUI

struct UserRecommendationsView: View {
    // MARK: - Properties
    @StateObject private var viewModel = UserRecommendationsViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if !viewModel.errorMessage.isEmpty {
                errorView
            } else if viewModel.recommendations.isEmpty {
                emptyStateView
            } else {
                recommendationsList
            }
        }
        .navigationTitle("My Recommendations")
        .navigationBarTitleDisplayMode(.large)
        .withHomeButton()
        .onAppear {
            viewModel.initialize(recommendationService: serviceProvider.recommendationService)
            Task {
                await viewModel.loadRecommendations()
            }
        }
        .refreshable {
            await viewModel.loadRecommendations()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading your recommendations...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Unable to Load Recommendations")
                .font(.title2)
                .fontWeight(.semibold)

            Text(viewModel.errorMessage)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Try Again") {
                Task {
                    await viewModel.loadRecommendations()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lightbulb.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("No Recommendations Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("When you find outdated information in navigation units, you can suggest updates to help other mariners.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }

            VStack(spacing: 16) {
                Text("To submit a recommendation:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("1.")
                            .fontWeight(.bold)
                        Text("Browse to any navigation unit")
                    }

                    HStack {
                        Text("2.")
                            .fontWeight(.bold)
                        Text("Tap the \"Suggest Update\" button")
                    }

                    HStack {
                        Text("3.")
                            .fontWeight(.bold)
                        Text("Fill out the recommendation form")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Recommendations List

    private var recommendationsList: some View {
        List {
            // Summary Section
            Section {
                summaryCard
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Recommendations Section
            Section(header: Text("Your Recommendations")) {
                ForEach(viewModel.recommendations) { recommendation in
                    RecommendationRow(recommendation: recommendation)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.recommendations.count)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("Total Recommendations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }

            HStack(spacing: 24) {
                StatusCount(
                    status: .pending,
                    count: viewModel.pendingCount
                )

                StatusCount(
                    status: .approved,
                    count: viewModel.approvedCount
                )

                StatusCount(
                    status: .rejected,
                    count: viewModel.rejectedCount
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Recommendation Row Component

struct RecommendationRow: View {
    let recommendation: CloudRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with nav unit and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.navUnitName)
                        .font(.headline)
                        .lineLimit(1)

                    Text("ID: \(recommendation.navUnitId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                StatusBadge(status: recommendation.status)
            }

            // Category
            HStack(spacing: 8) {
                Image(systemName: recommendation.category.iconName)
                    .foregroundColor(.blue)
                    .font(.system(size: 14))

                Text(recommendation.category.displayName)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }

            // Description
            Text(recommendation.description)
                .font(.body)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Footer with date and admin notes
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Submitted \(recommendation.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let reviewedAt = recommendation.reviewedAt {
                        Text("Reviewed \(reviewedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let adminNotes = recommendation.adminNotes, !adminNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Admin Notes:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Text(adminNotes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(UIColor.tertiarySystemBackground))
                            )
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Status Badge Component

struct StatusBadge: View {
    let status: RecommendationStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .font(.system(size: 12))

            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(statusColor.opacity(0.2))
        )
        .foregroundColor(statusColor)
    }

    private var statusColor: Color {
        switch status {
        case .pending:
            return .orange
        case .approved:
            return .green
        case .rejected:
            return .red
        }
    }
}

// MARK: - Status Count Component

struct StatusCount: View {
    let status: RecommendationStatus
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(statusColor)

            Text(status.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusColor: Color {
        switch status {
        case .pending:
            return .orange
        case .approved:
            return .green
        case .rejected:
            return .red
        }
    }
}

// MARK: - Preview

#if DEBUG
struct UserRecommendationsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            UserRecommendationsView()
                .environmentObject(ServiceProvider())
        }
    }
}
#endif
