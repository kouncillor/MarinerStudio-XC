//
//  NavUnitDetailsView.swift
//  Mariner Studio
//
//  Navigation Unit Details View - Shows comprehensive information about a navigation unit
//  Completely rewritten to follow MainView pattern for proper spacing
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
            }
            
            // Add new chart overlay if provided
            if let overlay = newOverlay {
                mapView.addOverlay(overlay, level: .aboveLabels)
                currentChartOverlay = overlay
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // Handle NOAA Chart tile overlays
            if let chartOverlay = overlay as? NOAAChartTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: chartOverlay)
                renderer.alpha = 0.7
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
            return nil
        }
    }
}

struct NavUnitDetailsView: View {
    @StateObject private var viewModel: NavUnitDetailsViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    
    // State for sheet presentations
    @State private var showingRecommendationForm = false
    @State private var showingUserRecommendations = false
    @State private var showingPhotoGallery = false
    
    // Photo state
    @State private var photos: [NavUnitPhoto] = []
    @State private var thumbnailImages: [UUID: UIImage] = [:]
    @State private var isLoadingPhotos = false
    
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
                // Main content when nav unit is loaded - following MainView pattern exactly
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                        
                        // Header section with name and coordinates
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
                        
                        // Map section
                        if viewModel.hasCoordinates {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Location Map")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
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
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        
                        // Photos section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Photos")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                if !photos.isEmpty {
                                    Text("(\(photos.count))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if !photos.isEmpty {
                                    Button(action: { showingPhotoGallery = true }) {
                                        Text("View All")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            if isLoadingPhotos {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading photos...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 20)
                            } else if photos.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray)
                                    Text("No photos yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Button(action: { showingPhotoGallery = true }) {
                                        Text("Add Photo")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 16)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(photos.prefix(4).enumerated()), id: \.element.id) { index, photo in
                                            Button(action: { showingPhotoGallery = true }) {
                                                if let thumbnail = thumbnailImages[photo.id] {
                                                    Image(uiImage: thumbnail)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 80, height: 80)
                                                        .clipped()
                                                        .cornerRadius(8)
                                                } else {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color(.systemGray5))
                                                        .frame(width: 80, height: 80)
                                                        .overlay(
                                                            ProgressView()
                                                                .scaleEffect(0.7)
                                                        )
                                                }
                                            }
                                        }
                                        
                                        // Add photo button (if there are photos)
                                        if !photos.isEmpty {
                                            Button(action: { showingPhotoGallery = true }) {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(Color.blue, lineWidth: 2, antialiased: true)
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        VStack(spacing: 4) {
                                                            Image(systemName: "plus")
                                                                .font(.system(size: 24))
                                                                .foregroundColor(.blue)
                                                            Text("Add")
                                                                .font(.caption2)
                                                                .foregroundColor(.blue)
                                                        }
                                                    )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        
                        // Action buttons section
                        HStack(spacing: 15) {
                            // Maps button
                            Button(action: { viewModel.openInMaps() }) {
                                Image("carsixseven")
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .opacity(viewModel.hasCoordinates ? 1.0 : 0.5)
                            }
                            .disabled(!viewModel.hasCoordinates)
                            
                            // Phone button
                            Button(action: { viewModel.makePhoneCall() }) {
                                Image("greenphonesixseven")
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .opacity(viewModel.hasPhoneNumbers ? 1.0 : 0.5)
                            }
                            .disabled(!viewModel.hasPhoneNumbers)
                            
                            // Favorite button
                            Button(action: {
                                Task {
                                    await viewModel.toggleFavorite()
                                }
                            }) {
                                Image(viewModel.favoriteIcon)
                                    .resizable()
                                    .frame(width: 44, height: 44)
                            }
                            
                            // Comments button
                            Button(action: { showingUserRecommendations = true }) {
                                Image("commentsixseven")
                                    .resizable()
                                    .frame(width: 44, height: 44)
                            }
                            
                            // Recommendation button
                            Button(action: { showingRecommendationForm = true }) {
                                Image(systemName: "lightbulb.fill")
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(.orange)
                            }
                            
                            // Share button
                            Button(action: { viewModel.shareUnit() }) {
                                Image("sharesixseven")
                                    .resizable()
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        // Location information section
                        if !(navUnit.streetAddress?.isEmpty ?? true) ||
                           !(navUnit.cityOrTown?.isEmpty ?? true) ||
                           !(navUnit.statePostalCode?.isEmpty ?? true) ||
                           !(navUnit.zipCode?.isEmpty ?? true) ||
                           !(navUnit.countyName?.isEmpty ?? true) {
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Location")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    if let streetAddress = navUnit.streetAddress, !streetAddress.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Address:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(streetAddress)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let city = navUnit.cityOrTown, !city.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("City:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(city)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let state = navUnit.statePostalCode, !state.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("State:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(state)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let zip = navUnit.zipCode, !zip.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("ZIP Code:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(zip)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let county = navUnit.countyName, !county.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("County:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(county)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        
                        // Facility information section
                        if !(navUnit.waterwayName?.isEmpty ?? true) ||
                           !(navUnit.portName?.isEmpty ?? true) ||
                           navUnit.mile != nil ||
                           !(navUnit.bank?.isEmpty ?? true) ||
                           !(navUnit.location?.isEmpty ?? true) {
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Facility Information")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    if let waterwayName = navUnit.waterwayName, !waterwayName.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Waterway:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(waterwayName)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let portName = navUnit.portName, !portName.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Port:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(portName)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let mile = navUnit.mile {
                                        HStack(alignment: .top) {
                                            Text("Mile:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(String(format: "%.1f", mile))
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let bank = navUnit.bank, !bank.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Bank:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(bank)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let location = navUnit.location, !location.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Location:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(location)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        
                        // Contact information section
                        if !(navUnit.operators?.isEmpty ?? true) ||
                           !(navUnit.owners?.isEmpty ?? true) {
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Contact Information")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    if let operators = navUnit.operators, !operators.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Operators:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(operators)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let owners = navUnit.owners, !owners.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Owners:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(owners)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        
                        // Technical specifications section
                        if !viewModel.depthRange.isEmpty ||
                           !viewModel.deckHeightRange.isEmpty ||
                           navUnit.berthingLargest != nil ||
                           navUnit.berthingTotal != nil ||
                           !(navUnit.verticalDatum?.isEmpty ?? true) {
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Technical Specifications")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    if !viewModel.depthRange.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Depth:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(viewModel.depthRange)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if !viewModel.deckHeightRange.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Deck Height:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(viewModel.deckHeightRange)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let berthingLargest = navUnit.berthingLargest {
                                        HStack(alignment: .top) {
                                            Text("Largest Berthing:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(String(format: "%.1f ft", berthingLargest))
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let berthingTotal = navUnit.berthingTotal {
                                        HStack(alignment: .top) {
                                            Text("Total Berthing:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(String(format: "%.1f ft", berthingTotal))
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let verticalDatum = navUnit.verticalDatum, !verticalDatum.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Vertical Datum:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(verticalDatum)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        
                        // Additional information section
                        if !(navUnit.purpose?.isEmpty ?? true) ||
                           !(navUnit.commodities?.isEmpty ?? true) ||
                           !(navUnit.construction?.isEmpty ?? true) ||
                           !(navUnit.mechanicalHandling?.isEmpty ?? true) ||
                           !(navUnit.remarks?.isEmpty ?? true) {
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Additional Information")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    if let purpose = navUnit.purpose, !purpose.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Purpose:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(purpose)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let commodities = navUnit.commodities, !commodities.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Commodities:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(commodities)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let construction = navUnit.construction, !construction.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Construction:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(construction)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let mechanicalHandling = navUnit.mechanicalHandling, !mechanicalHandling.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Mechanical Handling:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(mechanicalHandling)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    if let remarks = navUnit.remarks, !remarks.isEmpty {
                                        HStack(alignment: .top) {
                                            Text("Remarks:")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(remarks)
                                                .font(.subheadline)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding()
                }
                
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
                await loadPhotos()
            }
        }
        .sheet(isPresented: $showingUserRecommendations) {
            NavigationView {
                UserRecommendationsView()
                    .environmentObject(serviceProvider)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingUserRecommendations = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingRecommendationForm) {
            if let navUnit = viewModel.unit {
                RecommendationFormView(
                    viewModel: RecommendationFormViewModel(
                        navUnit: navUnit,
                        recommendationService: serviceProvider.recommendationService
                    ),
                    isPresented: $showingRecommendationForm
                )
            }
        }
        .sheet(isPresented: $showingPhotoGallery) {
            if let navUnit = viewModel.unit {
                NavUnitPhotoGalleryView(
                    navUnitId: navUnit.navUnitId,
                    photoService: serviceProvider.photoService
                )
            }
        }
    }
    
    // MARK: - Photo Loading Functions
    
    private func loadPhotos() async {
        guard let navUnit = viewModel.unit else { return }
        
        isLoadingPhotos = true
        
        do {
            // Get photos from PhotoService
            let loadedPhotos = try await serviceProvider.photoService.getPhotos(for: navUnit.navUnitId)
            
            await MainActor.run {
                photos = loadedPhotos
                isLoadingPhotos = false
            }
            
            // Load thumbnails for the first 4 photos
            for photo in loadedPhotos.prefix(4) {
                await loadThumbnail(for: photo)
            }
            
        } catch {
            await MainActor.run {
                photos = []
                isLoadingPhotos = false
            }
            print("Error loading photos: \(error)")
        }
    }
    
    private func loadThumbnail(for photo: NavUnitPhoto) async {
        // Skip if we already have this thumbnail loaded in memory
        if thumbnailImages[photo.id] != nil { 
            return 
        }
        
        do {
            // PhotoService.loadThumbnailImage should handle cache checking internally,
            // but we avoid redundant calls by checking our memory cache first
            let thumbnail = try await serviceProvider.photoService.loadThumbnailImage(photo)
            
            await MainActor.run {
                thumbnailImages[photo.id] = thumbnail
            }
        } catch {
            print("Error loading thumbnail for photo \(photo.id): \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        NavUnitDetailsView(
            viewModel: NavUnitDetailsViewModel(
                navUnit: NavUnit(
                    navUnitId: "PREVIEW001",
                    navUnitName: "Sample Marina",
                    facilityType: "Marina",
                    streetAddress: "123 Harbor Way",
                    cityOrTown: "Newport Beach",
                    statePostalCode: "CA",
                    zipCode: "92663",
                    countyName: "Orange County",
                    waterwayName: "Newport Bay",
                    portName: "Newport Harbor",
                    mile: 2.5,
                    bank: "Left Bank",
                    latitude: 33.6189,
                    longitude: -117.9298,
                    operators: "Harbor Marina LLC",
                    owners: "City of Newport Beach",
                    purpose: "Commercial Marina",
                    location: "Inner Harbor",
                    commodities: "Recreational Vessels, Fuel",
                    construction: "Concrete Docks",
                    mechanicalHandling: "Fuel Dock, Pump-out Station",
                    remarks: "Full-service marina with 24-hour security. Phone: 949-555-0123",
                    verticalDatum: "MLLW",
                    depthMin: 8.0,
                    depthMax: 15.0,
                    berthingLargest: 150.0,
                    berthingTotal: 2400.0,
                    deckHeightMin: 3.0,
                    deckHeightMax: 8.0,
                    isFavorite: false
                ),
                databaseService: NavUnitDatabaseService(databaseCore: DatabaseCore()),
                favoritesService: FavoritesServiceImpl(),
                noaaChartService: NOAAChartServiceImpl()
            )
        )
    }
    .environmentObject(ServiceProvider())
}