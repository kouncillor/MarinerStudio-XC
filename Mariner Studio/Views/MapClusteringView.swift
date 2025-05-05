import SwiftUI
import MapKit

struct MapClusteringView: View {
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.8050315413548, longitude: -122.413632917219),
        span: MKCoordinateSpan(latitudeDelta: 0.00978871051851371, longitudeDelta: 0.008167393319212121)
    )
    
    @StateObject private var viewModel: MapClusteringViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    
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
            // Use the renamed view representable
            TandmMapViewRepresentable(region: $mapRegion, annotations: viewModel.navobjects)
                .edgesIgnoringSafeArea(.all)
            
            // Add loading indicator if needed
            if viewModel.isLoadingNavUnits || viewModel.isLoadingTideStations || viewModel.isLoadingCurrentStations {
                VStack {
                    HStack {
                        ProgressView()
                        Text("Loading data...")
                    }
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    
                    Spacer()
                }
                .padding(.top)
            }
        }
        .navigationTitle("Maritime Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load the cycle data and maritime data when view appears
            viewModel.loadData()
        }
    }
}

// Add preview for SwiftUI Preview
#Preview {
    MapClusteringView()
        .environmentObject(ServiceProvider())
}
