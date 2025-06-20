
import Foundation
import RevenueCat
import Combine
import Network

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")

    init() {
        print("🎯 AUTH INIT: AuthenticationViewModel initializing")
        setupNetworkMonitoring()
        
        Task {
            print("🎯 AUTH INIT: Starting checkSession task")
            await checkSession()
        }
    }
    
    private func setupNetworkMonitoring() {
        print("📡 NETWORK: Setting up network monitoring")
        networkMonitor.pathUpdateHandler = { path in
            print("📡 NETWORK STATUS: \(path.status)")
            print("📡 NETWORK EXPENSIVE: \(path.isExpensive)")
            print("📡 NETWORK CONSTRAINED: \(path.isConstrained)")
            print("📡 NETWORK INTERFACES: \(path.availableInterfaces)")
            
            if path.status == .satisfied {
                print("✅ NETWORK: Connection is available")
                if path.usesInterfaceType(.wifi) {
                    print("📡 NETWORK: Using WiFi")
                } else if path.usesInterfaceType(.cellular) {
                    print("📡 NETWORK: Using Cellular")
                } else if path.usesInterfaceType(.wiredEthernet) {
                    print("📡 NETWORK: Using Ethernet")
                }
            } else {
                print("❌ NETWORK: No connection available")
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    func checkSession() async {
        print("\n🔍 SESSION CHECK: Starting session validation using SupabaseManager")
        print("🔍 SESSION CHECK: Current authentication state = \(isAuthenticated)")
        print("🔍 SESSION CHECK: Thread = \(Thread.current)")
        print("🔍 SESSION CHECK: Timestamp = \(Date())")
        
        do {
            let session = try await SupabaseManager.shared.getSession()
            
            print("✅ SESSION CHECK: SUCCESS! Session retrieved via SupabaseManager")
            print("✅ SESSION CHECK: User ID = \(session.user.id)")
            print("✅ SESSION CHECK: User email = \(session.user.email ?? "NO EMAIL")")
            
            self.isAuthenticated = true
            print("✅ SESSION CHECK: Authentication state updated to TRUE")
            
            print("🎫 REVENUE CAT: Starting RevenueCat login")
            await logInToRevenueCat(userId: session.user.id.uuidString)
            
        } catch {
            print("\n❌ SESSION CHECK: Error occurred via SupabaseManager")
            print("❌ SESSION CHECK: Error = \(error)")
            
            self.isAuthenticated = false
            print("❌ SESSION CHECK: Authentication state updated to FALSE")
        }
        
        print("🔍 SESSION CHECK: Complete. Final auth state = \(isAuthenticated)\n")
    }
    
    func signUp(email: String, password: String) async {
        print("\n📝 SIGN UP: Starting user registration via SupabaseManager")
        print("📝 SIGN UP: Email = \(email)")
        print("📝 SIGN UP: Password length = \(password.count)")
        
        isLoading = true
        errorMessage = nil
        print("📝 SIGN UP: Loading state set to TRUE")
        
        do {
            let authResponse = try await SupabaseManager.shared.signUp(email: email, password: password)
            
            print("✅ SIGN UP: SUCCESS! User created via SupabaseManager")
            print("✅ SIGN UP: User ID = \(authResponse.user.id)")
            print("✅ SIGN UP: User email = \(authResponse.user.email ?? "NO EMAIL")")
            
            await logInToRevenueCat(userId: authResponse.user.id.uuidString)
            
            self.isAuthenticated = true
            print("✅ SIGN UP: Authentication state updated to TRUE")
            
        } catch {
            print("\n❌ SIGN UP: Error occurred via SupabaseManager")
            print("❌ SIGN UP: Error = \(error)")
            
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
        print("📝 SIGN UP: Complete. Auth state = \(isAuthenticated)\n")
    }

    func signIn(email: String, password: String) async {
        print("\n🔐 SIGN IN: Starting user authentication via SupabaseManager")
        print("🔐 SIGN IN: Email = \(email)")
        print("🔐 SIGN IN: Password length = \(password.count)")
        
        isLoading = true
        errorMessage = nil
        print("🔐 SIGN IN: Loading state set to TRUE")
        
        do {
            let session = try await SupabaseManager.shared.signIn(email: email, password: password)
            
            print("✅ SIGN IN: SUCCESS! User authenticated via SupabaseManager")
            print("✅ SIGN IN: User ID = \(session.user.id)")
            print("✅ SIGN IN: User email = \(session.user.email ?? "NO EMAIL")")
            
            await logInToRevenueCat(userId: session.user.id.uuidString)
            
            self.isAuthenticated = true
            print("✅ SIGN IN: Authentication state updated to TRUE")
            
        } catch {
            print("\n❌ SIGN IN: Error occurred via SupabaseManager")
            print("❌ SIGN IN: Error = \(error)")
            
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
        print("🔐 SIGN IN: Complete. Auth state = \(isAuthenticated)\n")
    }

    func signOut() async {
        print("\n🚪 SIGN OUT: Starting user sign out via SupabaseManager")
        print("🚪 SIGN OUT: Current auth state = \(isAuthenticated)")
        
        do {
            try await SupabaseManager.shared.signOut()
            print("✅ SIGN OUT: Supabase signOut completed via SupabaseManager")
            
            print("🎫 SIGN OUT: Calling RevenueCat logOut...")
            try await Purchases.shared.logOut()
            print("✅ SIGN OUT: RevenueCat logOut completed")
            
            self.isAuthenticated = false
            print("✅ SIGN OUT: Authentication state updated to FALSE")
            
        } catch {
            print("\n❌ SIGN OUT: Error occurred")
            print("❌ SIGN OUT: Error = \(error)")
            
            self.errorMessage = error.localizedDescription
        }
        
        print("🚪 SIGN OUT: Complete. Auth state = \(isAuthenticated)\n")
    }

    private func logInToRevenueCat(userId: String) async {
        print("\n🎫 REVENUE CAT: Starting RevenueCat authentication")
        print("🎫 REVENUE CAT: User ID = \(userId)")
        
        do {
            let result = try await Purchases.shared.logIn(userId)
            
            print("✅ REVENUE CAT: SUCCESS! Login completed")
            print("✅ REVENUE CAT: Customer info received")
            print("✅ REVENUE CAT: Entitlements count = \(result.customerInfo.entitlements.all.count)")
            
        } catch {
            print("\n❌ REVENUE CAT: Error occurred")
            print("❌ REVENUE CAT: Error = \(error)")
            
            self.errorMessage = "Could not connect to subscription service: \(error.localizedDescription)"
        }
        
        print("🎫 REVENUE CAT: Complete\n")
    }
    
    deinit {
        print("💀 AUTH DEINIT: AuthenticationViewModel is being deallocated")
        networkMonitor.cancel()
    }
}
