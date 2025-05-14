
import SwiftUI
import RevenueCat // Ensure RevenueCat is imported
import RevenueCatUI

struct MainView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var showSettings = false
    @State private var selectedRoute: GpxRoute? = nil
    @State private var routeAverageSpeed: String = ""
    @State private var navigateToGpxView = false
    @State private var navigateToRouteDetails = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // In MainView.swift, update the NavigationLink for MAP:
                    NavigationLink(destination: MapClusteringView(
                        navUnitService: serviceProvider.navUnitService,
                        tideStationService: serviceProvider.tideStationService,
                        currentStationService: serviceProvider.currentStationService,
                        locationService: serviceProvider.locationService
                    )) {
                        NavigationButtonContent(
                            icon: "earthsixfour",
                            title: "MAP"
                        )
                    }

                    // WEATHER
                    NavigationLink(destination: WeatherMenuView()) {
                        NavigationButtonContent(
                            icon: "weathersixseventwo",
                            title: "WEATHER"
                        )
                    }

                    // TIDES
                    NavigationLink(destination: TideMenuView()) {
                        NavigationButtonContent(
                            icon: "tsixseven",
                            title: "TIDES"
                        )
                    }
                    
                    // In MainView.swift, update the NavigationLink for CURRENTS:
                    NavigationLink(destination: CurrentMenuView()) {
                        NavigationButtonContent(
                            icon: "csixseven",
                            title: "CURRENTS"
                        )
                    }

                    // NAV UNITS - Updated to use NavUnitMenuView instead of NavUnitsView
                    NavigationLink(destination: NavUnitMenuView()) {
                        NavigationButtonContent(
                            icon: "nsixseven",
                            title: "NAV UNITS"
                        )
                    }

                    // BUOYS
                    NavigationLink {
                        BuoyStationsView(
                            buoyService: BuoyServiceImpl(),
                            locationService: serviceProvider.locationService,
                            buoyDatabaseService: serviceProvider.buoyService
                        )
                    } label: {
                        NavigationButtonContent(
                            icon: "buoysixseven",
                            title: "BUOYS"
                        )
                    }

                    
                    //TUGS
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

                    // Route Button - Updated with correct navigation
                    Button(action: {
                        navigateToGpxView = true
                    }) {
                        HStack {
                            Image("tsixseven") // Assuming this is an intended placeholder or actual image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 67, height: 67)
                                .padding(.leading, 5)

                            VStack(alignment: .leading) {
                                Text("Route")
                                    .font(.headline)
                                Text("View Route from GPX File")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.leading, 10)
                            .frame(height: 67)
                            .padding(.vertical, 10)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Navigation links
                    NavigationLink(destination: createGpxView(), isActive: $navigateToGpxView) {
                        EmptyView()
                    }
                    
                    NavigationLink(destination: createRouteDetailsView(), isActive: $navigateToRouteDetails) {
                        EmptyView()
                    }
                }
                .padding()
            }
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
            // Removed the sheet that was presenting WeatherSettingsView
        }
        // Apply the .presentPaywallIfNeeded modifier to the NavigationStack
        // This will present the paywall if the "Pro" entitlement is not active
        // when MainView appears.
        .presentPaywallIfNeeded(
            requiredEntitlementIdentifier: "Pro",
            presentationMode: .fullScreen
        )
    }
    
    // Function to create the GpxView with necessary dependencies
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
                    navigateToGpxView = false // Close the GpxView
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        navigateToRouteDetails = true // Navigate to RouteDetailsView
                    }
                }
            }
        )
        
        return GpxView(viewModel: gpxViewModel)
    }
    
    // Function to create the RouteDetailsView with the selected route
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

// Your existing NavigationButton, NavigationButtonContent, and RouteButton structs remain the same:

struct NavigationButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NavigationButtonContent(icon: icon, title: title)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NavigationButtonContent: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 67, height: 67)
                .padding(.leading, 5)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.largeTitle)
            }
            .padding(.leading, 20)
            .frame(height: 67)
            .padding(.vertical, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
    }
}
