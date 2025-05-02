import Foundation
import SwiftUI
import CoreLocation // Added import

// This class will hold our service instances
class ServiceProvider: ObservableObject {
    // MARK: - Service Properties
    let databaseService: DatabaseService
    let locationService: LocationService // Added LocationService

    // MARK: - Initialization
    init(databaseService: DatabaseService? = nil, locationService: LocationService? = nil) {

        // --- Initialize DatabaseService ---
        // Use provided service or get the singleton instance
        if let providedDatabaseService = databaseService {
            self.databaseService = providedDatabaseService
            print("📦 ServiceProvider: Initialized with provided DatabaseService.")
        } else {
            // Use the singleton instance
            self.databaseService = DatabaseServiceImpl.getInstance()
            print("📦 ServiceProvider: Initialized with singleton DatabaseService.")
        }

        // --- Initialize LocationService ---
        // Use provided service or create a default instance
        if let providedLocationService = locationService {
            self.locationService = providedLocationService
            print("📦 ServiceProvider: Initialized with provided LocationService.")
        } else {
            // Create a default instance
            self.locationService = LocationServiceImpl()
            print("📦 ServiceProvider: Initialized with default LocationServiceImpl.")
        }

        // --- Asynchronous Initialization Tasks ---

        // Task 1: Initialize database
        Task(priority: .utility) { // Run database init concurrently
            do {
                print("🚀 ServiceProvider: Initializing Database...")
                try await self.databaseService.initializeAsync()
                print("✅ ServiceProvider: Database successfully initialized.")
            } catch {
                // Log error, but don't necessarily block app launch
                print("❌ ServiceProvider: Error initializing database: \(error.localizedDescription)")
            }
        }

        // Task 2: Request location permission and start updates early
        Task(priority: .utility) { // Run location init concurrently
            do {
                print("🚀 ServiceProvider: Requesting location permission...")
                // Optional: Small delay to allow UI to settle before permission prompt
                try await Task.sleep(for: .seconds(0.5))

                let authorized = await self.locationService.requestLocationPermission()

                await MainActor.run { // Ensure UI-related state or calls happen on main thread if needed later
                    if authorized {
                        print("✅ ServiceProvider: Location permission granted/exists. Starting updates.")
                        // Start location updates if authorized
                        self.locationService.startUpdatingLocation()
                    } else {
                        // This case is expected if user denies, restricts, or hasn't decided yet
                        print("⚠️ ServiceProvider: Location permission not authorized at launch (Status: \(self.locationService.permissionStatus.description)). Updates not started.")
                    }
                }
            } catch {
                // This catch block handles errors during the Task.sleep or potentially future
                // errors if requestLocationPermission were to throw.
                 print("❌ ServiceProvider: Error during location permission request task: \(error.localizedDescription)")
            }
        }

        print("📦 ServiceProvider initialization complete (async tasks launched).")
    }
}
