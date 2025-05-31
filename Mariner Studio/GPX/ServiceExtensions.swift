//
//import SwiftUI
//
//// Extensions to make it easier to work with services
//extension View {
//    /// Injects all services into this view
//    func withInjectedServices(_ serviceProvider: ServiceProvider = ServiceProvider()) -> some View {
//        self.environmentObject(serviceProvider)
//    }
//}
//
//// Convenience extensions to access specific database services from SwiftUI views
//extension EnvironmentObject where ObjectType == ServiceProvider {
//    var databaseCore: DatabaseCore {
//        wrappedValue.databaseCore
//    }
//    
//    var tideStationService: TideStationDatabaseService {
//        wrappedValue.tideStationService
//    }
//    
//    var currentStationService: CurrentStationDatabaseService {
//        wrappedValue.currentStationService
//    }
//    
//    var navUnitService: NavUnitDatabaseService {
//        wrappedValue.navUnitService
//    }
//    
//    var photoService: PhotoDatabaseService {
//        wrappedValue.photoService
//    }
//    
//    var vesselService: VesselDatabaseService {
//        wrappedValue.vesselService
//    }
//    
//    var buoyDatabaseService: BuoyDatabaseService {
//        wrappedValue.buoyDatabaseService
//    }
//    
//    var weatherService: WeatherDatabaseService {
//        wrappedValue.weatherService
//    }
//    
//    var routeFavoritesService: RouteFavoritesDatabaseService {
//        wrappedValue.routeFavoritesService
//    }
//    
//    var locationService: LocationService {
//        wrappedValue.locationService
//    }
//    
//    var openMeteoService: WeatherService {
//        wrappedValue.openMeteoService
//    }
//    
//    var geocodingService: GeocodingService {
//        wrappedValue.geocodingService
//    }
//    
//    var noaaChartService: NOAAChartService {
//        wrappedValue.noaaChartService
//    }
//    
//    var mapOverlayService: MapOverlayDatabaseService {
//        wrappedValue.mapOverlayService
//    }
//    
//    // GPX and Route Service Extensions
//    var gpxService: ExtendedGpxServiceProtocol {
//        wrappedValue.gpxService
//    }
//    
//    var routeCalculationService: RouteCalculationService {
//        wrappedValue.routeCalculationService
//    }
//    
//    // Photo Services
//    var photoCaptureService: PhotoCaptureService {
//        wrappedValue.photoCaptureService
//    }
//    
//    var fileStorageService: FileStorageService {
//        wrappedValue.fileStorageService
//    }
//}
//
//// Extension for converting degrees to cardinal directions
//extension Double {
//    func toCardinalDirection() -> String {
//        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
//                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
//        let index = Int(((self + 11.25) / 22.5).truncatingRemainder(dividingBy: 16))
//        return directions[index]
//    }
//}
//
//// Extension for date formatting utilities
//extension Date {
//    func formattedTime() -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "h:mm a"
//        return formatter.string(from: self)
//    }
//    
//    func formattedDay() -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "EEE"
//        return formatter.string(from: self)
//    }
//    
//    func formattedDate() -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "MMM d"
//        return formatter.string(from: self)
//    }
//    
//    func isSameDay(as date: Date) -> Bool {
//        let calendar = Calendar.current
//        return calendar.isDate(self, inSameDayAs: date)
//    }
//}
//
//// Extension for temperature conversions
//extension Double {
//    func fahrenheitToCelsius() -> Double {
//        return (self - 32) * 5/9
//    }
//    
//    func celsiusToFahrenheit() -> Double {
//        return (self * 9/5) + 32
//    }
//}
//
//// Extension for wind speed conversions
//extension Double {
//    func mphToKmh() -> Double {
//        return self * 1.60934
//    }
//    
//    func kmhToMph() -> Double {
//        return self / 1.60934
//    }
//}
//
//// Extension for precipitation conversions
//extension Double {
//    func inchesToMm() -> Double {
//        return self * 25.4
//    }
//    
//    func mmToInches() -> Double {
//        return self / 25.4
//    }
//}







import SwiftUI

// Extensions to make it easier to work with services
extension View {
    /// Injects all services into this view
    func withInjectedServices(_ serviceProvider: ServiceProvider = ServiceProvider()) -> some View {
        self.environmentObject(serviceProvider)
    }
}

// Convenience extensions to access specific database services from SwiftUI views
extension EnvironmentObject where ObjectType == ServiceProvider {
    var databaseCore: DatabaseCore {
        wrappedValue.databaseCore
    }
    
    var tideStationService: TideStationDatabaseService {
        wrappedValue.tideStationService
    }
    
    var currentStationService: CurrentStationDatabaseService {
        wrappedValue.currentStationService
    }
    
    var navUnitService: NavUnitDatabaseService {
        wrappedValue.navUnitService
    }
    
    var photoService: PhotoDatabaseService {
        wrappedValue.photoService
    }
    
    var vesselService: VesselDatabaseService {
        wrappedValue.vesselService
    }
    
    var buoyDatabaseService: BuoyDatabaseService {
        wrappedValue.buoyDatabaseService
    }
    
    var weatherService: WeatherDatabaseService {
        wrappedValue.weatherService
    }
    
    var routeFavoritesService: RouteFavoritesDatabaseService {
        wrappedValue.routeFavoritesService
    }
    
    var locationService: LocationService {
        wrappedValue.locationService
    }
    
    var openMeteoService: WeatherService {
        wrappedValue.openMeteoService
    }
    
    var geocodingService: GeocodingService {
        wrappedValue.geocodingService
    }
    
    var noaaChartService: NOAAChartService {
        wrappedValue.noaaChartService
    }
    
    var mapOverlayService: MapOverlayDatabaseService {
        wrappedValue.mapOverlayService
    }
    
    // GPX and Route Service Extensions
    var gpxService: ExtendedGpxServiceProtocol {
        wrappedValue.gpxService
    }
    
    var routeCalculationService: RouteCalculationService {
        wrappedValue.routeCalculationService
    }
    
    // Photo Services
    var photoCaptureService: PhotoCaptureService {
        wrappedValue.photoCaptureService
    }
    
    var fileStorageService: FileStorageService {
        wrappedValue.fileStorageService
    }
    
        
        var iCloudSyncService: iCloudSyncService {
            wrappedValue.iCloudSyncService
        }
    
    
    
    
}

// Extension for converting degrees to cardinal directions
extension Double {
    func toCardinalDirection() -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int(((self + 11.25) / 22.5).truncatingRemainder(dividingBy: 16))
        return directions[index]
    }
}

// Extension for date formatting utilities
extension Date {
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
    
    func formattedDay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }
    
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
    
    func isSameDay(as date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: date)
    }
}

// Extension for temperature conversions
extension Double {
    func fahrenheitToCelsius() -> Double {
        return (self - 32) * 5/9
    }
    
    func celsiusToFahrenheit() -> Double {
        return (self * 9/5) + 32
    }
}

// Extension for wind speed conversions
extension Double {
    func mphToKmh() -> Double {
        return self * 1.60934
    }
    
    func kmhToMph() -> Double {
        return self / 1.60934
    }
}

// Extension for precipitation conversions
extension Double {
    func inchesToMm() -> Double {
        return self * 25.4
    }
    
    func mmToInches() -> Double {
        return self / 25.4
    }
}
