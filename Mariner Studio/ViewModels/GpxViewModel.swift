//
//  GpxViewModel.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//


import Foundation
import CoreLocation
import Combine
import SwiftUI

class GpxViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var routeName = ""
    @Published var startDate = Date()
    @Published var startTime = Date()
    @Published var averageSpeed = "10"
    @Published var hasRoute = false
    @Published var etasCalculated = false
    @Published var routePoints: [RoutePoint] = []
    @Published var isReversed = false
    @Published var directionButtonText = "Reverse Route"
    
    // MARK: - Services
    private let gpxService: GpxService
    private let routeCalculationService: RouteCalculationService
    private let navigationService: (([String: Any]) -> Void)?
    
    // MARK: - Computed Properties
    var canCalculateETAs: Bool {
        return hasRoute && !averageSpeed.isEmpty && Double(averageSpeed) != nil
    }
    
    // MARK: - Event handlers
    var onRouteReversed: (([RoutePoint]) -> Void)?
    
    // MARK: - Initialization
    init(gpxService: GpxService, routeCalculationService: RouteCalculationService, navigationService: (([String: Any]) -> Void)? = nil) {
        self.gpxService = gpxService
        self.routeCalculationService = routeCalculationService
        self.navigationService = navigationService
    }
    
    // MARK: - Public Methods
    func openGpxFile() async {
        // Reset state
        isLoading = true
        errorMessage = ""
        clearRoute()
        
        do {
            // Present document picker
            let url = try await presentDocumentPicker(fileTypes: ["org.topografix.gpx"])
            
            // Load GPX file
            let gpxFile = try await gpxService.loadGpxFile(from: url)
            
            // Process route
            if !gpxFile.route.routePoints.isEmpty {
                let firstPoint = gpxFile.route.routePoints.first!
                let lastPoint = gpxFile.route.routePoints.last!
                
                routeName = "\(firstPoint.name ?? "Start") - \(lastPoint.name ?? "End")"
                
                // Convert GPX route points to RoutePoints
                routePoints = gpxFile.route.routePoints.map { point in
                    RoutePoint(
                        name: point.name ?? "Waypoint",
                        latitude: point.latitude,
                        longitude: point.longitude
                    )
                }
                
                hasRoute = true
            } else {
                errorMessage = "Invalid GPX file format"
            }
        } catch {
            errorMessage = "Error loading GPX file: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func calculateETAs() {
        guard canCalculateETAs, routePoints.count >= 2 else { return }
        
        // Create date from startDate + startTime
        let calendar = Calendar.current
        let startDateComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
        let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = startDateComponents.year
        combinedComponents.month = startDateComponents.month
        combinedComponents.day = startDateComponents.day
        combinedComponents.hour = startTimeComponents.hour
        combinedComponents.minute = startTimeComponents.minute
        
        if let startDateTime = calendar.date(from: combinedComponents) {
            // Set the ETA of the first point to the start date/time
            routePoints[0].eta = startDateTime
            
            // Get the speed in knots
            guard let speed = Double(averageSpeed) else { return }
            
            // Calculate distances, bearings, and ETAs
            routePoints = routeCalculationService.calculateDistanceAndBearing(routePoints: routePoints, averageSpeed: speed)
            
            etasCalculated = true
        }
    }
    
    func reverseRoute() {
        guard hasRoute else { return }
        
        isReversed.toggle()
        directionButtonText = isReversed ? "Original Direction" : "Reverse Route"
        
        // Create a new reversed list
        let reversedPoints = routePoints.reversed()
        
        // Clear and repopulate the observable collection
        routePoints = Array(reversedPoints)
        
        // Update route name to reflect direction
        if let firstPoint = routePoints.first, let lastPoint = routePoints.last {
            routeName = "\(firstPoint.name) - \(lastPoint.name)"
        }
        
        // Reset ETAs since they need to be recalculated
        etasCalculated = false
        
        // Notify listeners that the route has been reversed
        onRouteReversed?(routePoints)
    }
    
    func viewRouteDetails() {
        guard etasCalculated, let navigationService = navigationService else { return }
        
        // Convert RoutePoints to GpxRoutePoints for the navigation
        let gpxRoutePoints = routePoints.map { point -> GpxRoutePoint in
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
        
        // Create route for navigation
        let route = GpxRoute(
            name: routeName,
            routePoints: gpxRoutePoints
        )
        
        // Create parameters for navigation
        let parameters: [String: Any] = [
            "route": route,
            "averageSpeed": averageSpeed
        ]
        
        // Navigate to route details
        navigationService(parameters)
    }
    
    func clearRoute() {
        routeName = ""
        hasRoute = false
        routePoints = []
        errorMessage = ""
        etasCalculated = false
        isReversed = false
        directionButtonText = "Reverse Route"
    }
    
    // MARK: - Private Methods
    
    private func presentDocumentPicker(fileTypes: [String]) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let documentPickerVC = UIDocumentPickerViewController(documentTypes: fileTypes, in: .import)
                
                // Create a delegate to handle the document picker
                let delegate = DocumentPickerDelegate { result in
                    switch result {
                    case .success(let url):
                        continuation.resume(returning: url)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                // Store the delegate to prevent it from being deallocated
                documentPickerVC.delegate = delegate
                
                // Use explicit 'self' to make capture semantics clear
                self.setDocumentPickerDelegate(delegate)
                
                // Present the document picker
                UIApplication.shared.windows.first?.rootViewController?.present(documentPickerVC, animated: true)
            }
        }
    }
    
    
    
    // A property to store the document picker delegate
    private var documentPickerDelegate: DocumentPickerDelegate?
    
    private func setDocumentPickerDelegate(_ delegate: DocumentPickerDelegate) {
        documentPickerDelegate = delegate
    }
}

// Document picker delegate to handle the file selection
class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    typealias CompletionHandler = (Result<URL, Error>) -> Void
    
    private let completion: CompletionHandler
    
    init(completion: @escaping CompletionHandler) {
        self.completion = completion
        super.init()
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            completion(.failure(NSError(domain: "com.marinerstudio", code: 404, 
                               userInfo: [NSLocalizedDescriptionKey: "No document selected"])))
            return
        }
        
        // Ensure we have access to the URL
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        completion(.success(url))
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(.failure(NSError(domain: "com.marinerstudio", code: 401, 
                           userInfo: [NSLocalizedDescriptionKey: "Document picker was cancelled"])))
    }
}
