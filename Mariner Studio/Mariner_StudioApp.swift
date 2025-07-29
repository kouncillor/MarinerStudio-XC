
import SwiftUI

@main
struct Mariner_StudioApp: App {
    
    //Access the Adaptor for RevenueCat
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Create a shared service provider at app startup
    @StateObject private var serviceProvider = ServiceProvider()
    
    init() {
        // Initialize Supabase manager early
        _ = SupabaseManager.shared
        SupabaseManager.shared.enableVerboseLogging()
        DebugLogger.shared.printLogLocation()
        DebugLogger.shared.log("🚀 Mariner_StudioApp: App initialization started", category: "APP_INIT")
        DebugLogger.shared.log("🔧 Mariner_StudioApp: SupabaseManager initialized and verbose logging enabled", category: "APP_INIT")
        
        // Test obfuscated keys (debug only)
        #if DEBUG
        SecureKeys.verifyKeys()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject the service provider into the environment
                .environmentObject(serviceProvider)
                .preferredColorScheme(.light) // Force light mode
        }
    }
}
