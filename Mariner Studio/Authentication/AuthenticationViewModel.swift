import Foundation
import RevenueCat
import Combine
import Network

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userEmail: String?

    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")

    init() {
        DebugLogger.shared.log("🎯 AUTH INIT: AuthenticationViewModel initializing", category: "AUTH_INIT")
        setupNetworkMonitoring()

        Task {
            DebugLogger.shared.log("🎯 AUTH INIT: Starting checkSession task", category: "AUTH_INIT")
            await checkSession()
        }
    }

    private func setupNetworkMonitoring() {
        // DebugLogger.shared.log("📡 NETWORK: Setting up network monitoring", category: "AUTH_NETWORK")
        networkMonitor.pathUpdateHandler = { path in
            // DebugLogger.shared.log("📡 NETWORK STATUS: \(path.status)", category: "AUTH_NETWORK")
            // DebugLogger.shared.log("📡 NETWORK EXPENSIVE: \(path.isExpensive)", category: "AUTH_NETWORK")
            // DebugLogger.shared.log("📡 NETWORK CONSTRAINED: \(path.isConstrained)", category: "AUTH_NETWORK")
            // DebugLogger.shared.log("📡 NETWORK INTERFACES: \(path.availableInterfaces)", category: "AUTH_NETWORK")

            if path.status == .satisfied {
                // DebugLogger.shared.log("✅ NETWORK: Connection is available", category: "AUTH_NETWORK")
                if path.usesInterfaceType(.wifi) {
                    // DebugLogger.shared.log("📡 NETWORK: Using WiFi", category: "AUTH_NETWORK")
                } else if path.usesInterfaceType(.cellular) {
                    // DebugLogger.shared.log("📡 NETWORK: Using Cellular", category: "AUTH_NETWORK")
                } else if path.usesInterfaceType(.wiredEthernet) {
                    // DebugLogger.shared.log("📡 NETWORK: Using Ethernet", category: "AUTH_NETWORK")
                }
            } else {
                // DebugLogger.shared.log("❌ NETWORK: No connection available", category: "AUTH_NETWORK")
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    func checkSession() async {
        DebugLogger.shared.log("\n🔍 SESSION CHECK: Starting session validation using SupabaseManager", category: "AUTH_SESSION")
        DebugLogger.shared.log("🔍 SESSION CHECK: Current authentication state = \(isAuthenticated)", category: "AUTH_SESSION")
        DebugLogger.shared.log("🔍 SESSION CHECK: Thread = \(Thread.current)", category: "AUTH_SESSION")
        DebugLogger.shared.log("🔍 SESSION CHECK: Timestamp = \(Date())", category: "AUTH_SESSION")

        do {
            let session = try await SupabaseManager.shared.getSession()

            DebugLogger.shared.log("✅ SESSION CHECK: SUCCESS! Session retrieved via SupabaseManager", category: "AUTH_SESSION")
            DebugLogger.shared.log("✅ SESSION CHECK: Valid session found", category: "AUTH_SESSION")
            DebugLogger.shared.log("✅ SESSION CHECK: User authenticated", category: "AUTH_SESSION")

            self.isAuthenticated = true
            self.userEmail = session.user.email
            DebugLogger.shared.log("✅ SESSION CHECK: Authentication state updated to TRUE", category: "AUTH_SESSION")

            DebugLogger.shared.log("🎫 SUPABASE SESSION: Authentication successful, Apple ID service will handle subscription linking", category: "AUTH_SESSION")

        } catch {
            DebugLogger.shared.log("\n❌ SESSION CHECK: Error occurred via SupabaseManager", category: "AUTH_SESSION")
            DebugLogger.shared.log("❌ SESSION CHECK: Error = \(error)", category: "AUTH_SESSION")

            self.isAuthenticated = false
            self.userEmail = nil
            DebugLogger.shared.log("❌ SESSION CHECK: Authentication state updated to FALSE", category: "AUTH_SESSION")
        }

        DebugLogger.shared.log("🔍 SESSION CHECK: Complete. Final auth state = \(isAuthenticated)\n", category: "AUTH_SESSION")
    }

    func signUp(email: String, password: String) async {
        DebugLogger.shared.log("\n📝 SIGN UP: Starting user registration via SupabaseManager", category: "AUTH_SIGNUP")
        DebugLogger.shared.log("📝 SIGN UP: User registration initiated", category: "AUTH_SIGNUP")
        DebugLogger.shared.log("📝 SIGN UP: Password length = \(password.count)", category: "AUTH_SIGNUP")

        isLoading = true
        errorMessage = nil
        DebugLogger.shared.log("📝 SIGN UP: Loading state set to TRUE", category: "AUTH_SIGNUP")

        do {
            let authResponse = try await SupabaseManager.shared.signUp(email: email, password: password)

            DebugLogger.shared.log("✅ SIGN UP: SUCCESS! User created via SupabaseManager", category: "AUTH_SIGNUP")
            DebugLogger.shared.log("✅ SIGN UP: User account created successfully", category: "AUTH_SIGNUP")
            DebugLogger.shared.log("✅ SIGN UP: User email verified", category: "AUTH_SIGNUP")

            DebugLogger.shared.log("🎫 SUPABASE SIGNUP: User created, Apple ID service will handle subscription linking", category: "AUTH_SIGNUP")

            self.isAuthenticated = true
            self.userEmail = authResponse.user.email
            DebugLogger.shared.log("✅ SIGN UP: Authentication state updated to TRUE", category: "AUTH_SIGNUP")

        } catch {
            DebugLogger.shared.log("\n❌ SIGN UP: Error occurred via SupabaseManager", category: "AUTH_SIGNUP")
            DebugLogger.shared.log("❌ SIGN UP: Error = \(error)", category: "AUTH_SIGNUP")

            self.errorMessage = error.localizedDescription
        }

        isLoading = false
        DebugLogger.shared.log("📝 SIGN UP: Complete. Auth state = \(isAuthenticated)\n", category: "AUTH_SIGNUP")
    }

    func signIn(email: String, password: String) async {
        DebugLogger.shared.log("\n🔐 SIGN IN: Starting user authentication via SupabaseManager", category: "AUTH_SIGNIN")
        DebugLogger.shared.log("🔐 SIGN IN: User authentication initiated", category: "AUTH_SIGNIN")
        DebugLogger.shared.log("🔐 SIGN IN: Password length = \(password.count)", category: "AUTH_SIGNIN")

        isLoading = true
        errorMessage = nil
        DebugLogger.shared.log("🔐 SIGN IN: Loading state set to TRUE", category: "AUTH_SIGNIN")

        do {
            let session = try await SupabaseManager.shared.signIn(email: email, password: password)

            DebugLogger.shared.log("✅ SIGN IN: SUCCESS! User authenticated via SupabaseManager", category: "AUTH_SIGNIN")
            DebugLogger.shared.log("✅ SIGN IN: User session established", category: "AUTH_SIGNIN")
            DebugLogger.shared.log("✅ SIGN IN: User credentials verified", category: "AUTH_SIGNIN")

            DebugLogger.shared.log("🎫 SUPABASE SIGNIN: User authenticated, Apple ID service will handle subscription linking", category: "AUTH_SIGNIN")

            self.isAuthenticated = true
            self.userEmail = session.user.email
            DebugLogger.shared.log("✅ SIGN IN: Authentication state updated to TRUE", category: "AUTH_SIGNIN")

        } catch {
            DebugLogger.shared.log("\n❌ SIGN IN: Error occurred via SupabaseManager", category: "AUTH_SIGNIN")
            DebugLogger.shared.log("❌ SIGN IN: Error = \(error)", category: "AUTH_SIGNIN")

            self.errorMessage = error.localizedDescription
        }

        isLoading = false
        DebugLogger.shared.log("🔐 SIGN IN: Complete. Auth state = \(isAuthenticated)\n", category: "AUTH_SIGNIN")
    }

    func signOut() async {
        DebugLogger.shared.log("\n🚪 SIGN OUT: Starting user sign out via SupabaseManager", category: "AUTH_SIGNOUT")
        DebugLogger.shared.log("🚪 SIGN OUT: Current auth state = \(isAuthenticated)", category: "AUTH_SIGNOUT")
        
        DebugLogger.shared.log("🚪 SIGN OUT: Signing out from Supabase only (Apple ID service manages subscriptions independently)", category: "AUTH_SIGNOUT")

        do {
            try await SupabaseManager.shared.signOut()
            DebugLogger.shared.log("✅ SIGN OUT: Supabase signOut completed via SupabaseManager", category: "AUTH_SIGNOUT")

            DebugLogger.shared.log("🎫 SIGN OUT: Supabase logout successful - subscriptions remain with Apple ID service", category: "AUTH_SIGNOUT")

            self.isAuthenticated = false
            self.userEmail = nil
            DebugLogger.shared.log("✅ SIGN OUT: Authentication state updated to FALSE", category: "AUTH_SIGNOUT")

        } catch {
            DebugLogger.shared.log("\n❌ SIGN OUT: Error occurred", category: "AUTH_SIGNOUT")
            DebugLogger.shared.log("❌ SIGN OUT: Error = \(error)", category: "AUTH_SIGNOUT")
            DebugLogger.shared.log("❌ SIGN OUT: Error code: \((error as NSError).code)", category: "AUTH_SIGNOUT")
            DebugLogger.shared.log("❌ SIGN OUT: Error domain: \((error as NSError).domain)", category: "AUTH_SIGNOUT")

            self.errorMessage = error.localizedDescription
        }

        DebugLogger.shared.log("🚪 SIGN OUT: Complete. Auth state = \(isAuthenticated)\n", category: "AUTH_SIGNOUT")
    }


    deinit {
        DebugLogger.shared.log("💀 AUTH DEINIT: AuthenticationViewModel is being deallocated", category: "AUTH_DEINIT")
        networkMonitor.cancel()
    }
}
