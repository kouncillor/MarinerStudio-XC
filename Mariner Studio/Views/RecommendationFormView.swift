//
//  RecommendationFormView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/31/25.
//

import SwiftUI

struct RecommendationFormView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: RecommendationFormViewModel
    @Binding var isPresented: Bool

    // MARK: - State
    @State private var selectedCategory: RecommendationCategory = .generalInfo
    @State private var description: String = ""
    @State private var userEmail: String = ""
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var isSubmitting = false

    // MARK: - Constants
    private let maxDescriptionLength = 500

    var body: some View {
        NavigationView {
            Form {
                // Nav Unit Info Section
                Section(header: Text("Navigation Unit")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.navUnit.navUnitName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("ID: \(viewModel.navUnit.navUnitId)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let facilityType = viewModel.navUnit.facilityType, !facilityType.isEmpty {
                            Text(facilityType)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Category Selection
                Section(header: Text("What type of update?")) {
                    ForEach(RecommendationCategory.allCases, id: \.self) { category in
                        CategoryRow(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }

                // Description Section
                Section(
                    header: Text("Description"),
                    footer: Text("Please describe what information should be updated. Be as specific as possible.")
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                            .overlay(
                                // Placeholder text
                                VStack {
                                    HStack {
                                        if description.isEmpty {
                                            Text("Example: The dock name has changed from 'Smith Marina' to 'Harbor View Marina'. The phone number is now (555) 123-4567.")
                                                .foregroundColor(.secondary)
                                                .font(.body)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                        }
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .allowsHitTesting(false)
                            )

                        // Character count
                        HStack {
                            Spacer()
                            Text("\(description.count)/\(maxDescriptionLength)")
                                .font(.caption)
                                .foregroundColor(description.count > maxDescriptionLength ? .red : .secondary)
                        }
                    }
                }

                // Optional Contact Info
                Section(
                    header: Text("Contact Information (Optional)"),
                    footer: Text("Provide your email if you're willing to be contacted for follow-up questions about this recommendation.")
                ) {
                    TextField("Your email address", text: $userEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                // Submission Status
                if isSubmitting {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Submitting recommendation...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Suggest Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitRecommendation()
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Recommendation Submitted", isPresented: $showingSuccessAlert) {
            Button("OK") {
                isPresented = false
            }
        } message: {
            Text("Thank you for your recommendation! We'll review it and update the navigation unit information as needed.")
        }
        .alert("Submission Failed", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An unexpected error occurred. Please try again.")
        }
        .onReceive(viewModel.$isSubmitting) { submitting in
            isSubmitting = submitting
        }
        .onReceive(viewModel.$errorMessage) { errorMessage in
            if errorMessage != nil {
                showingErrorAlert = true
            }
        }
    }

    // MARK: - Computed Properties

    private var canSubmit: Bool {
        return !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               description.count <= maxDescriptionLength &&
               !isSubmitting
    }

    // MARK: - Methods

    private func submitRecommendation() {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = userEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedDescription.isEmpty else { return }

        Task {
            let success = await viewModel.submitRecommendation(
                category: selectedCategory,
                description: trimmedDescription,
                userEmail: trimmedEmail.isEmpty ? nil : trimmedEmail
            )

            await MainActor.run {
                if success {
                    showingSuccessAlert = true
                }
            }
        }
    }
}

// MARK: - Category Row Component

struct CategoryRow: View {
    let category: RecommendationCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: category.iconName)
                    .foregroundColor(isSelected ? .white : .blue)
                    .font(.system(size: 20))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                    )

                // Category info
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct RecommendationFormView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendationFormView(
            viewModel: RecommendationFormViewModel(
                navUnit: NavUnit(
                    navUnitId: "TEST001",
                    navUnitName: "Test Marina",
                    facilityType: "Private Marina"
                ),
                recommendationService: RecommendationSupabaseService()
            ),
            isPresented: .constant(true)
        )
    }
}
#endif
