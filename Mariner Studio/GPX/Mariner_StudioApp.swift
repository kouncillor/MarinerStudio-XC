import SwiftUI

@main
struct Mariner_StudioApp: App {
    
    //Access the Adaptor for RevenueCat
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    
    

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

//TODO: Just leaving a comment here so that there is a change so I can update
//
//feat: Replace CloudKit with Supabase for cross-platform photo sync
//
//- Add Supabase infrastructure (SupabaseManager, SupabaseConfig)
//- Replace CloudPhoto model with SupabasePhoto model
//- Replace iCloudSyncService with SupabaseSyncService
//- Update ServiceProvider to use Supabase services
//- Maintain identical functionality and MVVM architecture
//- Enable anonymous authentication via Supabase
//- Preserve local SQLite caching and offline support
//- Remove all CloudKit dependencies and references
//
//This migration enables future Android/Web development while
//maintaining zero breaking changes for users. Photo upload,
//download, delete, and sync functionality remains identical.
//
//Breaking Changes: None (internal service replacement only)
