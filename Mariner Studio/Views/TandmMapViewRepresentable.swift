
import SwiftUI
import MapKit

struct TandmMapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var annotations: [NavObject]
    var viewModel: MapClusteringViewModel
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        
        // Register the annotation view classes
        mapView.register(UnicycleAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(BicycleAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(TricycleAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(ClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update the region
        mapView.setRegion(region, animated: true)
        
        // Remove old annotations and add new ones
        let currentAnnotations = mapView.annotations.filter { $0 is NavObject }
        mapView.removeAnnotations(currentAnnotations)
        mapView.addAnnotations(annotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Coordinator class to handle the map delegate methods
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TandmMapViewRepresentable
        
        init(_ parent: TandmMapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? NavObject else { return nil }
            
            switch annotation.type {
            case .navunit:
                return UnicycleAnnotationView(annotation: annotation, reuseIdentifier: UnicycleAnnotationView.ReuseID)
            case .tidalheightstation:
                return BicycleAnnotationView(annotation: annotation, reuseIdentifier: BicycleAnnotationView.ReuseID)
            case .tidalcurrentstation:
                return TricycleAnnotationView(annotation: annotation, reuseIdentifier: TricycleAnnotationView.ReuseID)
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Update the region binding for SwiftUI
            parent.region = mapView.region
            
            // Update the view model with the new region
            parent.viewModel.updateMapRegion(mapView.region)
        }
    }
}
