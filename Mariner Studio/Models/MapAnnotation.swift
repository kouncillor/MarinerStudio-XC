import MapKit

class MapAnnotation: NSObject, MKAnnotation {
    enum AnnotationType: Int, Codable {
        case unicycle
        case bicycle
        case tricycle
    }
    
    let type: AnnotationType
    var coordinate: CLLocationCoordinate2D
    
    init(type: AnnotationType, coordinate: CLLocationCoordinate2D) {
        self.type = type
        self.coordinate = coordinate
        super.init()
    }
    
    // Create from Cycle (for compatibility with Tandm data)
    convenience init(from cycle: NavObject) {
        let type = AnnotationType(rawValue: cycle.type.rawValue) ?? .bicycle
        self.init(type: type, coordinate: cycle.coordinate)
    }
}
