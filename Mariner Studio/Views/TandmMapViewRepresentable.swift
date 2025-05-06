import SwiftUI
import MapKit

//Just a comment to update  the commits

struct TandmMapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var annotations: [NavObject]
    var viewModel: MapClusteringViewModel
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        
        // Use higher performance rendering mode
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        
        // Register the annotation view classes
        mapView.register(NavUnitAnnotationView.self, forAnnotationViewWithReuseIdentifier: NavUnitAnnotationView.ReuseID)
        mapView.register(TidalHeightStationAnnotationView.self, forAnnotationViewWithReuseIdentifier: TidalHeightStationAnnotationView.ReuseID)
        mapView.register(TidalCurrentStationAnnotationView.self, forAnnotationViewWithReuseIdentifier: TidalCurrentStationAnnotationView.ReuseID)
        mapView.register(MapClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Only update the region if it was changed by user interaction, not by code
        if !context.coordinator.isUpdatingRegion && mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude {
            context.coordinator.isUpdatingRegion = true
            mapView.setRegion(region, animated: true)
            context.coordinator.isUpdatingRegion = false
        }
        
        // Use efficient annotation updates - only update what changed
        context.coordinator.updateAnnotations(in: mapView, newAnnotations: annotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Coordinator class to handle the map delegate methods
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TandmMapViewRepresentable
        var isUpdatingRegion = false
        var lastAnnotations: [NavObject] = []
        var lastUpdateTime: Date = Date()
        
        init(_ parent: TandmMapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Handle cluster annotations
            if let clusterAnnotation = annotation as? MKClusterAnnotation {
                return mapView.dequeueReusableAnnotationView(
                    withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier,
                    for: clusterAnnotation
                )
            }
            
            // Return nil for user location annotation
            if annotation is MKUserLocation {
                return nil
            }
            
            // Handle NavObject annotations
            guard let navObject = annotation as? NavObject else { return nil }
            
            switch navObject.type {
            case .navunit:
                return mapView.dequeueReusableAnnotationView(
                    withIdentifier: NavUnitAnnotationView.ReuseID,
                    for: navObject
                )
            case .tidalheightstation:
                return mapView.dequeueReusableAnnotationView(
                    withIdentifier: TidalHeightStationAnnotationView.ReuseID,
                    for: navObject
                )
            case .tidalcurrentstation:
                return mapView.dequeueReusableAnnotationView(
                    withIdentifier: TidalCurrentStationAnnotationView.ReuseID,
                    for: navObject
                )
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Avoid feedback loop by checking if we're currently updating
            guard !isUpdatingRegion else { return }
            
            // Update the region binding for SwiftUI
            parent.region = mapView.region
            
            // Only call viewModel update if enough time has passed (throttle)
            let now = Date()
            if now.timeIntervalSince(lastUpdateTime) >= 0.3 {
                lastUpdateTime = now
                parent.viewModel.updateMapRegion(mapView.region)
            }
        }
        
        // Efficient annotation update mechanism
        func updateAnnotations(in mapView: MKMapView, newAnnotations: [NavObject]) {
            // Only process updates if annotations have changed
            guard newAnnotations != lastAnnotations else { return }
            
            // Find annotations to add and remove
            let existingAnnotations = mapView.annotations.compactMap { $0 as? NavObject }
            
            // Find annotations to add (in new but not in existing)
            let annotationsToAdd = newAnnotations.filter { newAnnotation in
                !existingAnnotations.contains { existingAnnotation in
                    // Compare by coordinate since NavObject doesn't implement Equatable
                    return existingAnnotation.coordinate.latitude == newAnnotation.coordinate.latitude &&
                           existingAnnotation.coordinate.longitude == newAnnotation.coordinate.longitude &&
                           existingAnnotation.type == newAnnotation.type
                }
            }
            
            // Find annotations to remove (in existing but not in new)
            let annotationsToRemove = existingAnnotations.filter { existingAnnotation in
                !newAnnotations.contains { newAnnotation in
                    return existingAnnotation.coordinate.latitude == newAnnotation.coordinate.latitude &&
                           existingAnnotation.coordinate.longitude == newAnnotation.coordinate.longitude &&
                           existingAnnotation.type == newAnnotation.type
                }
            }
            
            // Update in batches to avoid UI freezes
            let batchSize = 100
            
            // Remove old annotations in batches
            for i in stride(from: 0, to: annotationsToRemove.count, by: batchSize) {
                let endIndex = min(i + batchSize, annotationsToRemove.count)
                let batch = Array(annotationsToRemove[i..<endIndex])
                mapView.removeAnnotations(batch)
            }
            
            // Add new annotations in batches
            for i in stride(from: 0, to: annotationsToAdd.count, by: batchSize) {
                let endIndex = min(i + batchSize, annotationsToAdd.count)
                let batch = Array(annotationsToAdd[i..<endIndex])
                mapView.addAnnotations(batch)
            }
            
            // Save last annotations
            lastAnnotations = newAnnotations
        }
    }
}
