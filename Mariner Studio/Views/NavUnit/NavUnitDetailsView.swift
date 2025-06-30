
import SwiftUI
import MapKit
import CoreLocation

// MARK: - NavUnit Chart Map View (NEW)
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
    // Use ObservedObject instead of StateObject since we'll initialize it from outside
    @ObservedObject var viewModel: NavUnitDetailsViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    
    // State for photo picker and gallery
    @State private var showingPhotoPicker = false
    @State private var showingSyncSettings = false
    
    // State for recommendations
    @State private var showingRecommendationForm = false
    @State private var showingUserRecommendations = false
    
    // Simple initializer that takes a view model
    init(viewModel: NavUnitDetailsViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Error Message
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Unit Header Card
                headerCard
                
                // Map Frame with Chart Overlay
                mapView
                
                // Action Buttons
                actionButtons
                
                // Primary Location
                locationDetailsSection
                
                // Waterway Info
                if viewModel.hasWaterwayInfo {
                    waterwayInfoSection
                }
                
                // Facility Info
                facilityInfoSection
                
                // Transportation
                if viewModel.hasTransportationInfo {
                    transportationInfoSection
                }
                
                // Specifications
                specificationsSection
                
                // Additional Info
                if viewModel.hasAdditionalInfo {
                    additionalInfoSection
                }
                
                // Service Info
                serviceInfoSection
            }
            .padding()
        }
        .navigationBarTitle("Navigation Unit Details", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: MainView(shouldClearNavigation: true)) {
                    Image(systemName: "house.fill")
                        .foregroundColor(.blue)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    // Provide haptic feedback
                    let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
                    impactGenerator.prepare()
                    impactGenerator.impactOccurred()
                })
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
     
        
    }
    
    // MARK: - View Components
    
    private var headerCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            
            VStack(spacing: 10) {
                Text(viewModel.unit?.navUnitName ?? "")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Divider()
                
                Text(viewModel.unit?.navUnitId ?? "")
                    .font(.body)
                    .foregroundColor(.gray)
                
                Text(viewModel.unit?.facilityType ?? "")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }

    private var mapView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            
            if viewModel.hasCoordinates,
               let mapRegion = viewModel.mapRegion,
               let mapAnnotation = viewModel.mapAnnotation {
                // NEW: Use custom map view with chart overlay support
                NavUnitChartMapView(
                    mapRegion: mapRegion,
                    annotation: mapAnnotation,
                    chartOverlay: viewModel.chartOverlay
                )
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()
            } else {
                ZStack {
                    Color(UIColor.systemGray6)
                        .cornerRadius(10)
                    
                    Text("No location coordinates available")
                        .foregroundColor(.gray)
                }
                .frame(height: 300)
                .padding()
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 15) {
            actionButton(
                icon: "carsixseven",
                action: { viewModel.openInMaps() },
                isEnabled: viewModel.hasCoordinates
            )
            
            actionButton(
                icon: "greenphonesixseven",
                action: { viewModel.makePhoneCall() },
                isEnabled: viewModel.hasPhoneNumbers
            )
            
            actionButton(
                icon: viewModel.favoriteIcon,
                action: {
                    Task {
                        await viewModel.toggleFavorite()
                    }
                },
                isEnabled: true
            )
            
            actionButton(
                icon: "commentsixseven",
                action: { showingUserRecommendations = true },
                isEnabled: true
            )
            
            // NEW: Suggest Update button
            actionButton(
                icon: "lightbulb.fill",
                action: { showingRecommendationForm = true },
                isEnabled: true
            )
            
            actionButton(
                icon: "sharesixseven",
                action: { viewModel.shareUnit() },
                isEnabled: true
            )
        }
        .padding(.horizontal)
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
    }
    
    private func actionButton(icon: String, action: @escaping () -> Void, isEnabled: Bool) -> some View {
        Button(action: action) {
            if icon == "lightbulb.fill" {
                // Use system icon for the new suggestion button
                Image(systemName: icon)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundColor(isEnabled ? .orange : .gray.opacity(0.5))
            } else {
                // Use custom icons for existing buttons
                Image(icon)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .opacity(isEnabled ? 1.0 : 0.5)
            }
        }
        .disabled(!isEnabled)
    }
     
    

    
    
    // MARK: - Detail Sections
    
    private var locationDetailsSection: some View {
        detailSection(title: "Location Details") {
            detailRow(label: "Address:", value: viewModel.unit?.streetAddress)
            detailRow(label: "City:", value: viewModel.unit?.cityOrTown)
            detailRow(label: "State:", value: viewModel.unit?.statePostalCode)
            detailRow(label: "ZIP:", value: viewModel.unit?.zipCode)
            detailRow(label: "Location:", value: viewModel.unit?.location)
            detailRow(label: "Description:", value: viewModel.unit?.locationDescription)
        }
    }
    
    private var waterwayInfoSection: some View {
        detailSection(title: "Waterway Information") {
            detailRow(label: "Waterway:", value: viewModel.unit?.waterwayName)
            detailRow(label: "Port:", value: viewModel.unit?.portName)
            
            if let mile = viewModel.unit?.mile {
                detailRow(label: "Mile Marker:", value: String(mile))
            }
            
            detailRow(label: "Bank:", value: viewModel.unit?.bank)
            detailRow(label: "Coordinates:", value: viewModel.formattedCoordinates)
        }
    }
    
    private var facilityInfoSection: some View {
        detailSection(title: "Facility Information") {
            detailRow(label: "Operators:", value: viewModel.unit?.operators)
            detailRow(label: "Owners:", value: viewModel.unit?.owners)
            detailRow(label: "Purpose:", value: viewModel.unit?.purpose)
        }
    }
    
    private var transportationInfoSection: some View {
        detailSection(title: "Transportation") {
            detailRow(label: "Highway:", value: viewModel.unit?.highwayNote)
            detailRow(label: "Railway:", value: viewModel.unit?.railwayNote)
        }
    }
    
    private var specificationsSection: some View {
        detailSection(title: "Specifications") {
            detailRow(label: "Depth Range:", value: viewModel.depthRange)
            detailRow(label: "Deck Height:", value: viewModel.deckHeightRange)
            
            let berthingText = "Largest: \(viewModel.unit?.berthingLargest?.description ?? "N/A"), Total: \(viewModel.unit?.berthingTotal?.description ?? "N/A")"
            detailRow(label: "Berthing:", value: berthingText)
            
            detailRow(label: "Vertical Datum:", value: viewModel.unit?.verticalDatum)
            detailRow(label: "Dock:", value: viewModel.unit?.dock)
        }
    }
    
    private var additionalInfoSection: some View {
        detailSection(title: "Additional Information") {
            detailRow(label: "Construction:", value: viewModel.unit?.construction)
            detailRow(label: "Mechanical:", value: viewModel.unit?.mechanicalHandling)
            detailRow(label: "Commodities:", value: viewModel.unit?.commodities)
            detailRow(label: "Remarks:", value: viewModel.unit?.remarks)
        }
    }
    
    private var serviceInfoSection: some View {
        detailSection(title: "Service Information") {
            detailRow(label: "Initiated:", value: viewModel.unit?.serviceInitiationDate)
            detailRow(label: "Terminated:", value: viewModel.unit?.serviceTerminationDate)
        }
    }
    
    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .padding(.bottom, 5)
            
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
    }
    
    private func detailRow(label: String, value: String?) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.body)
                .fontWeight(.bold)
                .frame(width: 120, alignment: .leading)
            
            Text(value ?? "Not specified")
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }
}
