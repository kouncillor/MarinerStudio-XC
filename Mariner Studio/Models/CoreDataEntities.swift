import Foundation
import CoreData
import CloudKit

// MARK: - TideFavorite Entity

@objc(TideFavorite)
public class TideFavorite: NSManagedObject {
    
}

extension TideFavorite {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TideFavorite> {
        return NSFetchRequest<TideFavorite>(entityName: "TideFavorite")
    }

    @NSManaged public var stationId: String
    @NSManaged public var name: String
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var dateAdded: Date

}

extension TideFavorite : Identifiable {

}

// MARK: - WeatherFavorite Entity

@objc(WeatherFavorite)
public class WeatherFavorite: NSManagedObject {
    
}

extension WeatherFavorite {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeatherFavorite> {
        return NSFetchRequest<WeatherFavorite>(entityName: "WeatherFavorite")
    }

    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var locationName: String
    @NSManaged public var dateAdded: Date

}

extension WeatherFavorite : Identifiable {

}

// MARK: - NavUnitFavorite Entity

@objc(NavUnitFavorite)
public class NavUnitFavorite: NSManagedObject {
    
}

extension NavUnitFavorite {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NavUnitFavorite> {
        return NSFetchRequest<NavUnitFavorite>(entityName: "NavUnitFavorite")
    }

    @NSManaged public var navUnitId: String
    @NSManaged public var name: String
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var dateAdded: Date

}

extension NavUnitFavorite : Identifiable {

}

// MARK: - CurrentFavorite Entity

@objc(CurrentFavorite)
public class CurrentFavorite: NSManagedObject {
    
}

extension CurrentFavorite {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CurrentFavorite> {
        return NSFetchRequest<CurrentFavorite>(entityName: "CurrentFavorite")
    }

    @NSManaged public var stationId: String
    @NSManaged public var currentBin: Int32
    @NSManaged public var dateAdded: Date

}

extension CurrentFavorite : Identifiable {

}

// MARK: - BuoyFavorite Entity

@objc(BuoyFavorite)
public class BuoyFavorite: NSManagedObject {
    
}

extension BuoyFavorite {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BuoyFavorite> {
        return NSFetchRequest<BuoyFavorite>(entityName: "BuoyFavorite")
    }

    @NSManaged public var stationId: String
    @NSManaged public var name: String
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var dateAdded: Date

}

extension BuoyFavorite : Identifiable {

}