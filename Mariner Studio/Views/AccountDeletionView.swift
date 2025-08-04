import SwiftUI

struct AccountDeletionView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showConfirmationAlert = false
    @State private var showFinalConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var confirmationText = ""
    
    private let requiredConfirmationText = "DELETE MY ACCOUNT"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Warning Icon
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    
                    // Title
                    Text("Delete Account")
                        .font(.largeTitle.bold())
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    // Warning Text
                    VStack(alignment: .leading, spacing: 16) {
                        Text("⚠️ This action cannot be undone")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("Deleting your account will permanently remove:")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DeletionItem(text: "All your saved favorites and preferences")
                            DeletionItem(text: "Your account information and profile")
                            DeletionItem(text: "All synced data across devices")
                            DeletionItem(text: "Access to premium features (if subscribed)")
                        }
                        
                        Text("Note: If you have an active subscription, you'll need to cancel it separately in your App Store settings. Account deletion does not automatically cancel subscriptions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.yellow.opacity(0.1))
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Divider()
                    
                    // Confirmation Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("To confirm deletion, type: \(requiredConfirmationText)")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        TextField("Type confirmation text", text: $confirmationText)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.body)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    
                    Spacer(minLength: 32)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            if confirmationText == requiredConfirmationText {
                                showFinalConfirmation = true
                            } else {
                                errorMessage = "Please type the exact confirmation text above."
                            }
                        }) {
                            if isDeleting {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Deleting Account...")
                                }
                            } else {
                                Text("Delete My Account")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .frame(maxWidth: .infinity)
                        .disabled(isDeleting || confirmationText != requiredConfirmationText)
                        
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .disabled(isDeleting)
                    }
                }
                .padding()
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .alert("Final Confirmation", isPresented: $showFinalConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Account", role: .destructive) {
                performAccountDeletion()
            }
        } message: {
            Text("Are you absolutely sure you want to delete your account? This action is permanent and cannot be reversed.")
        }
    }
    
    private func performAccountDeletion() {
        isDeleting = true
        errorMessage = nil
        
        Task {
            do {
                // Call Supabase account deletion
                try await SupabaseManager.shared.deleteAccount()
                
                // Sign out from RevenueCat
                try await authViewModel.signOut()
                
                DebugLogger.shared.log("✅ ACCOUNT DELETION: Account successfully deleted", category: "ACCOUNT_DELETION")
                
                await MainActor.run {
                    dismiss()
                }
                
            } catch {
                DebugLogger.shared.log("❌ ACCOUNT DELETION: Error = \(error)", category: "ACCOUNT_DELETION")
                
                await MainActor.run {
                    errorMessage = "Failed to delete account: \(error.localizedDescription)"
                    isDeleting = false
                }
            }
        }
    }
}

struct DeletionItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
                .padding(.top, 2)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    AccountDeletionView()
        .environmentObject(AuthenticationViewModel())
}