import Foundation
import Supabase
import RevenueCat
import Combine
import Network

// GLOBAL SUPABASE CLIENT WITH EXTREME LOGGING
let supabase: SupabaseClient = {
    print("🚀 SUPABASE INIT: Starting Supabase client initialization")
    print("🚀 SUPABASE INIT: URL = https://lgdsvefqqorvnvkiobth.supabase.co")
    print("🚀 SUPABASE INIT: Key length = 167 characters")
    
    guard let url = URL(string: "https://lgdsvefqqorvnvkiobth.supabase.co") else {
        print("❌ SUPABASE INIT: FATAL - Invalid URL string")
        fatalError("Invalid Supabase URL")
    }
    
    print("🚀 SUPABASE INIT: URL object created successfully")
    
    let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxnZHN2ZWZxcW9ydm52a2lvYnRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwOTQ1MjQsImV4cCI6MjA2NTY3MDUyNH0.rNc5QTtV4IQK5n-HvCEpOZDpVCwPpmKkjYVBEHOqnVI"
    
    print("🚀 SUPABASE INIT: Creating SupabaseClient instance...")
    let client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    print("✅ SUPABASE INIT: Client created successfully")
    
    return client
}()

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
        print("\n🔍 SESSION CHECK: Starting session validation")
        print("🔍 SESSION CHECK: Current authentication state = \(isAuthenticated)")
        print("🔍 SESSION CHECK: Thread = \(Thread.current)")
        print("🔍 SESSION CHECK: Timestamp = \(Date())")
        
        do {
            print("🔍 SESSION CHECK: Attempting to get session from Supabase...")
            print("🔍 SESSION CHECK: Client object = \(ObjectIdentifier(supabase))")
            
            let startTime = Date()
            print("🔍 SESSION CHECK: Request start time = \(startTime)")
            
            let session = try await supabase.auth.session
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            print("✅ SESSION CHECK: SUCCESS! Request completed in \(String(format: "%.3f", duration)) seconds")
            print("✅ SESSION CHECK: Session received")
            print("✅ SESSION CHECK: User ID = \(session.user.id)")
            print("✅ SESSION CHECK: User email = \(session.user.email ?? "NO EMAIL")")
            print("✅ SESSION CHECK: Session expires at = \(Date(timeIntervalSince1970: TimeInterval(session.expiresAt)))")
            print("✅ SESSION CHECK: Access token length = \(session.accessToken.count)")
            print("✅ SESSION CHECK: Refresh token length = \(session.refreshToken.count)")
            
            self.isAuthenticated = true
            print("✅ SESSION CHECK: Authentication state updated to TRUE")
            
            print("🎫 REVENUE CAT: Starting RevenueCat login")
            await logInToRevenueCat(userId: session.user.id.uuidString)
            
        } catch let error as URLError {
            print("\n❌ SESSION CHECK: URLError occurred")
            print("❌ SESSION CHECK: Error code = \(error.code)")
            print("❌ SESSION CHECK: Error description = \(error.localizedDescription)")
            print("❌ SESSION CHECK: Failure reason = \(error.localizedDescription ?? "None")")
            
            print("❌ SESSION CHECK: Error domain = \(error.errorCode)")
            
            switch error.code {
            case .notConnectedToInternet:
                print("❌ SESSION CHECK: No internet connection")
            case .timedOut:
                print("❌ SESSION CHECK: Request timed out")
            case .cannotFindHost:
                print("❌ SESSION CHECK: Cannot find host (DNS issue)")
            case .cannotConnectToHost:
                print("❌ SESSION CHECK: Cannot connect to host")
            case .networkConnectionLost:
                print("❌ SESSION CHECK: Network connection lost")
            case .dnsLookupFailed:
                print("❌ SESSION CHECK: DNS lookup failed")
            case .httpTooManyRedirects:
                print("❌ SESSION CHECK: Too many redirects")
            case .resourceUnavailable:
                print("❌ SESSION CHECK: Resource unavailable")
            case .secureConnectionFailed:
                print("❌ SESSION CHECK: SSL/TLS connection failed")
            default:
                print("❌ SESSION CHECK: Other URL error: \(error.code)")
            }
            
            self.isAuthenticated = false
            print("❌ SESSION CHECK: Authentication state updated to FALSE")
            
        } catch {
            print("\n❌ SESSION CHECK: General error occurred")
            print("❌ SESSION CHECK: Error type = \(type(of: error))")
            print("❌ SESSION CHECK: Error description = \(error.localizedDescription)")
            print("❌ SESSION CHECK: Error = \(error)")
            
            // Check if it's a Supabase-specific error
            if String(describing: type(of: error)).contains("Supabase") {
                print("❌ SESSION CHECK: This appears to be a Supabase-related error")
            }
            
            // Try to extract more error info
            let nsError = error as NSError
            print("❌ SESSION CHECK: NSError domain = \(nsError.domain)")
            print("❌ SESSION CHECK: NSError code = \(nsError.code)")
            print("❌ SESSION CHECK: NSError userInfo = \(nsError.userInfo)")
            
            self.isAuthenticated = false
            print("❌ SESSION CHECK: Authentication state updated to FALSE")
        }
        
        print("🔍 SESSION CHECK: Complete. Final auth state = \(isAuthenticated)\n")
    }
    
    func signUp(email: String, password: String) async {
        print("\n📝 SIGN UP: Starting user registration")
        print("📝 SIGN UP: Email = \(email)")
        print("📝 SIGN UP: Password length = \(password.count)")
        print("📝 SIGN UP: Timestamp = \(Date())")
        
        isLoading = true
        errorMessage = nil
        print("📝 SIGN UP: Loading state set to TRUE")
        
        do {
            print("📝 SIGN UP: Calling Supabase signUp...")
            let startTime = Date()
            
            let authResponse = try await supabase.auth.signUp(email: email, password: password)
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            print("✅ SIGN UP: SUCCESS! Request completed in \(String(format: "%.3f", duration)) seconds")
            print("✅ SIGN UP: User created with ID = \(authResponse.user.id)")
            print("✅ SIGN UP: User email = \(authResponse.user.email ?? "NO EMAIL")")
            print("✅ SIGN UP: Email confirmed = \(authResponse.user.emailConfirmedAt != nil)")
            
            print("🎫 SIGN UP: Starting RevenueCat login")
            await logInToRevenueCat(userId: authResponse.user.id.uuidString)
            
            self.isAuthenticated = true
            print("✅ SIGN UP: Authentication state updated to TRUE")
            
        } catch let error as URLError {
            print("\n❌ SIGN UP: URLError occurred")
            print("❌ SIGN UP: Error code = \(error.code)")
            print("❌ SIGN UP: Error description = \(error.localizedDescription)")
            self.errorMessage = "Network error: \(error.localizedDescription)"
            
        } catch {
            print("\n❌ SIGN UP: General error occurred")
            print("❌ SIGN UP: Error type = \(type(of: error))")
            print("❌ SIGN UP: Error description = \(error.localizedDescription)")
            print("❌ SIGN UP: Error = \(error)")
            
            let nsError = error as NSError
            print("❌ SIGN UP: NSError domain = \(nsError.domain)")
            print("❌ SIGN UP: NSError code = \(nsError.code)")
            print("❌ SIGN UP: NSError userInfo = \(nsError.userInfo)")
            
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
        print("📝 SIGN UP: Loading state set to FALSE")
        print("📝 SIGN UP: Complete. Auth state = \(isAuthenticated)\n")
    }

    func signIn(email: String, password: String) async {
        print("\n🔐 SIGN IN: Starting user authentication")
        print("🔐 SIGN IN: Email = \(email)")
        print("🔐 SIGN IN: Password length = \(password.count)")
        print("🔐 SIGN IN: Timestamp = \(Date())")
        
        isLoading = true
        errorMessage = nil
        print("🔐 SIGN IN: Loading state set to TRUE")
        
        do {
            print("🔐 SIGN IN: Calling Supabase signIn...")
            let startTime = Date()
            
            let authResponse = try await supabase.auth.signIn(email: email, password: password)
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            print("✅ SIGN IN: SUCCESS! Request completed in \(String(format: "%.3f", duration)) seconds")
            print("✅ SIGN IN: User authenticated with ID = \(authResponse.user.id)")
            print("✅ SIGN IN: User email = \(authResponse.user.email ?? "NO EMAIL")")
            
            
            print("🎫 SIGN IN: Starting RevenueCat login")
            await logInToRevenueCat(userId: authResponse.user.id.uuidString)
            
            self.isAuthenticated = true
            print("✅ SIGN IN: Authentication state updated to TRUE")
            
        } catch let error as URLError {
            print("\n❌ SIGN IN: URLError occurred")
            print("❌ SIGN IN: Error code = \(error.code)")
            print("❌ SIGN IN: Error description = \(error.localizedDescription)")
            self.errorMessage = "Network error: \(error.localizedDescription)"
            
        } catch {
            print("\n❌ SIGN IN: General error occurred")
            print("❌ SIGN IN: Error type = \(type(of: error))")
            print("❌ SIGN IN: Error description = \(error.localizedDescription)")
            print("❌ SIGN IN: Error = \(error)")
            
            let nsError = error as NSError
            print("❌ SIGN IN: NSError domain = \(nsError.domain)")
            print("❌ SIGN IN: NSError code = \(nsError.code)")
            print("❌ SIGN IN: NSError userInfo = \(nsError.userInfo)")
            
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
        print("🔐 SIGN IN: Loading state set to FALSE")
        print("🔐 SIGN IN: Complete. Auth state = \(isAuthenticated)\n")
    }

    func signOut() async {
        print("\n🚪 SIGN OUT: Starting user sign out")
        print("🚪 SIGN OUT: Current auth state = \(isAuthenticated)")
        print("🚪 SIGN OUT: Timestamp = \(Date())")
        
        do {
            print("🚪 SIGN OUT: Calling Supabase signOut...")
            let startTime = Date()
            
            try await supabase.auth.signOut()
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            print("✅ SIGN OUT: Supabase signOut completed in \(String(format: "%.3f", duration)) seconds")
            
            print("🎫 SIGN OUT: Calling RevenueCat logOut...")
            let rcStartTime = Date()
            
            try await Purchases.shared.logOut()
            
            let rcEndTime = Date()
            let rcDuration = rcEndTime.timeIntervalSince(rcStartTime)
            print("✅ SIGN OUT: RevenueCat logOut completed in \(String(format: "%.3f", rcDuration)) seconds")
            
            self.isAuthenticated = false
            print("✅ SIGN OUT: Authentication state updated to FALSE")
            
        } catch let error as URLError {
            print("\n❌ SIGN OUT: URLError occurred")
            print("❌ SIGN OUT: Error code = \(error.code)")
            print("❌ SIGN OUT: Error description = \(error.localizedDescription)")
            self.errorMessage = "Network error during sign out: \(error.localizedDescription)"
            
        } catch {
            print("\n❌ SIGN OUT: General error occurred")
            print("❌ SIGN OUT: Error type = \(type(of: error))")
            print("❌ SIGN OUT: Error description = \(error.localizedDescription)")
            print("❌ SIGN OUT: Error = \(error)")
            
            let nsError = error as NSError
            print("❌ SIGN OUT: NSError domain = \(nsError.domain)")
            print("❌ SIGN OUT: NSError code = \(nsError.code)")
            print("❌ SIGN OUT: NSError userInfo = \(nsError.userInfo)")
            
            self.errorMessage = error.localizedDescription
        }
        
        print("🚪 SIGN OUT: Complete. Auth state = \(isAuthenticated)\n")
    }

    private func logInToRevenueCat(userId: String) async {
        print("\n🎫 REVENUE CAT: Starting RevenueCat authentication")
        print("🎫 REVENUE CAT: User ID = \(userId)")
        print("🎫 REVENUE CAT: Timestamp = \(Date())")
        
        do {
            print("🎫 REVENUE CAT: Calling Purchases.shared.logIn...")
            let startTime = Date()
            
            let result = try await Purchases.shared.logIn(userId)
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            print("✅ REVENUE CAT: SUCCESS! Login completed in \(String(format: "%.3f", duration)) seconds")
            print("✅ REVENUE CAT: Customer info received")
            print("✅ REVENUE CAT: Customer ID = \(result.customerInfo.originalApplicationVersion ?? "Unknown")")
            print("✅ REVENUE CAT: Entitlements count = \(result.customerInfo.entitlements.all.count)")
            
        } catch {
            print("\n❌ REVENUE CAT: Error occurred")
            print("❌ REVENUE CAT: Error type = \(type(of: error))")
            print("❌ REVENUE CAT: Error description = \(error.localizedDescription)")
            print("❌ REVENUE CAT: Error = \(error)")
            
            let nsError = error as NSError
            print("❌ REVENUE CAT: NSError domain = \(nsError.domain)")
            print("❌ REVENUE CAT: NSError code = \(nsError.code)")
            print("❌ REVENUE CAT: NSError userInfo = \(nsError.userInfo)")
            
            self.errorMessage = "Could not connect to subscription service: \(error.localizedDescription)"
        }
        
        print("🎫 REVENUE CAT: Complete\n")
    }
    
    deinit {
        print("💀 AUTH DEINIT: AuthenticationViewModel is being deallocated")
        networkMonitor.cancel()
    }
}
