//
//
//import SwiftUI
//import MapKit
//
//// Proxy to access the MapView from the overlay button
//class TandmMapViewProxy {
//   static let shared = TandmMapViewProxy()
//   weak var mapView: MKMapView?
//   weak var coordinator: TandmMapViewRepresentable.Coordinator?
//}
//
//struct MapClusteringView: View {
//   // State for tracking if user location was attempted to be set
//   @State private var userLocationUsed = false
//   
//   // We'll still have a default region but will prefer not to use it
//   @State private var mapRegion = MKCoordinateRegion(
//       center: CLLocationCoordinate2D(latitude: 37.8050315413548, longitude: -122.413632917219),
//       span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//   )
//   
//   @StateObject private var viewModel: MapClusteringViewModel
//   @State private var showFilterOptions = false
//   @State private var showNavUnits = true
//   @State private var showTidalHeightStations = true
//   @State private var showTidalCurrentStations = true
//   @State private var showBuoyStations = true
//   
//   // NavUnit navigation state
//   @State private var selectedNavUnitId: String? = nil
//   @State private var showNavUnitDetails = false
//   
//   // Tidal height station navigation state
//   @State private var selectedTidalHeightStationId: String? = nil
//   @State private var selectedTidalHeightStationName: String? = nil
//   @State private var showTidalHeightDetails = false
//   
//   // Tidal current station navigation state
//   @State private var selectedTidalCurrentStationId: String? = nil
//   @State private var selectedTidalCurrentStationBin: Int? = nil
//   @State private var selectedTidalCurrentStationName: String? = nil
//   @State private var showTidalCurrentDetails = false
//   
//   // Buoy station navigation state
//   @State private var selectedBuoyStationId: String? = nil
//   @State private var selectedBuoyStationName: String? = nil
//   @State private var showBuoyStationDetails = false
//   
//   @EnvironmentObject var serviceProvider: ServiceProvider
//   
//   // MARK: - Initialization
//   init() {
//       // Default initializer - uses ServiceProvider via EnvironmentObject
//       _viewModel = StateObject(wrappedValue: MapClusteringViewModel(
//           navUnitService: NavUnitDatabaseService(databaseCore: DatabaseCore()),
//           tideStationService: TideStationDatabaseService(databaseCore: DatabaseCore()),
//           currentStationService: CurrentStationDatabaseService(databaseCore: DatabaseCore()),
//           tidalHeightService: TidalHeightServiceImpl(),
//           tidalCurrentService: TidalCurrentServiceImpl(),
//           buoyService: BuoyServiceImpl(),
//           buoyDatabaseService: BuoyDatabaseService(databaseCore: DatabaseCore()),
//           locationService: LocationServiceImpl()
//       ))
//   }
//   
//   // MARK: - Convenience init that takes services for easier testing
//   init(navUnitService: NavUnitDatabaseService,
//        tideStationService: TideStationDatabaseService,
//        currentStationService: CurrentStationDatabaseService,
//        buoyDatabaseService: BuoyDatabaseService,
//        locationService: LocationService) {
//       // Create the required service implementations
//       let tidalHeightService = TidalHeightServiceImpl()
//       let tidalCurrentService = TidalCurrentServiceImpl()
//       let buoyService = BuoyServiceImpl()
//       
//       _viewModel = StateObject(wrappedValue: MapClusteringViewModel(
//           navUnitService: navUnitService,
//           tideStationService: tideStationService,
//           currentStationService: currentStationService,
//           tidalHeightService: tidalHeightService,
//           tidalCurrentService: tidalCurrentService,
//           buoyService: buoyService,
//           buoyDatabaseService: buoyDatabaseService,
//           locationService: locationService
//       ))
//   }
//   
//   // Helper method to update the map region based on user location
//   private func updateMapToUserLocation() {
//       // Force location service to start updating
//       viewModel.locationService.startUpdatingLocation()
//       
//       if let userLocation = viewModel.locationService.currentLocation?.coordinate {
//           print("Setting map to user location: \(userLocation.latitude), \(userLocation.longitude)")
//           
//           // Update our state
//           userLocationUsed = true
//           
//           // Create a new region centered on the user location
//           let newRegion = MKCoordinateRegion(
//               center: userLocation,
//               span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//           )
//           
//           // Update the map region
//           mapRegion = newRegion
//           
//           // Also update the viewModel's current region
//           viewModel.updateMapRegion(newRegion)
//           
//           print("Map centered on user location")
//       } else {
//           print("User location not available yet, starting location updates")
//           // Explicitly force location updates to start - this is important
//           viewModel.locationService.startUpdatingLocation()
//       }
//   }
//   
//   var body: some View {
//       ZStack {
//           // Use TandmMapViewRepresentable directly
//           TandmMapViewRepresentable(
//               region: $mapRegion,
//               annotations: filteredAnnotations(),
//               viewModel: viewModel,
//               onNavUnitSelected: { navUnitId in
//                   print("NavUnit selected: \(navUnitId)")
//                   resetAllNavigationState()
//                   selectedNavUnitId = navUnitId
//                   showNavUnitDetails = true
//               },
//               onTidalHeightStationSelected: { stationId, stationName in
//                   print("Tidal Height Station selected: \(stationId), \(stationName)")
//                   resetAllNavigationState()
//                   selectedTidalHeightStationId = stationId
//                   selectedTidalHeightStationName = stationName
//                   showTidalHeightDetails = true
//               },
//               onTidalCurrentStationSelected: { stationId, bin, stationName in
//                   print("Tidal Current Station selected: \(stationId), \(bin), \(stationName)")
//                   resetAllNavigationState()
//                   selectedTidalCurrentStationId = stationId
//                   selectedTidalCurrentStationBin = bin
//                   selectedTidalCurrentStationName = stationName
//                   showTidalCurrentDetails = true
//               },
//               onBuoyStationSelected: { stationId, stationName in
//                   print("Buoy Station selected: \(stationId), \(stationName)")
//                   resetAllNavigationState()
//                   selectedBuoyStationId = stationId
//                   selectedBuoyStationName = stationName
//                   showBuoyStationDetails = true
//               }
//           )
//           .edgesIgnoringSafeArea(.all)
//           .onAppear {
//               // Register the proxy coordinator when the view appears
//               if let proxy = TandmMapViewProxy.shared.mapView?.delegate as? TandmMapViewRepresentable.Coordinator {
//                   TandmMapViewProxy.shared.coordinator = proxy
//               }
//               
//               // FORCE RESET all navigation state when the map view appears
//               print("MapClusteringView appeared - Resetting all navigation state")
//               resetAllNavigationState()
//               
//               // Ensure location service is active as soon as possible
//               viewModel.locationService.startUpdatingLocation()
//               
//               // First attempt immediately
//               updateMapToUserLocation()
//               
//               // Schedule multiple attempts with a more aggressive strategy
//               for (index, delaySeconds) in [0.3, 0.7, 1.5, 2.5, 4.0, 7.0].enumerated() {
//                   DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
//                       // Only try to update if we haven't successfully used user location yet
//                       if !userLocationUsed {
//                           print("Delayed attempt #\(index + 1) (\(delaySeconds)s) to get user location")
//                           
//                           // Explicitly force location service to update
//                           viewModel.locationService.startUpdatingLocation()
//                           
//                           // Try to get the location - this attempt might work after startUpdatingLocation
//                           if let userLocation = viewModel.locationService.currentLocation?.coordinate {
//                               print("User location found on attempt #\(index + 1): \(userLocation.latitude), \(userLocation.longitude)")
//                               
//                               userLocationUsed = true
//                               
//                               let newRegion = MKCoordinateRegion(
//                                   center: userLocation,
//                                   span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//                               )
//                               
//                               mapRegion = newRegion
//                               viewModel.updateMapRegion(newRegion)
//                               
//                               print("Map centered on user location")
//                           } else {
//                               // If we're on the last attempt and still no location, try to use the location button method
//                               if index == 5 {
//                                   print("Last attempt - trying location button approach")
//                                   if let mapView = TandmMapViewProxy.shared.mapView,
//                                      let coordinator = TandmMapViewProxy.shared.coordinator {
//                                       coordinator.centerMapOnUserLocation(mapView)
//                                   }
//                               } else {
//                                   print("User location still not available on attempt #\(index + 1)")
//                               }
//                           }
//                       }
//                   }
//               }
//               
//               // Load the data when view appears
//               viewModel.loadData()
//           }
//           
//           // Loading indicator
//           if isLoading() {
//               VStack {
//                   HStack {
//                       ProgressView()
//                           .scaleEffect(1.2)
//                           .padding(.trailing, 5)
//                       Text("Loading map data...")
//                   }
//                   .padding()
//                   .background(Color.white.opacity(0.9))
//                   .cornerRadius(10)
//                   .shadow(radius: 4)
//                   
//                   Spacer()
//               }
//               .padding(.top)
//           }
//           
//           // Floating buttons - now with both location and filter buttons inline
//           VStack {
//               Spacer()
//               
//               HStack {
//                   Spacer()
//                   
//                   // Location button (moved from overlay)
//                   Button(action: {
//                       print("Location button tapped")
//                       if let mapView = TandmMapViewProxy.shared.mapView,
//                          let coordinator = TandmMapViewProxy.shared.coordinator {
//                           coordinator.centerMapOnUserLocation(mapView)
//                       } else {
//                           print("MapView or Coordinator not available")
//                       }
//                   }) {
//                       Image(systemName: "location.fill")
//                           .font(.system(size: 24))
//                           .foregroundColor(.white)
//                           .padding(12)
//                           .background(Color.orange)
//                           .clipShape(Circle())
//                           .shadow(radius: 4)
//                   }
//                   .padding(.trailing, 8) // Add spacing between buttons
//                   
//                   // Filter button (already exists)
//                   Button(action: {
//                       showFilterOptions.toggle()
//                   }) {
//                       Image(systemName: "line.3.horizontal.decrease.circle.fill")
//                           .font(.system(size: 24))
//                           .foregroundColor(.white)
//                           .padding(12)
//                           .background(Color.blue)
//                           .clipShape(Circle())
//                           .shadow(radius: 4)
//                   }
//               }
//               .padding(.trailing, 16)
//               .padding(.bottom, 16)
//           }
//       }
//       .navigationTitle("Maritime Map")
//       .navigationBarTitleDisplayMode(.inline)
//       .sheet(isPresented: $showFilterOptions) {
//           filterOptionsView
//       }
//       .background(
//           Group {
//               // NavUnit navigation link
//               NavigationLink(
//                   isActive: $showNavUnitDetails,
//                   destination: {
//                       if let navUnitId = selectedNavUnitId,
//                          let navUnit = viewModel.findNavUnitById(navUnitId) {
//                           let detailsViewModel = NavUnitDetailsViewModel(
//                               navUnit: navUnit,
//                               databaseService: viewModel.navUnitService,
//                               photoService: serviceProvider.photoService,
//                               navUnitFtpService: serviceProvider.navUnitFtpService,
//                               imageCacheService: serviceProvider.imageCacheService,
//                               favoritesService: serviceProvider.favoritesService
//                           )
//                           NavUnitDetailsView(viewModel: detailsViewModel)
//                       } else {
//                           Text("Navigation Unit not found")
//                       }
//                   },
//                   label: { EmptyView() }
//               )
//               
//               // Tidal Height Station navigation link
//               NavigationLink(
//                   isActive: $showTidalHeightDetails,
//                   destination: {
//                       if let stationId = selectedTidalHeightStationId,
//                          let stationName = selectedTidalHeightStationName {
//                           TidalHeightPredictionView(
//                               stationId: stationId,
//                               stationName: stationName,
//                               tideStationService: serviceProvider.tideStationService
//                           )
//                       } else {
//                           Text("Tidal Height Station not found")
//                       }
//                   },
//                   label: { EmptyView() }
//               )
//               
//               // Tidal Current Station navigation link
//               NavigationLink(
//                   isActive: $showTidalCurrentDetails,
//                   destination: {
//                       if let stationId = selectedTidalCurrentStationId,
//                          let bin = selectedTidalCurrentStationBin,
//                          let stationName = selectedTidalCurrentStationName {
//                           TidalCurrentPredictionView(
//                               stationId: stationId,
//                               bin: bin,
//                               stationName: stationName,
//                               currentStationService: serviceProvider.currentStationService
//                           )
//                       } else {
//                           Text("Tidal Current Station not found")
//                       }
//                   },
//                   label: { EmptyView() }
//               )
//               
//               // Buoy Station navigation link
//               NavigationLink(
//                   isActive: $showBuoyStationDetails,
//                   destination: {
//                       if let stationId = selectedBuoyStationId,
//                          let stationName = selectedBuoyStationName {
//                           // Create a dummy buoy station with ID and name to pass to web view
//                           let buoyStation = BuoyStation(
//                               id: stationId,
//                               name: stationName,
//                               latitude: nil,
//                               longitude: nil,
//                               elevation: nil,
//                               type: "",
//                               meteorological: nil,
//                               currents: nil,
//                               waterQuality: nil,
//                               dart: nil
//                           )
//                           BuoyStationWebView(
//                               station: buoyStation,
//                               buoyDatabaseService: serviceProvider.buoyDatabaseService
//                           )
//                       } else {
//                           Text("Buoy Station not found")
//                       }
//                   },
//                   label: { EmptyView() }
//               )
//           }
//       )
//   }
//   
//   // Filter options sheet view
//   private var filterOptionsView: some View {
//       VStack(spacing: 20) {
//           Text("Filter Map Annotations")
//               .font(.headline)
//               .padding(.top)
//           
//           Toggle("Show Navigation Units", isOn: $showNavUnits)
//               .padding(.horizontal)
//           
//           Toggle("Show Tidal Height Stations", isOn: $showTidalHeightStations)
//               .padding(.horizontal)
//           
//           Toggle("Show Tidal Current Stations", isOn: $showTidalCurrentStations)
//               .padding(.horizontal)
//           
//           Toggle("Show Buoy Stations", isOn: $showBuoyStations)
//               .padding(.horizontal)
//           
//           Button("Close") {
//               showFilterOptions = false
//           }
//           .padding()
//           .background(Color.blue)
//           .foregroundColor(.white)
//           .cornerRadius(8)
//           
//           Spacer()
//       }
//       .padding()
//   }
//   
//   // MARK: - Helper Methods
//   
//   // Check if any data is still loading
//   private func isLoading() -> Bool {
//       return viewModel.isLoadingNavUnits ||
//              viewModel.isLoadingTideStations ||
//              viewModel.isLoadingCurrentStations ||
//              viewModel.isLoadingBuoyStations
//   }
//   
//   // Filter annotations based on user preferences
//   private func filteredAnnotations() -> [NavObject] {
//       return viewModel.navobjects.filter { annotation in
//           switch annotation.type {
//           case .navunit:
//               return showNavUnits
//           case .tidalheightstation:
//               return showTidalHeightStations
//           case .tidalcurrentstation:
//               return showTidalCurrentStations
//           case .buoystation:
//               return showBuoyStations
//           }
//       }
//   }
//   
//   // Reset all navigation state variables
//   private func resetAllNavigationState() {
//       print("Resetting all navigation state")
//       
//       // Reset NavUnit state
//       selectedNavUnitId = nil
//       showNavUnitDetails = false
//       
//       // Reset Tidal Height Station state
//       selectedTidalHeightStationId = nil
//       selectedTidalHeightStationName = nil
//       showTidalHeightDetails = false
//       
//       // Reset Tidal Current Station state
//       selectedTidalCurrentStationId = nil
//       selectedTidalCurrentStationBin = nil
//       selectedTidalCurrentStationName = nil
//       showTidalCurrentDetails = false
//       
//       // Reset Buoy Station state
//       selectedBuoyStationId = nil
//       selectedBuoyStationName = nil
//       showBuoyStationDetails = false
//   }
//}



































import SwiftUI
import MapKit

// Proxy to access the MapView from the overlay button
class TandmMapViewProxy {
   static let shared = TandmMapViewProxy()
   weak var mapView: MKMapView?
   weak var coordinator: TandmMapViewRepresentable.Coordinator?
}

struct MapClusteringView: View {
   // State for tracking if user location was attempted to be set
   @State private var userLocationUsed = false
   
   // We'll still have a default region but will prefer not to use it
   @State private var mapRegion = MKCoordinateRegion(
       center: CLLocationCoordinate2D(latitude: 37.8050315413548, longitude: -122.413632917219),
       span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
   )
   
   @StateObject private var viewModel: MapClusteringViewModel
   @State private var showFilterOptions = false
   @State private var showNavUnits = true
   @State private var showTidalHeightStations = true
   @State private var showTidalCurrentStations = true
   @State private var showBuoyStations = true
   
   // Chart overlay states
   @State private var showChartOptions = false
   
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
           buoyService: BuoyServiceImpl(),
           buoyDatabaseService: BuoyDatabaseService(databaseCore: DatabaseCore()),
           locationService: LocationServiceImpl(),
           noaaChartService: NOAAChartServiceImpl()
       ))
   }
   
   // MARK: - Convenience init that takes services for easier testing
   init(navUnitService: NavUnitDatabaseService,
        tideStationService: TideStationDatabaseService,
        currentStationService: CurrentStationDatabaseService,
        buoyDatabaseService: BuoyDatabaseService,
        locationService: LocationService,
        noaaChartService: NOAAChartService) {
       // Create the required service implementations
       let tidalHeightService = TidalHeightServiceImpl()
       let tidalCurrentService = TidalCurrentServiceImpl()
       let buoyService = BuoyServiceImpl()
       
       _viewModel = StateObject(wrappedValue: MapClusteringViewModel(
           navUnitService: navUnitService,
           tideStationService: tideStationService,
           currentStationService: currentStationService,
           tidalHeightService: tidalHeightService,
           tidalCurrentService: tidalCurrentService,
           buoyService: buoyService,
           buoyDatabaseService: buoyDatabaseService,
           locationService: locationService,
           noaaChartService: noaaChartService
       ))
   }
   
   // Helper method to update the map region based on user location
   private func updateMapToUserLocation() {
       // Force location service to start updating
       viewModel.locationService.startUpdatingLocation()
       
       if let userLocation = viewModel.locationService.currentLocation?.coordinate {
           print("Setting map to user location: \(userLocation.latitude), \(userLocation.longitude)")
           
           // Update our state
           userLocationUsed = true
           
           // Create a new region centered on the user location
           let newRegion = MKCoordinateRegion(
               center: userLocation,
               span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
           )
           
           // Update the map region
           mapRegion = newRegion
           
           // Also update the viewModel's current region
           viewModel.updateMapRegion(newRegion)
           
           print("Map centered on user location")
       } else {
           print("User location not available yet, starting location updates")
           // Explicitly force location updates to start - this is important
           viewModel.locationService.startUpdatingLocation()
       }
   }
   
   var body: some View {
       ZStack {
           // Use TandmMapViewRepresentable directly
           TandmMapViewRepresentable(
               region: $mapRegion,
               annotations: filteredAnnotations(),
               viewModel: viewModel,
               chartOverlay: viewModel.chartOverlay,
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
               
               // Ensure location service is active as soon as possible
               viewModel.locationService.startUpdatingLocation()
               
               // First attempt immediately
               updateMapToUserLocation()
               
               // Schedule multiple attempts with a more aggressive strategy
               for (index, delaySeconds) in [0.3, 0.7, 1.5, 2.5, 4.0, 7.0].enumerated() {
                   DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
                       // Only try to update if we haven't successfully used user location yet
                       if !userLocationUsed {
                           print("Delayed attempt #\(index + 1) (\(delaySeconds)s) to get user location")
                           
                           // Explicitly force location service to update
                           viewModel.locationService.startUpdatingLocation()
                           
                           // Try to get the location - this attempt might work after startUpdatingLocation
                           if let userLocation = viewModel.locationService.currentLocation?.coordinate {
                               print("User location found on attempt #\(index + 1): \(userLocation.latitude), \(userLocation.longitude)")
                               
                               userLocationUsed = true
                               
                               let newRegion = MKCoordinateRegion(
                                   center: userLocation,
                                   span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                               )
                               
                               mapRegion = newRegion
                               viewModel.updateMapRegion(newRegion)
                               
                               print("Map centered on user location")
                           } else {
                               // If we're on the last attempt and still no location, try to use the location button method
                               if index == 5 {
                                   print("Last attempt - trying location button approach")
                                   if let mapView = TandmMapViewProxy.shared.mapView,
                                      let coordinator = TandmMapViewProxy.shared.coordinator {
                                       coordinator.centerMapOnUserLocation(mapView)
                                   }
                               } else {
                                   print("User location still not available on attempt #\(index + 1)")
                               }
                           }
                       }
                   }
               }
               
               // Load the data when view appears
               viewModel.loadData()
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
           
           // Floating buttons - now with location, filter, and chart buttons
           VStack {
               Spacer()
               
               HStack {
                   Spacer()
                   
                   // Chart overlay button (new)
                   Button(action: {
                       showChartOptions.toggle()
                   }) {
//                       Image(systemName: viewModel.isChartOverlayVisible ? "map.fill" : "map")
//                           .font(.system(size: 24))
//                           .foregroundColor(.white)
//                           .padding(12)
//                           .background(viewModel.isChartOverlayVisible ? Color.blue : Color.gray)
//                           .clipShape(Circle())
//                           .shadow(radius: 4)
                       
                       
                       
                       Image("overlaysixseven")
                                                 .resizable()
                                                 .aspectRatio(contentMode: .fit)
                                                 .frame(width: 24, height: 24)
                                                 .foregroundColor(.white)
                                                 .padding(12)
                                                 .background(viewModel.isChartOverlayVisible ? Color.blue : Color.gray)
                                                 .clipShape(Circle())
                                                 .shadow(radius: 4)
                       
                       
                       
                       
                   }
                   .padding(.trailing, 8)
                   
                   // Location button
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
                   .padding(.trailing, 8)
                   
                   // Filter button
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
       .sheet(isPresented: $showChartOptions) {
           chartOptionsView
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
   
   // MARK: - Filter options sheet view
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
           
           Toggle("Show Buoy Stations", isOn: $showBuoyStations)
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
   
   // MARK: - Chart options sheet view
   private var chartOptionsView: some View {
       VStack(spacing: 20) {
           Text("NOAA Chart Overlay")
               .font(.headline)
               .padding(.top)
           
           // Chart visibility toggle
           Toggle("Show Chart Overlay", isOn: $viewModel.isChartOverlayVisible)
               .padding(.horizontal)
               .onChange(of: viewModel.isChartOverlayVisible) { _, newValue in
                   if newValue != viewModel.isChartOverlayVisible {
                       viewModel.toggleChartOverlay()
                   }
               }
           
           if viewModel.isChartOverlayVisible {
               Divider()
               
               // Chart type selection
               VStack(alignment: .leading, spacing: 10) {
                   Text("Chart Type")
                       .font(.subheadline)
                       .fontWeight(.semibold)
                       .padding(.horizontal)
                   
                   Picker("Chart Type", selection: $viewModel.selectedChartType) {
                       Text("Traditional").tag(NOAAChartType.traditional)
                       Text("ECDIS").tag(NOAAChartType.ecdis)
                   }
                   .pickerStyle(SegmentedPickerStyle())
                   .padding(.horizontal)
                   .onChange(of: viewModel.selectedChartType) { _, newType in
                       viewModel.changeChartType(newType)
                   }
               }
               
               Divider()
               
               // Layer count control
               VStack(alignment: .center, spacing: 15) {
                   Text("Chart Detail Level")
                       .font(.subheadline)
                       .fontWeight(.semibold)
                   
                   Text("Showing \(viewModel.currentChartLayerCount) of 15 layers")
                       .font(.caption)
                       .foregroundColor(.secondary)
                   
                   HStack(spacing: 20) {
                       // Decrease button
                       Button(action: {
                           viewModel.decreaseChartLayerCount()
                           // Haptic feedback
                           let impactGenerator = UIImpactFeedbackGenerator(style: .light)
                           impactGenerator.impactOccurred()
                       }) {
                           Image(systemName: "minus.circle.fill")
                               .font(.title2)
                               .foregroundColor(viewModel.canDecreaseLayerCount ? .red : .gray)
                       }
                       .disabled(!viewModel.canDecreaseLayerCount)
                       
                       // Current count display
                       Text("\(viewModel.currentChartLayerCount)")
                           .font(.title)
                           .fontWeight(.bold)
                           .frame(minWidth: 40)
                       
                       // Increase button
                       Button(action: {
                           viewModel.increaseChartLayerCount()
                           // Haptic feedback
                           let impactGenerator = UIImpactFeedbackGenerator(style: .light)
                           impactGenerator.impactOccurred()
                       }) {
                           Image(systemName: "plus.circle.fill")
                               .font(.title2)
                               .foregroundColor(viewModel.canIncreaseLayerCount ? .green : .gray)
                       }
                       .disabled(!viewModel.canIncreaseLayerCount)
                   }
               }
               .padding(.horizontal)
               
               Divider()
               
               // Information text
               Text("NOAA Official Charts\n\nDisplaying official NOAA Electronic Navigational Charts (ENCs) with official marine chart symbology.\n\nMore layers = more detail")
                   .font(.caption)
                   .foregroundColor(.secondary)
                   .multilineTextAlignment(.center)
                   .padding(.horizontal)
           }
           
           Button("Close") {
               showChartOptions = false
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
              viewModel.isLoadingBuoyStations
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
               return showBuoyStations
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
