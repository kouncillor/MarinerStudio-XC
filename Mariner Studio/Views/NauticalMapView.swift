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
    @State private var chartOverlay: MKTileOverlay?
    @State private var currentChartType: NOAAChartType = .traditional
    @State private var showingChartTypeSelector = false
    @State private var userLocation: CLLocation?
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showingChartInfo = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main Map View
                NauticalChartMapView(
                    region: $mapRegion,
                    chartOverlay: $chartOverlay,
                    userLocation: $userLocation
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
                
                // Chart Type & Info Controls
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            // Chart Type Toggle Button
                            Button(action: {
                                showingChartTypeSelector = true
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "map.fill")
                                        .font(.title2)
                                    Text(currentChartType == .traditional ? "Traditional" : "ECDIS")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
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
                    
                    // Chart Status Indicator
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOAA Nautical Charts")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(currentChartType == .traditional ? "Traditional Paper Chart Style" : "ECDIS S-52 Compliant")
                                .font(.caption2)
                            Text("Zoom in for chart details")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Nautical Chart")
        .withHomeButton()
        .onAppear {
            setupChartDisplay()
        }
        .alert("Chart Information", isPresented: $showingChartInfo) {
            Button("OK") { }
        } message: {
            Text("NOAA Official Charts\n\nDisplaying official NOAA Electronic Navigational Charts (ENCs) with \(currentChartType == .traditional ? "traditional paper chart" : "ECDIS S-52 compliant") symbology.\n\nData Source: NOAA Chart Display Service\n\nZoom in to see nautical features like depth soundings, buoys, and navigation aids.")
        }
        .actionSheet(isPresented: $showingChartTypeSelector) {
            ActionSheet(
                title: Text("Chart Type"),
                message: Text("Choose the nautical chart display style"),
                buttons: [
                    .default(Text("Traditional Paper Chart Style")) {
                        switchChartType(to: .traditional)
                    },
                    .default(Text("ECDIS S-52 Compliant")) {
                        switchChartType(to: .ecdis)
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private func setupChartDisplay() {
        print("🗺️ NauticalMapView: Setting up chart display")
        
        // Setup location first
        setupUserLocation()
        
        // Create NOAA chart overlay with current type
        let overlay = serviceProvider.noaaChartService.createChartTileOverlay(chartType: currentChartType)
        chartOverlay = overlay
        
        // Simulate loading time and remove loading indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isLoading = false
            }
        }
        
        print("✅ NauticalMapView: Chart overlay configured with \(currentChartType == .traditional ? "Traditional" : "ECDIS") chart type")
    }
    
    private func switchChartType(to newType: NOAAChartType) {
        print("🗺️ NauticalMapView: Switching chart type from \(currentChartType == .traditional ? "Traditional" : "ECDIS") to \(newType == .traditional ? "Traditional" : "ECDIS")")
        
        currentChartType = newType
        
        // Create new overlay with the selected chart type
        let newOverlay = serviceProvider.noaaChartService.createChartTileOverlay(chartType: currentChartType)
        chartOverlay = newOverlay
        
        print("✅ NauticalMapView: Chart type switched successfully")
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

// MARK: - NauticalChartMapView

struct NauticalChartMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var chartOverlay: MKTileOverlay?
    @Binding var userLocation: CLLocation?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true
        
        print("🗺️ NauticalChartMapView: Created MapKit view")
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
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 0.9 // Make charts more visible
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Update the binding when user pans/zooms
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
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
