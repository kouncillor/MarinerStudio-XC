#if DEBUG

import SwiftUI

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminDashboardViewModel()
    @State private var searchText = ""
    @State private var selectedStatus: RecommendationStatusFilter = .all
    @State private var showingStatusChangeAlert = false
    @State private var statusChangeMessage = ""
    @State private var selectedRecommendations = Set<UUID>()
    @State private var showingBulkActionSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Statistics Header
                statisticsHeader

                // Search and Filter Controls
                searchAndFilterSection

                // Recommendations List
                recommendationsList

                // Bulk Actions Toolbar
                if !selectedRecommendations.isEmpty {
                    bulkActionsToolbar
                }
            }
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                leading: refreshButton,
                trailing: HStack {
                    selectAllButton
                    clearSelectionButton
                }
            )
            .onAppear {
                viewModel.loadAllRecommendations()
            }
            .alert("Status Updated", isPresented: $showingStatusChangeAlert) {
                Button("OK") { }
            } message: {
                Text(statusChangeMessage)
            }
            .actionSheet(isPresented: $showingBulkActionSheet) {
                ActionSheet(
                    title: Text("Bulk Actions"),
                    message: Text("Selected \(selectedRecommendations.count) recommendations"),
                    buttons: [
                        .default(Text("Approve All")) {
                            bulkUpdateStatus(.approved)
                        },
                        .destructive(Text("Reject All")) {
                            bulkUpdateStatus(.rejected)
                        },
                        .cancel()
                    ]
                )
            }
        }
    }

    // MARK: - Statistics Header

    private var statisticsHeader: some View {
        VStack(spacing: 12) {
            HStack {
                StatCard(
                    title: "Total",
                    count: viewModel.totalCount,
                    color: .blue
                )

                StatCard(
                    title: "Pending",
                    count: viewModel.pendingCount,
                    color: .orange
                )

                StatCard(
                    title: "Approved",
                    count: viewModel.approvedCount,
                    color: .green
                )

                StatCard(
                    title: "Rejected",
                    count: viewModel.rejectedCount,
                    color: .red
                )
            }
            .padding(.horizontal)

            if viewModel.isLoading {
                ProgressView("Loading recommendations...")
                    .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Search and Filter Section

    private var searchAndFilterSection: some View {
        VStack(spacing: 8) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search nav units or descriptions...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            // Status Filter
            Picker("Filter by Status", selection: $selectedStatus) {
                Text("All").tag(RecommendationStatusFilter.all)
                Text("Pending").tag(RecommendationStatusFilter.pending)
                Text("Approved").tag(RecommendationStatusFilter.approved)
                Text("Rejected").tag(RecommendationStatusFilter.rejected)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Recommendations List

    private var recommendationsList: some View {
        List {
            ForEach(filteredRecommendations, id: \.id) { recommendation in
                RecommendationAdminRow(
                    recommendation: recommendation,
                    isSelected: selectedRecommendations.contains(recommendation.id),
                    onToggleSelection: { toggleSelection(recommendation) },
                    onStatusChange: { newStatus, notes in
                        updateRecommendationStatus(recommendation, newStatus: newStatus, notes: notes)
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await viewModel.refreshRecommendations()
        }
    }

    // MARK: - Bulk Actions Toolbar

    private var bulkActionsToolbar: some View {
        HStack {
            Text("\(selectedRecommendations.count) selected")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button("Bulk Actions") {
                showingBulkActionSheet = true
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }

    // MARK: - Navigation Bar Buttons

    private var refreshButton: some View {
        Button(action: {
            viewModel.loadAllRecommendations()
        }) {
            Image(systemName: "arrow.clockwise")
        }
    }

    private var selectAllButton: some View {
        Button("Select All") {
            selectedRecommendations = Set(filteredRecommendations.map { $0.id })
        }
        .disabled(filteredRecommendations.isEmpty)
    }

    private var clearSelectionButton: some View {
        Button("Clear") {
            selectedRecommendations.removeAll()
        }
        .disabled(selectedRecommendations.isEmpty)
    }

    // MARK: - Computed Properties

    private var filteredRecommendations: [CloudRecommendation] {
        var recommendations = viewModel.recommendations

        // Filter by status
        switch selectedStatus {
        case .pending:
            recommendations = recommendations.filter { $0.status == .pending }
        case .approved:
            recommendations = recommendations.filter { $0.status == .approved }
        case .rejected:
            recommendations = recommendations.filter { $0.status == .rejected }
        case .all:
            break
        }

        // Filter by search text
        if !searchText.isEmpty {
            recommendations = recommendations.filter { recommendation in
                recommendation.navUnitName.localizedCaseInsensitiveContains(searchText) ||
                recommendation.description.localizedCaseInsensitiveContains(searchText) ||
                recommendation.category.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return recommendations.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Helper Methods

    private func toggleSelection(_ recommendation: CloudRecommendation) {
        if selectedRecommendations.contains(recommendation.id) {
            selectedRecommendations.remove(recommendation.id)
        } else {
            selectedRecommendations.insert(recommendation.id)
        }
    }

    private func updateRecommendationStatus(_ recommendation: CloudRecommendation, newStatus: RecommendationStatus, notes: String?) {
        Task {
            await viewModel.updateRecommendationStatus(recommendation, newStatus: newStatus, adminNotes: notes)
            await MainActor.run {
                statusChangeMessage = "Recommendation \(newStatus.displayName.lowercased()) successfully"
                showingStatusChangeAlert = true
            }
        }
    }

    private func bulkUpdateStatus(_ newStatus: RecommendationStatus) {
        let selectedRecs = viewModel.recommendations.filter { selectedRecommendations.contains($0.id) }

        Task {
            await viewModel.bulkUpdateStatus(selectedRecs, newStatus: newStatus)
            await MainActor.run {
                selectedRecommendations.removeAll()
                statusChangeMessage = "Updated \(selectedRecs.count) recommendations to \(newStatus.displayName.lowercased())"
                showingStatusChangeAlert = true
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

struct RecommendationAdminRow: View {
    let recommendation: CloudRecommendation
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onStatusChange: (RecommendationStatus, String?) -> Void

    @State private var showingStatusSheet = false
    @State private var adminNotes = ""
    @State private var selectedNewStatus: RecommendationStatus = .approved

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with selection and nav unit
            HStack {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.navUnitName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(recommendation.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                AdminStatusBadge(status: recommendation.status)
            }

            // Description
            Text(recommendation.description)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(3)

            // Metadata
            HStack {
                Text(recommendation.createdAt.timeAgoDisplay())
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if recommendation.status == .pending {
                    Button("Review") {
                        showingStatusSheet = true
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .actionSheet(isPresented: $showingStatusSheet) {
            ActionSheet(
                title: Text("Update Status"),
                message: Text("Choose action for this recommendation"),
                buttons: [
                    .default(Text("Approve")) {
                        selectedNewStatus = .approved
                        requestAdminNotes()
                    },
                    .destructive(Text("Reject")) {
                        selectedNewStatus = .rejected
                        requestAdminNotes()
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingStatusSheet) {
            AdminNotesView(
                status: selectedNewStatus,
                notes: $adminNotes,
                onSave: {
                    onStatusChange(selectedNewStatus, adminNotes.isEmpty ? nil : adminNotes)
                    adminNotes = ""
                }
            )
        }
    }

    private func requestAdminNotes() {
        // This will trigger the sheet to show for notes entry
        showingStatusSheet = true
    }
}

struct AdminStatusBadge: View {
    let status: RecommendationStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(status.backgroundColor)
            .foregroundColor(status.textColor)
            .cornerRadius(4)
    }
}

struct AdminNotesView: View {
    let status: RecommendationStatus
    @Binding var notes: String
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add admin notes (optional)")
                    .font(.headline)

                Text("Status: \(status.displayName)")
                    .foregroundColor(status.uiColor)
                    .font(.subheadline)

                TextEditor(text: $notes)
                    .border(Color.gray, width: 1)
                    .frame(minHeight: 100)

                Spacer()
            }
            .padding()
            .navigationTitle("Admin Notes")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// MARK: - Filter Enum

enum RecommendationStatusFilter {
    case all, pending, approved, rejected
}

#endif
