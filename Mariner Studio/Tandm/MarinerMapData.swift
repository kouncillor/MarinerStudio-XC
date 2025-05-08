

import MapKit
import CoreLocation

struct MarinerMapData: Decodable {
    let navobjects: [NavObject]
    let centerLatitude: CLLocationDegrees
    let centerLongitude: CLLocationDegrees
    let latitudeDelta: CLLocationDegrees
    let longitudeDelta: CLLocationDegrees
    
    var region: MKCoordinateRegion {
        let center = CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
        let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        return MKCoordinateRegion(center: center, span: span)
    }
}


class NavObject: NSObject, Decodable, MKAnnotation {
    enum NavObjectType: Int, Decodable {
        case navunit
        case tidalheightstation
        case tidalcurrentstation
    }
    
    var type: NavObjectType = .navunit
    var name: String = "" // Added name property
    var objectId: String = "" // Added objectId to store the original identifier
    
    private var latitude: CLLocationDegrees = 0
    private var longitude: CLLocationDegrees = 0
    
    @objc dynamic var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
    
    // MARK: - Title for annotation callout
    @objc var title: String? {
        return name
    }
}
