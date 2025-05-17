//
//import SwiftUI
//import MapKit
//
//struct TandmMapViewRepresentable: UIViewRepresentable {
//    @Binding var region: MKCoordinateRegion
//    var annotations: [NavObject]
//    var viewModel: MapClusteringViewModel
//    var onNavUnitSelected: (String) -> Void
//    var onTidalHeightStationSelected: (String, String) -> Void
//    var onTidalCurrentStationSelected: (String, Int, String) -> Void
//    
//    func makeUIView(context: Context) -> MKMapView {
//        let mapView = MKMapView()
//        mapView.delegate = context.coordinator
//        mapView.showsUserLocation = true
//        
//        // Use higher performance rendering mode
//        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
//        
//        // Register the annotation view classes
//        mapView.register(NavUnitAnnotationView.self, forAnnotationViewWithReuseIdentifier: NavUnitAnnotationView.ReuseID)
//        mapView.register(TidalHeightStationAnnotationView.self, forAnnotationViewWithReuseIdentifier: TidalHeightStationAnnotationView.ReuseID)
//        mapView.register(TidalCurrentStationAnnotationView.self, forAnnotationViewWithReuseIdentifier: TidalCurrentStationAnnotationView.ReuseID)
//        
//        // Remove cluster registration since we've disabled clustering
//        // mapView.register(MapClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
//        
//        // Store the mapView in our proxy for access from SwiftUI
//        TandmMapViewProxy.shared.mapView = mapView
//        TandmMapViewProxy.shared.coordinator = context.coordinator
//        
//        return mapView
//    }
//    
//    func updateUIView(_ mapView: MKMapView, context: Context) {
//        // Only update the region if it was changed by user interaction, not by code
//        if !context.coordinator.isUpdatingRegion && (mapView.region.center.latitude != region.center.latitude ||
//           mapView.region.center.longitude != region.center.longitude) {
//            context.coordinator.isUpdatingRegion = true
//            mapView.setRegion(region, animated: true)
//            context.coordinator.isUpdatingRegion = false
//        }
//        
//        // Important: Update the callbacks BEFORE handling annotations
//        // This ensures the latest callbacks are used
//        context.coordinator.updateCallbacks(
//            navUnitCallback: onNavUnitSelected,
//            tidalHeightCallback: onTidalHeightStationSelected,
//            tidalCurrentCallback: onTidalCurrentStationSelected
//        )
//        
//        // Use efficient annotation updates - only update what changed
//        context.coordinator.updateAnnotations(in: mapView, newAnnotations: annotations)
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//    
//    // Coordinator class to handle the map delegate methods
//    class Coordinator: NSObject, MKMapViewDelegate {
//        var parent: TandmMapViewRepresentable
//        var isUpdatingRegion = false
//        var lastAnnotations: [NavObject] = []
//        var lastUpdateTime: Date = Date()
//        
//        // Callbacks stored as properties
//        private var _onNavUnitSelected: ((String) -> Void)?
//        private var _onTidalHeightStationSelected: ((String, String) -> Void)?
//        private var _onTidalCurrentStationSelected: ((String, Int, String) -> Void)?
//        
//        // Method to safely update callbacks
//        func updateCallbacks(
//            navUnitCallback: @escaping (String) -> Void,
//            tidalHeightCallback: @escaping (String, String) -> Void,
//            tidalCurrentCallback: @escaping (String, Int, String) -> Void
//        ) {
//            self._onNavUnitSelected = navUnitCallback
//            self._onTidalHeightStationSelected = tidalHeightCallback
//            self._onTidalCurrentStationSelected = tidalCurrentCallback
//        }
//        
//        init(_ parent: TandmMapViewRepresentable) {
//            self.parent = parent
//            super.init()
//            
//            // Initialize callbacks from parent
//            self._onNavUnitSelected = parent.onNavUnitSelected
//            self._onTidalHeightStationSelected = parent.onTidalHeightStationSelected
//            self._onTidalCurrentStationSelected = parent.onTidalCurrentStationSelected
//        }
//        
//        // Center map on user's location
//        func centerMapOnUserLocation(_ mapView: MKMapView) {
//            print("Attempting to center on user location")
//            
//            if let userLocation = parent.viewModel.locationService.currentLocation?.coordinate {
//                print("User location found: \(userLocation.latitude), \(userLocation.longitude)")
//                
//                let newRegion = MKCoordinateRegion(
//                    center: userLocation,
//                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//                )
//                
//                isUpdatingRegion = true
//                mapView.setRegion(newRegion, animated: true)
//                
//                // Update the parent's region binding
//                DispatchQueue.main.async {
//                    self.parent.region = newRegion
//                    
//                    // Update the viewModel's current region
//                    self.parent.viewModel.updateMapRegion(newRegion)
//                    self.isUpdatingRegion = false
//                    
//                    print("Map centered on user location")
//                }
//            } else {
//                print("User location not available")
//            }
//        }
//        
//        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
//            // Return nil for user location annotation
//            if annotation is MKUserLocation {
//                return nil
//            }
//            
//            // We no longer handle cluster annotations since clustering is disabled
//            // if let clusterAnnotation = annotation as? MKClusterAnnotation {
//            //     return mapView.dequeueReusableAnnotationView(
//            //         withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier,
//            //         for: clusterAnnotation
//            //     )
//            // }
//            
//            // Handle NavObject annotations
//            guard let navObject = annotation as? NavObject else { return nil }
//            
//            switch navObject.type {
//            case .navunit:
//                return mapView.dequeueReusableAnnotationView(
//                    withIdentifier: NavUnitAnnotationView.ReuseID,
//                    for: navObject
//                )
//            case .tidalheightstation:
//                return mapView.dequeueReusableAnnotationView(
//                    withIdentifier: TidalHeightStationAnnotationView.ReuseID,
//                    for: navObject
//                )
//            case .tidalcurrentstation:
//                return mapView.dequeueReusableAnnotationView(
//                    withIdentifier: TidalCurrentStationAnnotationView.ReuseID,
//                    for: navObject
//                )
//            }
//        }
//        
//        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
//            // Handle when a user taps on an annotation
//            guard let annotation = view.annotation else { return }
//            
//            if let navObject = annotation as? NavObject {
//                // Important: Deselect the annotation immediately to ensure fresh selection next time
//                mapView.deselectAnnotation(annotation, animated: true)
//                
//                switch navObject.type {
//                case .navunit:
//                    print("Tapped on NavUnit: \(navObject.name), ID: \(navObject.objectId)")
//                    // Navigate to NavUnit details
//                    DispatchQueue.main.async { [weak self] in
//                        if !navObject.objectId.isEmpty, let callback = self?._onNavUnitSelected {
//                            callback(navObject.objectId)
//                        }
//                    }
//                case .tidalheightstation:
//                    print("Tapped on Tidal Height Station: \(navObject.name), ID: \(navObject.objectId)")
//                    // Navigate to Tidal Height Prediction view
//                    DispatchQueue.main.async { [weak self] in
//                        if !navObject.objectId.isEmpty, let callback = self?._onTidalHeightStationSelected {
//                            callback(navObject.objectId, navObject.name)
//                        }
//                    }
//                case .tidalcurrentstation:
//                    print("Tapped on Tidal Current Station: \(navObject.name), ID: \(navObject.objectId), Bin: \(navObject.currentBin ?? 0)")
//                    // Navigate to Tidal Current Prediction view
//                    DispatchQueue.main.async { [weak self] in
//                        if !navObject.objectId.isEmpty, let callback = self?._onTidalCurrentStationSelected {
//                            let bin = navObject.currentBin ?? 0
//                            callback(navObject.objectId, bin, navObject.name)
//                        }
//                    }
//                }
//            }
//            // Remove cluster handling since we've disabled clustering
//            // else if let cluster = annotation as? MKClusterAnnotation {
//            //     print("Tapped on cluster with \(cluster.memberAnnotations.count) annotations")
//            //     // Handle cluster tap if needed
//            // }
//        }
//        
//        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
//            // Avoid feedback loop by checking if we're currently updating
//            guard !isUpdatingRegion else { return }
//            
//            // Update the region binding for SwiftUI
//            parent.region = mapView.region
//            
//            // Only call viewModel update if enough time has passed (throttle)
//            let now = Date()
//            if now.timeIntervalSince(lastUpdateTime) >= 0.3 {
//                lastUpdateTime = now
//                parent.viewModel.updateMapRegion(mapView.region)
//            }
//        }
//        
//        // Efficient annotation update mechanism
//        func updateAnnotations(in mapView: MKMapView, newAnnotations: [NavObject]) {
//            // Cache comparison for better performance
//            let newAnnotationCount = newAnnotations.count
//            let existingAnnotationCount = mapView.annotations.count
//            
//            // Quick check if collections are identical by count (and last known set)
//            if newAnnotationCount == lastAnnotations.count && newAnnotations == lastAnnotations {
//                return
//            }
//            
//            // If we're dealing with significantly different numbers of annotations,
//            // or we have a large number of annotations, use a faster approach
//            if abs(newAnnotationCount - existingAnnotationCount) > 50 || newAnnotationCount > 200 {
//                // Remove all existing non-user location annotations
//                let nonUserAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
//                mapView.removeAnnotations(nonUserAnnotations)
//                
//                // Add all new annotations at once
//                mapView.addAnnotations(newAnnotations)
//                lastAnnotations = newAnnotations
//                return
//            }
//            
//            // For smaller changes, do a more precise update
//            // Find annotations to add and remove
//            let existingAnnotations = mapView.annotations.compactMap { $0 as? NavObject }
//            
//            // Find annotations to add (in new but not in existing)
//            let annotationsToAdd = newAnnotations.filter { newAnnotation in
//                !existingAnnotations.contains { existingAnnotation in
//                    // Compare by coordinate since NavObject doesn't implement Equatable
//                    return existingAnnotation.coordinate.latitude == newAnnotation.coordinate.latitude &&
//                           existingAnnotation.coordinate.longitude == newAnnotation.coordinate.longitude &&
//                           existingAnnotation.type == newAnnotation.type
//                }
//            }
//            
//            // Find annotations to remove (in existing but not in new)
//            let annotationsToRemove = existingAnnotations.filter { existingAnnotation in
//                !newAnnotations.contains { newAnnotation in
//                    return existingAnnotation.coordinate.latitude == newAnnotation.coordinate.latitude &&
//                           existingAnnotation.coordinate.longitude == newAnnotation.coordinate.longitude &&
//                           existingAnnotation.type == newAnnotation.type
//                }
//            }
//            
//            // Update in batches to avoid UI freezes
//            let batchSize = 50
//            
//            // Remove old annotations in batches
//            for i in stride(from: 0, to: annotationsToRemove.count, by: batchSize) {
//                let endIndex = min(i + batchSize, annotationsToRemove.count)
//                let batch = Array(annotationsToRemove[i..<endIndex])
//                mapView.removeAnnotations(batch)
//            }
//            
//            // Add new annotations in batches
//            for i in stride(from: 0, to: annotationsToAdd.count, by: batchSize) {
//                let endIndex = min(i + batchSize, annotationsToAdd.count)
//                let batch = Array(annotationsToAdd[i..<endIndex])
//                mapView.addAnnotations(batch)
//            }
//            
//            // Save last annotations
//            lastAnnotations = newAnnotations
//        }
//    }
//}













import SwiftUI
import MapKit

struct TandmMapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var annotations: [NavObject]
    var viewModel: MapClusteringViewModel
    var onNavUnitSelected: (String) -> Void
    var onTidalHeightStationSelected: (String, String) -> Void
    var onTidalCurrentStationSelected: (String, Int, String) -> Void
    var onBuoyStationSelected: (String, String) -> Void // Added callback for buoy stations
    
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
        mapView.register(BuoyStationAnnotationView.self, forAnnotationViewWithReuseIdentifier: BuoyStationAnnotationView.ReuseID) // Register buoy annotation view
        
        // Remove cluster registration since we've disabled clustering
        // mapView.register(MapClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        
        // Store the mapView in our proxy for access from SwiftUI
        TandmMapViewProxy.shared.mapView = mapView
        TandmMapViewProxy.shared.coordinator = context.coordinator
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Only update the region if it was changed by user interaction, not by code
        if !context.coordinator.isUpdatingRegion && (mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude) {
            context.coordinator.isUpdatingRegion = true
            mapView.setRegion(region, animated: true)
            context.coordinator.isUpdatingRegion = false
        }
        
        // Important: Update the callbacks BEFORE handling annotations
        // This ensures the latest callbacks are used
        context.coordinator.updateCallbacks(
            navUnitCallback: onNavUnitSelected,
            tidalHeightCallback: onTidalHeightStationSelected,
            tidalCurrentCallback: onTidalCurrentStationSelected,
            buoyStationCallback: onBuoyStationSelected // Added buoy station callback
        )
        
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
        
        // Callbacks stored as properties
        private var _onNavUnitSelected: ((String) -> Void)?
        private var _onTidalHeightStationSelected: ((String, String) -> Void)?
        private var _onTidalCurrentStationSelected: ((String, Int, String) -> Void)?
        private var _onBuoyStationSelected: ((String, String) -> Void)? // Added buoy station callback property
        
        // Method to safely update callbacks
        func updateCallbacks(
            navUnitCallback: @escaping (String) -> Void,
            tidalHeightCallback: @escaping (String, String) -> Void,
            tidalCurrentCallback: @escaping (String, Int, String) -> Void,
            buoyStationCallback: @escaping (String, String) -> Void // Added buoy station callback parameter
        ) {
            self._onNavUnitSelected = navUnitCallback
            self._onTidalHeightStationSelected = tidalHeightCallback
            self._onTidalCurrentStationSelected = tidalCurrentCallback
            self._onBuoyStationSelected = buoyStationCallback // Store buoy station callback
        }
        
        init(_ parent: TandmMapViewRepresentable) {
            self.parent = parent
            super.init()
            
            // Initialize callbacks from parent
            self._onNavUnitSelected = parent.onNavUnitSelected
            self._onTidalHeightStationSelected = parent.onTidalHeightStationSelected
            self._onTidalCurrentStationSelected = parent.onTidalCurrentStationSelected
            self._onBuoyStationSelected = parent.onBuoyStationSelected // Initialize buoy station callback
        }
        
        // Center map on user's location
        func centerMapOnUserLocation(_ mapView: MKMapView) {
            print("Attempting to center on user location")
            
            if let userLocation = parent.viewModel.locationService.currentLocation?.coordinate {
                print("User location found: \(userLocation.latitude), \(userLocation.longitude)")
                
                let newRegion = MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                
                isUpdatingRegion = true
                mapView.setRegion(newRegion, animated: true)
                
                // Update the parent's region binding
                DispatchQueue.main.async {
                    self.parent.region = newRegion
                    
                    // Update the viewModel's current region
                    self.parent.viewModel.updateMapRegion(newRegion)
                    self.isUpdatingRegion = false
                    
                    print("Map centered on user location")
                }
            } else {
                print("User location not available")
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Return nil for user location annotation
            if annotation is MKUserLocation {
                return nil
            }
            
            // We no longer handle cluster annotations since clustering is disabled
            // if let clusterAnnotation = annotation as? MKClusterAnnotation {
            //     return mapView.dequeueReusableAnnotationView(
            //         withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier,
            //         for: clusterAnnotation
            //     )
            // }
            
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
            case .buoystation: // Handle buoy station annotations
                return mapView.dequeueReusableAnnotationView(
                    withIdentifier: BuoyStationAnnotationView.ReuseID,
                    for: navObject
                )
            }
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // Handle when a user taps on an annotation
            guard let annotation = view.annotation else { return }
            
            if let navObject = annotation as? NavObject {
                // Important: Deselect the annotation immediately to ensure fresh selection next time
                mapView.deselectAnnotation(annotation, animated: true)
                
                switch navObject.type {
                case .navunit:
                    print("Tapped on NavUnit: \(navObject.name), ID: \(navObject.objectId)")
                    // Navigate to NavUnit details
                    DispatchQueue.main.async { [weak self] in
                        if !navObject.objectId.isEmpty, let callback = self?._onNavUnitSelected {
                            callback(navObject.objectId)
                        }
                    }
                case .tidalheightstation:
                    print("Tapped on Tidal Height Station: \(navObject.name), ID: \(navObject.objectId)")
                    // Navigate to Tidal Height Prediction view
                    DispatchQueue.main.async { [weak self] in
                        if !navObject.objectId.isEmpty, let callback = self?._onTidalHeightStationSelected {
                            callback(navObject.objectId, navObject.name)
                        }
                    }
                case .tidalcurrentstation:
                    print("Tapped on Tidal Current Station: \(navObject.name), ID: \(navObject.objectId), Bin: \(navObject.currentBin ?? 0)")
                    // Navigate to Tidal Current Prediction view
                    DispatchQueue.main.async { [weak self] in
                        if !navObject.objectId.isEmpty, let callback = self?._onTidalCurrentStationSelected {
                            let bin = navObject.currentBin ?? 0
                            callback(navObject.objectId, bin, navObject.name)
                        }
                    }
                case .buoystation:
                    print("Tapped on Buoy Station: \(navObject.name), ID: \(navObject.objectId)")
                    // Navigate to Buoy Station details
                    DispatchQueue.main.async { [weak self] in
                        if !navObject.objectId.isEmpty, let callback = self?._onBuoyStationSelected {
                            callback(navObject.objectId, navObject.name)
                        }
                    }
                }
            }
            // Remove cluster handling since we've disabled clustering
            // else if let cluster = annotation as? MKClusterAnnotation {
            //     print("Tapped on cluster with \(cluster.memberAnnotations.count) annotations")
            //     // Handle cluster tap if needed
            // }
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
            // Cache comparison for better performance
            let newAnnotationCount = newAnnotations.count
            let existingAnnotationCount = mapView.annotations.count
            
            // Quick check if collections are identical by count (and last known set)
            if newAnnotationCount == lastAnnotations.count && newAnnotations == lastAnnotations {
                return
            }
            
            // If we're dealing with significantly different numbers of annotations,
            // or we have a large number of annotations, use a faster approach
            if abs(newAnnotationCount - existingAnnotationCount) > 50 || newAnnotationCount > 200 {
                // Remove all existing non-user location annotations
                let nonUserAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
                mapView.removeAnnotations(nonUserAnnotations)
                
                // Add all new annotations at once
                mapView.addAnnotations(newAnnotations)
                lastAnnotations = newAnnotations
                return
            }
            
            // For smaller changes, do a more precise update
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
            let batchSize = 50
            
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
