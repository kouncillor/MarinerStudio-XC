import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // App Information Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("App Information")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            AppInfoRow(label: "Version", value: getAppVersion())
                            AppInfoRow(label: "Build", value: getBuildNumber())
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Legal Section - Required for App Store compliance
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Legal")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            // Privacy Policy Link - Required by Apple App Store Guidelines 3.1.2
                            Button(action: {
                                openPrivacyPolicy()
                            }) {
                                HStack {
                                    Image(systemName: "hand.raised.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Privacy Policy")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("View our privacy policy")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Terms of Use Link - Required by Apple App Store Guidelines 3.1.2
                            Button(action: {
                                openTermsOfUse()
                            }) {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Terms of Use")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("View terms and conditions")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Account Section (only show if authenticated)
                    if authViewModel.isAuthenticated {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Account")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                // Sign Out Button
                                Button(action: {
                                    Task {
                                        await authViewModel.signOut()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.right.square")
                                            .foregroundColor(.red)
                                            .frame(width: 24)
                                        
                                        Text("Sign Out")
                                            .font(.body)
                                            .foregroundColor(.red)
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.red.opacity(0.1))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Delete Account Button - Required by Apple App Store Guidelines 5.1.1(v)
                                NavigationLink(destination: AccountDeletionView()) {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                            .foregroundColor(.red)
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Delete Account")
                                                .font(.body)
                                                .foregroundColor(.red)
                                            Text("Permanently delete your account")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.red.opacity(0.1))
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Divider()
                            .padding(.horizontal)
                    } else {
                        // Show sign in option if not authenticated
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Account")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Text("Sign in to sync your favorites and settings across devices")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            // This will be handled by the paywall flow
                        }
                        
                        Divider()
                            .padding(.horizontal)
                    }
                    
                    // About Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About Mariner Studio")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text("Mariner Studio provides comprehensive maritime weather data, tidal information, and navigation tools for maritime professionals and enthusiasts.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("Settings")
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color.white
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func openPrivacyPolicy() {
        DebugLogger.shared.log("Opening Privacy Policy link", category: "SETTINGS")
        if let url = URL(string: "https://marinerstudio.com/privacy/") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfUse() {
        DebugLogger.shared.log("Opening Terms of Use link", category: "SETTINGS")
        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
            UIApplication.shared.open(url)
        }
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

// MARK: - Supporting Views

struct AppInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    AppSettingsView()
        .environmentObject(AuthenticationViewModel())
}