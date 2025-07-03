
//
//  RouteCreationMapView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/25/25.
//

import SwiftUI
import MapKit

struct RouteCreationMapView: View {
    let routeName: String
    let serviceProvider: ServiceProvider
    
    @StateObject private var viewModel: CreateRouteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingWaypointList = false
    
    init(routeName: String, serviceProvider: ServiceProvider) {
        self.routeName = routeName
        self.serviceProvider = serviceProvider
        _viewModel = StateObject(wrappedValue: CreateRouteViewModel(
            gpxService: serviceProvider.gpxService,
            locationService: serviceProvider.locationService,
            noaaChartService: serviceProvider.noaaChartService,
            allRoutesService: serviceProvider.allRoutesService
        ))
        print("📍 RouteCreationMapView: Initialized with route name '\(routeName)'")
    }
    
    var body: some View {
        ZStack {
            // Full-screen map with chart overlay and leg label support
            CreateRouteMapView(viewModel: viewModel)
                .ignoresSafeArea(.all, edges: .bottom)
            
            // Top overlay with route info and controls
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routeName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(viewModel.waypoints.count) waypoints")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Chart overlay toggle button
                        Button(action: {
                            print("🎛️ RouteCreationMapView: Chart overlay button tapped - current state: \(viewModel.isChartOverlayEnabled)")
                            viewModel.toggleChartOverlay()
                        }) {
                            Image(systemName: viewModel.isChartOverlayEnabled ? "map.fill" : "map")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(viewModel.isChartOverlayEnabled ? Color.blue : Color.gray)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        
                        // NEW: Leg labels toggle button
                        Button(action: {
                            print("🎛️ RouteCreationMapView: Leg labels button tapped - current state: \(viewModel.showLegLabels)")
                            viewModel.toggleLegLabels()
                        }) {
                            Image(systemName: viewModel.showLegLabels ? "ruler.fill" : "ruler")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(viewModel.showLegLabels ? Color.orange : Color.gray)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        
                        // Waypoint list button
                        if !viewModel.waypoints.isEmpty {
                            Button(action: {
                                print("🎛️ RouteCreationMapView: Waypoint list button tapped - \(viewModel.waypoints.count) waypoints")
                                showingWaypointList = true
                            }) {
                                Image(systemName: "list.bullet")
                                    .foregroundColor(.blue)
                                    .padding(8)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                        }
                        
                        // Clear all button
                        if !viewModel.waypoints.isEmpty {
                            Button(action: {
                                print("🎛️ RouteCreationMapView: Clear all button tapped - clearing \(viewModel.waypoints.count) waypoints")
                                viewModel.clearAllWaypoints()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .padding(8)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(12)
                .padding()
                
                Spacer()
            }
            
            // Bottom overlay with save button
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        if viewModel.isSaving {
                            ProgressView()
                                .padding()
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        
                        Button("Save Route") {
                            print("💾 RouteCreationMapView: Save Route button tapped - canSaveRoute: \(viewModel.canSaveRoute)")
                            Task {
                                await viewModel.saveRoute()
                            }
                        }
                        .disabled(!viewModel.canSaveRoute || viewModel.isSaving)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(viewModel.canSaveRoute && !viewModel.isSaving ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        .shadow(radius: 3)
                        .font(.headline)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 30)
            }
            
            // Success/Error overlays
            if viewModel.saveSuccess {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text("Route saved to database!")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Your route is now available in All Routes and can be favorited.")
                            .font(.caption)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
                    .padding()
                    
                    Spacer()
                }
                .transition(.move(edge: .bottom))
                .onAppear {
                    print("✅ RouteCreationMapView: Save success message displayed")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        print("📍 RouteCreationMapView: Auto-dismissing after successful save")
                        dismiss()
                    }
                }
            }
            
            if !viewModel.saveError.isEmpty {
                VStack {
                    Text(viewModel.saveError)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                        .padding()
                    
                    Spacer()
                }
                .transition(.move(edge: .top))
                .onTapGesture {
                    print("🎛️ RouteCreationMapView: Error message tapped - clearing error")
                    viewModel.saveError = ""
                }
            }
        }
        .navigationTitle("Creating: \(routeName)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .sheet(isPresented: $showingWaypointList) {
            WaypointListSheet(viewModel: viewModel)
        }
        .onAppear {
            print("📍 RouteCreationMapView: View appeared - setting route name to '\(routeName)'")
            viewModel.routeName = routeName
        }
    }
}

// MARK: - Waypoint List Sheet

struct WaypointListSheet: View {
    @ObservedObject var viewModel: CreateRouteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var renamingWaypointIndex: Int? = nil
    @State private var renameText: String = ""
    @State private var showingRenameAlert = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(viewModel.waypoints.enumerated()), id: \.element.id) { index, waypoint in
                    HStack {
                        Text("\(index + 1).")
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(waypoint.name)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text(formatCoordinate(waypoint.coordinate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // Delete action
                        Button(role: .destructive) {
                            print("🗑️ WaypointListSheet: Delete action triggered for waypoint at index \(index)")
                            viewModel.removeWaypoint(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        // Rename action
                        Button {
                            print("✏️ WaypointListSheet: Rename action triggered for waypoint '\(waypoint.name)' at index \(index)")
                            startRenaming(waypoint: waypoint, at: index)
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onMove(perform: { source, destination in
                    print("🔄 WaypointListSheet: Move operation - from \(Array(source)) to \(destination)")
                    viewModel.moveWaypoint(from: source, to: destination)
                })
            }
            .navigationTitle("Waypoints (\(viewModel.waypoints.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        print("📍 WaypointListSheet: Done button tapped - dismissing sheet")
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .alert("Rename Waypoint", isPresented: $showingRenameAlert) {
                TextField("Waypoint name", text: $renameText)
                
                Button("Cancel", role: .cancel) {
                    print("❌ WaypointListSheet: Rename cancelled")
                    cancelRenaming()
                }
                
                Button("Rename") {
                    print("✅ WaypointListSheet: Rename confirmed with text: '\(renameText)'")
                    confirmRenaming()
                }
            } message: {
                if let index = renamingWaypointIndex {
                    Text("Enter a new name for waypoint \(index + 1)")
                }
            }
        }
        .onAppear {
            print("📍 WaypointListSheet: Sheet appeared with \(viewModel.waypoints.count) waypoints")
        }
    }
    
    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        let formatted = String(format: "%.4f°, %.4f°", coordinate.latitude, coordinate.longitude)
        print("📍 WaypointListSheet: formatCoordinate() - input: (\(coordinate.latitude), \(coordinate.longitude)), output: '\(formatted)'")
        return formatted
    }
    
    private func startRenaming(waypoint: CreateRouteWaypoint, at index: Int) {
        print("✏️ WaypointListSheet: startRenaming() - waypoint '\(waypoint.name)' at index \(index)")
        renamingWaypointIndex = index
        renameText = waypoint.name
        showingRenameAlert = true
    }
    
    private func confirmRenaming() {
        guard let index = renamingWaypointIndex else {
            print("❌ WaypointListSheet: confirmRenaming() - no waypoint index set")
            return
        }
        
        print("✅ WaypointListSheet: confirmRenaming() - renaming waypoint at index \(index) to '\(renameText)'")
        viewModel.renameWaypoint(at: index, to: renameText)
        cancelRenaming()
    }
    
    private func cancelRenaming() {
        print("📍 WaypointListSheet: cancelRenaming() - clearing rename state")
        renamingWaypointIndex = nil
        renameText = ""
        showingRenameAlert = false
    }
}

// MARK: - Map View Component (Enhanced with Leg Label Support)

struct CreateRouteMapView: UIViewRepresentable {
    @ObservedObject var viewModel: CreateRouteViewModel
    
    func makeUIView(context: Context) -> MKMapView {
        print("🗺️ CreateRouteMapView: makeUIView() called - creating new MKMapView")
        
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = .standard
        
        // Set initial region to user's location (only on first load)
        mapView.setRegion(viewModel.mapRegion, animated: false)
        print("🗺️ CreateRouteMapView: Set initial map region to (\(viewModel.mapRegion.center.latitude), \(viewModel.mapRegion.center.longitude))")
        
        // Add chart overlay if available
        if let overlay = viewModel.chartOverlay {
            mapView.addOverlay(overlay, level: .aboveLabels)
            print("🗺️ CreateRouteMapView: Added chart overlay on initialization")
        } else {
            print("🗺️ CreateRouteMapView: No chart overlay to add on initialization")
        }
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapTapped(_:)))
        mapView.addGestureRecognizer(tapGesture)
        print("🗺️ CreateRouteMapView: Added tap gesture recognizer")
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        print("🗺️ CreateRouteMapView: updateUIView() called")
        
        // Handle chart overlay updates
        context.coordinator.updateChartOverlay(in: mapView, newOverlay: viewModel.chartOverlay)
        
        // Clear existing overlays (except chart overlay) and annotations
        let overlaysToRemove = mapView.overlays.filter { !($0 is NOAAChartTileOverlay) }
        if !overlaysToRemove.isEmpty {
            print("🧹 CreateRouteMapView: Removing \(overlaysToRemove.count) non-chart overlays")
            mapView.removeOverlays(overlaysToRemove)
        }
        
        let annotationsToRemove = mapView.annotations.filter { !($0 is MKUserLocation) }
        if !annotationsToRemove.isEmpty {
            print("🧹 CreateRouteMapView: Removing \(annotationsToRemove.count) existing annotations")
            mapView.removeAnnotations(annotationsToRemove)
        }
        
        // Add route polyline
        if let polyline = viewModel.routePolyline {
            mapView.addOverlay(polyline)
            print("🗺️ CreateRouteMapView: Added route polyline with \(polyline.pointCount) points")
        } else {
            print("🗺️ CreateRouteMapView: No route polyline to add")
        }
        
        // Add waypoint annotations
        let waypointAnnotations = viewModel.routeAnnotations
        if !waypointAnnotations.isEmpty {
            mapView.addAnnotations(waypointAnnotations)
            print("📍 CreateRouteMapView: Added \(waypointAnnotations.count) waypoint annotations")
        } else {
            print("📍 CreateRouteMapView: No waypoint annotations to add")
        }
        
        // NEW: Add leg annotations if leg labels are enabled
        if viewModel.showLegLabels && !viewModel.legAnnotations.isEmpty {
            mapView.addAnnotations(viewModel.legAnnotations)
            print("📐 CreateRouteMapView: Added \(viewModel.legAnnotations.count) leg label annotations")
        } else if viewModel.showLegLabels {
            print("📐 CreateRouteMapView: Leg labels enabled but no leg annotations available")
        } else {
            print("📐 CreateRouteMapView: Leg labels disabled - not adding leg annotations")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        print("🗺️ CreateRouteMapView: makeCoordinator() called")
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CreateRouteMapView
        private var currentChartOverlay: NOAAChartTileOverlay?
        
        init(_ parent: CreateRouteMapView) {
            self.parent = parent
            super.init()
            print("🗺️ CreateRouteMapView.Coordinator: Initialized")
        }
        
        // Chart overlay management
        func updateChartOverlay(in mapView: MKMapView, newOverlay: NOAAChartTileOverlay?) {
            print("🗺️ CreateRouteMapView.Coordinator: updateChartOverlay() called")
            
            // Remove existing chart overlay if it exists
            if let existingOverlay = currentChartOverlay {
                mapView.removeOverlay(existingOverlay)
                currentChartOverlay = nil
                print("🗺️ CreateRouteMapView.Coordinator: Removed existing chart overlay")
            }
            
            // Add new chart overlay if provided
            if let overlay = newOverlay {
                mapView.addOverlay(overlay, level: .aboveLabels)
                currentChartOverlay = overlay
                print("🗺️ CreateRouteMapView.Coordinator: Added new chart overlay")
            } else {
                print("🗺️ CreateRouteMapView.Coordinator: No new chart overlay to add")
            }
        }
        
        @objc func mapTapped(_ gesture: UITapGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let touchPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            print("🎯 CreateRouteMapView.Coordinator: Map tapped at screen point (\(touchPoint.x), \(touchPoint.y))")
            print("🎯 CreateRouteMapView.Coordinator: Converted to coordinate (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))")
            
            parent.viewModel.handleMapTap(at: coordinate)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            print("🎨 CreateRouteMapView.Coordinator: rendererFor overlay called - overlay type: \(type(of: overlay))")
            
            // Handle NOAA Chart tile overlays (render first, underneath route)
            if let chartOverlay = overlay as? NOAAChartTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: chartOverlay)
                renderer.alpha = 0.7 // Slightly transparent to keep route visible
                print("🎨 CreateRouteMapView.Coordinator: Created chart overlay renderer with alpha 0.7")
                return renderer
            }
            
            // Handle route polyline (render on top of chart)
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 3
                print("🎨 CreateRouteMapView.Coordinator: Created polyline renderer - color: blue, width: 3")
                return renderer
            }
            
            print("⚠️ CreateRouteMapView.Coordinator: Unknown overlay type, returning default renderer")
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            print("📌 CreateRouteMapView.Coordinator: viewFor annotation called - annotation type: \(type(of: annotation))")
            
            if annotation is MKUserLocation {
                print("📌 CreateRouteMapView.Coordinator: User location annotation - returning nil (use default)")
                return nil
            }
            
            // NEW: Handle leg annotations differently from waypoint annotations
            if let legAnnotation = annotation as? RouteLegAnnotation {
                print("📐 CreateRouteMapView.Coordinator: Processing leg annotation #\(legAnnotation.legNumber)")
                
                let identifier = "LegLabelPin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    print("📐 CreateRouteMapView.Coordinator: Created new leg annotation view")
                } else {
                    annotationView?.annotation = annotation
                    print("📐 CreateRouteMapView.Coordinator: Reused existing leg annotation view")
                }
                
                // Customize leg annotation appearance
                if let markerView = annotationView as? MKMarkerAnnotationView {
                    markerView.markerTintColor = .orange
                    markerView.glyphImage = UIImage(systemName: "ruler")
                    markerView.titleVisibility = .visible
                    markerView.subtitleVisibility = .visible
                    print("📐 CreateRouteMapView.Coordinator: Customized leg annotation - orange marker with ruler icon")
                }
                
                return annotationView
            }
            
            // Handle regular waypoint annotations
            if let waypointAnnotation = annotation as? CreateRouteAnnotation {
                print("📍 CreateRouteMapView.Coordinator: Processing waypoint annotation '\(waypointAnnotation.title ?? "nil")'")
                
                let identifier = "WaypointPin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    print("📍 CreateRouteMapView.Coordinator: Created new waypoint annotation view")
                } else {
                    annotationView?.annotation = annotation
                    print("📍 CreateRouteMapView.Coordinator: Reused existing waypoint annotation view")
                }
                
                // Customize waypoint annotation appearance
                if let markerView = annotationView as? MKMarkerAnnotationView {
                    markerView.markerTintColor = .blue
                    markerView.glyphImage = UIImage(systemName: "flag.fill")
                    print("📍 CreateRouteMapView.Coordinator: Customized waypoint annotation - blue marker with flag icon")
                }
                
                return annotationView
            }
            
            print("⚠️ CreateRouteMapView.Coordinator: Unknown annotation type, returning nil")
            return nil
        }
    }
}
