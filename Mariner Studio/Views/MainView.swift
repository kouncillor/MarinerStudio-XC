////21,May,2025
//
//
//
//
//
//import SwiftUI
//import RevenueCat // Ensure RevenueCat is imported
//import RevenueCatUI
//
//struct MainView: View {
//    @EnvironmentObject var serviceProvider: ServiceProvider
//    @State private var showSettings = false
//    @State private var selectedRoute: GpxRoute? = nil
//    @State private var routeAverageSpeed: String = ""
//    @State private var navigateToGpxView = false
//    @State private var navigateToRouteDetails = false
//
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 12) {
//                    
//                    NavigationLink(destination: MapClusteringView()) {
//                        NavigationButtonContent(
//                            icon: "earthsixfour",
//                            title: "MAP"
//                        )
//                    }
//
//                    // WEATHER
//                    NavigationLink(destination: WeatherMenuView()) {
//                        NavigationButtonContent(
//                            icon: "weathersixseventwo",
//                            title: "WEATHER"
//                        )
//                    }
//
//                    // TIDES
//                    NavigationLink(destination: TideMenuView()) {
//                        NavigationButtonContent(
//                            icon: "tsixseven",
//                            title: "TIDES"
//                        )
//                    }
//                    
//                    // In MainView.swift, update the NavigationLink for CURRENTS:
//                    NavigationLink(destination: CurrentMenuView()) {
//                        NavigationButtonContent(
//                            icon: "csixseven",
//                            title: "CURRENTS"
//                        )
//                    }
//
//                    // NAV UNITS - Updated to use NavUnitMenuView instead of NavUnitsView
//                    NavigationLink(destination: NavUnitMenuView()) {
//                        NavigationButtonContent(
//                            icon: "nsixseven",
//                            title: "NAV UNITS"
//                        )
//                    }
//
//                    // BUOYS - Updated to use BuoyMenuView
//                    NavigationLink(destination: BuoyMenuView()) {
//                        NavigationButtonContent(
//                            icon: "buoysixseven",
//                            title: "BUOYS"
//                        )
//                    }
//
//                    
//                    //TUGS
//                    NavigationLink(destination: TugsView(
//                        vesselService: serviceProvider.vesselService
//                    )) {
//                        NavigationButtonContent(
//                            icon: "tugboatsixseven",
//                            title: "TUGS"
//                        )
//                    }
//
//                    NavigationLink(destination: BargesView(
//                        vesselService: serviceProvider.vesselService
//                    )) {
//                        NavigationButtonContent(
//                            icon: "bargesixseventwo",
//                            title: "BARGES"
//                        )
//                    }
//
//                    // Route Button - Updated with correct navigation
//                    Button(action: {
//                        navigateToGpxView = true
//                    }) {
//                        HStack {
//                            Image("tsixseven") // Assuming this is an intended placeholder or actual image
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 67, height: 67)
//                                .padding(.leading, 5)
//
//                            VStack(alignment: .leading) {
//                                Text("Route")
//                                    .font(.headline)
//                                Text("View Route from GPX File")
//                                    .font(.subheadline)
//                                    .foregroundColor(.gray)
//                            }
//                            .padding(.leading, 10)
//                            .frame(height: 67)
//                            .padding(.vertical, 10)
//
//                            Spacer()
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding(10)
//                        .background(
//                            RoundedRectangle(cornerRadius: 10)
//                                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
//                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
//                        )
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                    
//                    // Navigation links
//                    NavigationLink(destination: createGpxView(), isActive: $navigateToGpxView) {
//                        EmptyView()
//                    }
//                    
//                    NavigationLink(destination: createRouteDetailsView(), isActive: $navigateToRouteDetails) {
//                        EmptyView()
//                    }
//                }
//                .padding()
//            }
//            .navigationTitle("Mariner Studio")
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button(action: {
//                        // No action for now - dead button
//                    }) {
//                        Image(systemName: "line.3.horizontal")
//                    }
//                }
//            }
//            // Removed the sheet that was presenting WeatherSettingsView
//        }
//        // Apply the .presentPaywallIfNeeded modifier to the NavigationStack
//        // This will present the paywall if the "Pro" entitlement is not active
//        // when MainView appears.
//        .presentPaywallIfNeeded(
//            requiredEntitlementIdentifier: "Pro",
//            presentationMode: .fullScreen
//        )
//    }
//    
//    // Function to create the GpxView with necessary dependencies
//    private func createGpxView() -> some View {
//        let gpxService = GpxServiceImpl()
//        let routeCalculationService = RouteCalculationServiceImpl()
//        
//        let gpxViewModel = GpxViewModel(
//            gpxService: gpxService,
//            routeCalculationService: routeCalculationService,
//            navigationService: { parameters in
//                if let route = parameters["route"] as? GpxRoute,
//                   let averageSpeed = parameters["averageSpeed"] as? String {
//                    selectedRoute = route
//                    routeAverageSpeed = averageSpeed
//                    navigateToGpxView = false // Close the GpxView
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                        navigateToRouteDetails = true // Navigate to RouteDetailsView
//                    }
//                }
//            }
//        )
//        
//        return GpxView(viewModel: gpxViewModel)
//    }
//    
//    // Function to create the RouteDetailsView with the selected route
//    private func createRouteDetailsView() -> some View {
//        let routeDetailsViewModel = RouteDetailsViewModel(
//            weatherService: serviceProvider.openMeteoService,
//            routeCalculationService: RouteCalculationServiceImpl()
//        )
//        
//        if let route = selectedRoute {
//            routeDetailsViewModel.applyRouteData(route, averageSpeed: routeAverageSpeed)
//        }
//        
//        return RouteDetailsView(viewModel: routeDetailsViewModel)
//    }
//}
//
//// Your existing NavigationButton, NavigationButtonContent, and RouteButton structs remain the same:
//
//struct NavigationButton: View {
//    let icon: String
//    let title: String
//    let action: () -> Void
//
//    var body: some View {
//        Button(action: action) {
//            NavigationButtonContent(icon: icon, title: title)
//        }
//        .buttonStyle(PlainButtonStyle())
//    }
//}
//
//struct NavigationButtonContent: View {
//    let icon: String
//    let title: String
//
//    var body: some View {
//        HStack {
//            Image(icon)
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                .frame(width: 67, height: 67)
//                .padding(.leading, 5)
//
//            VStack(alignment: .leading) {
//                Text(title)
//                    .font(.largeTitle)
//            }
//            .padding(.leading, 20)
//            .frame(height: 67)
//            .padding(.vertical, 10)
//
//            Spacer()
//        }
//        .frame(maxWidth: .infinity)
//        .padding(10)
//        .background(
//            RoundedRectangle(cornerRadius: 10)
//                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
//                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
//        )
//    }
//}
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//










































//
////21,May,2025
//
//import SwiftUI
//import RevenueCat // Ensure RevenueCat is imported
//import RevenueCatUI
//
//struct MainView: View {
//    @EnvironmentObject var serviceProvider: ServiceProvider
//    // @State private var showSettings = false // This was unused
//    @State private var selectedRoute: GpxRoute? = nil
//    @State private var routeAverageSpeed: String = ""
//    @State private var navigateToGpxView = false
//    @State private var navigateToRouteDetails = false
//
//    // Define the grid layout: two columns
//    let columns: [GridItem] = [
//        GridItem(.flexible(), spacing: 12),
//        GridItem(.flexible(), spacing: 12)
//    ]
//
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                LazyVGrid(columns: columns, spacing: 12) {
//                    NavigationLink(destination: MapClusteringView()) {
//                        NavigationButtonContent(
//                            icon: "earthsixfour",
//                            title: "MAP"
//                        )
//                    }
//
//                    NavigationLink(destination: WeatherMenuView()) {
//                        NavigationButtonContent(
//                            icon: "weathersixseventwo",
//                            title: "WEATHER"
//                        )
//                    }
//
//                    NavigationLink(destination: TideMenuView()) {
//                        NavigationButtonContent(
//                            icon: "tsixseven",
//                            title: "TIDES"
//                        )
//                    }
//                    
//                    NavigationLink(destination: CurrentMenuView()) {
//                        NavigationButtonContent(
//                            icon: "csixseven",
//                            title: "CURRENTS"
//                        )
//                    }
//
//                    NavigationLink(destination: NavUnitMenuView()) {
//                        NavigationButtonContent(
//                            icon: "nsixseven",
//                            title: "NAV UNITS"
//                        )
//                    }
//
//                    NavigationLink(destination: BuoyMenuView()) {
//                        NavigationButtonContent(
//                            icon: "buoysixseven",
//                            title: "BUOYS"
//                        )
//                    }
//                    
//                    NavigationLink(destination: TugsView(
//                        vesselService: serviceProvider.vesselService
//                    )) {
//                        NavigationButtonContent(
//                            icon: "tugboatsixseven",
//                            title: "TUGS"
//                        )
//                    }
//
//                    NavigationLink(destination: BargesView(
//                        vesselService: serviceProvider.vesselService
//                    )) {
//                        NavigationButtonContent(
//                            icon: "bargesixseventwo",
//                            title: "BARGES"
//                        )
//                    }
//
//                    Button(action: {
//                        navigateToGpxView = true
//                    }) {
//                        HStack {
//                            Image("tsixseven")
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 67, height: 67)
//                                .padding(.leading, 5)
//
//                            VStack(alignment: .leading) {
//                                Text("Route")
//                                    .font(.headline)
//                                Text("View Route from GPX File")
//                                    .font(.subheadline)
//                                    .foregroundColor(.gray)
//                            }
//                            .padding(.leading, 10)
//                            .frame(height: 67)
//                            .padding(.vertical, 10)
//
//                            Spacer()
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding(10)
//                        .background(
//                            RoundedRectangle(cornerRadius: 10)
//                                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
//                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
//                        )
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                }
//                .padding()
//            }
//            // Apply the hidden NavigationLinks to the background of the ScrollView
//            // This ensures they are part of the NavigationStack's managed hierarchy
//            .background(
//                Group { // Using Group to contain multiple views for the background modifier
//                    NavigationLink(destination: createGpxView(), isActive: $navigateToGpxView) { EmptyView() }
//                    NavigationLink(destination: createRouteDetailsView(), isActive: $navigateToRouteDetails) { EmptyView() }
//                }
//            )
//            .navigationTitle("Mariner Studio")
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button(action: {
//                        // No action for now - dead button
//                    }) {
//                        Image(systemName: "line.3.horizontal")
//                    }
//                }
//            }
//            .presentPaywallIfNeeded(
//                requiredEntitlementIdentifier: "Pro",
//                presentationMode: .fullScreen
//            )
//        }
//    }
//    
//    private func createGpxView() -> some View {
//        let gpxService = GpxServiceImpl()
//        let routeCalculationService = RouteCalculationServiceImpl()
//        
//        let gpxViewModel = GpxViewModel(
//            gpxService: gpxService,
//            routeCalculationService: routeCalculationService,
//            navigationService: { parameters in
//                if let route = parameters["route"] as? GpxRoute,
//                   let averageSpeed = parameters["averageSpeed"] as? String {
//                    selectedRoute = route
//                    routeAverageSpeed = averageSpeed
//                    navigateToGpxView = false // Close the GpxView
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Slight delay
//                        navigateToRouteDetails = true // Navigate to RouteDetailsView
//                    }
//                }
//            }
//        )
//        
//        return GpxView(viewModel: gpxViewModel)
//    }
//    
//    private func createRouteDetailsView() -> some View {
//        let routeDetailsViewModel = RouteDetailsViewModel(
//            weatherService: serviceProvider.openMeteoService,
//            routeCalculationService: RouteCalculationServiceImpl()
//        )
//        
//        if let route = selectedRoute {
//            routeDetailsViewModel.applyRouteData(route, averageSpeed: routeAverageSpeed)
//        }
//        
//        return RouteDetailsView(viewModel: routeDetailsViewModel)
//    }
//}
//
//// Your existing NavigationButton, NavigationButtonContent structs remain the same:
//
//struct NavigationButton: View {
//    let icon: String
//    let title: String
//    let action: () -> Void
//
//    var body: some View {
//        Button(action: action) {
//            NavigationButtonContent(icon: icon, title: title)
//        }
//        .buttonStyle(PlainButtonStyle())
//    }
//}
//
//struct NavigationButtonContent: View {
//    let icon: String
//    let title: String
//
//    var body: some View {
//        HStack {
//            Image(icon)
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                .frame(width: 67, height: 67)
//                .padding(.leading, 5)
//
//            VStack(alignment: .leading) {
//                Text(title)
//                    .font(.largeTitle) // Consider adjusting if too large for two columns
//            }
//            .padding(.leading, 10)
//            .frame(height: 67)
//            .padding(.vertical, 10)
//
//            Spacer()
//        }
//        .frame(maxWidth: .infinity)
//        .padding(10)
//        .background(
//            RoundedRectangle(cornerRadius: 10)
//                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
//                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
//        )
//    }
//}





































































//
//
//
////21,May,2025
//
//import SwiftUI
//import RevenueCat // Ensure RevenueCat is imported
//import RevenueCatUI
//
//struct MainView: View {
//    @EnvironmentObject var serviceProvider: ServiceProvider
//    @State private var selectedRoute: GpxRoute? = nil
//    @State private var routeAverageSpeed: String = ""
//    @State private var navigateToGpxView = false
//    @State private var navigateToRouteDetails = false
//
//    let columns: [GridItem] = [
//        GridItem(.flexible(), spacing: 12),
//        GridItem(.flexible(), spacing: 12)
//    ]
//
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                LazyVGrid(columns: columns, spacing: 12) {
//                    NavigationLink(destination: MapClusteringView()) {
//                        NavigationButtonContent(
//                            icon: "earthsixfour",
//                            title: "MAP"
//                        )
//                    }
//
//                    NavigationLink(destination: WeatherMenuView()) {
//                        NavigationButtonContent(
//                            icon: "weathersixseventwo",
//                            title: "WEATHER"
//                        )
//                    }
//
//                    NavigationLink(destination: TideMenuView()) {
//                        NavigationButtonContent(
//                            icon: "tsixseven",
//                            title: "TIDES"
//                        )
//                    }
//                    
//                    NavigationLink(destination: CurrentMenuView()) {
//                        NavigationButtonContent(
//                            icon: "csixseven",
//                            title: "CURRENTS"
//                        )
//                    }
//
//                    NavigationLink(destination: NavUnitMenuView()) {
//                        NavigationButtonContent(
//                            icon: "nsixseven",
//                            title: "NAV UNITS"
//                        )
//                    }
//
//                    NavigationLink(destination: BuoyMenuView()) {
//                        NavigationButtonContent(
//                            icon: "buoysixseven",
//                            title: "BUOYS"
//                        )
//                    }
//                    
//                    NavigationLink(destination: TugsView(
//                        vesselService: serviceProvider.vesselService
//                    )) {
//                        NavigationButtonContent(
//                            icon: "tugboatsixseven",
//                            title: "TUGS"
//                        )
//                    }
//
//                    NavigationLink(destination: BargesView(
//                        vesselService: serviceProvider.vesselService
//                    )) {
//                        NavigationButtonContent(
//                            icon: "bargesixseventwo",
//                            title: "BARGES"
//                        )
//                    }
//
//                    // Route Button - Updated for vertical layout
//                    Button(action: {
//                        navigateToGpxView = true
//                    }) {
//                        VStack(alignment: .center, spacing: 8) { // Changed to VStack
//                            Image("tsixseven")
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 67, height: 67)
//                                // Removed .padding(.leading, 5)
//
//                            VStack(alignment: .center) { // Centered text block
//                                Text("Route")
//                                    .font(.headline)
//                                Text("View Route from GPX File")
//                                    .font(.subheadline)
//                                    .foregroundColor(.gray)
//                                    .multilineTextAlignment(.center)
//                            }
//                            // Removed .padding(.leading, 10)
//                            // Removed Spacer()
//                        }
//                        .frame(maxWidth: .infinity) // Ensures the button takes full width of the cell
//                        .padding(10) // Keeps the outer padding
//                        .background(
//                            RoundedRectangle(cornerRadius: 10)
//                                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
//                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
//                        )
//                        .frame(minHeight: 120) // Optional: Set a minHeight for consistency if needed
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                }
//                .padding()
//            }
//            .background(
//                Group {
//                    NavigationLink(destination: createGpxView(), isActive: $navigateToGpxView) { EmptyView() }
//                    NavigationLink(destination: createRouteDetailsView(), isActive: $navigateToRouteDetails) { EmptyView() }
//                }
//            )
//            .navigationTitle("Mariner Studio")
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button(action: {
//                        // No action for now - dead button
//                    }) {
//                        Image(systemName: "line.3.horizontal")
//                    }
//                }
//            }
//            .presentPaywallIfNeeded(
//                requiredEntitlementIdentifier: "Pro",
//                presentationMode: .fullScreen
//            )
//        }
//    }
//    
//    private func createGpxView() -> some View {
//        let gpxService = GpxServiceImpl()
//        let routeCalculationService = RouteCalculationServiceImpl()
//        
//        let gpxViewModel = GpxViewModel(
//            gpxService: gpxService,
//            routeCalculationService: routeCalculationService,
//            navigationService: { parameters in
//                if let route = parameters["route"] as? GpxRoute,
//                   let averageSpeed = parameters["averageSpeed"] as? String {
//                    selectedRoute = route
//                    routeAverageSpeed = averageSpeed
//                    navigateToGpxView = false
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                        navigateToRouteDetails = true
//                    }
//                }
//            }
//        )
//        
//        return GpxView(viewModel: gpxViewModel)
//    }
//    
//    private func createRouteDetailsView() -> some View {
//        let routeDetailsViewModel = RouteDetailsViewModel(
//            weatherService: serviceProvider.openMeteoService,
//            routeCalculationService: RouteCalculationServiceImpl()
//        )
//        
//        if let route = selectedRoute {
//            routeDetailsViewModel.applyRouteData(route, averageSpeed: routeAverageSpeed)
//        }
//        
//        return RouteDetailsView(viewModel: routeDetailsViewModel)
//    }
//}
//
//struct NavigationButton: View { // This struct seems unused directly in MainView's body now
//    let icon: String
//    let title: String
//    let action: () -> Void
//
//    var body: some View {
//        Button(action: action) {
//            NavigationButtonContent(icon: icon, title: title)
//        }
//        .buttonStyle(PlainButtonStyle())
//    }
//}
//
//// Updated NavigationButtonContent for vertical layout
//struct NavigationButtonContent: View {
//    let icon: String
//    let title: String
//
//    var body: some View {
//        VStack(alignment: .center, spacing: 8) { // Changed to VStack, added spacing
//            Image(icon)
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                .frame(width: 67, height: 67)
//                // Removed .padding(.leading, 5)
//
//            Text(title)
//                .font(.headline) // Changed from .largeTitle to .headline for better fit
//                .multilineTextAlignment(.center) // Ensure text is centered if it wraps
//                // Removed .padding(.leading, 20)
//                // Removed Spacer from HStack
//
//        }
//        .frame(maxWidth: .infinity) // Ensures the content takes full width of the cell
//        .padding(10) // Keeps the outer padding consistent
//        .background(
//            RoundedRectangle(cornerRadius: 10)
//                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
//                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
//        )
//        .frame(minHeight: 120) // Optional: Set a minHeight for consistency across buttons
//    }
//}

















//
//
//
////21,May,2025
//
//import SwiftUI
//import RevenueCat // Ensure RevenueCat is imported
//import RevenueCatUI
//
//struct MainView: View {
//    @EnvironmentObject var serviceProvider: ServiceProvider
//    @State private var selectedRoute: GpxRoute? = nil
//    @State private var routeAverageSpeed: String = ""
//    @State private var navigateToGpxView = false
//    @State private var navigateToRouteDetails = false
//
//    let columns: [GridItem] = [
//        GridItem(.flexible(), spacing: 12),
//        GridItem(.flexible(), spacing: 12)
//    ]
//
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                LazyVGrid(columns: columns, spacing: 12) {
//                    NavigationLink(destination: MapClusteringView()) {
//                        NavigationButtonContent(
//                            icon: "earthsixfour", // Existing custom asset
//                            title: "MAP"
//                        )
//                    }
//
//                    NavigationLink(destination: WeatherMenuView()) {
//                        NavigationButtonContent(
//                            icon: "weathersixseventwo", // Existing custom asset
//                            title: "WEATHER"
//                        )
//                    }
//
//                    // TIDES - Updated to use SF Symbol "water.waves"
//                    NavigationLink(destination: TideMenuView()) {
//                        NavigationButtonContent(
//                            icon: "water.waves",       // SF Symbol name
//                            title: "TIDES",
//                            isSystemIcon: true        // Specify this is an SF Symbol
//                        )
//                    }
//                    
//                    NavigationLink(destination: CurrentMenuView()) {
//                        NavigationButtonContent(
//                            icon: "csixseven", // Existing custom asset
//                            title: "CURRENTS"
//                        )
//                    }
//
//                    NavigationLink(destination: NavUnitMenuView()) {
//                        NavigationButtonContent(
//                            icon: "nsixseven", // Existing custom asset
//                            title: "NAV UNITS"
//                        )
//                    }
//
//                    NavigationLink(destination: BuoyMenuView()) {
//                        NavigationButtonContent(
//                            icon: "buoysixseven", // Existing custom asset
//                            title: "BUOYS"
//                        )
//                    }
//                    
//                    NavigationLink(destination: TugsView(
//                        vesselService: serviceProvider.vesselService
//                    )) {
//                        NavigationButtonContent(
//                            icon: "tugboatsixseven", // Existing custom asset
//                            title: "TUGS"
//                        )
//                    }
//
//                    NavigationLink(destination: BargesView(
//                        vesselService: serviceProvider.vesselService
//                    )) {
//                        NavigationButtonContent(
//                            icon: "bargesixseventwo", // Existing custom asset
//                            title: "BARGES"
//                        )
//                    }
//
//                    // Route Button
//                    Button(action: {
//                        navigateToGpxView = true
//                    }) {
//                        VStack(alignment: .center, spacing: 8) {
//                            Image("tsixseven") // This is a custom asset for the Route button
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 67, height: 67)
//
//                            VStack(alignment: .center) {
//                                Text("Route")
//                                    .font(.headline)
//                                Text("View Route from GPX File")
//                                    .font(.subheadline)
//                                    .foregroundColor(.gray)
//                                    .multilineTextAlignment(.center)
//                            }
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding(10)
//                        .background(
//                            RoundedRectangle(cornerRadius: 10)
//                                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
//                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
//                        )
//                        .frame(minHeight: 120)
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                }
//                .padding()
//            }
//            .background(
//                Group {
//                    NavigationLink(destination: createGpxView(), isActive: $navigateToGpxView) { EmptyView() }
//                    NavigationLink(destination: createRouteDetailsView(), isActive: $navigateToRouteDetails) { EmptyView() }
//                }
//            )
//            .navigationTitle("Mariner Studio")
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button(action: {
//                        // No action for now - dead button
//                    }) {
//                        Image(systemName: "line.3.horizontal")
//                    }
//                }
//            }
//            .presentPaywallIfNeeded(
//                requiredEntitlementIdentifier: "Pro",
//                presentationMode: .fullScreen
//            )
//        }
//    }
//    
//    private func createGpxView() -> some View {
//        let gpxService = GpxServiceImpl()
//        let routeCalculationService = RouteCalculationServiceImpl()
//        
//        let gpxViewModel = GpxViewModel(
//            gpxService: gpxService,
//            routeCalculationService: routeCalculationService,
//            navigationService: { parameters in
//                if let route = parameters["route"] as? GpxRoute,
//                   let averageSpeed = parameters["averageSpeed"] as? String {
//                    selectedRoute = route
//                    routeAverageSpeed = averageSpeed
//                    navigateToGpxView = false
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                        navigateToRouteDetails = true
//                    }
//                }
//            }
//        )
//        
//        return GpxView(viewModel: gpxViewModel)
//    }
//    
//    private func createRouteDetailsView() -> some View {
//        let routeDetailsViewModel = RouteDetailsViewModel(
//            weatherService: serviceProvider.openMeteoService,
//            routeCalculationService: RouteCalculationServiceImpl()
//        )
//        
//        if let route = selectedRoute {
//            routeDetailsViewModel.applyRouteData(route, averageSpeed: routeAverageSpeed)
//        }
//        
//        return RouteDetailsView(viewModel: routeDetailsViewModel)
//    }
//}
//
//struct NavigationButton: View {
//    let icon: String
//    let title: String
//    let action: () -> Void
//    let isSystemIcon: Bool // Added for consistency if this struct were to be used more directly
//
//    init(icon: String, title: String, action: @escaping () -> Void, isSystemIcon: Bool = false) {
//        self.icon = icon
//        self.title = title
//        self.action = action
//        self.isSystemIcon = isSystemIcon
//    }
//
//    var body: some View {
//        Button(action: action) {
//            NavigationButtonContent(icon: icon, title: title, isSystemIcon: isSystemIcon)
//        }
//        .buttonStyle(PlainButtonStyle())
//    }
//}
//
//// Updated NavigationButtonContent to support both asset images and SF Symbols
//struct NavigationButtonContent: View {
//    let icon: String
//    let title: String
//    let isSystemIcon: Bool // Flag to determine if the icon is an SF Symbol
//
//    // Initializer to make isSystemIcon optional, defaulting to false for existing asset images
//    init(icon: String, title: String, isSystemIcon: Bool = false) {
//        self.icon = icon
//        self.title = title
//        self.isSystemIcon = isSystemIcon
//    }
//
//    var body: some View {
//        VStack(alignment: .center, spacing: 8) {
//            if isSystemIcon {
//                Image(systemName: icon) // Use systemName for SF Symbols
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: 60, height: 60) // Adjusted frame slightly for typical SF Symbol proportions
//                    .foregroundColor(.accentColor) // SF Symbols often look good with accent color
//            } else {
//                Image(icon) // Use regular initializer for asset images
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: 67, height: 67) // Original frame for assets
//            }
//
//            Text(title)
//                .font(.headline)
//                .multilineTextAlignment(.center)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(10)
//        .background(
//            RoundedRectangle(cornerRadius: 10)
//                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
//                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
//        )
//        .frame(minHeight: 120)
//    }
//}













//21,May,2025

import SwiftUI
import RevenueCat // Ensure RevenueCat is imported
import RevenueCatUI

struct MainView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var selectedRoute: GpxRoute? = nil
    @State private var routeAverageSpeed: String = ""
    @State private var navigateToGpxView = false
    @State private var navigateToRouteDetails = false

    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    NavigationLink(destination: MapClusteringView()) {
                        NavigationButtonContent(
                            icon: "earthsixfour",
                            title: "MAP"
                        )
                    }

                    NavigationLink(destination: WeatherMenuView()) {
                        NavigationButtonContent(
                            icon: "weathersixseventwo",
                            title: "WEATHER"
                        )
                    }

                    // TIDES - Icon "water.waves", Color Green
                    NavigationLink(destination: TideMenuView()) {
                        NavigationButtonContent(
                            icon: "water.waves",
                            title: "TIDES",
                            isSystemIcon: true,
                            iconColor: .green // Set Tides icon to Green
                        )
                    }
                    
                    // CURRENTS - Icon "arrow.right.arrow.left", Color Red
                    NavigationLink(destination: CurrentMenuView()) {
                        NavigationButtonContent(
                            icon: "arrow.right.arrow.left", // New SF Symbol for Currents
                            title: "CURRENTS",
                            isSystemIcon: true,
                            iconColor: .red // Set Currents icon to Red
                        )
                    }

                    NavigationLink(destination: NavUnitMenuView()) {
                        NavigationButtonContent(
                            icon: "refinerysixseven",
                            title: "NAV UNITS"
                        )
                    }

                    NavigationLink(destination: BuoyMenuView()) {
                        NavigationButtonContent(
                            icon: "buoysixseven",
                            title: "BUOYS"
                        )
                    }
                    
                    NavigationLink(destination: TugsView(
                        vesselService: serviceProvider.vesselService
                    )) {
                        NavigationButtonContent(
                            icon: "tugboatsixseven",
                            title: "TUGS"
                        )
                    }

                    NavigationLink(destination: BargesView(
                        vesselService: serviceProvider.vesselService
                    )) {
                        NavigationButtonContent(
                            icon: "bargesixseventwo",
                            title: "BARGES"
                        )
                    }

                    // Route Button
                    Button(action: {
                        navigateToGpxView = true
                    }) {
                        VStack(alignment: .center, spacing: 8) {
                            Image("tsixseven")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 67, height: 67)

                            VStack(alignment: .center) {
                                Text("Route")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                        )
                        .frame(minHeight: 120)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            }
            .background(
                Group {
                    NavigationLink(destination: createGpxView(), isActive: $navigateToGpxView) { EmptyView() }
                    NavigationLink(destination: createRouteDetailsView(), isActive: $navigateToRouteDetails) { EmptyView() }
                }
            )
            .navigationTitle("Mariner Studio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // No action for now - dead button
                    }) {
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }
            .presentPaywallIfNeeded(
                requiredEntitlementIdentifier: "Pro",
                presentationMode: .fullScreen
            )
        }
    }
    
    private func createGpxView() -> some View {
        let gpxService = GpxServiceImpl()
        let routeCalculationService = RouteCalculationServiceImpl()
        
        let gpxViewModel = GpxViewModel(
            gpxService: gpxService,
            routeCalculationService: routeCalculationService,
            navigationService: { parameters in
                if let route = parameters["route"] as? GpxRoute,
                   let averageSpeed = parameters["averageSpeed"] as? String {
                    selectedRoute = route
                    routeAverageSpeed = averageSpeed
                    navigateToGpxView = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        navigateToRouteDetails = true
                    }
                }
            }
        )
        
        return GpxView(viewModel: gpxViewModel)
    }
    
    private func createRouteDetailsView() -> some View {
        let routeDetailsViewModel = RouteDetailsViewModel(
            weatherService: serviceProvider.openMeteoService,
            routeCalculationService: RouteCalculationServiceImpl()
        )
        
        if let route = selectedRoute {
            routeDetailsViewModel.applyRouteData(route, averageSpeed: routeAverageSpeed)
        }
        
        return RouteDetailsView(viewModel: routeDetailsViewModel)
    }
}

struct NavigationButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    let isSystemIcon: Bool
    let iconColor: Color? // Added iconColor

    init(icon: String, title: String, action: @escaping () -> Void, isSystemIcon: Bool = false, iconColor: Color? = nil) {
        self.icon = icon
        self.title = title
        self.action = action
        self.isSystemIcon = isSystemIcon
        self.iconColor = iconColor
    }

    var body: some View {
        Button(action: action) {
            NavigationButtonContent(icon: icon, title: title, isSystemIcon: isSystemIcon, iconColor: iconColor)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Updated NavigationButtonContent to support icon color
struct NavigationButtonContent: View {
    let icon: String
    let title: String
    let isSystemIcon: Bool
    let iconColor: Color? // New optional parameter for icon color

    init(icon: String, title: String, isSystemIcon: Bool = false, iconColor: Color? = nil) {
        self.icon = icon
        self.title = title
        self.isSystemIcon = isSystemIcon
        self.iconColor = iconColor
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Group {
                if isSystemIcon {
                    Image(systemName: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(iconColor ?? .accentColor) // Apply specific color or default to accentColor
                } else {
                    Image(icon) // Asset images
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 67, height: 67)
                }
            }

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
        .frame(minHeight: 120)
    }
}
