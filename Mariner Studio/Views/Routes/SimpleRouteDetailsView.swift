import SwiftUI
import CoreLocation

struct SimpleRouteDetailsView: View {
    let route: AllRoute
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var gpxFile: GpxFile?
    @State private var isLoading = true
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if let gpxFile = gpxFile {
                    // Route content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Route Map at top
                            SimpleRouteMapView(gpxFile: gpxFile)
                                .frame(height: 300)
                            
                            // Route Summary Card
                            routeSummaryCard(gpxFile.route)
                            
                            // Waypoints List
                            waypointsListView(gpxFile.route)
                        }
                        .padding()
                    }
                } else {
                    errorView
                }
            }
            .navigationTitle("Route Details")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            loadRouteData()
        }
    }
    
    // MARK: - Route Summary Card
    
    private func routeSummaryCard(_ gpxRoute: GpxRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Route name
            Text(route.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Source type indicator
            HStack(spacing: 4) {
                Image(systemName: route.sourceTypeIcon)
                    .font(.caption)
                Text(route.sourceTypeDisplayName)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(sourceTypeColor.opacity(0.2))
            .foregroundColor(sourceTypeColor)
            .cornerRadius(6)
            
            Divider()
            
            // Route statistics
            VStack(spacing: 8) {
                StatRow(
                    icon: "point.3.connected.trianglepath.dotted",
                    label: "Waypoints",
                    value: "\(gpxRoute.routePoints.count)"
                )
                
                StatRow(
                    icon: "ruler",
                    label: "Total Distance", 
                    value: route.formattedDistance
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Waypoints List
    
    private func waypointsListView(_ gpxRoute: GpxRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                Text("Waypoints")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Waypoints
            LazyVStack(spacing: 8) {
                ForEach(Array(gpxRoute.routePoints.enumerated()), id: \.offset) { index, point in
                    SimpleWaypointRow(
                        waypoint: point,
                        index: index + 1,
                        isLast: index == gpxRoute.routePoints.count - 1
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Loading and Error Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading route details...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Failed to Load Route")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Retry") {
                loadRouteData()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Properties
    
    private var sourceTypeColor: Color {
        switch route.sourceType {
        case "public":
            return .blue
        case "imported":
            return .purple
        case "created":
            return .orange
        default:
            return .gray
        }
    }
    
    // MARK: - Data Loading
    
    private func loadRouteData() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                var loadedGpxFile = try await serviceProvider.gpxService.loadGpxFile(from: route.gpxData)
                
                // Calculate distances and bearings between waypoints
                loadedGpxFile = calculateDistancesAndBearings(for: loadedGpxFile)
                
                await MainActor.run {
                    self.gpxFile = loadedGpxFile
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load route data: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Distance and Bearing Calculations
    
    private func calculateDistancesAndBearings(for gpxFile: GpxFile) -> GpxFile {
        var updatedGpxFile = gpxFile
        var updatedRoutePoints = gpxFile.route.routePoints
        
        // Calculate distance and bearing from each waypoint to the next
        for i in 0..<(updatedRoutePoints.count - 1) {
            let currentPoint = updatedRoutePoints[i]
            let nextPoint = updatedRoutePoints[i + 1]
            
            let fromCoord = CLLocationCoordinate2D(
                latitude: currentPoint.latitude,
                longitude: currentPoint.longitude
            )
            let toCoord = CLLocationCoordinate2D(
                latitude: nextPoint.latitude,
                longitude: nextPoint.longitude
            )
            
            // Calculate distance in nautical miles
            let distanceKilometers = serviceProvider.routeCalculationService.calculateDistance(from: fromCoord, to: toCoord)
            let distanceNauticalMiles = distanceKilometers / 1.852 // Convert kilometers to nautical miles
            
            // Calculate bearing in degrees
            let bearing = serviceProvider.routeCalculationService.calculateBearing(from: fromCoord, to: toCoord)
            
            // Update the current point with calculated values
            updatedRoutePoints[i].distanceToNext = distanceNauticalMiles
            updatedRoutePoints[i].bearingToNext = bearing
        }
        
        // Last waypoint has no "next" waypoint, so distance and bearing remain 0
        if !updatedRoutePoints.isEmpty {
            let lastIndex = updatedRoutePoints.count - 1
            updatedRoutePoints[lastIndex].distanceToNext = 0.0
            updatedRoutePoints[lastIndex].bearingToNext = 0.0
        }
        
        // Update the route with calculated points
        updatedGpxFile.route.routePoints = updatedRoutePoints
        return updatedGpxFile
    }
}

// MARK: - Supporting Views

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
                .frame(width: 16)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct SimpleWaypointRow: View {
    let waypoint: GpxRoutePoint
    let index: Int
    let isLast: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Waypoint header
            HStack {
                // Waypoint number
                Text("\(index)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.blue))
                
                // Waypoint name
                VStack(alignment: .leading, spacing: 2) {
                    Text(waypoint.name ?? "Waypoint \(index)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Coordinates
                    Text(formatCoordinates(waypoint.latitude, waypoint.longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Distance and course to next waypoint (if not last)
            if !isLast {
                HStack(spacing: 16) {
                    // Distance to next
                    HStack(spacing: 4) {
                        Image(systemName: "ruler")
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Distance")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.3f nm", waypoint.distanceToNext))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                    
                    // Course to next
                    HStack(spacing: 4) {
                        Image(systemName: "location.north")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Course")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%03.0f°", waypoint.bearingToNext))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.leading, 32) // Align with waypoint text
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func formatCoordinates(_ lat: Double, _ lon: Double) -> String {
        return String(format: "%.6f°, %.6f°", lat, lon)
    }
}

// MARK: - Preview

#Preview {
    let mockRoute = AllRoute(
        id: 1,
        name: "Boston Harbor Tour",
        gpxData: "<gpx></gpx>",
        waypointCount: 8,
        totalDistance: 25.5,
        sourceType: "public",
        isFavorite: true,
        tags: "Harbor, Scenic",
        notes: "Beautiful harbor route with historic landmarks"
    )
    
    SimpleRouteDetailsView(route: mockRoute)
        .environmentObject(ServiceProvider())
}