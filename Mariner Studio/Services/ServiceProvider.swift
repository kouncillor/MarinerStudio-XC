import Foundation
import SwiftUI

// This class will hold our service instances
class ServiceProvider: ObservableObject {
    // Database service
    let databaseService: DatabaseService
    
    // Initialize with default implementations
    init(databaseService: DatabaseService? = nil) {
        // Use provided service or create default
        if let databaseService = databaseService {
            self.databaseService = databaseService
        } else {
            #if DEBUG && targetEnvironment(simulator)
            // Use mock service for simulator debugging if needed
            self.databaseService = MockDatabaseService()
            #else
            // Use real implementation for device and production
            self.databaseService = DatabaseServiceImpl()
            #endif
        }
        
        // Initialize database on creation
        Task {
            do {
                try await self.databaseService.initializeAsync()
                print("Database successfully initialized")
            } catch {
                print("Error initializing database: \(error)")
            }
        }
    }
}
