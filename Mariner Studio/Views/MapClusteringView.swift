import SwiftUI
import MapKit

struct MapClusteringView: View {
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.8050315413548, longitude: -122.413632917219),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @StateObject private var viewModel: MapClusteringViewModel
    @State private var showFilterOptions = false
    @State private var showNavUnits = true
    @State private var showTidalHeightStations = true
    @State private var showTidalCurrentStations = true
    
    // MARK: - Initialization
    init() {
        // Default initializer - uses ServiceProvider via EnvironmentObject
        _viewModel = StateObject(wrappedValue: MapClusteringViewModel(
            navUnitService: NavUnitDatabaseService(databaseCore: DatabaseCore()),
            tideStationService: TideStationDatabaseService(databaseCore: DatabaseCore()),
            currentStationService: CurrentStationDatabaseService(databaseCore: DatabaseCore()),
            tidalHeightService: TidalHeightServiceImpl(),
            tidalCurrentService: TidalCurrentServiceImpl(),
            locationService: LocationServiceImpl()
        ))
    }
    
    // MARK: - Convenience init that takes services for easier testing
    init(navUnitService: NavUnitDatabaseService,
         tideStationService: TideStationDatabaseService,
         currentStationService: CurrentStationDatabaseService,
         locationService: LocationService) {
        // Create the required service implementations
        let tidalHeightService = TidalHeightServiceImpl()
        let tidalCurrentService = TidalCurrentServiceImpl()
        
        _viewModel = StateObject(wrappedValue: MapClusteringViewModel(
            navUnitService: navUnitService,
            tideStationService: tideStationService,
            currentStationService: currentStationService,
            tidalHeightService: tidalHeightService,
            tidalCurrentService: tidalCurrentService,
            locationService: locationService
        ))
    }
    
    var body: some View {
        ZStack {
            // Map view
            TandmMapViewRepresentable(
                region: $mapRegion,
                annotations: filteredAnnotations(),
                viewModel: viewModel
            )
            .edgesIgnoringSafeArea(.all)
            
            // Loading indicator
            if isLoading() {
                VStack {
                    HStack {
                        ProgressView()
                            .scaleEffect(1.2)
                            .padding(.trailing, 5)
                        Text("Loading map data...")
                    }
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(10)
                    .shadow(radius: 4)
                    
                    Spacer()
                }
                .padding(.top)
            }
            
            // Floating filter button
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: {
                        showFilterOptions.toggle()
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationTitle("Maritime Map")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilterOptions) {
            filterOptionsView
        }
        .onAppear {
            // Initialize the map region from the view model if needed
            if let initialRegion = viewModel.currentRegion {
                mapRegion = initialRegion
            }
            
            // Load the data when view appears
            viewModel.loadData()
        }
    }
    
    // Filter options sheet view
    private var filterOptionsView: some View {
        VStack(spacing: 20) {
            Text("Filter Map Annotations")
                .font(.headline)
                .padding(.top)
            
            Toggle("Show Navigation Units", isOn: $showNavUnits)
                .padding(.horizontal)
            
            Toggle("Show Tidal Height Stations", isOn: $showTidalHeightStations)
                .padding(.horizontal)
            
            Toggle("Show Tidal Current Stations", isOn: $showTidalCurrentStations)
                .padding(.horizontal)
            
            Button("Close") {
                showFilterOptions = false
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    // Check if any data is still loading
    private func isLoading() -> Bool {
        return viewModel.isLoadingNavUnits ||
               viewModel.isLoadingTideStations ||
               viewModel.isLoadingCurrentStations
    }
    
    // Filter annotations based on user preferences
    private func filteredAnnotations() -> [NavObject] {
        return viewModel.navobjects.filter { annotation in
            switch annotation.type {
            case .navunit:
                return showNavUnits
            case .tidalheightstation:
                return showTidalHeightStations
            case .tidalcurrentstation:
                return showTidalCurrentStations
            }
        }
    }
}

// Add preview for SwiftUI Preview
#Preview {
    MapClusteringView()
        .environmentObject(ServiceProvider())
}
