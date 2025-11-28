//
//  AISMapView.swift
//  Mariner Studio
//
//  Created by Claude on 11/28/25.
//

import SwiftUI
import MapKit

struct AISMapView: View {
    @StateObject private var viewModel = AISMapViewModel()
    @State private var showAPIKeyAlert = false
    @State private var apiKeyInput = "f562294562e9a1417d56f25392f8988b8dea3224"
    @State private var selectedVessel: AISVessel?
    @State private var showVesselDetail = false
    @State private var mapType: MKMapType = .standard

    var body: some View {
        ZStack {
            // Map
            AISMapViewRepresentable(
                initialRegion: viewModel.initialRegion,
                programmaticMoveTarget: viewModel.programmaticMoveTarget,
                vessels: viewModel.vessels,
                mapType: mapType,
                selectedVessel: $selectedVessel,
                onRegionChanged: { region in
                    viewModel.updateBoundingBoxFromRegion(region)
                },
                onProgrammaticMoveComplete: {
                    viewModel.clearProgrammaticMove()
                }
            )
            .edgesIgnoringSafeArea(.bottom)

            // Overlay controls
            VStack {
                Spacer()

                // Bottom control panel
                VStack(spacing: 12) {
                    // Connection status and vessel count
                    HStack {
                        // Status indicator
                        HStack(spacing: 6) {
                            Circle()
                                .fill(viewModel.isConnected ? Color.green : (viewModel.isConnecting ? Color.orange : Color.red))
                                .frame(width: 10, height: 10)

                            Text(viewModel.isConnected ? "Connected" : (viewModel.isConnecting ? "Connecting..." : "Disconnected"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Vessel count
                        if viewModel.isConnected {
                            HStack(spacing: 4) {
                                Image(systemName: "ferry.fill")
                                    .font(.caption)
                                Text("\(viewModel.vesselCount) vessels")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }

                    // Control buttons
                    HStack(spacing: 12) {
                        // Connect/Disconnect button
                        Button(action: {
                            if viewModel.isConnected {
                                viewModel.disconnect()
                            } else {
                                if AISMapViewModel.hasAPIKey() {
                                    viewModel.connect()
                                } else {
                                    showAPIKeyAlert = true
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: viewModel.isConnected ? "stop.fill" : "play.fill")
                                Text(viewModel.isConnected ? "Stop" : "Start")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(viewModel.isConnected ? Color.red : Color.green)
                            .cornerRadius(8)
                        }
                        .disabled(viewModel.isConnecting)

                        // Center on NY Harbor button
                        Button(action: {
                            viewModel.centerOnNYHarbor()
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("NY Harbor")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }

                        // Map type toggle
                        Button(action: {
                            mapType = mapType == .standard ? .satellite : .standard
                        }) {
                            Image(systemName: mapType == .standard ? "globe.americas" : "map")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.gray.opacity(0.8))
                                .cornerRadius(8)
                        }
                    }

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemBackground).opacity(0.95))
                        .shadow(radius: 5)
                )
                .padding()
            }
        }
        .navigationTitle("AIS Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    showAPIKeyAlert = true
                }) {
                    Image(systemName: "key.fill")
                }
            }
        }
        .alert("AIS Stream API Key", isPresented: $showAPIKeyAlert) {
            TextField("Enter API Key", text: $apiKeyInput)
            Button("Save") {
                if !apiKeyInput.isEmpty {
                    AISMapViewModel.setAPIKey(apiKeyInput)
                    // Reinitialize view model with new key
                    viewModel.disconnect()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your AISStream.io API key to receive live vessel data. Get a free key at aisstream.io")
        }
        .sheet(isPresented: $showVesselDetail) {
            if let vessel = selectedVessel {
                VesselDetailView(vessel: vessel)
            }
        }
        .onChange(of: selectedVessel) { _, newValue in
            if newValue != nil {
                showVesselDetail = true
            }
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }
}

// MARK: - Map View Representable

struct AISMapViewRepresentable: UIViewRepresentable {
    let initialRegion: MKCoordinateRegion?
    let programmaticMoveTarget: MKCoordinateRegion?
    let vessels: [AISVessel]
    let mapType: MKMapType
    @Binding var selectedVessel: AISVessel?
    var onRegionChanged: ((MKCoordinateRegion) -> Void)?
    var onProgrammaticMoveComplete: (() -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = mapType

        // Set initial region if available
        if let region = initialRegion {
            mapView.setRegion(region, animated: false)
            context.coordinator.hasSetInitialRegion = true
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update map type
        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        // Update annotations
        updateAnnotations(on: mapView)

        // Set initial region once when it becomes available
        if !context.coordinator.hasSetInitialRegion, let region = initialRegion {
            mapView.setRegion(region, animated: false)
            context.coordinator.hasSetInitialRegion = true
        }

        // Handle programmatic moves (e.g., NY Harbor button)
        if let target = programmaticMoveTarget {
            mapView.setRegion(target, animated: true)
            // Clear the target after applying
            DispatchQueue.main.async {
                onProgrammaticMoveComplete?()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func updateAnnotations(on mapView: MKMapView) {
        // Get existing vessel annotations
        let existingAnnotations = mapView.annotations.compactMap { $0 as? VesselAnnotation }
        let existingMMSIs = Set(existingAnnotations.map { $0.vessel.mmsi })
        let newMMSIs = Set(vessels.map { $0.mmsi })

        // Remove annotations for vessels no longer in the list
        let toRemove = existingAnnotations.filter { !newMMSIs.contains($0.vessel.mmsi) }
        mapView.removeAnnotations(toRemove)

        // Add new annotations
        let toAdd = vessels.filter { !existingMMSIs.contains($0.mmsi) }
        let newAnnotations = toAdd.map { VesselAnnotation(vessel: $0) }
        mapView.addAnnotations(newAnnotations)

        // Update existing annotations (position changes)
        for annotation in existingAnnotations {
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

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AISMapViewRepresentable
        var hasSetInitialRegion = false
        private var lastRegionUpdate = Date()

        init(_ parent: AISMapViewRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Throttle region updates - only update every 3 seconds
            let now = Date()
            guard now.timeIntervalSince(lastRegionUpdate) > 3.0 else { return }
            lastRegionUpdate = now

            parent.onRegionChanged?(mapView.region)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            guard let vesselAnnotation = annotation as? VesselAnnotation else { return nil }

            let identifier = "VesselAnnotation"
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

            // Color based on ship type
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

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let vesselAnnotation = view.annotation as? VesselAnnotation else { return }
            parent.selectedVessel = vesselAnnotation.vessel
        }
    }
}

// MARK: - Vessel Detail View

struct VesselDetailView: View {
    let vessel: AISVessel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Vessel Information") {
                    AISDetailRow(label: "Name", value: vessel.name)
                    AISDetailRow(label: "MMSI", value: String(vessel.mmsi))
                    AISDetailRow(label: "Type", value: vessel.shipTypeDescription)
                    if let destination = vessel.destination, !destination.isEmpty {
                        AISDetailRow(label: "Destination", value: destination)
                    }
                }

                Section("Position") {
                    AISDetailRow(label: "Latitude", value: String(format: "%.5f°", vessel.latitude))
                    AISDetailRow(label: "Longitude", value: String(format: "%.5f°", vessel.longitude))
                }

                Section("Navigation") {
                    if let sog = vessel.speedOverGround {
                        AISDetailRow(label: "Speed (SOG)", value: String(format: "%.1f knots", sog))
                    }
                    if let cog = vessel.courseOverGround {
                        AISDetailRow(label: "Course (COG)", value: String(format: "%.0f°", cog))
                    }
                    if let heading = vessel.heading {
                        AISDetailRow(label: "Heading", value: String(format: "%.0f°", heading))
                    }
                }

                Section("Status") {
                    AISDetailRow(label: "Last Updated", value: formatDate(vessel.lastUpdated))
                }
            }
            .navigationTitle(vessel.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct AISDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AISMapView()
    }
}
