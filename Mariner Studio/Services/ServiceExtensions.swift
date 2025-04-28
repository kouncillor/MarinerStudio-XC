import SwiftUI

// Extensions to make it easier to work with services
extension View {
    /// Injects all services into this view
    func withInjectedServices(_ serviceProvider: ServiceProvider = ServiceProvider()) -> some View {
        self.environmentObject(serviceProvider)
    }
}

// Convenience extension to access the database service from SwiftUI views
extension EnvironmentObject where ObjectType == ServiceProvider {
    var database: DatabaseService {
        wrappedValue.databaseService
    }
}
