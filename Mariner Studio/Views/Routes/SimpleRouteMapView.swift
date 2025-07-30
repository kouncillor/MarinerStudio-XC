import SwiftUI
import MapKit

struct SimpleRouteMapView: View {
    let gpxFile: GpxFile
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var isChartOverlayEnabled = false
    @State private var chartOverlay: NOAAChartTileOverlay?

    private let defaultChartLayers: Set<Int> = [0, 1, 2, 6] // Same layers as main map

    var body: some View {
        ZStack {
            RouteMapViewRepresentable(
                gpxFile: gpxFile,
                region: $region,
                chartOverlay: chartOverlay
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .onAppear {
                calculateInitialRegion()
                createChartOverlay()
            }

            // Chart overlay toggle button
            VStack {
                HStack {
                    Spacer()

                    Button(action: {
                        toggleChartOverlay()
                    }) {
                        Image(systemName: isChartOverlayEnabled ? "map.fill" : "map")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(isChartOverlayEnabled ? Color.blue : Color.gray)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .padding()
                }

                Spacer()
            }
        }
    }

    private func calculateInitialRegion() {
        let routePoints = gpxFile.route.routePoints

        guard !routePoints.isEmpty else { return }

        let coordinates = routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2

        let latDelta = (maxLat - minLat) * 1.2 // Add 20% padding
        let lonDelta = (maxLon - minLon) * 1.2 // Add 20% padding

        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.01), longitudeDelta: max(lonDelta, 0.01))
        )
    }

    // MARK: - Chart Overlay Methods

    private func toggleChartOverlay() {
        isChartOverlayEnabled.toggle()

        if isChartOverlayEnabled {
            createChartOverlay()
        } else {
            chartOverlay = nil
        }
    }

    private func createChartOverlay() {
        guard isChartOverlayEnabled else {
            chartOverlay = nil
            return
        }

        chartOverlay = serviceProvider.noaaChartService.createChartTileOverlay(
            selectedLayers: defaultChartLayers
        )
    }
}

struct RouteMapViewRepresentable: UIViewRepresentable {
    let gpxFile: GpxFile
    @Binding var region: MKCoordinateRegion
    let chartOverlay: NOAAChartTileOverlay?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.isUserInteractionEnabled = true // Enable interactions
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.mapType = .standard

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Only set region if not updated by user interaction
        if !context.coordinator.isUpdatingFromUser {
            mapView.setRegion(region, animated: false)
        }

        // Handle chart overlay updates
        context.coordinator.updateChartOverlay(in: mapView, newOverlay: chartOverlay)

        // Clear existing route overlays and annotations (but keep chart overlay)
        let overlaysToRemove = mapView.overlays.filter { !($0 is NOAAChartTileOverlay) }
        if !overlaysToRemove.isEmpty {
            mapView.removeOverlays(overlaysToRemove)
        }
        mapView.removeAnnotations(mapView.annotations)

        // Add route polyline
        let coordinates = gpxFile.route.routePoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }

        // Add waypoint annotations
        let annotations = gpxFile.route.routePoints.enumerated().map { index, point in
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            annotation.title = point.name ?? "Waypoint \(index + 1)"
            return annotation
        }

        mapView.addAnnotations(annotations)
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.parent = self
        return coordinator
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var isUpdatingFromUser = false
        var parent: RouteMapViewRepresentable?
        private var currentChartOverlay: NOAAChartTileOverlay?

        // MARK: - Chart Overlay Management

        func updateChartOverlay(in mapView: MKMapView, newOverlay: NOAAChartTileOverlay?) {
            // Remove existing chart overlay if it exists
            if let existingOverlay = currentChartOverlay {
                mapView.removeOverlay(existingOverlay)
                currentChartOverlay = nil
            }

            // Add new chart overlay if provided
            if let overlay = newOverlay {
                mapView.addOverlay(overlay, level: .aboveRoads)
                currentChartOverlay = overlay
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // Handle NOAA Chart tile overlays
            if let chartOverlay = overlay as? NOAAChartTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: chartOverlay)
                renderer.alpha = 1.0
                return renderer
            }

            // Handle route polyline
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 3
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "WaypointPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = .red
                markerView.glyphImage = UIImage(systemName: "flag.fill")
            }

            return annotationView
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Update the parent's region binding when user interacts with map
            isUpdatingFromUser = true
            parent?.region = mapView.region

            // Reset flag after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isUpdatingFromUser = false
            }
        }
    }
}
