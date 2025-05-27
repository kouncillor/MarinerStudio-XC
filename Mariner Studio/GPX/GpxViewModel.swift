
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
    @Published var isPreLoaded = false // New property to track if route was pre-loaded
    
    // MARK: - Services
    private let gpxService: GpxServiceProtocol
    private let routeCalculationService: RouteCalculationService
    
    // MARK: - Computed Properties
    var canCalculateETAs: Bool {
        return hasRoute && !averageSpeed.isEmpty && Double(averageSpeed) != nil
    }
    
    // MARK: - Event handlers
    var onRouteReversed: (([RoutePoint]) -> Void)?
    
    // MARK: - Initialization
    init(gpxService: GpxServiceProtocol, routeCalculationService: RouteCalculationService) {
        self.gpxService = gpxService
        self.routeCalculationService = routeCalculationService
    }
    
    // MARK: - New Initialization with Pre-loaded Data
    convenience init(gpxService: GpxServiceProtocol, routeCalculationService: RouteCalculationService, preLoadedRoute: GpxFile) {
        self.init(gpxService: gpxService, routeCalculationService: routeCalculationService)
        self.loadPreExistingRoute(preLoadedRoute)
    }
    
    // MARK: - Public Methods
    
    /// Load a route that already exists (from favorites, etc.)
    func loadPreExistingRoute(_ gpxFile: GpxFile) {
        // Process route on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !gpxFile.route.routePoints.isEmpty {
                let firstPoint = gpxFile.route.routePoints.first!
                let lastPoint = gpxFile.route.routePoints.last!
                
                self.routeName = gpxFile.route.name.isEmpty ? "\(firstPoint.name ?? "Start") - \(lastPoint.name ?? "End")" : gpxFile.route.name
                
                // Convert GPX route points to RoutePoints
                self.routePoints = gpxFile.route.routePoints.map { point in
                    RoutePoint(
                        name: point.name ?? "Waypoint",
                        latitude: point.latitude,
                        longitude: point.longitude
                    )
                }
                
                self.hasRoute = true
                self.isPreLoaded = true
                self.errorMessage = ""
                
                print("📍 GpxViewModel: Pre-loaded route '\(self.routeName)' with \(self.routePoints.count) waypoints")
            } else {
                self.errorMessage = "Invalid route data"
                self.isPreLoaded = false
            }
        }
    }
    
    func openGpxFile() async {
        // Reset state on main thread
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            clearRoute()
        }
        
        do {
            // Present document picker with updated file types
            let url = try await presentDocumentPicker(fileTypes: ["com.topografix.gpx", "public.xml"])
            
            // Load GPX file using the protocol service
            let gpxFile = try await gpxService.loadGpxFile(from: url)
            
            // Process route on main thread
            await MainActor.run {
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
                    isPreLoaded = false // This was loaded from file, not pre-loaded
                } else {
                    errorMessage = "Invalid GPX file format"
                }
            }
        } catch let gpxError as GpxServiceError {
            // Handle standardized GPX errors with clean user messages
            await MainActor.run {
                errorMessage = gpxError.localizedDescription
            }
        } catch {
            // Handle any other errors
            await MainActor.run {
                errorMessage = "Error loading GPX file: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
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
    
    private func clearRoute() {
        routeName = ""
        hasRoute = false
        routePoints = []
        errorMessage = ""
        etasCalculated = false
        isReversed = false
        directionButtonText = "Reverse Route"
        isPreLoaded = false
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
