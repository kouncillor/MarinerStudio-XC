import MapKit
import CoreLocation

struct MarinerMapData: Decodable {
    let cycles: [Cycle]
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

// Copy Cycle class from Tandm for compatibility with their data format
class Cycle: NSObject, Decodable, MKAnnotation {
    enum CycleType: Int, Decodable {
        case unicycle
        case bicycle
        case tricycle
    }
    
    var type: CycleType = .unicycle
    
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
}
