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
    
    var buoyService: BuoyDatabaseService {
        wrappedValue.buoyService
    }
    
    var weatherService: WeatherDatabaseService {
        wrappedValue.weatherService
    }
    
    var locationService: LocationService {
        wrappedValue.locationService
    }
}
