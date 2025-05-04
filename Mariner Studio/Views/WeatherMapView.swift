import SwiftUI
import MapKit

struct WeatherMapView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var mapRegion = MKCoordinateRegion()
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName: String = ""
    @State private var isLoading = false
    @State private var showWeatherDetails = false
    @State private var errorMessage: String?
    
    // State to track if we need to initialize map location
    @State private var hasSetInitialLocation = false
    
    var body: some View {
        ZStack {
            // Map View
            MapViewRepresentable(
                region: $mapRegion,
                selectedLocation: $selectedLocation,
                onLongPress: handleLongPress
            )
            .ignoresSafeArea(edges: .top)
            
            // Info panel at the top
            VStack {
                InfoPanel(
                    message: selectedLocation == nil ?
                        "Long press anywhere on the map to check weather at that location" :
                        "Loading weather for \(locationName)...",
                    isLoading: isLoading
                )
                .padding()
                
                Spacer()
            }
            
            // Error message if present
            if let errorMessage = errorMessage {
                VStack {
                    Spacer()
                    
                    Text(errorMessage)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                        .padding()
                    
                    Spacer().frame(height: 40)
                }
            }
        }
        .navigationTitle("Weather Map")
        .background(
            // Navigation link for weather details
            NavigationLink(isActive: $showWeatherDetails) {
                if let selectedLocation = selectedLocation {
                    WeatherMapLocationView(
                        latitude: selectedLocation.latitude,
                        longitude: selectedLocation.longitude,
                        locationName: locationName
                    )
                } else {
                    EmptyView()
                }
            } label: {
                EmptyView()
            }
        )
        .onAppear {
            setupInitialLocation()
        }
    }
    
    private func setupInitialLocation() {
        guard !hasSetInitialLocation else { return }
        
        // Try to get user location from service
        if let userLocation = serviceProvider.locationService.currentLocation {
            mapRegion = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            hasSetInitialLocation = true
        } else {
            // Default to NYC if user location not available
            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            hasSetInitialLocation = true
            
            // Start location updates to try to get user location later
            serviceProvider.locationService.startUpdatingLocation()
        }
    }
    
    private func handleLongPress(at coordinate: CLLocationCoordinate2D) {
        selectedLocation = coordinate
        isLoading = true
        errorMessage = nil
        
        // Geocode the location to get a place name
        Task {
            do {
                let geocodingResult = try await serviceProvider.geocodingService.reverseGeocode(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                
                if let result = geocodingResult.results.first {
                    let placeName = result.name
                    let state = result.state
                    
                    await MainActor.run {
                        locationName = "\(placeName), \(state)"
                        isLoading = false
                        showWeatherDetails = true
                    }
                } else {
                    // Fallback to coordinates if no place name is found
                    await MainActor.run {
                        locationName = "Location (\(String(format: "%.4f", coordinate.latitude)), \(String(format: "%.4f", coordinate.longitude)))"
                        isLoading = false
                        showWeatherDetails = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error getting location information: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// MapKit wrapper for SwiftUI
struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedLocation: CLLocationCoordinate2D?
    var onLongPress: (CLLocationCoordinate2D) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Add long press gesture recognizer
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        mapView.addGestureRecognizer(longPressGesture)
        
        // Show user location
        mapView.showsUserLocation = true
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if needed
        if mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude ||
           mapView.region.span.latitudeDelta != region.span.latitudeDelta {
            mapView.setRegion(region, animated: true)
        }
        
        // Update selected location pin if needed
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        if let location = selectedLocation {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location
            annotation.title = "Selected Location"
            mapView.addAnnotation(annotation)
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
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            
            let mapView = gesture.view as! MKMapView
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // Add haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            parent.onLongPress(coordinate)
        }
        
        // Customize annotation view
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            let identifier = "SelectedLocation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = .red
                markerView.glyphImage = UIImage(systemName: "mappin.and.ellipse")
            }
            
            return annotationView
        }
    }
}

// Info panel at the top of the map
struct InfoPanel: View {
    var message: String
    var isLoading: Bool
    
    var body: some View {
        HStack {
            Text(message)
                .font(.system(size: 14))
                .padding(8)
            
            if isLoading {
                ProgressView()
                    .padding(.leading, 5)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground).opacity(0.9))
        .cornerRadius(8)
    }
}
