import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var showAuthenticationView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    AppInformationSection()
                    
                    DividerView()
                    
                    LegalSection()
                    
                    DividerView()
                    
                    AccountSection(showAuthenticationView: $showAuthenticationView)
                        .environmentObject(authViewModel)
                    
                    DividerView()
                    
                    AboutSection()
                    
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
        .fullScreenCover(isPresented: $showAuthenticationView) {
            AuthenticationView()
                .environmentObject(authViewModel)
        }
    }
}

// MARK: - Supporting Views

struct AppInformationSection: View {
    var body: some View {
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
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

struct LegalSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legal")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                PrivacyPolicyButton()
                TermsOfUseButton()
            }
            .padding(.horizontal)
        }
    }
}

struct PrivacyPolicyButton: View {
    var body: some View {
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
    }
    
    private func openPrivacyPolicy() {
        DebugLogger.shared.log("Opening Privacy Policy link", category: "SETTINGS")
        if let url = URL(string: "https://marinerstudio.com/privacy/") {
            UIApplication.shared.open(url)
        }
    }
}

struct TermsOfUseButton: View {
    var body: some View {
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
    
    private func openTermsOfUse() {
        DebugLogger.shared.log("Opening Terms of Use link", category: "SETTINGS")
        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
            UIApplication.shared.open(url)
        }
    }
}

struct AccountSection: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @Binding var showAuthenticationView: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.headline)
                .padding(.horizontal)
            
            if authViewModel.isAuthenticated {
                AuthenticatedAccountView()
                    .environmentObject(authViewModel)
            } else {
                UnauthenticatedAccountView(showAuthenticationView: $showAuthenticationView)
            }
        }
    }
}

struct AuthenticatedAccountView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            UserStatusDisplay()
                .environmentObject(authViewModel)
            
            SignOutButton()
                .environmentObject(authViewModel)
            
            DeleteAccountButton()
        }
        .padding(.horizontal)
    }
}

struct UserStatusDisplay: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Signed In")
                    .font(.body)
                    .foregroundColor(.primary)
                Text(authViewModel.userEmail ?? "Account active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.1))
        )
    }
}

struct SignOutButton: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    
    var body: some View {
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
    }
}

struct DeleteAccountButton: View {
    var body: some View {
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
}

struct UnauthenticatedAccountView: View {
    @Binding var showAuthenticationView: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Sign in to sync your favorites and settings across devices")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            SignInButton(showAuthenticationView: $showAuthenticationView)
                .padding(.horizontal)
        }
    }
}

struct SignInButton: View {
    @Binding var showAuthenticationView: Bool
    
    var body: some View {
        Button(action: {
            showAuthenticationView = true
        }) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign Up / Sign In")
                        .font(.body)
                        .foregroundColor(.primary)
                    Text("Access your account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
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
}

struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About Mariner Studio")
                .font(.headline)
                .padding(.horizontal)
            
            Text("Mariner Studio provides comprehensive maritime weather data, tidal information, and navigation tools for maritime professionals and enthusiasts.")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
}

struct DividerView: View {
    var body: some View {
        Divider()
            .padding(.horizontal)
    }
}

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


