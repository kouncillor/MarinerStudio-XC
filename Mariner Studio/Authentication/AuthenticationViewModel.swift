
import Foundation
import Supabase
import RevenueCat
import Combine

// This should be defined globally where it's accessible, like in your App struct.
//let supabase = SupabaseClient(
//  supabaseURL: URL(string: "https://lgdsvefqqorvnvkiobth.supabase.co")!,
//  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxnZHN2ZWZxcW9ydm52a2lvYnRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwOTQ1MjQsImV4cCI6MjA2NTY3MDUyNH0.rNc5QTtV4IQK5n-HvCEpOZDpVCwPpmKkjYVBEHOqnVI"
//)




let GLOBAL_SUPABASE_CLIENT = SupabaseClient( supabaseURL: URL(string: "https://lgdsvefqqorvnvkiobth.supabase.co")!,
                                             supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxnZHN2ZWZxcW9ydm52a2lvYnRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwOTQ1MjQsImV4cCI6MjA2NTY3MDUyNH0.rNc5QTtV4IQK5n-HvCEpOZDpVCwPpmKkjYVBEHOqnVI")




@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        Task {
            await checkSession()
        }
    }

    func checkSession() async {
        do {
            let session = try await GLOBAL_SUPABASE_CLIENT.auth.session
            self.isAuthenticated = true
            print("User is already authenticated.")
            await logInToRevenueCat(userId: session.user.id.uuidString)
        } catch {
            self.isAuthenticated = false
            print("No active session found.")
        }
    }
    
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let authResponse = try await GLOBAL_SUPABASE_CLIENT.auth.signUp(email: email, password: password)
            await logInToRevenueCat(userId: authResponse.user.id.uuidString)
            self.isAuthenticated = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let authResponse = try await GLOBAL_SUPABASE_CLIENT.auth.signIn(email: email, password: password)
            await logInToRevenueCat(userId: authResponse.user.id.uuidString)
            self.isAuthenticated = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() async {
        do {
            try await GLOBAL_SUPABASE_CLIENT.auth.signOut()
            try await Purchases.shared.logOut()
            self.isAuthenticated = false
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func logInToRevenueCat(userId: String) async {
        do {
            print("Logging into RevenueCat with user ID: \(userId)")
            _ = try await Purchases.shared.logIn(userId)
        } catch {
            print("RevenueCat login failed: \(error.localizedDescription)")
            self.errorMessage = "Could not connect to subscription service."
        }
    }
}
