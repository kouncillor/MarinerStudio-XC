

//
//  NauticalMapView.swift
//  Mariner Studio
//
//  Created by Assistant on 5/22/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct NauticalMapView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var mapRegion = MKCoordinateRegion()
    @State private var chartOverlay: NOAAChartTileOverlay?
    @State private var userLocation: CLLocation?
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showingChartInfo = false
    @State private var currentLayerCount = 1 // Start with 1 layer
    @State private var showingLayerSelector = false
    @State private var selectedLayers: Set<Int> = [0, 1, 2, 6] // Start with layers 0, 1, 2, and 6
    @State private var userPins: [UserPin] = [] // Array to store user-placed pins
    
    private let maxAllowedLayers = 13
    private let minAllowedLayers = 1
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main Map View
                NauticalChartMapView(
                    region: $mapRegion,
                    chartOverlay: Binding<MKTileOverlay?>(
                        get: { chartOverlay },
                        set: { chartOverlay = $0 as? NOAAChartTileOverlay }
                    ),
                    userLocation: $userLocation,
                    userPins: $userPins
                )
                .ignoresSafeArea(edges: .all)
                
                // Loading Overlay
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading Nautical Charts...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground).opacity(0.9))
                    .cornerRadius(10)
                }
                
                // Error Message
                if !errorMessage.isEmpty {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground).opacity(0.9))
                    .cornerRadius(10)
                    .transition(.opacity)
                }
                
                // Chart Controls
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            // Layers Button
                            Button(action: {
                                showingLayerSelector = true
                            }) {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .padding(8)
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                            }
                            
                            // Chart Info Button
                            Button(action: {
                                showingChartInfo = true
                            }) {
                                Image(systemName: "info.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .padding(8)
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
            }
        }
        .withHomeButton()
        .onAppear {
            setupChartDisplay()
        }
        .alert("Chart Information", isPresented: $showingChartInfo) {
            Button("OK") { }
        } message: {
            Text("NOAA Official Charts\n\nDisplaying official NOAA Electronic Navigational Charts (ENCs) with official marine chart symbology.\n\nData Source: NOAA Chart Display Service\n\nCurrently showing \(selectedLayers.count) chart layers. Use +/- buttons or the layers button to control detail levels.")
        }
        .sheet(isPresented: $showingLayerSelector) {
            LayerSelectorView(selectedLayers: $selectedLayers, onLayersChanged: updateChartOverlay)
        }
    }
    
    // MARK: - Layer Control Methods
    
    private func increaseLayerCount() {
        let maxLayers = 13
        guard selectedLayers.count < maxLayers else { return }
        
        // Add the next layer in sequence (0, 1, 2, 3, etc.)
        for layerId in 0..<maxLayers {
            if !selectedLayers.contains(layerId) {
                selectedLayers.insert(layerId)
                break
            }
        }
        
        updateChartOverlay()
        
        // Provide haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
        
        print("➕ NauticalMapView: Increased layers to \(selectedLayers.sorted())")
    }
    
    private func decreaseLayerCount() {
        guard selectedLayers.count > 1 else { return }
        
        // Remove the highest numbered layer
        if let maxLayer = selectedLayers.max() {
            selectedLayers.remove(maxLayer)
        }
        
        updateChartOverlay()
        
        // Provide haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
        
        print("➖ NauticalMapView: Decreased layers to \(selectedLayers.sorted())")
    }
    
    private func updateChartOverlay() {
        // Create new overlay with selected layers
        let newOverlay = NOAAChartTileOverlay(chartType: .traditional, selectedLayers: selectedLayers)
        chartOverlay = newOverlay
        
        print("🔄 NauticalMapView: Updated chart overlay with layers: \(selectedLayers.sorted())")
    }
    
    // MARK: - Chart Setup Methods
    
    private func setupChartDisplay() {
        print("🗺️ NauticalMapView: Setting up chart display")
        
        // Setup location first
        setupUserLocation()
        
        // Create NOAA chart overlay with current settings
        let overlay = NOAAChartTileOverlay(chartType: .traditional, selectedLayers: selectedLayers)
        chartOverlay = overlay
        
        // Simulate loading time and remove loading indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isLoading = false
            }
        }
        
        print("✅ NauticalMapView: Chart overlay configured with Traditional chart type and layers: \(selectedLayers.sorted())")
    }
    
    private func setupUserLocation() {
        // Use existing location service from ServiceProvider
        let locationService = serviceProvider.locationService
        
        // Check if we already have a location
        if let currentLocation = getCurrentLocation() {
            userLocation = currentLocation
            centerMapOnLocation(currentLocation)
            print("📍 NauticalMapView: Using current location: \(currentLocation.coordinate)")
        } else {
            // Request location permission and start updates
            Task {
                let authorized = await locationService.requestLocationPermission()
                
                await MainActor.run {
                    if authorized {
                        locationService.startUpdatingLocation()
                        print("✅ NauticalMapView: Location permission granted, starting updates")
                        
                        // Try to get location again after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if let location = getCurrentLocation() {
                                userLocation = location
                                centerMapOnLocation(location)
                                print("📍 NauticalMapView: Got updated location: \(location.coordinate)")
                            } else {
                                // Fallback to default location (Chesapeake Bay)
                                useDefaultLocation()
                            }
                        }
                    } else {
                        print("⚠️ NauticalMapView: Location permission denied, using default location")
                        useDefaultLocation()
                    }
                }
            }
        }
    }
    
    private func getCurrentLocation() -> CLLocation? {
        // Try to get location from the existing location service
        if let locationService = serviceProvider.locationService as? LocationServiceImpl {
            return locationService.currentLocation
        }
        return nil
    }
    
    private func centerMapOnLocation(_ location: CLLocation) {
        let coordinate = location.coordinate
        
        // Set region with appropriate zoom level for nautical charts
        mapRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        
        userLocation = location
        print("🗺️ NauticalMapView: Centered map on location: \(coordinate)")
    }
    
    private func useDefaultLocation() {
        // Default to Chesapeake Bay - good area for nautical charts
        let defaultCoordinate = CLLocationCoordinate2D(latitude: 38.9784, longitude: -76.4951)
        let defaultLocation = CLLocation(latitude: defaultCoordinate.latitude, longitude: defaultCoordinate.longitude)
        
        centerMapOnLocation(defaultLocation)
        
        errorMessage = "Using default location (Chesapeake Bay). Enable location services for your current position."
        
        // Clear error message after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation {
                errorMessage = ""
            }
        }
        
        print("📍 NauticalMapView: Using default location: Chesapeake Bay")
    }
}

// MARK: - UserPin Model

class UserPin: NSObject, MKAnnotation, ObservableObject, Identifiable {
    let id = UUID()
    @Published var coordinate: CLLocationCoordinate2D
    @Published var title: String?
    @Published var subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String? = nil, subtitle: String? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        super.init()
    }
}

// MARK: - LayerSelectorView

struct LayerSelectorView: View {
    @Binding var selectedLayers: Set<Int>
    let onLayersChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let layerInfo = [
        (id: 0, name: "Information about the chart display"),
        (id: 1, name: "Natural and man-made features, port features"),
        (id: 2, name: "Depths, currents, etc"),
        (id: 3, name: "Seabed, obstructions, pipelines"),
        (id: 4, name: "Traffic routes"),
        (id: 5, name: "Special areas"),
        (id: 6, name: "Buoys, beacons, lights, fog signals, radar"),
        (id: 7, name: "Services and small craft facilities"),
        (id: 8, name: "Data quality"),
        (id: 9, name: "Low accuracy"),
        (id: 10, name: "Additional chart information"),
        (id: 11, name: "Shallow water pattern"),
        (id: 12, name: "Overscale warning")
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Chart Layers")) {
                    ForEach(layerInfo, id: \.id) { layer in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Layer \(layer.id)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(layer.name)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { selectedLayers.contains(layer.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedLayers.insert(layer.id)
                                    } else {
                                        // Don't allow removing layer 0 if it's the only one
                                        if selectedLayers.count > 1 || layer.id != 0 {
                                            selectedLayers.remove(layer.id)
                                        }
                                    }
                                    onLayersChanged()
                                }
                            ))
                            .toggleStyle(SwitchToggleStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(footer: Text("Select which chart layers to display. Layer 0 provides the basic chart framework and is recommended to keep enabled.")) {
                    HStack {
                        Text("Total Layers Selected:")
                            .font(.headline)
                        Spacer()
                        Text("\(selectedLayers.count)")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Chart Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - NauticalChartMapView

struct NauticalChartMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var chartOverlay: MKTileOverlay?
    @Binding var userLocation: CLLocation?
    @Binding var userPins: [UserPin]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true
        
        // Add long press gesture recognizer
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPressGesture.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPressGesture)
        
        print("🗺️ NauticalChartMapView: Created MapKit view with long press gesture")
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if needed
        if !mapView.region.center.isEqual(to: region.center) {
            mapView.setRegion(region, animated: true)
        }
        
        // Remove existing NOAA chart overlays
        let existingNOAAOverlays = mapView.overlays.compactMap { $0 as? NOAAChartTileOverlay }
        if !existingNOAAOverlays.isEmpty {
            mapView.removeOverlays(existingNOAAOverlays)
            print("🗺️ NauticalChartMapView: Removed existing NOAA chart overlays")
        }
        
        // Add new chart overlay if available
        if let overlay = chartOverlay {
            mapView.addOverlay(overlay, level: .aboveLabels)
            print("🗺️ NauticalChartMapView: Added NOAA chart overlay")
            
            // Force a refresh by slightly adjusting the map region
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let currentRegion = mapView.region
                let adjustedRegion = MKCoordinateRegion(
                    center: currentRegion.center,
                    span: MKCoordinateSpan(
                        latitudeDelta: currentRegion.span.latitudeDelta,
                        longitudeDelta: currentRegion.span.longitudeDelta
                    )
                )
                mapView.setRegion(adjustedRegion, animated: false)
            }
        }
        
        // Update user pins
        let currentUserPins = mapView.annotations.compactMap { $0 as? UserPin }
        let newUserPins = userPins.filter { newPin in
            !currentUserPins.contains { $0.id == newPin.id }
        }
        let removedUserPins = currentUserPins.filter { currentPin in
            !userPins.contains { $0.id == currentPin.id }
        }
        
        if !newUserPins.isEmpty {
            mapView.addAnnotations(newUserPins)
            print("📍 NauticalChartMapView: Added \(newUserPins.count) user pins")
        }
        
        if !removedUserPins.isEmpty {
            mapView.removeAnnotations(removedUserPins)
            print("📍 NauticalChartMapView: Removed \(removedUserPins.count) user pins")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NauticalChartMapView
        
        init(_ parent: NauticalChartMapView) {
            self.parent = parent
        }
        
        @objc func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
            guard gestureRecognizer.state == .began else { return }
            
            let mapView = gestureRecognizer.view as! MKMapView
            let touchPoint = gestureRecognizer.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            // Create a new user pin
            let newPin = UserPin(
                coordinate: coordinate,
                title: "Custom Pin",
                subtitle: "Lat: \(String(format: "%.6f", coordinate.latitude)), Lon: \(String(format: "%.6f", coordinate.longitude))"
            )
            
            // Add to the parent's pin array
            DispatchQueue.main.async {
                self.parent.userPins.append(newPin)
            }
            
            // Provide haptic feedback
            let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
            impactGenerator.impactOccurred()
            
            print("📍 NauticalChartMapView: Placed pin at \(coordinate)")
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Don't customize the user location annotation
            if annotation is MKUserLocation {
                return nil
            }
            
            // Handle user pins
            if let userPin = annotation as? UserPin {
                let identifier = "UserPin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    
                    // Add delete button to callout
                    let deleteButton = UIButton(type: .system)
                    deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
                    deleteButton.tintColor = .red
                    annotationView?.rightCalloutAccessoryView = deleteButton
                } else {
                    annotationView?.annotation = annotation
                }
                
                // Customize the marker
                if let markerView = annotationView as? MKMarkerAnnotationView {
                    markerView.markerTintColor = .red
                    markerView.glyphImage = UIImage(systemName: "mappin")
                }
                
                return annotationView
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            // Handle delete button tap
            if let userPin = view.annotation as? UserPin {
                DispatchQueue.main.async {
                    self.parent.userPins.removeAll { $0.id == userPin.id }
                }
                print("📍 NauticalChartMapView: Removed pin at \(userPin.coordinate)")
                
                // Provide haptic feedback
                let impactGenerator = UIImpactFeedbackGenerator(style: .light)
                impactGenerator.impactOccurred()
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? NOAAChartTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 1.0 // Maximum opacity - completely opaque
                print("🎨 NauticalChartMapView: Created NOAA tile overlay renderer with alpha 1.0")
                return renderer
            }
            
            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 1.0 // Maximum opacity
                print("🎨 NauticalChartMapView: Created generic tile overlay renderer")
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
            
            let zoomLevel = log2(360 / mapView.region.span.longitudeDelta)
            print("🔍 NauticalChartMapView: Map region changed, zoom level: \(Int(zoomLevel))")
        }
        
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("✅ NauticalChartMapView: Map finished loading")
        }
        
        func mapView(_ mapView: MKMapView, didAdd renderers: [MKOverlayRenderer]) {
            print("➕ NauticalChartMapView: Added \(renderers.count) overlay renderer(s)")
        }
    }
}

// MARK: - Helper Extensions

extension CLLocationCoordinate2D {
    func isEqual(to other: CLLocationCoordinate2D, tolerance: Double = 0.0001) -> Bool {
        return abs(self.latitude - other.latitude) < tolerance &&
               abs(self.longitude - other.longitude) < tolerance
    }
}
