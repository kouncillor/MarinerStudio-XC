import SwiftUI

struct AuthenticationPromptView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                // Title
                Text("Enhance Your Experience")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                // Benefits
                VStack(alignment: .leading, spacing: 16) {
                    BenefitRow(icon: "icloud.and.arrow.up", text: "Sync favorites across all your devices")
                    BenefitRow(icon: "bookmark.fill", text: "Save your favorite locations and routes")
                    BenefitRow(icon: "gear", text: "Personalized settings and preferences")
                    BenefitRow(icon: "shield.fill", text: "Secure cloud backup of your data")
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button("Sign In / Sign Up") {
                        dismiss()
                        // Navigate to authentication view
                        // This could be implemented later as needed
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("Continue Without Account") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .navigationTitle("Optional Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    AuthenticationPromptView()
        .environmentObject(AuthenticationViewModel())
}