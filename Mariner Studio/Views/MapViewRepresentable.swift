import SwiftUI
import MapKit

struct MapViewRepresentable: UIViewRepresentable {
    var annotations: [MapAnnotation]
    var region: MKCoordinateRegion
    var showsUserLocation: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.region = region
        
        // Register annotation view classes
        mapView.register(UnicycleAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(BicycleAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(TricycleAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(MapClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing annotations
        let existingAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(existingAnnotations)
        
        // Add new annotations
        mapView.addAnnotations(annotations)
        
        // Update region if needed
        if mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude ||
           mapView.region.span.latitudeDelta != region.span.latitudeDelta ||
           mapView.region.span.longitudeDelta != region.span.longitudeDelta {
            mapView.setRegion(region, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Skip user location annotation
            if annotation is MKUserLocation {
                return nil
            }
            
            guard let annotation = annotation as? MapAnnotation else {
                return nil
            }
            
            switch annotation.type {
            case .unicycle:
                return UnicycleAnnotationView(annotation: annotation, reuseIdentifier: UnicycleAnnotationView.reuseID)
            case .bicycle:
                return BicycleAnnotationView(annotation: annotation, reuseIdentifier: BicycleAnnotationView.reuseID)
            case .tricycle:
                return TricycleAnnotationView(annotation: annotation, reuseIdentifier: TricycleAnnotationView.reuseID)
            }
        }
    }
}
