
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
    
    // MARK: - Chart Overlay Properties
    @Published var isChartOverlayEnabled = true // Default to ON
    @Published var chartOverlay: NOAAChartTileOverlay?
    private let defaultChartLayers: Set<Int> = [0, 1, 2, 6] // Same as other maps
    
    // MARK: - NEW: Leg Information Properties
    @Published var showLegLabels: Bool = false
    @Published var legAnnotations: [RouteLegAnnotation] = []
    
    // MARK: - Services
    private let gpxService: ExtendedGpxServiceProtocol
    private let locationService: LocationService
    private let noaaChartService: NOAAChartService
    
    // MARK: - Computed Properties
    var canSaveRoute: Bool {
        let result = !routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && waypoints.count >= 2
        print("🧮 CreateRouteViewModel: canSaveRoute evaluated - routeName: '\(routeName.trimmingCharacters(in: .whitespacesAndNewlines))', waypoints: \(waypoints.count), result: \(result)")
        return result
    }
    
    var routePolyline: MKPolyline? {
        guard waypoints.count >= 2 else {
            print("📍 CreateRouteViewModel: routePolyline - insufficient waypoints (\(waypoints.count))")
            return nil
        }
        let coordinates = waypoints.map { $0.coordinate }
        print("📍 CreateRouteViewModel: routePolyline created with \(coordinates.count) coordinates")
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }
    
    var routeAnnotations: [CreateRouteAnnotation] {
        let annotations = waypoints.enumerated().map { index, waypoint in
            CreateRouteAnnotation(
                coordinate: waypoint.coordinate,
                title: waypoint.name,
                subtitle: "Waypoint \(index + 1)"
            )
        }
        print("📍 CreateRouteViewModel: routeAnnotations generated - \(annotations.count) annotations")
        return annotations
    }
    
    // MARK: - Initialization
    init(gpxService: ExtendedGpxServiceProtocol, locationService: LocationService, noaaChartService: NOAAChartService) {
        self.gpxService = gpxService
        self.locationService = locationService
        self.noaaChartService = noaaChartService
        print("📍 CreateRouteViewModel: Initialized with chart overlay and leg information support")
        print("📍 CreateRouteViewModel: Initial state - showLegLabels: \(showLegLabels), chartOverlay: \(isChartOverlayEnabled)")
        
        // Set initial map region to user's location
        setupInitialMapRegion()
        
        // Create chart overlay (enabled by default)
        createChartOverlay()
    }
    
    // MARK: - Chart Overlay Methods
    
    func toggleChartOverlay() {
        isChartOverlayEnabled.toggle()
        print("🎛️ CreateRouteViewModel: toggleChartOverlay() - new state: \(isChartOverlayEnabled)")
        
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
            print("📴 CreateRouteViewModel: createChartOverlay() - overlay disabled, setting to nil")
            return
        }
        
        chartOverlay = noaaChartService.createChartTileOverlay(
            selectedLayers: defaultChartLayers
        )
        print("📊 CreateRouteViewModel: Created chart overlay with layers: \(defaultChartLayers)")
    }
    
    // MARK: - NEW: Leg Information Methods
    
    func toggleLegLabels() {
        showLegLabels.toggle()
        print("🎛️ CreateRouteViewModel: toggleLegLabels() - new state: \(showLegLabels)")
        
        if showLegLabels {
            calculateAndDisplayLegInformation()
        } else {
            clearLegAnnotations()
        }
    }
    
    private func calculateAndDisplayLegInformation() {
        guard waypoints.count >= 2 else {
            print("📍 CreateRouteViewModel: calculateAndDisplayLegInformation() - insufficient waypoints (\(waypoints.count))")
            clearLegAnnotations()
            return
        }
        
        print("🧮 CreateRouteViewModel: calculateAndDisplayLegInformation() started with \(waypoints.count) waypoints")
        var newAnnotations: [RouteLegAnnotation] = []
        
        // Calculate leg information for each consecutive pair of waypoints
        for i in 0..<(waypoints.count - 1) {
            let fromWaypoint = waypoints[i]
            let toWaypoint = waypoints[i + 1]
            
            print("🧮 CreateRouteViewModel: Processing leg \(i + 1): '\(fromWaypoint.name)' to '\(toWaypoint.name)'")
            
            // Calculate bearing (true heading)
            let bearing = calculateBearing(
                from: fromWaypoint.coordinate,
                to: toWaypoint.coordinate
            )
            
            // Calculate distance in nautical miles
            let distance = calculateDistance(
                from: fromWaypoint.coordinate,
                to: toWaypoint.coordinate
            )
            
            // Calculate midpoint for label positioning
            let midpoint = calculateMidpoint(
                from: fromWaypoint.coordinate,
                to: toWaypoint.coordinate
            )
            
            print("✅ CreateRouteViewModel: Leg \(i + 1) calculations complete:")
            print("   📐 Bearing: \(String(format: "%.0f", bearing))°T")
            print("   📏 Distance: \(String(format: "%.2f", distance)) nm")
            print("   📍 Midpoint: (\(String(format: "%.6f", midpoint.latitude)), \(String(format: "%.6f", midpoint.longitude)))")
            
            // Create leg annotation
            let legAnnotation = RouteLegAnnotation(
                coordinate: midpoint,
                heading: bearing,
                distance: distance,
                legNumber: i + 1
            )
            
            newAnnotations.append(legAnnotation)
        }
        
        // Update annotations array
        legAnnotations = newAnnotations
        print("✅ CreateRouteViewModel: Leg information calculation complete - generated \(legAnnotations.count) leg annotations")
    }
    
    private func clearLegAnnotations() {
        print("🧹 CreateRouteViewModel: clearLegAnnotations() - removing \(legAnnotations.count) annotations")
        legAnnotations.removeAll()
    }
    
    // MARK: - NEW: Mathematical Calculation Methods
    
    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        print("🧮 CreateRouteViewModel: calculateBearing() from (\(String(format: "%.6f", from.latitude)), \(String(format: "%.6f", from.longitude))) to (\(String(format: "%.6f", to.latitude)), \(String(format: "%.6f", to.longitude)))")
        
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(y, x) * 180 / .pi
        let normalizedBearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        
        print("🧮 CreateRouteViewModel: calculateBearing() intermediate values - lat1: \(lat1), lat2: \(lat2), deltaLon: \(deltaLon)")
        print("🧮 CreateRouteViewModel: calculateBearing() result - raw: \(bearing)°, normalized: \(normalizedBearing)°")
        
        return normalizedBearing
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        print("🧮 CreateRouteViewModel: calculateDistance() from (\(String(format: "%.6f", from.latitude)), \(String(format: "%.6f", from.longitude))) to (\(String(format: "%.6f", to.latitude)), \(String(format: "%.6f", to.longitude)))")
        
        let earthRadiusNM = 3440.065 // Earth radius in nautical miles
        
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        let distance = earthRadiusNM * c
        
        print("🧮 CreateRouteViewModel: calculateDistance() intermediate values - deltaLat: \(deltaLat), deltaLon: \(deltaLon), a: \(a), c: \(c)")
        print("🧮 CreateRouteViewModel: calculateDistance() result - \(String(format: "%.3f", distance)) nm")
        
        return distance
    }
    
    private func calculateMidpoint(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        print("🧮 CreateRouteViewModel: calculateMidpoint() from (\(String(format: "%.6f", from.latitude)), \(String(format: "%.6f", from.longitude))) to (\(String(format: "%.6f", to.latitude)), \(String(format: "%.6f", to.longitude)))")
        
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        
        let bx = cos(lat2) * cos(deltaLon)
        let by = cos(lat2) * sin(deltaLon)
        
        let lat3 = atan2(sin(lat1) + sin(lat2), sqrt((cos(lat1) + bx) * (cos(lat1) + bx) + by * by))
        let lon3 = lon1 + atan2(by, cos(lat1) + bx)
        
        let midpoint = CLLocationCoordinate2D(
            latitude: lat3 * 180 / .pi,
            longitude: lon3 * 180 / .pi
        )
        
        print("🧮 CreateRouteViewModel: calculateMidpoint() result - (\(String(format: "%.6f", midpoint.latitude)), \(String(format: "%.6f", midpoint.longitude)))")
        
        return midpoint
    }
    
    // MARK: - Location Setup
    private func setupInitialMapRegion() {
        print("📍 CreateRouteViewModel: setupInitialMapRegion() started")
        
        // Try to get current location
        if let currentLocation = locationService.currentLocation {
            print("📍 CreateRouteViewModel: Setting map region to user location: (\(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude))")
            mapRegion = MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else {
            print("📍 CreateRouteViewModel: No user location available, using default (Chesapeake Bay)")
            // Request location permission and try again
            Task {
                print("📍 CreateRouteViewModel: Requesting location permission...")
                let authorized = await locationService.requestLocationPermission()
                print("📍 CreateRouteViewModel: Location permission result: \(authorized)")
                
                if authorized {
                    await MainActor.run {
                        if let location = locationService.currentLocation {
                            print("📍 CreateRouteViewModel: Location permission granted, updating map region to: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
                            mapRegion = MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )
                        } else {
                            print("⚠️ CreateRouteViewModel: Location permission granted but no location available")
                        }
                    }
                } else {
                    print("❌ CreateRouteViewModel: Location permission denied")
                }
            }
        }
    }
    
    // MARK: - Map Interaction
    func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        let waypointNumber = waypoints.count + 1
        let defaultName = "Waypoint \(waypointNumber)"
        
        print("📍 CreateRouteViewModel: handleMapTap() at (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))")
        print("📍 CreateRouteViewModel: Creating waypoint #\(waypointNumber) with name '\(defaultName)'")
        
        let newWaypoint = CreateRouteWaypoint(
            coordinate: coordinate,
            name: defaultName
        )
        
        // Add waypoint directly without naming popup
        waypoints.append(newWaypoint)
        
        print("✅ CreateRouteViewModel: Added waypoint '\(newWaypoint.name)' - total waypoints: \(waypoints.count)")
        
        // Recalculate leg information if labels are shown
        if showLegLabels {
            print("🔄 CreateRouteViewModel: Leg labels enabled, recalculating leg information")
            calculateAndDisplayLegInformation()
        }
    }
    
    // MARK: - Waypoint Management
    func removeWaypoint(at index: Int) {
        guard index < waypoints.count else {
            print("❌ CreateRouteViewModel: removeWaypoint() - invalid index \(index), waypoints count: \(waypoints.count)")
            return
        }
        
        let removedWaypoint = waypoints.remove(at: index)
        print("🗑️ CreateRouteViewModel: Removed waypoint '\(removedWaypoint.name)' at index \(index) - remaining waypoints: \(waypoints.count)")
        
        // Recalculate leg information if labels are shown
        if showLegLabels {
            print("🔄 CreateRouteViewModel: Leg labels enabled, recalculating after waypoint removal")
            calculateAndDisplayLegInformation()
        }
    }
    
    func renameWaypoint(at index: Int, to newName: String) {
        guard index < waypoints.count else {
            print("❌ CreateRouteViewModel: renameWaypoint() - invalid index \(index), waypoints count: \(waypoints.count)")
            return
        }
        
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use default name if empty
        let finalName = trimmedName.isEmpty ? "Waypoint \(index + 1)" : trimmedName
        
        let oldName = waypoints[index].name
        waypoints[index].name = finalName
        
        print("✏️ CreateRouteViewModel: Renamed waypoint at index \(index) from '\(oldName)' to '\(finalName)'")
        
        // Note: No need to recalculate leg information for rename - coordinates haven't changed
    }
    
    func moveWaypoint(from source: IndexSet, to destination: Int) {
        print("🔄 CreateRouteViewModel: moveWaypoint() from indices \(Array(source)) to destination \(destination)")
        waypoints.move(fromOffsets: source, toOffset: destination)
        print("✅ CreateRouteViewModel: Waypoint reordering complete - total waypoints: \(waypoints.count)")
        
        // Recalculate leg information if labels are shown (order changed)
        if showLegLabels {
            print("🔄 CreateRouteViewModel: Leg labels enabled, recalculating after waypoint reordering")
            calculateAndDisplayLegInformation()
        }
    }
    
    func clearAllWaypoints() {
        let previousCount = waypoints.count
        waypoints.removeAll()
        print("🧹 CreateRouteViewModel: Cleared all waypoints - removed \(previousCount) waypoints")
        
        // Clear leg annotations
        if showLegLabels {
            print("🧹 CreateRouteViewModel: Clearing leg annotations after waypoint clearing")
            clearLegAnnotations()
        }
    }
    
    // MARK: - Route Export
    func exportRoute() async {
        print("📤 CreateRouteViewModel: exportRoute() started")
        print("📤 CreateRouteViewModel: Route validation - canSaveRoute: \(canSaveRoute)")
        
        guard canSaveRoute else {
            await MainActor.run {
                exportError = "Please enter a route name and add at least 2 waypoints"
                print("❌ CreateRouteViewModel: Export failed - validation error: \(exportError)")
            }
            return
        }
        
        await MainActor.run {
            isExporting = true
            exportError = ""
            exportSuccess = false
            print("🚀 CreateRouteViewModel: Export process started - isExporting: \(isExporting)")
        }
        
        do {
            print("📤 CreateRouteViewModel: Converting \(waypoints.count) waypoints to GPX format")
            
            // Convert waypoints to GpxRoutePoints
            let gpxRoutePoints = waypoints.map { waypoint in
                print("📤 CreateRouteViewModel: Converting waypoint '\(waypoint.name)' at (\(waypoint.coordinate.latitude), \(waypoint.coordinate.longitude))")
                return GpxRoutePoint(
                    latitude: waypoint.coordinate.latitude,
                    longitude: waypoint.coordinate.longitude,
                    name: waypoint.name
                )
            }
            
            // Create GPX route and file
            let routeNameTrimmed = routeName.trimmingCharacters(in: .whitespacesAndNewlines)
            print("📤 CreateRouteViewModel: Creating GPX route with name '\(routeNameTrimmed)'")
            
            let gpxRoute = GpxRoute(
                name: routeNameTrimmed,
                routePoints: gpxRoutePoints
            )
            
            let gpxFile = GpxFile(route: gpxRoute)
            print("✅ CreateRouteViewModel: GPX file structure created successfully")
            
            // Create temporary file with actual GPX content
            print("📤 CreateRouteViewModel: Creating temporary GPX file...")
            let tempFileURL = try await createTemporaryGPXFile(gpxFile: gpxFile)
            
            // Present document picker for save location
            print("📤 CreateRouteViewModel: Presenting document picker for save location...")
            let finalURL = try await presentDocumentPickerForSave(tempFileURL: tempFileURL)
            
            // Clean up temporary file
            print("🧹 CreateRouteViewModel: Cleaning up temporary file at \(tempFileURL.path)")
            try? FileManager.default.removeItem(at: tempFileURL)
            
            await MainActor.run {
                exportSuccess = true
                isExporting = false
                print("🎉 CreateRouteViewModel: Export completed successfully!")
                print("✅ CreateRouteViewModel: Route '\(routeNameTrimmed)' exported to \(finalURL.lastPathComponent)")
            }
            
        } catch {
            await MainActor.run {
                exportError = "Failed to export route: \(error.localizedDescription)"
                isExporting = false
                print("❌ CreateRouteViewModel: Export failed with error: \(error.localizedDescription)")
                print("❌ CreateRouteViewModel: Error details: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    private func createTemporaryGPXFile(gpxFile: GpxFile) async throws -> URL {
        let fileName = routeName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_") + ".gpx"
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(fileName)
        
        print("📄 CreateRouteViewModel: createTemporaryGPXFile() - filename: '\(fileName)'")
        print("📄 CreateRouteViewModel: Temporary file path: \(tempFileURL.path)")
        
        // Write the GPX file to the temporary location
        try await gpxService.writeGpxFile(gpxFile, to: tempFileURL)
        
        print("✅ CreateRouteViewModel: Temporary GPX file created successfully at \(tempFileURL.path)")
        return tempFileURL
    }
    
    private func presentDocumentPickerForSave(tempFileURL: URL) async throws -> URL {
        print("📄 CreateRouteViewModel: presentDocumentPickerForSave() started")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                print("📄 CreateRouteViewModel: Creating document picker for export")
                
                // Create document picker with the existing temporary file
                let documentPicker = UIDocumentPickerViewController(forExporting: [tempFileURL])
                
                // Create delegate
                let delegate = DocumentPickerExportDelegate { result in
                    switch result {
                    case .success(let url):
                        print("✅ CreateRouteViewModel: Document picker succeeded - saved to: \(url.path)")
                        continuation.resume(returning: url)
                    case .failure(let error):
                        print("❌ CreateRouteViewModel: Document picker failed: \(error.localizedDescription)")
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
                    print("📄 CreateRouteViewModel: Presenting document picker")
                    rootViewController.present(documentPicker, animated: true)
                } else {
                    print("❌ CreateRouteViewModel: Unable to find root view controller for document picker")
                    continuation.resume(throwing: NSError(domain: "CreateRouteViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unable to present document picker"]))
                }
            }
        }
    }
    
    // Store delegate to prevent deallocation
    private var documentPickerDelegate: DocumentPickerExportDelegate?
    
    private func setDocumentPickerDelegate(_ delegate: DocumentPickerExportDelegate) {
        documentPickerDelegate = delegate
        print("📄 CreateRouteViewModel: Document picker delegate stored to prevent deallocation")
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
        print("📍 CreateRouteWaypoint: Created waypoint '\(name)' at (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))")
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
        super.init()
        print("📍 CreateRouteAnnotation: Created annotation '\(title ?? "nil")' at (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))")
    }
}

// MARK: - NEW: Route Leg Annotation Class

class RouteLegAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let heading: Double
    let distance: Double
    let legNumber: Int
    
    init(coordinate: CLLocationCoordinate2D, heading: Double, distance: Double, legNumber: Int) {
        self.coordinate = coordinate
        self.heading = heading
        self.distance = distance
        self.legNumber = legNumber
        self.title = String(format: "%03.0f°T", heading)
        self.subtitle = String(format: "%.2f nm", distance)
        
        super.init()
        print("📐 RouteLegAnnotation: Created leg annotation #\(legNumber)")
        print("   📍 Position: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))")
        print("   📐 Heading: \(String(format: "%.0f", heading))°T")
        print("   📏 Distance: \(String(format: "%.2f", distance)) nm")
    }
}
