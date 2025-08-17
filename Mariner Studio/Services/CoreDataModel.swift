import Foundation
import CoreData
import CloudKit

/// Programmatic Core Data model definition
/// This replaces the need for a .xcdatamodeld file
/// All entities are automatically CloudKit-enabled
class CoreDataModel {
    
    static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create all entities
        let tideFavoriteEntity = createTideFavoriteEntity()
        let weatherFavoriteEntity = createWeatherFavoriteEntity()
        let navUnitFavoriteEntity = createNavUnitFavoriteEntity()
        let currentFavoriteEntity = createCurrentFavoriteEntity()
        let buoyFavoriteEntity = createBuoyFavoriteEntity()
        
        // Add entities to model
        model.entities = [
            tideFavoriteEntity,
            weatherFavoriteEntity,
            navUnitFavoriteEntity,
            currentFavoriteEntity,
            buoyFavoriteEntity
        ]
        
        DebugLogger.shared.log("📊 CORE_DATA_MODEL: Programmatic model created with \(model.entities.count) entities", category: "CORE_DATA_MODEL")
        
        return model
    }
    
    // MARK: - TideFavorite Entity
    private static func createTideFavoriteEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "TideFavorite"
        entity.managedObjectClassName = "TideFavorite"
        
        // CloudKit configuration
        entity.userInfo = [
            "NSCloudKitTableNameKey": "CD_TideFavorite"
        ]
        
        // Attributes
        let stationId = NSAttributeDescription()
        stationId.name = "stationId"
        stationId.attributeType = .stringAttributeType
        stationId.isOptional = false
        stationId.defaultValue = ""
        
        let name = NSAttributeDescription()
        name.name = "name"
        name.attributeType = .stringAttributeType
        name.isOptional = false
        name.defaultValue = ""
        
        let latitude = NSAttributeDescription()
        latitude.name = "latitude"
        latitude.attributeType = .doubleAttributeType
        latitude.isOptional = false
        latitude.defaultValue = 0.0
        
        let longitude = NSAttributeDescription()
        longitude.name = "longitude"
        longitude.attributeType = .doubleAttributeType
        longitude.isOptional = false
        longitude.defaultValue = 0.0
        
        let dateAdded = NSAttributeDescription()
        dateAdded.name = "dateAdded"
        dateAdded.attributeType = .dateAttributeType
        dateAdded.isOptional = false
        dateAdded.defaultValue = Date()
        
        entity.properties = [stationId, name, latitude, longitude, dateAdded]
        
        return entity
    }
    
    // MARK: - WeatherFavorite Entity
    private static func createWeatherFavoriteEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "WeatherFavorite"
        entity.managedObjectClassName = "WeatherFavorite"
        
        // CloudKit configuration
        entity.userInfo = [
            "NSCloudKitTableNameKey": "CD_WeatherFavorite"
        ]
        
        // Attributes
        let latitude = NSAttributeDescription()
        latitude.name = "latitude"
        latitude.attributeType = .doubleAttributeType
        latitude.isOptional = false
        latitude.defaultValue = 0.0
        
        let longitude = NSAttributeDescription()
        longitude.name = "longitude"
        longitude.attributeType = .doubleAttributeType
        longitude.isOptional = false
        longitude.defaultValue = 0.0
        
        let locationName = NSAttributeDescription()
        locationName.name = "locationName"
        locationName.attributeType = .stringAttributeType
        locationName.isOptional = false
        locationName.defaultValue = ""
        
        let dateAdded = NSAttributeDescription()
        dateAdded.name = "dateAdded"
        dateAdded.attributeType = .dateAttributeType
        dateAdded.isOptional = false
        dateAdded.defaultValue = Date()
        
        entity.properties = [latitude, longitude, locationName, dateAdded]
        
        return entity
    }
    
    // MARK: - NavUnitFavorite Entity
    private static func createNavUnitFavoriteEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "NavUnitFavorite"
        entity.managedObjectClassName = "NavUnitFavorite"
        
        // CloudKit configuration
        entity.userInfo = [
            "NSCloudKitTableNameKey": "CD_NavUnitFavorite"
        ]
        
        // Attributes
        let navUnitId = NSAttributeDescription()
        navUnitId.name = "navUnitId"
        navUnitId.attributeType = .stringAttributeType
        navUnitId.isOptional = false
        navUnitId.defaultValue = ""
        
        let name = NSAttributeDescription()
        name.name = "name"
        name.attributeType = .stringAttributeType
        name.isOptional = false
        name.defaultValue = ""
        
        let latitude = NSAttributeDescription()
        latitude.name = "latitude"
        latitude.attributeType = .doubleAttributeType
        latitude.isOptional = false
        latitude.defaultValue = 0.0
        
        let longitude = NSAttributeDescription()
        longitude.name = "longitude"
        longitude.attributeType = .doubleAttributeType
        longitude.isOptional = false
        longitude.defaultValue = 0.0
        
        let dateAdded = NSAttributeDescription()
        dateAdded.name = "dateAdded"
        dateAdded.attributeType = .dateAttributeType
        dateAdded.isOptional = false
        dateAdded.defaultValue = Date()
        
        entity.properties = [navUnitId, name, latitude, longitude, dateAdded]
        
        return entity
    }
    
    // MARK: - CurrentFavorite Entity
    private static func createCurrentFavoriteEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CurrentFavorite"
        entity.managedObjectClassName = "CurrentFavorite"
        
        // CloudKit configuration
        entity.userInfo = [
            "NSCloudKitTableNameKey": "CD_CurrentFavorite"
        ]
        
        // Attributes
        let stationId = NSAttributeDescription()
        stationId.name = "stationId"
        stationId.attributeType = .stringAttributeType
        stationId.isOptional = false
        stationId.defaultValue = ""
        
        let currentBin = NSAttributeDescription()
        currentBin.name = "currentBin"
        currentBin.attributeType = .integer32AttributeType
        currentBin.isOptional = false
        currentBin.defaultValue = 0
        
        let dateAdded = NSAttributeDescription()
        dateAdded.name = "dateAdded"
        dateAdded.attributeType = .dateAttributeType
        dateAdded.isOptional = false
        dateAdded.defaultValue = Date()
        
        entity.properties = [stationId, currentBin, dateAdded]
        
        return entity
    }
    
    // MARK: - BuoyFavorite Entity
    private static func createBuoyFavoriteEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "BuoyFavorite"
        entity.managedObjectClassName = "BuoyFavorite"
        
        // CloudKit configuration
        entity.userInfo = [
            "NSCloudKitTableNameKey": "CD_BuoyFavorite"
        ]
        
        // Attributes
        let stationId = NSAttributeDescription()
        stationId.name = "stationId"
        stationId.attributeType = .stringAttributeType
        stationId.isOptional = false
        stationId.defaultValue = ""
        
        let name = NSAttributeDescription()
        name.name = "name"
        name.attributeType = .stringAttributeType
        name.isOptional = false
        name.defaultValue = ""
        
        let latitude = NSAttributeDescription()
        latitude.name = "latitude"
        latitude.attributeType = .doubleAttributeType
        latitude.isOptional = false
        latitude.defaultValue = 0.0
        
        let longitude = NSAttributeDescription()
        longitude.name = "longitude"
        longitude.attributeType = .doubleAttributeType
        longitude.isOptional = false
        longitude.defaultValue = 0.0
        
        let dateAdded = NSAttributeDescription()
        dateAdded.name = "dateAdded"
        dateAdded.attributeType = .dateAttributeType
        dateAdded.isOptional = false
        dateAdded.defaultValue = Date()
        
        entity.properties = [stationId, name, latitude, longitude, dateAdded]
        
        return entity
    }
}