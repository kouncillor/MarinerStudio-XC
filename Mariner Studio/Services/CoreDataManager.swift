import Foundation
import CoreData
import CloudKit

/// Core Data manager that replaces SupabaseManager
/// Provides a simple, clean interface for all favorite operations
/// CloudKit handles synchronization automatically - no complex sync logic needed
final class CoreDataManager: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = CoreDataManager()
    
    // MARK: - Core Data Stack
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    // MARK: - CloudKit Status
    @Published var isCloudKitAvailable = false
    
    // MARK: - Initialization
    private init() {
        self.persistenceController = PersistenceController.shared
        
        DebugLogger.shared.log("🚀 CORE_DATA_MANAGER: Initializing - much simpler than SupabaseManager!", category: "CORE_DATA_INIT")
        
        Task {
            await checkCloudKitAvailability()
        }
    }
    
    // MARK: - CloudKit Status
    func checkCloudKitAvailability() async {
        let available = await persistenceController.checkCloudKitAvailability()
        
        await MainActor.run {
            self.isCloudKitAvailable = available
            if available {
                DebugLogger.shared.log("✅ CORE_DATA_MANAGER: CloudKit ready - sync will happen automatically", category: "CORE_DATA_CLOUDKIT")
            } else {
                DebugLogger.shared.log("⚠️ CORE_DATA_MANAGER: CloudKit not available - local storage only", category: "CORE_DATA_CLOUDKIT")
            }
        }
    }
    
    // MARK: - Save Operations
    func save() {
        persistenceController.save()
    }
    
    func saveContext() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
                DebugLogger.shared.log("💾 CORE_DATA_MANAGER: Context saved successfully", category: "CORE_DATA_SAVE")
            } catch {
                DebugLogger.shared.log("❌ CORE_DATA_MANAGER: Save failed - \(error)", category: "CORE_DATA_SAVE")
            }
        }
    }
    
    // MARK: - Tide Favorites
    func addTideFavorite(stationId: String, name: String, latitude: Double?, longitude: Double?) {
        DebugLogger.shared.log("➕ TIDE_FAVORITE: Adding \(name) (\(stationId))", category: "CORE_DATA_TIDE")
        
        let favorite = TideFavorite(context: viewContext)
        favorite.stationId = stationId
        favorite.name = name
        favorite.latitude = latitude ?? 0.0
        favorite.longitude = longitude ?? 0.0
        favorite.dateAdded = Date()
        
        saveContext()
        
        DebugLogger.shared.log("✅ TIDE_FAVORITE: Added successfully - CloudKit will sync automatically", category: "CORE_DATA_TIDE")
    }
    
    func removeTideFavorite(stationId: String) {
        DebugLogger.shared.log("➖ TIDE_FAVORITE: Removing \(stationId)", category: "CORE_DATA_TIDE")
        
        let request: NSFetchRequest<TideFavorite> = TideFavorite.fetchRequest()
        request.predicate = NSPredicate(format: "stationId == %@", stationId)
        
        do {
            let favorites = try viewContext.fetch(request)
            for favorite in favorites {
                viewContext.delete(favorite)
            }
            saveContext()
            DebugLogger.shared.log("✅ TIDE_FAVORITE: Removed successfully", category: "CORE_DATA_TIDE")
        } catch {
            DebugLogger.shared.log("❌ TIDE_FAVORITE: Remove failed - \(error)", category: "CORE_DATA_TIDE")
        }
    }
    
    func getTideFavorites() -> [TideFavorite] {
        let request: NSFetchRequest<TideFavorite> = TideFavorite.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TideFavorite.dateAdded, ascending: false)]
        
        do {
            let favorites = try viewContext.fetch(request)
            DebugLogger.shared.log("📥 TIDE_FAVORITE: Retrieved \(favorites.count) favorites", category: "CORE_DATA_TIDE")
            return favorites
        } catch {
            DebugLogger.shared.log("❌ TIDE_FAVORITE: Fetch failed - \(error)", category: "CORE_DATA_TIDE")
            return []
        }
    }
    
    func isTideFavorite(stationId: String) -> Bool {
        let request: NSFetchRequest<TideFavorite> = TideFavorite.fetchRequest()
        request.predicate = NSPredicate(format: "stationId == %@", stationId)
        request.fetchLimit = 1
        
        do {
            let count = try viewContext.count(for: request)
            return count > 0
        } catch {
            DebugLogger.shared.log("❌ TIDE_FAVORITE: Check failed - \(error)", category: "CORE_DATA_TIDE")
            return false
        }
    }
    
    // MARK: - Weather Favorites
    func addWeatherFavorite(latitude: Double, longitude: Double, locationName: String) {
        DebugLogger.shared.log("➕ WEATHER_FAVORITE: Adding \(locationName) (\(latitude), \(longitude))", category: "CORE_DATA_WEATHER")
        
        let favorite = WeatherFavorite(context: viewContext)
        favorite.latitude = latitude
        favorite.longitude = longitude
        favorite.locationName = locationName
        favorite.dateAdded = Date()
        
        saveContext()
        
        DebugLogger.shared.log("✅ WEATHER_FAVORITE: Added successfully", category: "CORE_DATA_WEATHER")
    }
    
    func removeWeatherFavorite(latitude: Double, longitude: Double) {
        DebugLogger.shared.log("➖ WEATHER_FAVORITE: Removing (\(latitude), \(longitude))", category: "CORE_DATA_WEATHER")
        
        let request: NSFetchRequest<WeatherFavorite> = WeatherFavorite.fetchRequest()
        request.predicate = NSPredicate(format: "latitude == %@ AND longitude == %@", 
                                      NSNumber(value: latitude), NSNumber(value: longitude))
        
        do {
            let favorites = try viewContext.fetch(request)
            for favorite in favorites {
                viewContext.delete(favorite)
            }
            saveContext()
            DebugLogger.shared.log("✅ WEATHER_FAVORITE: Removed successfully", category: "CORE_DATA_WEATHER")
        } catch {
            DebugLogger.shared.log("❌ WEATHER_FAVORITE: Remove failed - \(error)", category: "CORE_DATA_WEATHER")
        }
    }
    
    func getWeatherFavorites() -> [WeatherFavorite] {
        let request: NSFetchRequest<WeatherFavorite> = WeatherFavorite.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeatherFavorite.dateAdded, ascending: false)]
        
        do {
            let favorites = try viewContext.fetch(request)
            DebugLogger.shared.log("📥 WEATHER_FAVORITE: Retrieved \(favorites.count) favorites", category: "CORE_DATA_WEATHER")
            return favorites
        } catch {
            DebugLogger.shared.log("❌ WEATHER_FAVORITE: Fetch failed - \(error)", category: "CORE_DATA_WEATHER")
            return []
        }
    }
    
    func isWeatherFavorite(latitude: Double, longitude: Double) -> Bool {
        let request: NSFetchRequest<WeatherFavorite> = WeatherFavorite.fetchRequest()
        request.predicate = NSPredicate(format: "latitude == %@ AND longitude == %@", 
                                      NSNumber(value: latitude), NSNumber(value: longitude))
        request.fetchLimit = 1
        
        do {
            let count = try viewContext.count(for: request)
            return count > 0
        } catch {
            DebugLogger.shared.log("❌ WEATHER_FAVORITE: Check failed - \(error)", category: "CORE_DATA_WEATHER")
            return false
        }
    }
    
    // MARK: - Navigation Unit Favorites
    func addNavUnitFavorite(navUnitId: String, name: String, latitude: Double?, longitude: Double?) {
        DebugLogger.shared.log("➕ NAVUNIT_FAVORITE: Adding \(name) (\(navUnitId))", category: "CORE_DATA_NAVUNIT")
        
        let favorite = NavUnitFavorite(context: viewContext)
        favorite.navUnitId = navUnitId
        favorite.name = name
        favorite.latitude = latitude ?? 0.0
        favorite.longitude = longitude ?? 0.0
        favorite.dateAdded = Date()
        
        saveContext()
        
        DebugLogger.shared.log("✅ NAVUNIT_FAVORITE: Added successfully", category: "CORE_DATA_NAVUNIT")
    }
    
    func removeNavUnitFavorite(navUnitId: String) {
        DebugLogger.shared.log("➖ NAVUNIT_FAVORITE: Removing \(navUnitId)", category: "CORE_DATA_NAVUNIT")
        
        let request: NSFetchRequest<NavUnitFavorite> = NavUnitFavorite.fetchRequest()
        request.predicate = NSPredicate(format: "navUnitId == %@", navUnitId)
        
        do {
            let favorites = try viewContext.fetch(request)
            for favorite in favorites {
                viewContext.delete(favorite)
            }
            saveContext()
            DebugLogger.shared.log("✅ NAVUNIT_FAVORITE: Removed successfully", category: "CORE_DATA_NAVUNIT")
        } catch {
            DebugLogger.shared.log("❌ NAVUNIT_FAVORITE: Remove failed - \(error)", category: "CORE_DATA_NAVUNIT")
        }
    }
    
    func getNavUnitFavorites() -> [NavUnitFavorite] {
        let request: NSFetchRequest<NavUnitFavorite> = NavUnitFavorite.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NavUnitFavorite.dateAdded, ascending: false)]
        
        do {
            let favorites = try viewContext.fetch(request)
            DebugLogger.shared.log("📥 NAVUNIT_FAVORITE: Retrieved \(favorites.count) favorites", category: "CORE_DATA_NAVUNIT")
            return favorites
        } catch {
            DebugLogger.shared.log("❌ NAVUNIT_FAVORITE: Fetch failed - \(error)", category: "CORE_DATA_NAVUNIT")
            return []
        }
    }
    
    func isNavUnitFavorite(navUnitId: String) -> Bool {
        let request: NSFetchRequest<NavUnitFavorite> = NavUnitFavorite.fetchRequest()
        request.predicate = NSPredicate(format: "navUnitId == %@", navUnitId)
        request.fetchLimit = 1
        
        do {
            let count = try viewContext.count(for: request)
            return count > 0
        } catch {
            DebugLogger.shared.log("❌ NAVUNIT_FAVORITE: Check failed - \(error)", category: "CORE_DATA_NAVUNIT")
            return false
        }
    }
    
    // MARK: - Current Station Favorites
    func addCurrentFavorite(stationId: String, currentBin: Int) {
        DebugLogger.shared.log("➕ CURRENT_FAVORITE: Adding \(stationId) bin \(currentBin)", category: "CORE_DATA_CURRENT")
        
        let favorite = CurrentFavorite(context: viewContext)
        favorite.stationId = stationId
        favorite.currentBin = Int32(currentBin)
        favorite.dateAdded = Date()
        
        saveContext()
        
        DebugLogger.shared.log("✅ CURRENT_FAVORITE: Added successfully", category: "CORE_DATA_CURRENT")
    }
    
    func removeCurrentFavorite(stationId: String, currentBin: Int) {
        DebugLogger.shared.log("➖ CURRENT_FAVORITE: Removing \(stationId) bin \(currentBin)", category: "CORE_DATA_CURRENT")
        
        let request: NSFetchRequest<CurrentFavorite> = CurrentFavorite.fetchRequest()
        request.predicate = NSPredicate(format: "stationId == %@ AND currentBin == %d", stationId, currentBin)
        
        do {
            let favorites = try viewContext.fetch(request)
            for favorite in favorites {
                viewContext.delete(favorite)
            }
            saveContext()
            DebugLogger.shared.log("✅ CURRENT_FAVORITE: Removed successfully", category: "CORE_DATA_CURRENT")
        } catch {
            DebugLogger.shared.log("❌ CURRENT_FAVORITE: Remove failed - \(error)", category: "CORE_DATA_CURRENT")
        }
    }
    
    func getCurrentFavorites() -> [CurrentFavorite] {
        let request: NSFetchRequest<CurrentFavorite> = CurrentFavorite.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CurrentFavorite.dateAdded, ascending: false)]
        
        do {
            let favorites = try viewContext.fetch(request)
            DebugLogger.shared.log("📥 CURRENT_FAVORITE: Retrieved \(favorites.count) favorites", category: "CORE_DATA_CURRENT")
            return favorites
        } catch {
            DebugLogger.shared.log("❌ CURRENT_FAVORITE: Fetch failed - \(error)", category: "CORE_DATA_CURRENT")
            return []
        }
    }
    
    func isCurrentFavorite(stationId: String, currentBin: Int) -> Bool {
        let request: NSFetchRequest<CurrentFavorite> = CurrentFavorite.fetchRequest()
        request.predicate = NSPredicate(format: "stationId == %@ AND currentBin == %d", stationId, currentBin)
        request.fetchLimit = 1
        
        do {
            let count = try viewContext.count(for: request)
            return count > 0
        } catch {
            DebugLogger.shared.log("❌ CURRENT_FAVORITE: Check failed - \(error)", category: "CORE_DATA_CURRENT")
            return false
        }
    }
    
    // MARK: - Buoy Favorites
    func addBuoyFavorite(stationId: String, name: String, latitude: Double?, longitude: Double?) {
        DebugLogger.shared.log("➕ BUOY_FAVORITE: Adding \(name) (\(stationId))", category: "CORE_DATA_BUOY")
        
        let favorite = BuoyFavorite(context: viewContext)
        favorite.stationId = stationId
        favorite.name = name
        favorite.latitude = latitude ?? 0.0
        favorite.longitude = longitude ?? 0.0
        favorite.dateAdded = Date()
        
        saveContext()
        
        DebugLogger.shared.log("✅ BUOY_FAVORITE: Added successfully", category: "CORE_DATA_BUOY")
    }
    
    func removeBuoyFavorite(stationId: String) {
        DebugLogger.shared.log("➖ BUOY_FAVORITE: Removing \(stationId)", category: "CORE_DATA_BUOY")
        
        let request: NSFetchRequest<BuoyFavorite> = BuoyFavorite.fetchRequest()
        request.predicate = NSPredicate(format: "stationId == %@", stationId)
        
        do {
            let favorites = try viewContext.fetch(request)
            for favorite in favorites {
                viewContext.delete(favorite)
            }
            saveContext()
            DebugLogger.shared.log("✅ BUOY_FAVORITE: Removed successfully", category: "CORE_DATA_BUOY")
        } catch {
            DebugLogger.shared.log("❌ BUOY_FAVORITE: Remove failed - \(error)", category: "CORE_DATA_BUOY")
        }
    }
    
    func getBuoyFavorites() -> [BuoyFavorite] {
        let request: NSFetchRequest<BuoyFavorite> = BuoyFavorite.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BuoyFavorite.dateAdded, ascending: false)]
        
        do {
            let favorites = try viewContext.fetch(request)
            DebugLogger.shared.log("📥 BUOY_FAVORITE: Retrieved \(favorites.count) favorites", category: "CORE_DATA_BUOY")
            return favorites
        } catch {
            DebugLogger.shared.log("❌ BUOY_FAVORITE: Fetch failed - \(error)", category: "CORE_DATA_BUOY")
            return []
        }
    }
    
    func isBuoyFavorite(stationId: String) -> Bool {
        let request: NSFetchRequest<BuoyFavorite> = BuoyFavorite.fetchRequest()
        request.predicate = NSPredicate(format: "stationId == %@", stationId)
        request.fetchLimit = 1
        
        do {
            let count = try viewContext.count(for: request)
            return count > 0
        } catch {
            DebugLogger.shared.log("❌ BUOY_FAVORITE: Check failed - \(error)", category: "CORE_DATA_BUOY")
            return false
        }
    }
}