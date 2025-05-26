
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
            locationService: serviceProvider.locationService
        ))
    }
    
    var body: some View {
        ZStack {
            // Full-screen map
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
                        // Waypoint list button
                        if !viewModel.waypoints.isEmpty {
                            Button(action: { showingWaypointList = true }) {
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
                            Button(action: { viewModel.clearAllWaypoints() }) {
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
                        if viewModel.isExporting {
                            ProgressView()
                                .padding()
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        
                        Button("Save Route") {
                            Task {
                                await viewModel.exportRoute()
                            }
                        }
                        .disabled(!viewModel.canSaveRoute || viewModel.isExporting)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(viewModel.canSaveRoute && !viewModel.isExporting ? Color.blue : Color.gray)
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
            if viewModel.exportSuccess {
                VStack {
                    Spacer()
                    
                    Text("Route saved successfully!")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                        .padding()
                    
                    Spacer()
                }
                .transition(.move(edge: .bottom))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            }
            
            if !viewModel.exportError.isEmpty {
                VStack {
                    Text(viewModel.exportError)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                        .padding()
                    
                    Spacer()
                }
                .transition(.move(edge: .top))
                .onTapGesture {
                    viewModel.exportError = ""
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
            viewModel.routeName = routeName
        }
    }
}

// MARK: - Waypoint List Sheet

struct WaypointListSheet: View {
    @ObservedObject var viewModel: CreateRouteViewModel
    @Environment(\.dismiss) private var dismiss
    
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
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.removeWaypoint(at: index)
                    }
                }
                .onMove(perform: viewModel.moveWaypoint)
            }
            .navigationTitle("Waypoints (\(viewModel.waypoints.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.4f°, %.4f°", coordinate.latitude, coordinate.longitude)
    }
}

// MARK: - Map View Component (Reused)

struct CreateRouteMapView: UIViewRepresentable {
    @ObservedObject var viewModel: CreateRouteViewModel
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = .standard
        
        // Set initial region to user's location (only on first load)
        mapView.setRegion(viewModel.mapRegion, animated: false)
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapTapped(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // DO NOT update map region - let user control map position and zoom completely
        
        // Clear existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // Add route polyline
        if let polyline = viewModel.routePolyline {
            mapView.addOverlay(polyline)
        }
        
        // Add waypoint annotations
        mapView.addAnnotations(viewModel.routeAnnotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CreateRouteMapView
        
        init(_ parent: CreateRouteMapView) {
            self.parent = parent
        }
        
        @objc func mapTapped(_ gesture: UITapGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let touchPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            parent.viewModel.handleMapTap(at: coordinate)
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
            
            let identifier = "WaypointPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // Customize appearance
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = .orange
                markerView.glyphImage = UIImage(systemName: "flag.fill")
            }
            
            return annotationView
        }
    }
}

// MARK: - Waypoint Name Sheet (Reused)

struct WaypointNameSheet: View {
    @Binding var waypointName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Name this waypoint")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                TextField("Waypoint name", text: $waypointName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        onConfirm()
                    }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Waypoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onConfirm()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
