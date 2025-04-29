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

//TODO: Just leaving a comment here so that there is a change so I can update this github repo
