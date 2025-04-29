import Foundation
import SwiftUI

// This class will hold our service instances
class ServiceProvider: ObservableObject {
    // Database service
    let databaseService: DatabaseService
    
    init(databaseService: DatabaseService? = nil) {
        // Use provided service or get the singleton instance
        if let databaseService = databaseService {
            self.databaseService = databaseService
        } else {
            // Use the singleton instance
            self.databaseService = DatabaseServiceImpl.getInstance()
        }
        
        // Initialize database on creation
        Task {
            do {
                try await self.databaseService.initializeAsync()
                print("Database successfully initialized by ServiceProvider")
            } catch {
                print("Error initializing database: \(error)")
            }
        }
    }
        
}
