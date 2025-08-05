import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var viewModel: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningUp = true

    var body: some View {
        VStack {
            Text(isSigningUp ? "Create Your Account" : "Sign In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom)

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            SecureField("Password", text: $password)
                .textContentType(isSigningUp ? .newPassword : .password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            if viewModel.isLoading {
                VStack {
                    ProgressView()
                    Text(isSigningUp ? "Creating account..." : "Signing in...")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            } else {
                Button(action: {
                    Task {
                        if isSigningUp {
                            await viewModel.signUp(email: email, password: password)
                        } else {
                            await viewModel.signIn(email: email, password: password)
                        }
                    }
                }) {
                    Text(isSigningUp ? "Sign Up" : "Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(email.isEmpty || password.isEmpty)
            }

            Button(action: {
                isSigningUp.toggle()
            }) {
                Text(isSigningUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
            }
            .padding(.top)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top)
            }
        }
        .padding()
        .onChange(of: viewModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                // Add a small delay to show completion before dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
    }
}
