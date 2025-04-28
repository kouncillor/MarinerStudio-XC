import SwiftUI

@main
struct Mariner_StudioApp: App {
    // Create a shared service provider at app startup
    @StateObject private var serviceProvider = ServiceProvider()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                // Inject the service provider into the environment
                .environmentObject(serviceProvider)
                .preferredColorScheme(.light) // Force light mode
        }
    }
}
