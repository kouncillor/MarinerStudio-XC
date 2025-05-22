

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
                            icon: "crewsixseven",
                            title: "BARGES"
                        )
                    }

                    // Route and Navigation Flow on a row but with separate cells
                    Button(action: {
                        navigateToGpxView = true
                    }) {
                        VStack(alignment: .center, spacing: 8) {
                            Image("greencompasssixseven")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 67, height: 67)

                            VStack(alignment: .center) {
                                Text("ROUTES")
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
                    
                    // NEW: Navigation Flow Visualization Button
                    NavigationLink(destination: NavigationFlowView()) {
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: "arrow.triangle.branch")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .foregroundColor(.blue)

                            VStack(alignment: .center) {
                                Text("Navigation Flow")
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
    let iconColor: Color?

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

struct NavigationButtonContent: View {
    let icon: String
    let title: String
    let isSystemIcon: Bool
    let iconColor: Color?

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
                        .foregroundColor(iconColor ?? .accentColor)
                } else {
                    Image(icon)
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
