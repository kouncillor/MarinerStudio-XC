
import SwiftUI
import MapKit

struct GpxView: View {
    @ObservedObject var viewModel: GpxViewModel
    let serviceProvider: ServiceProvider
    @State private var mapRegion = MKCoordinateRegion()
    @State private var polyline: MKPolyline?
    @State private var annotations: [RouteAnnotation] = []
    @State private var showingRouteDetails = false
    @State private var routeDetailsViewModel: RouteDetailsViewModel?
    @State private var isFavorite = false
    @State private var showingFavoriteSuccess = false
    @State private var favoriteMessage = ""
    
    // MARK: - Initializers
    
    // Original initializer for GPX file loading - now expects pre-loaded data
    init(viewModel: GpxViewModel, serviceProvider: ServiceProvider) {
        self.viewModel = viewModel
        self.serviceProvider = serviceProvider
    }
    
    // New initializer for pre-loaded route data
    init(serviceProvider: ServiceProvider, preLoadedRoute: GpxFile, routeName: String? = nil) {
        self.serviceProvider = serviceProvider
        self.viewModel = GpxViewModel(
            gpxService: serviceProvider.gpxService,
            routeCalculationService: serviceProvider.routeCalculationService,
            preLoadedRoute: preLoadedRoute
        )
        
        // Set custom route name if provided
        if let customName = routeName {
            self.viewModel.routeName = customName
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 10) {
                    // Route Name
                    if !viewModel.routeName.isEmpty {
                        HStack {
                            Text(viewModel.routeName)
                                .font(.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Spacer()
                            
                            // Favorite button (only show when route is loaded and not pre-loaded)
                            if viewModel.hasRoute && !viewModel.isPreLoaded {
                                Button(action: {
                                    Task {
                                        await toggleFavorite()
                                    }
                                }) {
                                    Image(systemName: isFavorite ? "star.fill" : "star")
                                        .foregroundColor(isFavorite ? .yellow : .gray)
                                        .font(.title2)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Route Direction Control - Only visible when route is loaded
                    if viewModel.hasRoute {
                        VStack(spacing: 10) {
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
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    }
                    
                    // Route Planning Form - Only show if route is loaded
                    if viewModel.hasRoute {
                        VStack(spacing: 15) {
                            // Show route source info for pre-loaded routes
                            if viewModel.isPreLoaded {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text("Loaded from Favorites")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.bottom, 5)
                            }
                            
                            // Row 1: Start Date
                            HStack {
                                Text("Start Date:")
                                    .font(.subheadline)
                                    .frame(width: 120, alignment: .leading)
                                
                                Spacer()
                                
                                DatePicker("", selection: $viewModel.startDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            
                            // Row 2: Start Time
                            HStack {
                                Text("Start Time:")
                                    .font(.subheadline)
                                    .frame(width: 120, alignment: .leading)
                                
                                Spacer()
                                
                                DatePicker("", selection: $viewModel.startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            
                            // Row 3: Average Speed
                            HStack {
                                Text("Average Speed (knots):")
                                    .font(.subheadline)
                                    .frame(width: 180, alignment: .leading)
                                
                                Spacer()
                                
                                TextField("10", text: $viewModel.averageSpeed)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                            }
                            
                            // Row 4: Calculate ETAs Button
                            Button(action: {
                                viewModel.calculateETAs()
                            }) {
                                Text("Calculate ETAs")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(viewModel.canCalculateETAs ? Color.blue : Color.gray)
                                    .cornerRadius(8)
                            }
                            .disabled(!viewModel.canCalculateETAs)
                            
                            // Row 5: View Route Details Button
                            Button(action: {
                                navigateToRouteDetails()
                            }) {
                                Text("View Route Details")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(viewModel.etasCalculated ? Color.blue : Color.gray)
                                    .cornerRadius(8)
                            }
                            .disabled(!viewModel.etasCalculated)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    }
                    
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
                    
                    // Favorite success message
                    if showingFavoriteSuccess {
                        Text(favoriteMessage)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(8)
                            .transition(.move(edge: .top))
                    }
                    
                    // Map in a card - Only show if route is loaded
                    if viewModel.hasRoute {
                        VStack {
                            MapView(region: $mapRegion, polyline: $polyline, annotations: $annotations)
                                .frame(height: geometry.size.height * 0.55)
                                .cornerRadius(8)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                }
            }
            .onAppear {
                setupLocationPermission()
                
                // If this is a pre-loaded route, update the map immediately
                if viewModel.isPreLoaded {
                    updateMapDisplay(with: viewModel.routePoints)
                    checkFavoriteStatus()
                }
            }
            .onChange(of: viewModel.routePoints) { _, newPoints in
                updateMapDisplay(with: newPoints)
                if !viewModel.isPreLoaded {
                    checkFavoriteStatus()
                }
            }
            .withHomeButton()
            .navigationTitle("Voyage Plan")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showingRouteDetails) {
                if let routeDetailsViewModel = routeDetailsViewModel {
                    RouteDetailsView(viewModel: routeDetailsViewModel)
                }
            }
        }
    }
    
    // MARK: - Favorites Functions
    
    private func checkFavoriteStatus() {
        guard viewModel.hasRoute else { return }
        
        Task {
            let isRouteAlreadyFavorite = await serviceProvider.routeFavoritesService.isRouteFavoriteAsync(
                name: viewModel.routeName,
                waypointCount: viewModel.routePoints.count
            )
            
            await MainActor.run {
                isFavorite = isRouteAlreadyFavorite
            }
        }
    }
    
    private func toggleFavorite() async {
        if isFavorite {
            // Remove from favorites - would need to implement remove functionality
            favoriteMessage = "Removed from favorites"
        } else {
            await addToFavorites()
        }
    }
    
    private func addToFavorites() async {
        guard viewModel.hasRoute else { return }
        
        do {
            // Create GPX file from current route
            let gpxRoutePoints = viewModel.routePoints.map { point -> GpxRoutePoint in
                var gpxPoint = GpxRoutePoint(
                    latitude: point.latitude,
                    longitude: point.longitude,
                    name: point.name
                )
                gpxPoint.eta = point.eta
                gpxPoint.distanceToNext = point.distanceToNext
                gpxPoint.bearingToNext = point.bearingToNext
                return gpxPoint
            }
            
            let gpxRoute = GpxRoute(
                name: viewModel.routeName,
                routePoints: gpxRoutePoints
            )
            
            let gpxFile = GpxFile(route: gpxRoute)
            
            // Serialize GPX to string for database storage
            let gpxString = try await serviceProvider.gpxService.serializeGpxFile(gpxFile)
            
            // Calculate total distance
            let totalDistance = viewModel.routePoints.reduce(0.0) { $0 + $1.distanceToNext }
            
            // Create route favorite
            let routeFavorite = RouteFavorite(
                name: viewModel.routeName,
                gpxData: gpxString,
                waypointCount: viewModel.routePoints.count,
                totalDistance: totalDistance
            )
            
            // Save to database
            _ = try await serviceProvider.routeFavoritesService.addRouteFavoriteAsync(favorite: routeFavorite)
            
            await MainActor.run {
                isFavorite = true
                favoriteMessage = "Route added to favorites!"
                showingFavoriteSuccess = true
                
                // Hide success message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showingFavoriteSuccess = false
                }
            }
            
        } catch {
            await MainActor.run {
                favoriteMessage = "Failed to add to favorites: \(error.localizedDescription)"
                showingFavoriteSuccess = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showingFavoriteSuccess = false
                }
            }
        }
    }
    
    // Navigate to route details
    private func navigateToRouteDetails() {
        guard viewModel.etasCalculated else { return }
        
        // Convert RoutePoints to GpxRoutePoints for the route details
        let gpxRoutePoints = viewModel.routePoints.map { point -> GpxRoutePoint in
            var gpxPoint = GpxRoutePoint(
                latitude: point.latitude,
                longitude: point.longitude,
                name: point.name
            )
            gpxPoint.eta = point.eta
            gpxPoint.distanceToNext = point.distanceToNext
            gpxPoint.bearingToNext = point.bearingToNext
            return gpxPoint
        }
        
        // Create route for route details
        let route = GpxRoute(
            name: viewModel.routeName,
            routePoints: gpxRoutePoints
        )
        
        // Create RouteDetailsViewModel with services
        routeDetailsViewModel = RouteDetailsViewModel(
            weatherService: serviceProvider.openMeteoService,
            routeCalculationService: serviceProvider.routeCalculationService
        )
        
        // Apply route data to the view model
        routeDetailsViewModel?.applyRouteData(route, averageSpeed: viewModel.averageSpeed)
        
        // Show the route details view
        showingRouteDetails = true
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

// MARK: - Preview

#Preview {
    // Create mock route data
    let mockRoutePoints = [
        GpxRoutePoint(latitude: 42.3601, longitude: -71.0589, name: "Boston Harbor Start"),
        GpxRoutePoint(latitude: 42.3528, longitude: -71.0520, name: "Fan Pier"),
        GpxRoutePoint(latitude: 42.3467, longitude: -71.0428, name: "Castle Island"),
        GpxRoutePoint(latitude: 42.3398, longitude: -71.0276, name: "Thompson Island"),
        GpxRoutePoint(latitude: 42.3467, longitude: -71.0428, name: "Return to Castle Island"),
        GpxRoutePoint(latitude: 42.3601, longitude: -71.0589, name: "Boston Harbor End")
    ]
    
    let mockRoute = GpxRoute(
        name: "Boston Harbor Tour",
        routePoints: mockRoutePoints,
        totalDistance: 12.5,
        averageSpeed: 8.0
    )
    
    let mockGpxFile = GpxFile(route: mockRoute)
    
    // Create a mock service provider for preview
    let mockServiceProvider = ServiceProvider()
    
    GpxView(
        serviceProvider: mockServiceProvider,
        preLoadedRoute: mockGpxFile,
        routeName: "Boston Harbor Tour"
    )
}
