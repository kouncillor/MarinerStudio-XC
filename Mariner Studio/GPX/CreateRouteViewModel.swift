
//
//  CreateRouteViewModel.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/25/25.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation

class CreateRouteViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var routeName: String = ""
    @Published var waypoints: [CreateRouteWaypoint] = []
    @Published var isExporting = false
    @Published var exportError: String = ""
    @Published var exportSuccess = false
    @Published var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.0458, longitude: -76.6413), // Chesapeake Bay fallback
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    // MARK: - Chart Overlay Properties (NEW)
    @Published var isChartOverlayEnabled = true // Default to ON
    @Published var chartOverlay: NOAAChartTileOverlay?
    private let defaultChartLayers: Set<Int> = [0, 1, 2, 6] // Same as other maps
    
    // MARK: - Services
    private let gpxService: ExtendedGpxServiceProtocol
    private let locationService: LocationService
    private let noaaChartService: NOAAChartService // NEW: Chart service
    
    // MARK: - Computed Properties
    var canSaveRoute: Bool {
        return !routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && waypoints.count >= 2
    }
    
    var routePolyline: MKPolyline? {
        guard waypoints.count >= 2 else { return nil }
        let coordinates = waypoints.map { $0.coordinate }
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }
    
    var routeAnnotations: [CreateRouteAnnotation] {
        return waypoints.enumerated().map { index, waypoint in
            CreateRouteAnnotation(
                coordinate: waypoint.coordinate,
                title: waypoint.name,
                subtitle: "Waypoint \(index + 1)"
            )
        }
    }
    
    // MARK: - Initialization
    init(gpxService: ExtendedGpxServiceProtocol, locationService: LocationService, noaaChartService: NOAAChartService) {
        self.gpxService = gpxService
        self.locationService = locationService
        self.noaaChartService = noaaChartService
        print("📍 CreateRouteViewModel: Initialized with chart overlay support")
        
        // Set initial map region to user's location
        setupInitialMapRegion()
        
        // Create chart overlay (enabled by default)
        createChartOverlay()
    }
    
    // MARK: - Chart Overlay Methods (NEW)
    
    func toggleChartOverlay() {
        isChartOverlayEnabled.toggle()
        
        if isChartOverlayEnabled {
            createChartOverlay()
            print("🗺️ CreateRouteViewModel: Chart overlay enabled")
        } else {
            chartOverlay = nil
            print("📴 CreateRouteViewModel: Chart overlay disabled")
        }
    }
    
    private func createChartOverlay() {
        guard isChartOverlayEnabled else {
            chartOverlay = nil
            return
        }
        
        chartOverlay = noaaChartService.createChartTileOverlay(
            selectedLayers: defaultChartLayers
        )
        print("📊 CreateRouteViewModel: Created chart overlay with layers: \(defaultChartLayers)")
    }
    
    // MARK: - Location Setup
    private func setupInitialMapRegion() {
        // Try to get current location
        if let currentLocation = locationService.currentLocation {
            print("📍 CreateRouteViewModel: Setting map region to user location: \(currentLocation.coordinate)")
            mapRegion = MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else {
            print("📍 CreateRouteViewModel: No user location available, using default (Chesapeake Bay)")
            // Request location permission and try again
            Task {
                let authorized = await locationService.requestLocationPermission()
                if authorized {
                    await MainActor.run {
                        if let location = locationService.currentLocation {
                            print("📍 CreateRouteViewModel: Location permission granted, updating map region")
                            mapRegion = MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Map Interaction
    func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        let waypointNumber = waypoints.count + 1
        let defaultName = "Waypoint \(waypointNumber)"
        
        let newWaypoint = CreateRouteWaypoint(
            coordinate: coordinate,
            name: defaultName
        )
        
        // Add waypoint directly without naming popup
        waypoints.append(newWaypoint)
        
        print("📍 CreateRouteViewModel: Added waypoint '\(newWaypoint.name)' at \(coordinate.latitude), \(coordinate.longitude)")
    }
    
    // MARK: - Waypoint Management
    func removeWaypoint(at index: Int) {
        guard index < waypoints.count else { return }
        let removedWaypoint = waypoints.remove(at: index)
        print("📍 CreateRouteViewModel: Removed waypoint '\(removedWaypoint.name)'")
    }
    
    func renameWaypoint(at index: Int, to newName: String) {
        guard index < waypoints.count else { return }
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use default name if empty
        let finalName = trimmedName.isEmpty ? "Waypoint \(index + 1)" : trimmedName
        
        let oldName = waypoints[index].name
        waypoints[index].name = finalName
        
        print("📍 CreateRouteViewModel: Renamed waypoint from '\(oldName)' to '\(finalName)'")
    }
    
    func moveWaypoint(from source: IndexSet, to destination: Int) {
        waypoints.move(fromOffsets: source, toOffset: destination)
        print("📍 CreateRouteViewModel: Reordered waypoints")
    }
    
    func clearAllWaypoints() {
        waypoints.removeAll()
        print("📍 CreateRouteViewModel: Cleared all waypoints")
    }
    
    // MARK: - Route Export
    func exportRoute() async {
        guard canSaveRoute else {
            await MainActor.run {
                exportError = "Please enter a route name and add at least 2 waypoints"
            }
            return
        }
        
        await MainActor.run {
            isExporting = true
            exportError = ""
            exportSuccess = false
        }
        
        do {
            // Convert waypoints to GpxRoutePoints
            let gpxRoutePoints = waypoints.map { waypoint in
                GpxRoutePoint(
                    latitude: waypoint.coordinate.latitude,
                    longitude: waypoint.coordinate.longitude,
                    name: waypoint.name
                )
            }
            
            // Create GPX route and file
            let gpxRoute = GpxRoute(
                name: routeName.trimmingCharacters(in: .whitespacesAndNewlines),
                routePoints: gpxRoutePoints
            )
            
            let gpxFile = GpxFile(route: gpxRoute)
            
            // Create temporary file with actual GPX content
            let tempFileURL = try await createTemporaryGPXFile(gpxFile: gpxFile)
            
            // Present document picker for save location
            let finalURL = try await presentDocumentPickerForSave(tempFileURL: tempFileURL)
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempFileURL)
            
            await MainActor.run {
                exportSuccess = true
                isExporting = false
                print("✅ CreateRouteViewModel: Successfully exported route '\(routeName)' to \(finalURL.lastPathComponent)")
            }
            
        } catch {
            await MainActor.run {
                exportError = "Failed to export route: \(error.localizedDescription)"
                isExporting = false
                print("❌ CreateRouteViewModel: Export failed - \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private Methods
    private func createTemporaryGPXFile(gpxFile: GpxFile) async throws -> URL {
        let fileName = routeName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_") + ".gpx"
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(fileName)
        
        // Write the GPX file to the temporary location
        try await gpxService.writeGpxFile(gpxFile, to: tempFileURL)
        
        print("📄 CreateRouteViewModel: Created temporary GPX file at \(tempFileURL.path)")
        return tempFileURL
    }
    
    private func presentDocumentPickerForSave(tempFileURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                // Create document picker with the existing temporary file
                let documentPicker = UIDocumentPickerViewController(forExporting: [tempFileURL])
                
                // Create delegate
                let delegate = DocumentPickerExportDelegate { result in
                    switch result {
                    case .success(let url):
                        continuation.resume(returning: url)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                documentPicker.delegate = delegate
                
                // Store delegate to prevent deallocation
                self.setDocumentPickerDelegate(delegate)
                
                // Present picker
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    rootViewController.present(documentPicker, animated: true)
                } else {
                    continuation.resume(throwing: NSError(domain: "CreateRouteViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unable to present document picker"]))
                }
            }
        }
    }
    
    // Store delegate to prevent deallocation
    private var documentPickerDelegate: DocumentPickerExportDelegate?
    
    private func setDocumentPickerDelegate(_ delegate: DocumentPickerExportDelegate) {
        documentPickerDelegate = delegate
    }
}

// MARK: - Supporting Models

struct CreateRouteWaypoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    var name: String
    
    init(coordinate: CLLocationCoordinate2D, name: String) {
        self.coordinate = coordinate
        self.name = name
    }
}

class CreateRouteAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
}
