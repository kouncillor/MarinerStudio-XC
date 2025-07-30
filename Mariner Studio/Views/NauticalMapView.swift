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
    @State private var selectedLayers: Set<Int> = [0, 1, 2, 6] // Start with basic layers

    private let maxAllowedLayers = 15
    private let minAllowedLayers = 1

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Main Map View
                NauticalChartMapView(
                    region: $mapRegion,
                    chartOverlay: Binding<MKTileOverlay?>(
                        get: { chartOverlay },
                        set: { chartOverlay = $0 as? NOAAChartTileOverlay }
                    ),
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

                // Chart Controls
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
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

                    // Layer Control Section
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            // Layer Counter Display
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Chart Layers")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("Showing \(selectedLayers.count) of \(maxAllowedLayers)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            // Layer Control Buttons
                            HStack(spacing: 12) {
                                // Minus Button
                                Button(action: {
                                    decreaseLayerCount()
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(selectedLayers.count > minAllowedLayers ? .red : .gray)
                                }
                                .disabled(selectedLayers.count <= minAllowedLayers)

                                // Current Layer Count
                                Text("\(selectedLayers.count)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .frame(minWidth: 30)

                                // Plus Button
                                Button(action: {
                                    increaseLayerCount()
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(selectedLayers.count < maxAllowedLayers ? .green : .gray)
                                }
                                .disabled(selectedLayers.count >= maxAllowedLayers)
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                        .shadow(radius: 2)

                        Spacer()
                    }
                    .padding()
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
            Text("NOAA Official Charts\n\nDisplaying official NOAA Electronic Navigational Charts (ENCs) with official marine chart symbology.\n\nData Source: NOAA Chart Display Service\n\nCurrently showing \(selectedLayers.count) chart layers. Use +/- buttons to add or remove detail levels.")
        }
    }

    // MARK: - Layer Control Methods

    private func increaseLayerCount() {
        guard selectedLayers.count < maxAllowedLayers else { return }

        // Add the next layer in sequence (0, 1, 2, 3, etc.)
        for layerId in 0..<maxAllowedLayers {
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
        guard selectedLayers.count > minAllowedLayers else { return }

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
        let newOverlay = serviceProvider.noaaChartService.createChartTileOverlay(selectedLayers: selectedLayers)
        chartOverlay = newOverlay

        print("🔄 NauticalMapView: Updated chart overlay with layers: \(selectedLayers.sorted())")
    }

    // MARK: - Chart Setup Methods

    private func setupChartDisplay() {
        print("🗺️ NauticalMapView: Setting up chart display")

        // Setup location first
        setupUserLocation()

        // Create NOAA chart overlay with current settings
        let overlay = serviceProvider.noaaChartService.createChartTileOverlay(selectedLayers: selectedLayers)
        chartOverlay = overlay

        // Simulate loading time and remove loading indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isLoading = false
            }
        }

        print("✅ NauticalMapView: Chart overlay configured with layers: \(selectedLayers.sorted())")
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

// MARK: - NauticalChartMapView (Updated for NOAAChartTileOverlay)

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
            if let tileOverlay = overlay as? NOAAChartTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 0.8
                print("🎨 NauticalChartMapView: Created NOAA tile overlay renderer with alpha 0.8")
                return renderer
            }

            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 0.8
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
