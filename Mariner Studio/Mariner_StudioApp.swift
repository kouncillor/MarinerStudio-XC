import SwiftUI

@main
struct Mariner_StudioApp: App {

    // Access the Adaptor for RevenueCat
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Create a shared service provider at app startup
    @StateObject private var serviceProvider = ServiceProvider()

    init() {
        DebugLogger.shared.printLogLocation()
        DebugLogger.shared.log("🚀 Mariner_StudioApp: App initialization started", category: "APP_INIT")
        DebugLogger.shared.log("🔧 Mariner_StudioApp: Core Data + CloudKit replaces Supabase", category: "APP_INIT")

        // Test obfuscated keys - Still needed for legacy services
        SecureKeys.verifyKeys()
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
