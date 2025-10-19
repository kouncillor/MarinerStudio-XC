import SwiftUI
import MessageUI
import SafariServices

struct FeedbackView: View {
    // MARK: - Constants
    private static let forumURL = "https://marinerstudio.freeforums.net/"
    static let feedbackEmail = "admin@ospreyapplications.com"

    // MARK: - Properties
    let sourceView: String
    let onDismiss: () -> Void

    // MARK: - State
    @State private var showEmailComposer = false
    @State private var showFeedbackForm = false
    @State private var showFeatureRequestForm = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var emailResultTrigger: Int = 0
    @State private var showSafariView = false
    @State private var safariURL: URL?

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss

    // MARK: - Initialization
    init(sourceView: String, onDismiss: @escaping () -> Void = {}) {
        self.sourceView = sourceView
        self.onDismiss = onDismiss
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Source View Indicator
                    sourceViewCard

                    // Feedback Options
                    feedbackOptionsSection

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // TODO: Implement home navigation in later steps
                        onDismiss()
                        dismiss()
                    }) {
                        Image(systemName: "house.fill")
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .alert("Notice", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showEmailComposer) {
            EmailComposerView(
                sourceView: sourceView,
                onResult: { result in
                    handleEmailResult(result)
                    emailResultTrigger += 1
                }
            )
        }
        .sheet(isPresented: $showSafariView) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showFeedbackForm) {
            FeedbackFormModal(
                feedbackType: .general,
                sourceView: sourceView
            )
        }
        .sheet(isPresented: $showFeatureRequestForm) {
            FeedbackFormModal(
                feedbackType: .featureRequest,
                sourceView: sourceView
            )
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("We'd love to hear from you!")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Choose how you'd like to share your feedback")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Source View Card
    private var sourceViewCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text("You came from:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(sourceView)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Feedback Options Section
    private var feedbackOptionsSection: some View {
        VStack(spacing: 16) {
            ForEach(FeedbackOption.allCases, id: \.rawValue) { option in
                FeedbackOptionCard(
                    option: option,
                    action: {
                        handleOptionTap(option)
                    }
                )
            }
        }
    }

    // MARK: - Actions
    private func handleOptionTap(_ option: FeedbackOption) {
        switch option {
        case .email:
            handleEmailOption()
        case .forums:
            handleForumsOption()
        case .submitForm:
            showFeedbackForm = true
        case .featureRequest:
            showFeatureRequestForm = true
        }
    }

    private func handleEmailOption() {
        if MFMailComposeViewController.canSendMail() {
            showEmailComposer = true
        } else {
            showAlert(message: "Email is not configured on this device. Please set up email in Settings or use another feedback option.")
        }
    }

    private func handleForumsOption() {
        guard let url = URL(string: Self.forumURL) else {
            showAlert(message: "Invalid forum URL. Please try again later.")
            return
        }

        // Check if we can open URLs (network connectivity, etc.)
        if UIApplication.shared.canOpenURL(url) {
            safariURL = url
            showSafariView = true
        } else {
            showAlert(message: "Unable to open forum. Please check your internet connection and try again.")
        }
    }

    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }

    private func handleEmailResult(_ result: Result<MFMailComposeResult, Error>?) {
        guard let result = result else { return }

        switch result {
        case .success(let mailResult):
            switch mailResult {
            case .sent:
                showAlert(message: "Thank you! Your feedback email has been sent.")
            case .saved:
                showAlert(message: "Your feedback email has been saved to drafts.")
            case .cancelled:
                // Don't show alert for cancellation
                break
            case .failed:
                showAlert(message: "Failed to send email. Please try again or use another feedback option.")
            @unknown default:
                break
            }
        case .failure(let error):
            showAlert(message: "Email error: \(error.localizedDescription)")
        }

        // No reset needed with callback approach
    }
}

// MARK: - Feedback Option Card
struct FeedbackOptionCard: View {
    let option: FeedbackOption
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: option.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(option.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(FeedbackCardButtonStyle())
    }

    private var iconColor: Color {
        switch option.iconColor {
        case "green":
            return .green
        case "purple":
            return .purple
        case "blue":
            return .blue
        case "orange":
            return .orange
        default:
            return .blue
        }
    }
}

// MARK: - Custom Button Style
struct FeedbackCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Email Composer
struct EmailComposerView: UIViewControllerRepresentable {
    let sourceView: String
    let onResult: (Result<MFMailComposeResult, Error>) -> Void
    @Environment(\.presentationMode) var presentation

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator

        // Configure email
        composer.setToRecipients([FeedbackView.feedbackEmail])
        composer.setSubject("Feedback from \(sourceView)")
        composer.setMessageBody(DeviceInfoHelper.getEmailTemplate(sourceView: sourceView), isHTML: false)

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: EmailComposerView

        init(_ parent: EmailComposerView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                 didFinishWith result: MFMailComposeResult,
                                 error: Error?) {
            if let error = error {
                parent.onResult(.failure(error))
            } else {
                parent.onResult(.success(result))
            }

            parent.presentation.wrappedValue.dismiss()
        }
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.preferredBarTintColor = UIColor.systemBlue
        safariViewController.preferredControlTintColor = UIColor.white
        return safariViewController
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Feedback Form Modal
struct FeedbackFormModal: View {
    let feedbackType: FeedbackType
    let sourceView: String

    @StateObject private var formState: FeedbackFormState
    @Environment(\.dismiss) private var dismiss

    init(feedbackType: FeedbackType, sourceView: String) {
        self.feedbackType = feedbackType
        self.sourceView = sourceView
        self._formState = StateObject(wrappedValue: FeedbackFormState(feedbackType: feedbackType, sourceView: sourceView))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Form Content
                    formContent

                    // Submit Button
                    submitButton

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(feedbackType.displayName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Success", isPresented: $formState.showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Thank you for your feedback! We'll review it and get back to you if needed.")
        }
        .alert("Error", isPresented: .constant(formState.errorMessage != nil)) {
            Button("OK") {
                formState.errorMessage = nil
            }
        } message: {
            Text(formState.errorMessage ?? "")
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: feedbackType == .general ? "square.and.pencil" : "lightbulb.fill")
                .font(.system(size: 50))
                .foregroundColor(feedbackType == .general ? .blue : .orange)

            Text(feedbackType.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Form Content
    private var formContent: some View {
        VStack(spacing: 16) {
            // Source View Card
            sourceViewCard

            // Message Field
            messageField

            // Feature Importance Field (for feature requests only)
            if feedbackType == .featureRequest {
                featureImportanceField
            }

            // Contact Information Section
            contactSection
        }
    }

    // MARK: - Source View Card
    private var sourceViewCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text("From:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(sourceView)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Message Field
    private var messageField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(feedbackType == .general ? "Your Feedback" : "Feature Description")
                .font(.headline)
                .fontWeight(.semibold)

            Text(feedbackType == .general ?
                "Tell us about your experience, report bugs, or share suggestions." :
                "Describe the feature you'd like to see added.")
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(minHeight: 120)

                TextEditor(text: $formState.message)
                    .padding(8)
                    .background(Color.clear)
                    .cornerRadius(8)
                    .frame(minHeight: 120)
            }

            HStack {
                Text(formState.messageCharacterCount)
                    .font(.caption)
                    .foregroundColor(formState.message.count > 500 ? .red : .secondary)

                Spacer()

                if !formState.validationErrors.isEmpty {
                    Text("Required")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Feature Importance Field
    private var featureImportanceField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why is this important?")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Help us understand the value and priority of this feature.")
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(minHeight: 80)

                TextEditor(text: $formState.featureImportance)
                    .padding(8)
                    .background(Color.clear)
                    .cornerRadius(8)
                    .frame(minHeight: 80)
            }

            HStack {
                Text(formState.featureImportanceCharacterCount)
                    .font(.caption)
                    .foregroundColor(formState.featureImportance.count > 300 ? .red : .secondary)

                Spacer()

                if feedbackType == .featureRequest && formState.featureImportance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Required")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Contact Section
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Contact Information")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: formState.toggleAnonymous) {
                    HStack(spacing: 6) {
                        Image(systemName: formState.isAnonymous ? "checkmark.square.fill" : "square")
                            .foregroundColor(.blue)

                        Text("Anonymous")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            if !formState.isAnonymous {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email or Name (optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("your.email@example.com", text: $formState.contactInfo)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            } else {
                Text("Your feedback will be submitted anonymously.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Submit Button
    private var submitButton: some View {
        Button(action: submitFeedback) {
            HStack {
                if formState.isSubmitting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                }

                Text(formState.isSubmitting ? "Submitting..." : "Submit Feedback")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(formState.isValid ? Color.blue : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!formState.isValid || formState.isSubmitting)
        .padding(.horizontal, 16)
    }

    // MARK: - Actions
    private func submitFeedback() {
        guard formState.isValid else { return }

        formState.isSubmitting = true

        Task {
            let result = await SupabaseManager.shared.submitFeedback(
                feedbackType: formState.feedbackType.rawValue,
                message: formState.message,
                contactInfo: formState.contactInfo,
                isAnonymous: formState.isAnonymous,
                sourceView: formState.sourceView,
                appVersion: DeviceInfoHelper.getFullAppVersion(),
                iosVersion: DeviceInfoHelper.getIOSVersion(),
                deviceModel: DeviceInfoHelper.getDeviceModel(),
                featureImportance: formState.featureImportance.isEmpty ? nil : formState.featureImportance
            )

            await MainActor.run {
                formState.isSubmitting = false

                switch result {
                case .success:
                    formState.showSuccess = true
                case .failure(let error):
                    formState.errorMessage = "Failed to submit feedback: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Helper Extensions
extension FeedbackView {
    /// Create feedback view for presentation from any source view
    static func createForPresentation(from sourceView: String) -> some View {
        FeedbackView(sourceView: sourceView)
    }
}

// MARK: - Preview
struct FeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        FeedbackView(sourceView: "Weather Menu")

        FeedbackView(sourceView: "Tides Menu")
            .preferredColorScheme(.dark)
    }
}