
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
