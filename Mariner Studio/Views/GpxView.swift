//
//  GpxView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//


import SwiftUI
import MapKit

struct GpxView: View {
    @ObservedObject var viewModel: GpxViewModel
    @State private var mapRegion = MKCoordinateRegion()
    @State private var polyline: MKPolyline?
    @State private var annotations: [RouteAnnotation] = []
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top Section
                ScrollView {
                    VStack(spacing: 10) {
                        // Open GPX Button - Hides after file is loaded
                        if !viewModel.hasRoute {
                            Button(action: {
                                Task {
                                    await viewModel.openGpxFile()
                                }
                            }) {
                                Text("Open GPX File")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .padding(.vertical)
                        }
                        
                        // Route Name
                        if !viewModel.routeName.isEmpty {
                            Text(viewModel.routeName)
                                .font(.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Route Direction Control - Only visible when route is loaded
                        if viewModel.hasRoute {
                            HStack {
                                Text("Route Direction")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button(action: {
                                    viewModel.reverseRoute()
                                }) {
                                    Text(viewModel.directionButtonText)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            .padding(.horizontal)
                        }
                        
                        // Route Planning Form
                        VStack(spacing: 15) {
                            Text("Route Planning")
                                .font(.headline)
                                .padding(.top, 5)
                            
                            VStack(spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Start Date:")
                                            .font(.subheadline)
                                        
                                        DatePicker("", selection: $viewModel.startDate, displayedComponents: .date)
                                            .labelsHidden()
                                            .disabled(!viewModel.hasRoute)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Average Speed (knots):")
                                            .font(.subheadline)
                                        
                                        TextField("10", text: $viewModel.averageSpeed)
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .disabled(!viewModel.hasRoute)
                                    }
                                }
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Start Time:")
                                            .font(.subheadline)
                                        
                                        DatePicker("", selection: $viewModel.startTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .disabled(!viewModel.hasRoute)
                                    }
                                    
                                    Spacer()
                                }
                                
                                // Buttons
                                HStack(spacing: 15) {
                                    Button(action: {
                                        viewModel.calculateETAs()
                                    }) {
                                        Text("Calculate ETAs")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(viewModel.canCalculateETAs ? Color.blue : Color.gray)
                                            .cornerRadius(8)
                                    }
                                    .disabled(!viewModel.canCalculateETAs)
                                    
                                    Button(action: {
                                        viewModel.viewRouteDetails()
                                    }) {
                                        Text("View Route Details")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(viewModel.etasCalculated ? Color.blue : Color.gray)
                                            .cornerRadius(8)
                                    }
                                    .disabled(!viewModel.etasCalculated)
                                }
                                .padding(.top, 5)
                            }
                            .padding()
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                        
                        // Status Messages
                        if !viewModel.errorMessage.isEmpty {
                            Text(viewModel.errorMessage)
                                .foregroundColor(.red)
                                .padding()
                        }
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        }
                    }
                    .padding(.bottom, 10)
                }
                .frame(height: geometry.size.height * 0.4)
                
                // Map
                MapView(region: $mapRegion, polyline: $polyline, annotations: $annotations)
                    .frame(height: geometry.size.height * 0.6)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("GPX Route Planner")
            .onAppear {
                setupLocationPermission()
            }
            .onChange(of: viewModel.routePoints) { _, newPoints in
                updateMapDisplay(with: newPoints)
            }
        }
    }
    
    // Request location permission and set initial map location
    private func setupLocationPermission() {
        LocationManager.shared.requestLocationPermission { authorized in
            if authorized, let location = LocationManager.shared.currentLocation {
                mapRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            } else {
                // Default location if permission not granted
                mapRegion = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
        
        // Set up callback for route reversal
        viewModel.onRouteReversed = { points in
            updateMapDisplay(with: points)
        }
    }
    
    // Update the map display with route points
    private func updateMapDisplay(with points: [RoutePoint]) {
        guard !points.isEmpty else {
            polyline = nil
            annotations = []
            return
        }
        
        // Create coordinates array
        var coordinates: [CLLocationCoordinate2D] = []
        var newAnnotations: [RouteAnnotation] = []
        
        for (index, point) in points.enumerated() {
            let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            coordinates.append(coordinate)
            
            // Create annotation for each point
            let annotation = RouteAnnotation(
                coordinate: coordinate,
                title: point.name,
                subtitle: "Waypoint \(index + 1)"
            )
            newAnnotations.append(annotation)
        }
        
        // Create polyline
        polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        
        // Update annotations
        annotations = newAnnotations
        
        // Center map on the route
        if let firstCoord = coordinates.first, let lastCoord = coordinates.last {
            let center = CLLocationCoordinate2D(
                latitude: (firstCoord.latitude + lastCoord.latitude) / 2,
                longitude: (firstCoord.longitude + lastCoord.longitude) / 2
            )
            
            // Calculate appropriate span
            let latDeltas = coordinates.map { abs($0.latitude - center.latitude) }
            let lonDeltas = coordinates.map { abs($0.longitude - center.longitude) }
            
            let latDelta = (latDeltas.max() ?? 0.05) * 2.5
            let lonDelta = (lonDeltas.max() ?? 0.05) * 2.5
            
            mapRegion = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        }
    }
}

// MapView using UIViewRepresentable
struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var polyline: MKPolyline?
    @Binding var annotations: [RouteAnnotation]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = .standard
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if needed
        mapView.setRegion(region, animated: true)
        
        // Remove all existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // Add polyline if available
        if let polyline = polyline {
            mapView.addOverlay(polyline)
        }
        
        // Add annotations
        mapView.addAnnotations(annotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "RoutePin")
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "RoutePin")
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
    }
}

// Route Annotation
class RouteAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
}

// Location Manager for handling location permissions and updates
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocationPermission(completion: @escaping (Bool) -> Void) {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            completion(true)
            startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // Completion handled in didChangeAuthorization
            self.permissionCompletion = completion
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    private var permissionCompletion: ((Bool) -> Void)?
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            permissionCompletion?(true)
            startUpdatingLocation()
        case .denied, .restricted:
            permissionCompletion?(false)
        case .notDetermined:
            break // Waiting for user to make a choice
        @unknown default:
            permissionCompletion?(false)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
    }
}