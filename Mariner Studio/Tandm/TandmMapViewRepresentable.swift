import SwiftUI
import MapKit

struct TandmMapViewRepresentable: UIViewRepresentable {
   @Binding var region: MKCoordinateRegion
   var annotations: [NavObject]
   var viewModel: MapClusteringViewModel
   var chartOverlay: NOAAChartTileOverlay? // Added chart overlay binding
   var mapType: MKMapType // Added map type parameter
   var onNavUnitSelected: (String) -> Void
   var onTidalHeightStationSelected: (String, String) -> Void
   var onTidalCurrentStationSelected: (String, Int, String) -> Void
   var onBuoyStationSelected: (String, String) -> Void // Added callback for buoy stations

   // AIS vessel support
   var aisVessels: [AISVessel] = []
   var showAISVessels: Bool = false
   var onAISVesselSelected: ((AISVessel) -> Void)?
   var onRegionChanged: ((MKCoordinateRegion) -> Void)?

   func makeUIView(context: Context) -> MKMapView {
       let mapView = MKMapView()
       mapView.delegate = context.coordinator
       mapView.showsUserLocation = true
       
       // Set initial map type
       mapView.mapType = mapType

       // Use higher performance rendering mode
       mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)

       // Register the annotation view classes
       mapView.register(NavUnitAnnotationView.self, forAnnotationViewWithReuseIdentifier: NavUnitAnnotationView.ReuseID)
       mapView.register(TidalHeightStationAnnotationView.self, forAnnotationViewWithReuseIdentifier: TidalHeightStationAnnotationView.ReuseID)
       mapView.register(TidalCurrentStationAnnotationView.self, forAnnotationViewWithReuseIdentifier: TidalCurrentStationAnnotationView.ReuseID)
       mapView.register(BuoyStationAnnotationView.self, forAnnotationViewWithReuseIdentifier: BuoyStationAnnotationView.ReuseID) // Register buoy annotation view

       // Store the mapView in our proxy for access from SwiftUI
       TandmMapViewProxy.shared.mapView = mapView
       TandmMapViewProxy.shared.coordinator = context.coordinator

       return mapView
   }

   func updateUIView(_ mapView: MKMapView, context: Context) {
       // Update map type if it changed
       if mapView.mapType != mapType {
           mapView.mapType = mapType
       }

       // Only update the region if it was explicitly requested via programmatic move
       // and the change is significant (prevents snapping back during user pan)
       if !context.coordinator.isUpdatingRegion {
           let latDiff = abs(mapView.region.center.latitude - region.center.latitude)
           let lonDiff = abs(mapView.region.center.longitude - region.center.longitude)

           // Only force region update for significant changes (> 0.01 degrees, roughly 1km)
           // This prevents the snap-back during normal panning while still allowing
           // programmatic moves like "center on user location" to work
           if latDiff > 0.01 || lonDiff > 0.01 {
               // Check if this is likely a programmatic move (large jump)
               // vs incremental user panning
               if latDiff > 0.1 || lonDiff > 0.1 {
                   context.coordinator.isUpdatingRegion = true
                   mapView.setRegion(region, animated: true)
                   context.coordinator.isUpdatingRegion = false
               }
           }
       }

       // Important: Update the callbacks BEFORE handling annotations
       // This ensures the latest callbacks are used
       context.coordinator.updateCallbacks(
           navUnitCallback: onNavUnitSelected,
           tidalHeightCallback: onTidalHeightStationSelected,
           tidalCurrentCallback: onTidalCurrentStationSelected,
           buoyStationCallback: onBuoyStationSelected, // Added buoy station callback
           aisVesselCallback: onAISVesselSelected // AIS vessel callback
       )

       // Handle chart overlay updates - now respects the toggle state
       if viewModel.isChartOverlayEnabled {
           context.coordinator.updateChartOverlay(in: mapView, newOverlay: chartOverlay)
       } else {
           context.coordinator.updateChartOverlay(in: mapView, newOverlay: nil)
       }

       // Use efficient annotation updates - only update what changed
       context.coordinator.updateAnnotations(in: mapView, newAnnotations: annotations)

       // Update AIS vessel annotations
       context.coordinator.updateAISAnnotations(in: mapView, vessels: showAISVessels ? aisVessels : [])
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
       var currentChartOverlay: NOAAChartTileOverlay? // Track current chart overlay

       // Callbacks stored as properties
       private var _onNavUnitSelected: ((String) -> Void)?
       private var _onTidalHeightStationSelected: ((String, String) -> Void)?
       private var _onTidalCurrentStationSelected: ((String, Int, String) -> Void)?
       private var _onBuoyStationSelected: ((String, String) -> Void)? // Added buoy station callback property
       private var _onAISVesselSelected: ((AISVessel) -> Void)? // AIS vessel callback property

       // Method to safely update callbacks
       func updateCallbacks(
           navUnitCallback: @escaping (String) -> Void,
           tidalHeightCallback: @escaping (String, String) -> Void,
           tidalCurrentCallback: @escaping (String, Int, String) -> Void,
           buoyStationCallback: @escaping (String, String) -> Void, // Added buoy station callback parameter
           aisVesselCallback: ((AISVessel) -> Void)? // AIS vessel callback parameter
       ) {
           self._onNavUnitSelected = navUnitCallback
           self._onTidalHeightStationSelected = tidalHeightCallback
           self._onTidalCurrentStationSelected = tidalCurrentCallback
           self._onBuoyStationSelected = buoyStationCallback // Store buoy station callback
           self._onAISVesselSelected = aisVesselCallback // Store AIS vessel callback
       }

       init(_ parent: TandmMapViewRepresentable) {
           self.parent = parent
           super.init()

           // Initialize callbacks from parent
           self._onNavUnitSelected = parent.onNavUnitSelected
           self._onTidalHeightStationSelected = parent.onTidalHeightStationSelected
           self._onTidalCurrentStationSelected = parent.onTidalCurrentStationSelected
           self._onBuoyStationSelected = parent.onBuoyStationSelected // Initialize buoy station callback
           self._onAISVesselSelected = parent.onAISVesselSelected // Initialize AIS vessel callback
       }

       // MARK: - Chart Overlay Management

       func updateChartOverlay(in mapView: MKMapView, newOverlay: NOAAChartTileOverlay?) {
           // Remove existing chart overlay if it exists
           if let existingOverlay = currentChartOverlay {
               mapView.removeOverlay(existingOverlay)
               currentChartOverlay = nil
           }

           // Add new chart overlay if provided
           if let overlay = newOverlay {
               mapView.addOverlay(overlay, level: .aboveRoads) // CHANGED: from .aboveLabels to .aboveRoads
               currentChartOverlay = overlay
           }
       }

       // This is an improved version of the centerMapOnUserLocation method
       // to be incorporated into TandmMapViewRepresentable.swift

       func centerMapOnUserLocation(_ mapView: MKMapView) {

           // Explicitly start location updates
           parent.viewModel.locationService.startUpdatingLocation()

           if let userLocation = parent.viewModel.locationService.currentLocation?.coordinate {

               let newRegion = MKCoordinateRegion(
                   center: userLocation,
                   span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
               )

               // Set flag to prevent feedback loops
               isUpdatingRegion = true

               // Use animated transition for better UX
               mapView.setRegion(newRegion, animated: true)

               // Update the parent's region binding on main thread
               DispatchQueue.main.async {
                   self.parent.region = newRegion

                   // Update the viewModel's current region
                   self.parent.viewModel.updateMapRegion(newRegion)

                   // Reset flag
                   self.isUpdatingRegion = false

               }
           } else {
               // Try to force location service to update again with a different method
               parent.viewModel.locationService.startUpdatingLocation()

               // Try again after a short delay
               DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                   // Force location updates again
                   self.parent.viewModel.locationService.startUpdatingLocation()

                   if let userLocation = self.parent.viewModel.locationService.currentLocation?.coordinate {

                       let newRegion = MKCoordinateRegion(
                           center: userLocation,
                           span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                       )

                       self.isUpdatingRegion = true
                       mapView.setRegion(newRegion, animated: true)

                       DispatchQueue.main.async {
                           self.parent.region = newRegion
                           self.parent.viewModel.updateMapRegion(newRegion)
                           self.isUpdatingRegion = false
                       }
                   } else {

                       // One final attempt after a slightly longer delay
                       DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                           // Force location updates one more time
                           self.parent.viewModel.locationService.startUpdatingLocation()

                           if let userLocation = self.parent.viewModel.locationService.currentLocation?.coordinate {

                               let newRegion = MKCoordinateRegion(
                                   center: userLocation,
                                   span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                               )

                               self.isUpdatingRegion = true
                               mapView.setRegion(newRegion, animated: true)

                               DispatchQueue.main.async {
                                   self.parent.region = newRegion
                                   self.parent.viewModel.updateMapRegion(newRegion)
                                   self.isUpdatingRegion = false
                               }
                           } else {
                           }
                       }
                   }
               }
           }
       }

       func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
           // Return nil for user location annotation
           if annotation is MKUserLocation {
               return nil
           }

           // Handle AIS VesselAnnotation
           if let vesselAnnotation = annotation as? VesselAnnotation {
               let identifier = "AISVesselAnnotation"
               var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

               if annotationView == nil {
                   annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                   annotationView?.canShowCallout = true
                   annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
               } else {
                   annotationView?.annotation = annotation
               }

               // Customize marker based on vessel type
               let vessel = vesselAnnotation.vessel
               annotationView?.glyphImage = UIImage(systemName: "ferry.fill")

               // Color based on ship type (same as AISMapView)
               if let shipType = vessel.shipType {
                   switch shipType {
                   case 60...69: // Passenger
                       annotationView?.markerTintColor = .systemBlue
                   case 70...79: // Cargo
                       annotationView?.markerTintColor = .systemGreen
                   case 80...89: // Tanker
                       annotationView?.markerTintColor = .systemRed
                   case 30: // Fishing
                       annotationView?.markerTintColor = .systemOrange
                   case 36, 37: // Sailing, Pleasure
                       annotationView?.markerTintColor = .systemPurple
                   case 50...55: // Special craft
                       annotationView?.markerTintColor = .systemYellow
                   default:
                       annotationView?.markerTintColor = .systemGray
                   }
               } else {
                   annotationView?.markerTintColor = .systemGray
               }

               return annotationView
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
           case .buoystation: // Handle buoy station annotations
               return mapView.dequeueReusableAnnotationView(
                   withIdentifier: BuoyStationAnnotationView.ReuseID,
                   for: navObject
               )
           }
       }

       func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
           // Handle NOAA Chart tile overlays
           if let chartOverlay = overlay as? NOAAChartTileOverlay {
               let renderer = MKTileOverlayRenderer(tileOverlay: chartOverlay)
               renderer.alpha = 1.0 // CHANGED: from 0.7 to 1.0 (remove transparency)
               return renderer
           }

           // Handle generic tile overlays
           if let tileOverlay = overlay as? MKTileOverlay {
               let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
               renderer.alpha = 1.0 // CHANGED: from 0.7 to 1.0 (remove transparency)
               return renderer
           }

           return MKOverlayRenderer(overlay: overlay)
       }

       func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
           // Handle when a user taps on an annotation
           guard let annotation = view.annotation else { return }

           // Handle AIS Vessel annotation selection
           if let vesselAnnotation = annotation as? VesselAnnotation {
               mapView.deselectAnnotation(annotation, animated: true)
               DispatchQueue.main.async { [weak self] in
                   self?._onAISVesselSelected?(vesselAnnotation.vessel)
               }
               return
           }

           if let navObject = annotation as? NavObject {
               // Important: Deselect the annotation immediately to ensure fresh selection next time
               mapView.deselectAnnotation(annotation, animated: true)

               switch navObject.type {
               case .navunit:
                   // Navigate to NavUnit details
                   DispatchQueue.main.async { [weak self] in
                       if !navObject.objectId.isEmpty, let callback = self?._onNavUnitSelected {
                           callback(navObject.objectId)
                       }
                   }
               case .tidalheightstation:
                   // Navigate to Tidal Height Prediction view
                   DispatchQueue.main.async { [weak self] in
                       if !navObject.objectId.isEmpty, let callback = self?._onTidalHeightStationSelected {
                           callback(navObject.objectId, navObject.name)
                       }
                   }
               case .tidalcurrentstation:
                   // Navigate to Tidal Current Prediction view
                   DispatchQueue.main.async { [weak self] in
                       if !navObject.objectId.isEmpty, let callback = self?._onTidalCurrentStationSelected {
                           let bin = navObject.currentBin ?? 0
                           callback(navObject.objectId, bin, navObject.name)
                       }
                   }
               case .buoystation:
                   // Navigate to Buoy Station details
                   DispatchQueue.main.async { [weak self] in
                       if !navObject.objectId.isEmpty, let callback = self?._onBuoyStationSelected {
                           callback(navObject.objectId, navObject.name)
                       }
                   }
               }
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

               // Notify about region change for AIS updates
               parent.onRegionChanged?(mapView.region)
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

       // MARK: - AIS Vessel Annotation Management

       func updateAISAnnotations(in mapView: MKMapView, vessels: [AISVessel]) {
           // Get existing vessel annotations
           let existingVesselAnnotations = mapView.annotations.compactMap { $0 as? VesselAnnotation }
           let existingMMSIs = Set(existingVesselAnnotations.map { $0.vessel.mmsi })
           let newMMSIs = Set(vessels.map { $0.mmsi })

           // Remove annotations for vessels no longer in the list
           let toRemove = existingVesselAnnotations.filter { !newMMSIs.contains($0.vessel.mmsi) }
           if !toRemove.isEmpty {
               mapView.removeAnnotations(toRemove)
           }

           // Add new annotations
           let toAdd = vessels.filter { !existingMMSIs.contains($0.mmsi) }
           if !toAdd.isEmpty {
               let newAnnotations = toAdd.map { VesselAnnotation(vessel: $0) }
               mapView.addAnnotations(newAnnotations)
           }

           // Update existing annotations (position changes)
           for annotation in existingVesselAnnotations {
               if let updatedVessel = vessels.first(where: { $0.mmsi == annotation.vessel.mmsi }) {
                   // Check if position changed significantly
                   let latDiff = abs(annotation.coordinate.latitude - updatedVessel.latitude)
                   let lonDiff = abs(annotation.coordinate.longitude - updatedVessel.longitude)

                   if latDiff > 0.0001 || lonDiff > 0.0001 {
                       // Remove old and add updated annotation
                       mapView.removeAnnotation(annotation)
                       mapView.addAnnotation(VesselAnnotation(vessel: updatedVessel))
                   }
               }
           }
       }
   }
}
