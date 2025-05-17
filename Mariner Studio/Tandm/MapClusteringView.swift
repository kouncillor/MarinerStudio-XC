//
//import SwiftUI
//import MapKit
//
//// Proxy to access the MapView from the overlay button
//class TandmMapViewProxy {
//    static let shared = TandmMapViewProxy()
//    weak var mapView: MKMapView?
//    weak var coordinator: TandmMapViewRepresentable.Coordinator?
//}
//
//struct MapClusteringView: View {
//    @State private var mapRegion = MKCoordinateRegion(
//        center: CLLocationCoordinate2D(latitude: 37.8050315413548, longitude: -122.413632917219),
//        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//    )
//    
//    @StateObject private var viewModel: MapClusteringViewModel
//    @State private var showFilterOptions = false
//    @State private var showNavUnits = true
//    @State private var showTidalHeightStations = true
//    @State private var showTidalCurrentStations = true
//    
//    // NavUnit navigation state
//    @State private var selectedNavUnitId: String? = nil
//    @State private var showNavUnitDetails = false
//    
//    // Tidal height station navigation state
//    @State private var selectedTidalHeightStationId: String? = nil
//    @State private var selectedTidalHeightStationName: String? = nil
//    @State private var showTidalHeightDetails = false
//    
//    // Tidal current station navigation state
//    @State private var selectedTidalCurrentStationId: String? = nil
//    @State private var selectedTidalCurrentStationBin: Int? = nil
//    @State private var selectedTidalCurrentStationName: String? = nil
//    @State private var showTidalCurrentDetails = false
//    
//    @EnvironmentObject var serviceProvider: ServiceProvider
//    
//    // MARK: - Initialization
//    init() {
//        // Default initializer - uses ServiceProvider via EnvironmentObject
//        _viewModel = StateObject(wrappedValue: MapClusteringViewModel(
//            navUnitService: NavUnitDatabaseService(databaseCore: DatabaseCore()),
//            tideStationService: TideStationDatabaseService(databaseCore: DatabaseCore()),
//            currentStationService: CurrentStationDatabaseService(databaseCore: DatabaseCore()),
//            tidalHeightService: TidalHeightServiceImpl(),
//            tidalCurrentService: TidalCurrentServiceImpl(),
//            locationService: LocationServiceImpl()
//        ))
//    }
//    
//    // MARK: - Convenience init that takes services for easier testing
//    init(navUnitService: NavUnitDatabaseService,
//         tideStationService: TideStationDatabaseService,
//         currentStationService: CurrentStationDatabaseService,
//         locationService: LocationService) {
//        // Create the required service implementations
//        let tidalHeightService = TidalHeightServiceImpl()
//        let tidalCurrentService = TidalCurrentServiceImpl()
//        
//        _viewModel = StateObject(wrappedValue: MapClusteringViewModel(
//            navUnitService: navUnitService,
//            tideStationService: tideStationService,
//            currentStationService: currentStationService,
//            tidalHeightService: tidalHeightService,
//            tidalCurrentService: tidalCurrentService,
//            locationService: locationService
//        ))
//    }
//    
//    var body: some View {
//        ZStack {
//            // Use TandmMapViewRepresentable directly
//            TandmMapViewRepresentable(
//                region: $mapRegion,
//                annotations: filteredAnnotations(),
//                viewModel: viewModel,
//                onNavUnitSelected: { navUnitId in
//                    print("NavUnit selected: \(navUnitId)")
//                    resetAllNavigationState()
//                    selectedNavUnitId = navUnitId
//                    showNavUnitDetails = true
//                },
//                onTidalHeightStationSelected: { stationId, stationName in
//                    print("Tidal Height Station selected: \(stationId), \(stationName)")
//                    resetAllNavigationState()
//                    selectedTidalHeightStationId = stationId
//                    selectedTidalHeightStationName = stationName
//                    showTidalHeightDetails = true
//                },
//                onTidalCurrentStationSelected: { stationId, bin, stationName in
//                    print("Tidal Current Station selected: \(stationId), \(bin), \(stationName)")
//                    resetAllNavigationState()
//                    selectedTidalCurrentStationId = stationId
//                    selectedTidalCurrentStationBin = bin
//                    selectedTidalCurrentStationName = stationName
//                    showTidalCurrentDetails = true
//                }
//            )
//            .edgesIgnoringSafeArea(.all)
//            .onAppear {
//                // Register the proxy coordinator when the view appears
//                if let proxy = TandmMapViewProxy.shared.mapView?.delegate as? TandmMapViewRepresentable.Coordinator {
//                    TandmMapViewProxy.shared.coordinator = proxy
//                }
//                
//                // FORCE RESET all navigation state when the map view appears
//                print("MapClusteringView appeared - Resetting all navigation state")
//                resetAllNavigationState()
//            }
//            
//            // Loading indicator
//            if isLoading() {
//                VStack {
//                    HStack {
//                        ProgressView()
//                            .scaleEffect(1.2)
//                            .padding(.trailing, 5)
//                        Text("Loading map data...")
//                    }
//                    .padding()
//                    .background(Color.white.opacity(0.9))
//                    .cornerRadius(10)
//                    .shadow(radius: 4)
//                    
//                    Spacer()
//                }
//                .padding(.top)
//            }
//            
//            // Floating buttons - now with both location and filter buttons inline
//            VStack {
//                Spacer()
//                
//                HStack {
//                    Spacer()
//                    
//                    // Location button (moved from overlay)
//                    Button(action: {
//                        print("Location button tapped")
//                        if let mapView = TandmMapViewProxy.shared.mapView,
//                           let coordinator = TandmMapViewProxy.shared.coordinator {
//                            coordinator.centerMapOnUserLocation(mapView)
//                        } else {
//                            print("MapView or Coordinator not available")
//                        }
//                    }) {
//                        Image(systemName: "location.fill")
//                            .font(.system(size: 24))
//                            .foregroundColor(.white)
//                            .padding(12)
//                            .background(Color.orange)
//                            .clipShape(Circle())
//                            .shadow(radius: 4)
//                    }
//                    .padding(.trailing, 8) // Add spacing between buttons
//                    
//                    // Filter button (already exists)
//                    Button(action: {
//                        showFilterOptions.toggle()
//                    }) {
//                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
//                            .font(.system(size: 24))
//                            .foregroundColor(.white)
//                            .padding(12)
//                            .background(Color.blue)
//                            .clipShape(Circle())
//                            .shadow(radius: 4)
//                    }
//                }
//                .padding(.trailing, 16)
//                .padding(.bottom, 16)
//            }
//        }
//        .navigationTitle("Maritime Map")
//        .navigationBarTitleDisplayMode(.inline)
//        .sheet(isPresented: $showFilterOptions) {
//            filterOptionsView
//        }
//        .onAppear {
//            // First try to center on user's location immediately
//            if let userLocation = viewModel.locationService.currentLocation?.coordinate {
//                print("Centering map on initial user location: \(userLocation.latitude), \(userLocation.longitude)")
//                mapRegion = MKCoordinateRegion(
//                    center: userLocation,
//                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//                )
//            }
//            // Fall back to view model's region if no user location
//            else if let initialRegion = viewModel.currentRegion {
//                mapRegion = initialRegion
//            }
//            
//            // Load the data when view appears
//            viewModel.loadData()
//            
//            // Schedule a delayed attempt to center on user location (in case it wasn't available immediately)
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                if let userLocation = viewModel.locationService.currentLocation?.coordinate {
//                    print("Delayed centering on user location: \(userLocation.latitude), \(userLocation.longitude)")
//                    mapRegion = MKCoordinateRegion(
//                        center: userLocation,
//                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//                    )
//                }
//            }
//        }
//        .background(
//            Group {
//                // NavUnit navigation link
//                NavigationLink(
//                    isActive: $showNavUnitDetails,
//                    destination: {
//                        if let navUnitId = selectedNavUnitId,
//                           let navUnit = viewModel.findNavUnitById(navUnitId) {
//                            let detailsViewModel = NavUnitDetailsViewModel(
//                                navUnit: navUnit,
//                                databaseService: viewModel.navUnitService,
//                                photoService: serviceProvider.photoService,
//                                navUnitFtpService: serviceProvider.navUnitFtpService,
//                                imageCacheService: serviceProvider.imageCacheService,
//                                favoritesService: serviceProvider.favoritesService
//                            )
//                            NavUnitDetailsView(viewModel: detailsViewModel)
//                        } else {
//                            Text("Navigation Unit not found")
//                        }
//                    },
//                    label: { EmptyView() }
//                )
//                
//                // Tidal Height Station navigation link
//                NavigationLink(
//                    isActive: $showTidalHeightDetails,
//                    destination: {
//                        if let stationId = selectedTidalHeightStationId,
//                           let stationName = selectedTidalHeightStationName {
//                            TidalHeightPredictionView(
//                                stationId: stationId,
//                                stationName: stationName,
//                                tideStationService: serviceProvider.tideStationService
//                            )
//                        } else {
//                            Text("Tidal Height Station not found")
//                        }
//                    },
//                    label: { EmptyView() }
//                )
//                
//                // Tidal Current Station navigation link
//                NavigationLink(
//                    isActive: $showTidalCurrentDetails,
//                    destination: {
//                        if let stationId = selectedTidalCurrentStationId,
//                           let bin = selectedTidalCurrentStationBin,
//                           let stationName = selectedTidalCurrentStationName {
//                            TidalCurrentPredictionView(
//                                stationId: stationId,
//                                bin: bin,
//                                stationName: stationName,
//                                currentStationService: serviceProvider.currentStationService
//                            )
//                        } else {
//                            Text("Tidal Current Station not found")
//                        }
//                    },
//                    label: { EmptyView() }
//                )
//            }
//        )
//    }
//    
//    // Filter options sheet view
//    private var filterOptionsView: some View {
//        VStack(spacing: 20) {
//            Text("Filter Map Annotations")
//                .font(.headline)
//                .padding(.top)
//            
//            Toggle("Show Navigation Units", isOn: $showNavUnits)
//                .padding(.horizontal)
//            
//            Toggle("Show Tidal Height Stations", isOn: $showTidalHeightStations)
//                .padding(.horizontal)
//            
//            Toggle("Show Tidal Current Stations", isOn: $showTidalCurrentStations)
//                .padding(.horizontal)
//            
//            Button("Close") {
//                showFilterOptions = false
//            }
//            .padding()
//            .background(Color.blue)
//            .foregroundColor(.white)
//            .cornerRadius(8)
//            
//            Spacer()
//        }
//        .padding()
//    }
//    
//    // MARK: - Helper Methods
//    
//    // Check if any data is still loading
//    private func isLoading() -> Bool {
//        return viewModel.isLoadingNavUnits ||
//               viewModel.isLoadingTideStations ||
//               viewModel.isLoadingCurrentStations
//    }
//    
//    // Filter annotations based on user preferences
//    private func filteredAnnotations() -> [NavObject] {
//        return viewModel.navobjects.filter { annotation in
//            switch annotation.type {
//            case .navunit:
//                return showNavUnits
//            case .tidalheightstation:
//                return showTidalHeightStations
//            case .tidalcurrentstation:
//                return showTidalCurrentStations
//            }
//        }
//    }
//    
//    // Reset all navigation state variables
//    private func resetAllNavigationState() {
//        print("Resetting all navigation state")
//        
//        // Reset NavUnit state
//        selectedNavUnitId = nil
//        showNavUnitDetails = false
//        
//        // Reset Tidal Height Station state
//        selectedTidalHeightStationId = nil
//        selectedTidalHeightStationName = nil
//        showTidalHeightDetails = false
//        
//        // Reset Tidal Current Station state
//        selectedTidalCurrentStationId = nil
//        selectedTidalCurrentStationBin = nil
//        selectedTidalCurrentStationName = nil
//        showTidalCurrentDetails = false
//    }
//}
//
//
//
//
//


















import SwiftUI
import MapKit

// Proxy to access the MapView from the overlay button
class TandmMapViewProxy {
    static let shared = TandmMapViewProxy()
    weak var mapView: MKMapView?
    weak var coordinator: TandmMapViewRepresentable.Coordinator?
}

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
    @State private var showBuoyStations = true // Added state for buoy stations
    
    // NavUnit navigation state
    @State private var selectedNavUnitId: String? = nil
    @State private var showNavUnitDetails = false
    
    // Tidal height station navigation state
    @State private var selectedTidalHeightStationId: String? = nil
    @State private var selectedTidalHeightStationName: String? = nil
    @State private var showTidalHeightDetails = false
    
    // Tidal current station navigation state
    @State private var selectedTidalCurrentStationId: String? = nil
    @State private var selectedTidalCurrentStationBin: Int? = nil
    @State private var selectedTidalCurrentStationName: String? = nil
    @State private var showTidalCurrentDetails = false
    
    // Buoy station navigation state
    @State private var selectedBuoyStationId: String? = nil
    @State private var selectedBuoyStationName: String? = nil
    @State private var showBuoyStationDetails = false
    
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
            buoyService: BuoyServiceImpl(), // Added BuoyServiceImpl
            buoyDatabaseService: BuoyDatabaseService(databaseCore: DatabaseCore()), // Added BuoyDatabaseService
            locationService: LocationServiceImpl()
        ))
    }
    
    // MARK: - Convenience init that takes services for easier testing
    init(navUnitService: NavUnitDatabaseService,
         tideStationService: TideStationDatabaseService,
         currentStationService: CurrentStationDatabaseService,
         buoyDatabaseService: BuoyDatabaseService, // Added parameter
         locationService: LocationService) {
        // Create the required service implementations
        let tidalHeightService = TidalHeightServiceImpl()
        let tidalCurrentService = TidalCurrentServiceImpl()
        let buoyService = BuoyServiceImpl() // Added BuoyServiceImpl
        
        _viewModel = StateObject(wrappedValue: MapClusteringViewModel(
            navUnitService: navUnitService,
            tideStationService: tideStationService,
            currentStationService: currentStationService,
            tidalHeightService: tidalHeightService,
            tidalCurrentService: tidalCurrentService,
            buoyService: buoyService, // Added buoyService
            buoyDatabaseService: buoyDatabaseService, // Added buoyDatabaseService
            locationService: locationService
        ))
    }
    
    var body: some View {
        ZStack {
            // Use TandmMapViewRepresentable directly
            TandmMapViewRepresentable(
                region: $mapRegion,
                annotations: filteredAnnotations(),
                viewModel: viewModel,
                onNavUnitSelected: { navUnitId in
                    print("NavUnit selected: \(navUnitId)")
                    resetAllNavigationState()
                    selectedNavUnitId = navUnitId
                    showNavUnitDetails = true
                },
                onTidalHeightStationSelected: { stationId, stationName in
                    print("Tidal Height Station selected: \(stationId), \(stationName)")
                    resetAllNavigationState()
                    selectedTidalHeightStationId = stationId
                    selectedTidalHeightStationName = stationName
                    showTidalHeightDetails = true
                },
                onTidalCurrentStationSelected: { stationId, bin, stationName in
                    print("Tidal Current Station selected: \(stationId), \(bin), \(stationName)")
                    resetAllNavigationState()
                    selectedTidalCurrentStationId = stationId
                    selectedTidalCurrentStationBin = bin
                    selectedTidalCurrentStationName = stationName
                    showTidalCurrentDetails = true
                },
                onBuoyStationSelected: { stationId, stationName in
                    print("Buoy Station selected: \(stationId), \(stationName)")
                    resetAllNavigationState()
                    selectedBuoyStationId = stationId
                    selectedBuoyStationName = stationName
                    showBuoyStationDetails = true
                }
            )
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                // Register the proxy coordinator when the view appears
                if let proxy = TandmMapViewProxy.shared.mapView?.delegate as? TandmMapViewRepresentable.Coordinator {
                    TandmMapViewProxy.shared.coordinator = proxy
                }
                
                // FORCE RESET all navigation state when the map view appears
                print("MapClusteringView appeared - Resetting all navigation state")
                resetAllNavigationState()
            }
            
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
            
            // Floating buttons - now with both location and filter buttons inline
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Location button (moved from overlay)
                    Button(action: {
                        print("Location button tapped")
                        if let mapView = TandmMapViewProxy.shared.mapView,
                           let coordinator = TandmMapViewProxy.shared.coordinator {
                            coordinator.centerMapOnUserLocation(mapView)
                        } else {
                            print("MapView or Coordinator not available")
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 8) // Add spacing between buttons
                    
                    // Filter button (already exists)
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
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Maritime Map")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilterOptions) {
            filterOptionsView
        }
        .onAppear {
            // First try to center on user's location immediately
            if let userLocation = viewModel.locationService.currentLocation?.coordinate {
                print("Centering map on initial user location: \(userLocation.latitude), \(userLocation.longitude)")
                mapRegion = MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
            // Fall back to view model's region if no user location
            else if let initialRegion = viewModel.currentRegion {
                mapRegion = initialRegion
            }
            
            // Load the data when view appears
            viewModel.loadData()
            
            // Schedule a delayed attempt to center on user location (in case it wasn't available immediately)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let userLocation = viewModel.locationService.currentLocation?.coordinate {
                    print("Delayed centering on user location: \(userLocation.latitude), \(userLocation.longitude)")
                    mapRegion = MKCoordinateRegion(
                        center: userLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                }
            }
        }
        .background(
            Group {
                // NavUnit navigation link
                NavigationLink(
                    isActive: $showNavUnitDetails,
                    destination: {
                        if let navUnitId = selectedNavUnitId,
                           let navUnit = viewModel.findNavUnitById(navUnitId) {
                            let detailsViewModel = NavUnitDetailsViewModel(
                                navUnit: navUnit,
                                databaseService: viewModel.navUnitService,
                                photoService: serviceProvider.photoService,
                                navUnitFtpService: serviceProvider.navUnitFtpService,
                                imageCacheService: serviceProvider.imageCacheService,
                                favoritesService: serviceProvider.favoritesService
                            )
                            NavUnitDetailsView(viewModel: detailsViewModel)
                        } else {
                            Text("Navigation Unit not found")
                        }
                    },
                    label: { EmptyView() }
                )
                
                // Tidal Height Station navigation link
                NavigationLink(
                    isActive: $showTidalHeightDetails,
                    destination: {
                        if let stationId = selectedTidalHeightStationId,
                           let stationName = selectedTidalHeightStationName {
                            TidalHeightPredictionView(
                                stationId: stationId,
                                stationName: stationName,
                                tideStationService: serviceProvider.tideStationService
                            )
                        } else {
                            Text("Tidal Height Station not found")
                        }
                    },
                    label: { EmptyView() }
                )
                
                // Tidal Current Station navigation link
                NavigationLink(
                    isActive: $showTidalCurrentDetails,
                    destination: {
                        if let stationId = selectedTidalCurrentStationId,
                           let bin = selectedTidalCurrentStationBin,
                           let stationName = selectedTidalCurrentStationName {
                            TidalCurrentPredictionView(
                                stationId: stationId,
                                bin: bin,
                                stationName: stationName,
                                currentStationService: serviceProvider.currentStationService
                            )
                        } else {
                            Text("Tidal Current Station not found")
                        }
                    },
                    label: { EmptyView() }
                )
                
                // Buoy Station navigation link
                NavigationLink(
                    isActive: $showBuoyStationDetails,
                    destination: {
                        if let stationId = selectedBuoyStationId,
                           let stationName = selectedBuoyStationName {
                            // Create a dummy buoy station with ID and name to pass to web view
                            let buoyStation = BuoyStation(
                                id: stationId,
                                name: stationName,
                                latitude: nil,
                                longitude: nil,
                                elevation: nil,
                                type: "",
                                meteorological: nil,
                                currents: nil,
                                waterQuality: nil,
                                dart: nil
                            )
                            BuoyStationWebView(
                                station: buoyStation,
                                buoyDatabaseService: serviceProvider.buoyDatabaseService
                            )
                        } else {
                            Text("Buoy Station not found")
                        }
                    },
                    label: { EmptyView() }
                )
            }
        )
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
            
            Toggle("Show Buoy Stations", isOn: $showBuoyStations) // Added toggle for buoy stations
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
               viewModel.isLoadingCurrentStations ||
               viewModel.isLoadingBuoyStations // Added buoy stations loading check
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
            case .buoystation:
                return showBuoyStations // Added case for buoy stations
            }
        }
    }
    
    // Reset all navigation state variables
    private func resetAllNavigationState() {
        print("Resetting all navigation state")
        
        // Reset NavUnit state
        selectedNavUnitId = nil
        showNavUnitDetails = false
        
        // Reset Tidal Height Station state
        selectedTidalHeightStationId = nil
        selectedTidalHeightStationName = nil
        showTidalHeightDetails = false
        
        // Reset Tidal Current Station state
        selectedTidalCurrentStationId = nil
        selectedTidalCurrentStationBin = nil
        selectedTidalCurrentStationName = nil
        showTidalCurrentDetails = false
        
        // Reset Buoy Station state
        selectedBuoyStationId = nil
        selectedBuoyStationName = nil
        showBuoyStationDetails = false
    }
}
