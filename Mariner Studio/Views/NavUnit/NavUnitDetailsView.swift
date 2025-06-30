
//
//  NavUnitDetailsView.swift
//  Mariner Studio
//
//  Navigation Unit Details View - Shows comprehensive information about a navigation unit
//  Updated to support both direct model injection and async loading by ID
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - NavUnit Chart Map View
struct NavUnitChartMapView: UIViewRepresentable {
    let mapRegion: MapRegion
    let annotation: NavUnitMapAnnotation
    let chartOverlay: NOAAChartTileOverlay?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Set the region
        let region = MKCoordinateRegion(
            center: mapRegion.center,
            span: mapRegion.span
        )
        mapView.setRegion(region, animated: false)
        
        // Add the navigation unit annotation
        let mapAnnotation = MKPointAnnotation()
        mapAnnotation.coordinate = annotation.coordinate
        mapAnnotation.title = annotation.title
        mapAnnotation.subtitle = annotation.subtitle
        mapView.addAnnotation(mapAnnotation)
        
        // Add chart overlay if available
        if let overlay = chartOverlay {
            mapView.addOverlay(overlay, level: .aboveLabels)
            print("🗺️ NavUnitChartMapView: Added chart overlay with \(overlay.currentChartLayerCount) layers")
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if needed
        let region = MKCoordinateRegion(
            center: mapRegion.center,
            span: mapRegion.span
        )
        
        if mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
        
        // Handle chart overlay updates
        context.coordinator.updateChartOverlay(in: mapView, newOverlay: chartOverlay)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        private var currentChartOverlay: NOAAChartTileOverlay?
        
        func updateChartOverlay(in mapView: MKMapView, newOverlay: NOAAChartTileOverlay?) {
            // Remove existing chart overlay if it exists
            if let existingOverlay = currentChartOverlay {
                mapView.removeOverlay(existingOverlay)
                currentChartOverlay = nil
                print("🗺️ NavUnitChartMapView: Removed existing chart overlay")
            }
            
            // Add new chart overlay if provided
            if let overlay = newOverlay {
                mapView.addOverlay(overlay, level: .aboveLabels)
                currentChartOverlay = overlay
                print("🗺️ NavUnitChartMapView: Added new chart overlay with \(overlay.currentChartLayerCount) layers")
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // Handle NOAA Chart tile overlays
            if let chartOverlay = overlay as? NOAAChartTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: chartOverlay)
                renderer.alpha = 0.7 // Slightly transparent to keep annotations visible
                print("🎨 NavUnitChartMapView: Created chart overlay renderer with alpha 0.7")
                return renderer
            }
            
            // Handle generic tile overlays
            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 0.7
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Use default annotation view for the navigation unit pin
            return nil
        }
    }
}

struct NavUnitDetailsView: View {
    @StateObject private var viewModel: NavUnitDetailsViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    
    // MARK: - Initializers
    
    // New initializer: Load nav unit by ID (for navigation from list)
    init(navUnitId: String, serviceProvider: ServiceProvider) {
        _viewModel = StateObject(wrappedValue: NavUnitDetailsViewModel(
            navUnitId: navUnitId,
            databaseService: serviceProvider.navUnitService,
            favoritesService: serviceProvider.favoritesService,
            noaaChartService: serviceProvider.noaaChartService
        ))
    }
    
    // Existing initializer: Direct model injection (for other use cases)
    init(viewModel: NavUnitDetailsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if viewModel.isLoadingNavUnit {
                // Loading state for async nav unit fetch
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(1.2)
                    
                    Text("Loading Navigation Unit...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                
            } else if !viewModel.navUnitLoadError.isEmpty {
                // Error state for nav unit loading
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Unable to Load Navigation Unit")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(viewModel.navUnitLoadError)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        Task {
                            await viewModel.retryLoadNavUnit()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                
            } else if let navUnit = viewModel.unit {
                // Main content when nav unit is loaded
                mainContentView(for: navUnit)
                
            } else {
                // Fallback empty state
                VStack {
                    Text("No navigation unit data available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle(viewModel.unit?.navUnitName ?? "Navigation Unit")
        .navigationBarTitleDisplayMode(.inline)
        .withHomeButton()
        .onAppear {
            Task {
                await viewModel.loadNavUnitIfNeeded()
            }
        }
    }
    
    // MARK: - Main Content View
    
    @ViewBuilder
    private func mainContentView(for navUnit: NavUnit) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header section with name and coordinates
                headerSection(for: navUnit)
                
                
                // Map section
                if viewModel.hasCoordinates {
                    mapSection()
                }
                
                
                
                
                // Location information
                if hasLocationInfo(for: navUnit) {
                    locationSection(for: navUnit)
                }
                
                // Facility details
                if hasFacilityInfo(for: navUnit) {
                    facilitySection(for: navUnit)
                }
                
                // Contact information
                if hasContactInfo(for: navUnit) {
                    contactSection(for: navUnit)
                }
                
                // Technical specifications
                if hasTechnicalInfo(for: navUnit) {
                    technicalSection(for: navUnit)
                }
                
                // Additional information
                if hasAdditionalInfo(for: navUnit) {
                    additionalSection(for: navUnit)
                }
                
              
            }
            .padding()
        }
    }
    
    // MARK: - Section Views
    
    @ViewBuilder
    private func headerSection(for navUnit: NavUnit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(navUnit.navUnitName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Favorite button
                Button(action: {
                    Task {
                        await viewModel.toggleFavorite()
                    }
                }) {
                    Image(viewModel.favoriteIcon)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
            }
            
            if !viewModel.formattedCoordinates.isEmpty {
                Text(viewModel.formattedCoordinates)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let facilityType = navUnit.facilityType, !facilityType.isEmpty {
                Text(facilityType)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func locationSection(for navUnit: NavUnit) -> some View {
        SectionCard(title: "Location") {
            VStack(alignment: .leading, spacing: 8) {
                if let streetAddress = navUnit.streetAddress, !streetAddress.isEmpty {
                    InfoRow(label: "Address", value: streetAddress)
                }
                
                if let city = navUnit.cityOrTown, !city.isEmpty {
                    InfoRow(label: "City", value: city)
                }
                
                if let state = navUnit.statePostalCode, !state.isEmpty {
                    InfoRow(label: "State", value: state)
                }
                
                if let zip = navUnit.zipCode, !zip.isEmpty {
                    InfoRow(label: "ZIP Code", value: zip)
                }
                
                if let county = navUnit.countyName, !county.isEmpty {
                    InfoRow(label: "County", value: county)
                }
            }
        }
    }
    
    @ViewBuilder
    private func facilitySection(for navUnit: NavUnit) -> some View {
        SectionCard(title: "Facility Information") {
            VStack(alignment: .leading, spacing: 8) {
                if let waterwayName = navUnit.waterwayName, !waterwayName.isEmpty {
                    InfoRow(label: "Waterway", value: waterwayName)
                }
                
                if let portName = navUnit.portName, !portName.isEmpty {
                    InfoRow(label: "Port", value: portName)
                }
                
                if let mile = navUnit.mile {
                    InfoRow(label: "Mile", value: String(format: "%.1f", mile))
                }
                
                if let bank = navUnit.bank, !bank.isEmpty {
                    InfoRow(label: "Bank", value: bank)
                }
                
                if let location = navUnit.location, !location.isEmpty {
                    InfoRow(label: "Location", value: location)
                }
            }
        }
    }
    
    @ViewBuilder
    private func contactSection(for navUnit: NavUnit) -> some View {
        SectionCard(title: "Contact Information") {
            VStack(alignment: .leading, spacing: 8) {
                if let operators = navUnit.operators, !operators.isEmpty {
                    InfoRow(label: "Operators", value: operators)
                }
                
                if let owners = navUnit.owners, !owners.isEmpty {
                    InfoRow(label: "Owners", value: owners)
                }
            }
        }
    }
    
    @ViewBuilder
    private func technicalSection(for navUnit: NavUnit) -> some View {
        SectionCard(title: "Technical Specifications") {
            VStack(alignment: .leading, spacing: 8) {
                if !viewModel.depthRange.isEmpty {
                    InfoRow(label: "Depth", value: viewModel.depthRange)
                }
                
                if !viewModel.deckHeightRange.isEmpty {
                    InfoRow(label: "Deck Height", value: viewModel.deckHeightRange)
                }
                
                if let berthingLargest = navUnit.berthingLargest {
                    InfoRow(label: "Largest Berthing", value: String(format: "%.1f ft", berthingLargest))
                }
                
                if let berthingTotal = navUnit.berthingTotal {
                    InfoRow(label: "Total Berthing", value: String(format: "%.1f ft", berthingTotal))
                }
                
                if let verticalDatum = navUnit.verticalDatum, !verticalDatum.isEmpty {
                    InfoRow(label: "Vertical Datum", value: verticalDatum)
                }
            }
        }
    }
    
    @ViewBuilder
    private func additionalSection(for navUnit: NavUnit) -> some View {
        SectionCard(title: "Additional Information") {
            VStack(alignment: .leading, spacing: 8) {
                if let purpose = navUnit.purpose, !purpose.isEmpty {
                    InfoRow(label: "Purpose", value: purpose)
                }
                
                if let commodities = navUnit.commodities, !commodities.isEmpty {
                    InfoRow(label: "Commodities", value: commodities)
                }
                
                if let construction = navUnit.construction, !construction.isEmpty {
                    InfoRow(label: "Construction", value: construction)
                }
                
                if let mechanicalHandling = navUnit.mechanicalHandling, !mechanicalHandling.isEmpty {
                    InfoRow(label: "Mechanical Handling", value: mechanicalHandling)
                }
                
                if let remarks = navUnit.remarks, !remarks.isEmpty {
                    InfoRow(label: "Remarks", value: remarks)
                }
            }
        }
    }
    
    @ViewBuilder
    private func mapSection() -> some View {
        SectionCard(title: "Location Map") {
            if let mapRegion = viewModel.mapRegion,
               let annotation = viewModel.mapAnnotation {
                NavUnitChartMapView(
                    mapRegion: mapRegion,
                    annotation: annotation,
                    chartOverlay: viewModel.chartOverlay
                )
                .frame(height: 300)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 200)
                    .overlay(
                        Text("Location coordinates not available")
                            .foregroundColor(.secondary)
                            .frame(height: 100)
                    )
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func hasLocationInfo(for navUnit: NavUnit) -> Bool {
        return !(navUnit.streetAddress?.isEmpty ?? true) ||
               !(navUnit.cityOrTown?.isEmpty ?? true) ||
               !(navUnit.statePostalCode?.isEmpty ?? true) ||
               !(navUnit.zipCode?.isEmpty ?? true) ||
               !(navUnit.countyName?.isEmpty ?? true)
    }
    
    private func hasFacilityInfo(for navUnit: NavUnit) -> Bool {
        return !(navUnit.waterwayName?.isEmpty ?? true) ||
               !(navUnit.portName?.isEmpty ?? true) ||
               navUnit.mile != nil ||
               !(navUnit.bank?.isEmpty ?? true) ||
               !(navUnit.location?.isEmpty ?? true)
    }
    
    private func hasContactInfo(for navUnit: NavUnit) -> Bool {
        return !(navUnit.operators?.isEmpty ?? true) ||
               !(navUnit.owners?.isEmpty ?? true)
    }
    
    private func hasTechnicalInfo(for navUnit: NavUnit) -> Bool {
        return !viewModel.depthRange.isEmpty ||
               !viewModel.deckHeightRange.isEmpty ||
               navUnit.berthingLargest != nil ||
               navUnit.berthingTotal != nil ||
               !(navUnit.verticalDatum?.isEmpty ?? true)
    }
    
    private func hasAdditionalInfo(for navUnit: NavUnit) -> Bool {
        return !(navUnit.purpose?.isEmpty ?? true) ||
               !(navUnit.commodities?.isEmpty ?? true) ||
               !(navUnit.construction?.isEmpty ?? true) ||
               !(navUnit.mechanicalHandling?.isEmpty ?? true) ||
               !(navUnit.remarks?.isEmpty ?? true)
    }
}

// MARK: - Helper Views

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
