import CoreData
import CloudKit

/// Core Data persistence controller with CloudKit integration
/// Replaces the complex Supabase sync architecture with Apple's native solution
struct PersistenceController {
    
    // MARK: - Shared Instance
    static let shared = PersistenceController()
    
    // MARK: - Preview/Testing Instance
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Add sample data for previews
        let sampleTideFavorite = TideFavorite(context: viewContext)
        sampleTideFavorite.stationId = "8518750"
        sampleTideFavorite.name = "The Battery, NY"
        sampleTideFavorite.latitude = 40.7002
        sampleTideFavorite.longitude = -74.0142
        sampleTideFavorite.dateAdded = Date()
        
        do {
            try viewContext.save()
        } catch {
            // Handle the error appropriately in production
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    // MARK: - Core Data Container
    let container: NSPersistentCloudKitContainer
    
    // MARK: - Initialization
    init(inMemory: Bool = false) {
        // Use programmatic model instead of .xcdatamodeld file
        let model = CoreDataModel.createModel()
        container = NSPersistentCloudKitContainer(name: "MarinerData", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure CloudKit integration
            configureCloudKitIntegration()
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                DebugLogger.shared.log("❌ PERSISTENCE: Core Data store loading failed - \(error)", category: "CORE_DATA_ERROR")
                DebugLogger.shared.log("❌ PERSISTENCE: Error details - \(error.userInfo)", category: "CORE_DATA_ERROR")
                
                // For CloudKit errors, provide helpful guidance
                if error.domain == "NSCocoaErrorDomain" && error.code == 134060 {
                    DebugLogger.shared.log("💡 PERSISTENCE: This is a CloudKit schema issue - check entity definitions", category: "CORE_DATA_ERROR")
                }
                
                fatalError("Core Data store loading failed: \(error.localizedDescription)")
            } else {
                DebugLogger.shared.log("✅ PERSISTENCE: Core Data store loaded successfully", category: "CORE_DATA_INIT")
            }
        }
        
        // Configure automatic merging from CloudKit
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - CloudKit Configuration
    private func configureCloudKitIntegration() {
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }
        
        // Enable CloudKit integration
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Configure CloudKit container
        let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.ospreyapplications.Mariner-Studio")
        description.cloudKitContainerOptions = cloudKitContainerOptions
        
        DebugLogger.shared.log("☁️ PERSISTENCE: CloudKit integration configured", category: "CORE_DATA_CLOUDKIT")
        DebugLogger.shared.log("ℹ️ PERSISTENCE: Note - CloudKit push notifications require 'remote-notification' background mode", category: "CORE_DATA_CLOUDKIT")
    }
    
    // MARK: - Save Context
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                DebugLogger.shared.log("💾 PERSISTENCE: Context saved successfully", category: "CORE_DATA_SAVE")
            } catch {
                DebugLogger.shared.log("❌ PERSISTENCE: Save failed - \(error)", category: "CORE_DATA_SAVE")
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - Background Context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    // MARK: - CloudKit Status
    func checkCloudKitAvailability() async -> Bool {
        do {
            let status = try await CKContainer(identifier: "iCloud.com.ospreyapplications.Mariner-Studio").accountStatus()
            
            switch status {
            case .available:
                DebugLogger.shared.log("✅ CLOUDKIT: Account available", category: "CLOUDKIT_STATUS")
                return true
            case .noAccount:
                DebugLogger.shared.log("⚠️ CLOUDKIT: No iCloud account", category: "CLOUDKIT_STATUS")
                return false
            case .restricted:
                DebugLogger.shared.log("⚠️ CLOUDKIT: Account restricted", category: "CLOUDKIT_STATUS")
                return false
            case .couldNotDetermine:
                DebugLogger.shared.log("⚠️ CLOUDKIT: Could not determine status", category: "CLOUDKIT_STATUS")
                return false
            @unknown default:
                DebugLogger.shared.log("⚠️ CLOUDKIT: Unknown status", category: "CLOUDKIT_STATUS")
                return false
            }
        } catch {
            DebugLogger.shared.log("❌ CLOUDKIT: Status check failed - \(error)", category: "CLOUDKIT_STATUS")
            return false
        }
    }
}