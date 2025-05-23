////
////import SwiftUI
////import RevenueCat // Ensure RevenueCat is imported
////import RevenueCatUI
////
////struct MainView: View {
////    @EnvironmentObject var serviceProvider: ServiceProvider
////    @State private var selectedRoute: GpxRoute? = nil
////    @State private var routeAverageSpeed: String = ""
////    @State private var navigateToGpxView = false
////    @State private var navigateToRouteDetails = false
////    @State private var navigationPath = NavigationPath()
////    
////    // Parameter to indicate if navigation should be cleared
////    let shouldClearNavigation: Bool
////    
////    init(shouldClearNavigation: Bool = false) {
////        self.shouldClearNavigation = shouldClearNavigation
////    }
////
////    let columns: [GridItem] = [
////        GridItem(.flexible(), spacing: 12),
////        GridItem(.flexible(), spacing: 12)
////    ]
////
////    var body: some View {
////        NavigationStack(path: $navigationPath) {
////            ScrollView {
////                LazyVGrid(columns: columns, spacing: 12) {
////                    NavigationLink(destination: MapClusteringView()) {
////                        NavigationButtonContent(
////                            icon: "earthsixfour",
////                            title: "MAP"
////                        )
////                    }
////
////                    NavigationLink(destination: WeatherMenuView()) {
////                        NavigationButtonContent(
////                            icon: "weathersixseventwo",
////                            title: "WEATHER"
////                        )
////                    }
////
////                    // TIDES - Icon "water.waves", Color Green
////                    NavigationLink(destination: TideMenuView()) {
////                        NavigationButtonContent(
////                            icon: "water.waves",
////                            title: "TIDES",
////                            isSystemIcon: true,
////                            iconColor: .green // Set Tides icon to Green
////                        )
////                    }
////                    
////                    // CURRENTS - Icon "arrow.right.arrow.left", Color Red
////                    NavigationLink(destination: CurrentMenuView()) {
////                        NavigationButtonContent(
////                            icon: "arrow.right.arrow.left", // New SF Symbol for Currents
////                            title: "CURRENTS",
////                            isSystemIcon: true,
////                            iconColor: .red // Set Currents icon to Red
////                        )
////                    }
////
////                    NavigationLink(destination: NavUnitMenuView()) {
////                        NavigationButtonContent(
////                            icon: "refinerysixseven",
////                            title: "NAV UNITS"
////                        )
////                    }
////
////                    NavigationLink(destination: BuoyMenuView()) {
////                        NavigationButtonContent(
////                            icon: "buoysixseven",
////                            title: "BUOYS"
////                        )
////                    }
////                    
////                    NavigationLink(destination: TugsView(
////                        vesselService: serviceProvider.vesselService
////                    )) {
////                        NavigationButtonContent(
////                            icon: "tugboatsixseven",
////                            title: "TUGS"
////                        )
////                    }
////
////                    NavigationLink(destination: BargesView(
////                        vesselService: serviceProvider.vesselService
////                    )) {
////                        NavigationButtonContent(
////                            icon: "bargesixseventwo",
////                            title: "BARGES"
////                        )
////                    }
////
////                    // ROUTES button
////                    Button(action: {
////                        navigateToGpxView = true
////                    }) {
////                        VStack(alignment: .center, spacing: 8) {
////                            Image("greencompasssixseven")
////                                .resizable()
////                                .aspectRatio(contentMode: .fit)
////                                .frame(width: 67, height: 67)
////
////                            VStack(alignment: .center) {
////                                Text("ROUTES")
////                                    .font(.headline)
////                            }
////                        }
////                        .frame(maxWidth: .infinity)
////                        .padding(10)
////                        .background(
////                            RoundedRectangle(cornerRadius: 10)
////                                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
////                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
////                        )
////                        .frame(minHeight: 120)
////                    }
////                    .buttonStyle(PlainButtonStyle())
////                    
////                    // CREW button - New addition
////                    NavigationLink(destination: CrewManagementView()) {
////                        NavigationButtonContent(
////                            icon: "person.3.fill",
////                            title: "CREW",
////                            isSystemIcon: true,
////                            iconColor: .orange
////                        )
////                    }
////                    
////                    // Navigation Flow - Left column only
////                    NavigationLink(destination: NavigationFlowView()) {
////                        VStack(alignment: .center, spacing: 8) {
////                            Image(systemName: "arrow.triangle.branch")
////                                .resizable()
////                                .aspectRatio(contentMode: .fit)
////                                .frame(width: 60, height: 60)
////                                .foregroundColor(.blue)
////
////                            VStack(alignment: .center) {
////                                Text("Navigation Flow")
////                                    .font(.headline)
////                                    .multilineTextAlignment(.center)
////                            }
////                        }
////                        .frame(maxWidth: .infinity)
////                        .padding(10)
////                        .background(
////                            RoundedRectangle(cornerRadius: 10)
////                                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
////                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
////                        )
////                        .frame(minHeight: 120)
////                    }
////                    
////                    // Empty space for right column in the last row
////                    Color.clear
////                        .frame(minHeight: 120)
////                }
////                .padding()
////            }
////            .background(
////                Group {
////                    NavigationLink(destination: createGpxView(), isActive: $navigateToGpxView) { EmptyView() }
////                    NavigationLink(destination: createRouteDetailsView(), isActive: $navigateToRouteDetails) { EmptyView() }
////                }
////            )
////            .navigationTitle("Mariner Studio")
////            .toolbar {
////                ToolbarItem(placement: .topBarTrailing) {
////                    Button(action: navigateToHome) {
////                        Image(systemName: "house.fill")
////                            .foregroundColor(.blue)
////                    }
////                }
////            }
////            .presentPaywallIfNeeded(
////                requiredEntitlementIdentifier: "Pro",
////                presentationMode: .fullScreen
////            )
////            .onAppear {
////                // Clear navigation if we arrived here via home button
////                if shouldClearNavigation {
////                    clearNavigationStack()
////                }
////            }
////        }
////    }
////    
////    // MARK: - Navigation Actions
////    
////    private func clearNavigationStack() {
////        // Small delay to ensure view is fully loaded
////        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
////            // Reset the navigation path
////            navigationPath = NavigationPath()
////            
////            // Also clear any local navigation state
////            navigateToGpxView = false
////            navigateToRouteDetails = false
////            selectedRoute = nil
////            routeAverageSpeed = ""
////            
////            // Try to clear the broader navigation context
////            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
////               let window = windowScene.windows.first,
////               let rootViewController = window.rootViewController {
////                
////                clearNavigationHierarchy(from: rootViewController)
////            }
////        }
////    }
////    
////    private func clearNavigationHierarchy(from viewController: UIViewController) {
////        // If it's a navigation controller, pop to root
////        if let navController = viewController as? UINavigationController {
////            navController.popToRootViewController(animated: false)
////        }
////        
////        // Check for tab bar controllers
////        if let tabBarController = viewController as? UITabBarController,
////           let selectedNavController = tabBarController.selectedViewController as? UINavigationController {
////            selectedNavController.popToRootViewController(animated: false)
////        }
////        
////        // Recursively check child view controllers
////        for child in viewController.children {
////            clearNavigationHierarchy(from: child)
////        }
////    }
////    
////    private func navigateToHome() {
////        // Provide haptic feedback
////        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
////        impactGenerator.prepare()
////        impactGenerator.impactOccurred()
////        
////        // Reset the navigation path to go back to root
////        navigationPath = NavigationPath()
////        
////        // Reset any local navigation state
////        navigateToGpxView = false
////        navigateToRouteDetails = false
////        selectedRoute = nil
////        routeAverageSpeed = ""
////    }
////    
////    private func createGpxView() -> some View {
////        let gpxService = GpxServiceImpl()
////        let routeCalculationService = RouteCalculationServiceImpl()
////        
////        let gpxViewModel = GpxViewModel(
////            gpxService: gpxService,
////            routeCalculationService: routeCalculationService,
////            navigationService: { parameters in
////                if let route = parameters["route"] as? GpxRoute,
////                   let averageSpeed = parameters["averageSpeed"] as? String {
////                    selectedRoute = route
////                    routeAverageSpeed = averageSpeed
////                    navigateToGpxView = false
////                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
////                        navigateToRouteDetails = true
////                    }
////                }
////            }
////        )
////        
////        return GpxView(viewModel: gpxViewModel)
////    }
////    
////    private func createRouteDetailsView() -> some View {
////        let routeDetailsViewModel = RouteDetailsViewModel(
////            weatherService: serviceProvider.openMeteoService,
////            routeCalculationService: RouteCalculationServiceImpl()
////        )
////        
////        if let route = selectedRoute {
////            routeDetailsViewModel.applyRouteData(route, averageSpeed: routeAverageSpeed)
////        }
////        
////        return RouteDetailsView(viewModel: routeDetailsViewModel)
////    }
////}
////
////struct NavigationButton: View {
////    let icon: String
////    let title: String
////    let action: () -> Void
////    let isSystemIcon: Bool
////    let iconColor: Color?
////
////    init(icon: String, title: String, action: @escaping () -> Void, isSystemIcon: Bool = false, iconColor: Color? = nil) {
////        self.icon = icon
////        self.title = title
////        self.action = action
////        self.isSystemIcon = isSystemIcon
////        self.iconColor = iconColor
////    }
////
////    var body: some View {
////        Button(action: action) {
////            NavigationButtonContent(icon: icon, title: title, isSystemIcon: isSystemIcon, iconColor: iconColor)
////        }
////        .buttonStyle(PlainButtonStyle())
////    }
////}
////
////struct NavigationButtonContent: View {
////    let icon: String
////    let title: String
////    let isSystemIcon: Bool
////    let iconColor: Color?
////
////    init(icon: String, title: String, isSystemIcon: Bool = false, iconColor: Color? = nil) {
////        self.icon = icon
////        self.title = title
////        self.isSystemIcon = isSystemIcon
////        self.iconColor = iconColor
////    }
////
////    var body: some View {
////        VStack(alignment: .center, spacing: 8) {
////            Group {
////                if isSystemIcon {
////                    Image(systemName: icon)
////                        .resizable()
////                        .aspectRatio(contentMode: .fit)
////                        .frame(width: 60, height: 60)
////                        .foregroundColor(iconColor ?? .accentColor)
////                } else {
////                    Image(icon)
////                        .resizable()
////                        .aspectRatio(contentMode: .fit)
////                        .frame(width: 67, height: 67)
////                }
////            }
////
////            Text(title)
////                .font(.headline)
////                .multilineTextAlignment(.center)
////        }
////        .frame(maxWidth: .infinity)
////        .padding(10)
////        .background(
////            RoundedRectangle(cornerRadius: 10)
////                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
////                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
////        )
////        .frame(minHeight: 120)
////    }
////}
//
//
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
//    @State private var selectedRoute: GpxRoute? = nil
//    @State private var routeAverageSpeed: String = ""
//    @State private var navigateToGpxView = false
//    @State private var navigateToRouteDetails = false
//    @State private var navigationPath = NavigationPath()
//    
//    // Parameter to indicate if navigation should be cleared
//    let shouldClearNavigation: Bool
//    
//    init(shouldClearNavigation: Bool = false) {
//        self.shouldClearNavigation = shouldClearNavigation
//    }
//
//    let columns: [GridItem] = [
//        GridItem(.flexible(), spacing: 12),
//        GridItem(.flexible(), spacing: 12)
//    ]
//
//    var body: some View {
//        NavigationStack(path: $navigationPath) {
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
//                    // TIDES - Icon "water.waves", Color Green
//                    NavigationLink(destination: TideMenuView()) {
//                        NavigationButtonContent(
//                            icon: "water.waves",
//                            title: "TIDES",
//                            isSystemIcon: true,
//                            iconColor: .green // Set Tides icon to Green
//                        )
//                    }
//                    
//                    // CURRENTS - Icon "arrow.right.arrow.left", Color Red
//                    NavigationLink(destination: CurrentMenuView()) {
//                        NavigationButtonContent(
//                            icon: "arrow.right.arrow.left", // New SF Symbol for Currents
//                            title: "CURRENTS",
//                            isSystemIcon: true,
//                            iconColor: .red // Set Currents icon to Red
//                        )
//                    }
//
//                    NavigationLink(destination: NavUnitMenuView()) {
//                        NavigationButtonContent(
//                            icon: "refinerysixseven",
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
//                    // ROUTES - Now navigates to RoutesMenuView
//                    NavigationLink(destination: RoutesMenuView()) {
//                        VStack(alignment: .center, spacing: 8) {
//                            Image("greencompasssixseven")
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 67, height: 67)
//
//                            VStack(alignment: .center) {
//                                Text("ROUTES")
//                                    .font(.headline)
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
//                    
//                    // CREW button
//                    NavigationLink(destination: CrewManagementView()) {
//                        NavigationButtonContent(
//                            icon: "person.3.fill",
//                            title: "CREW",
//                            isSystemIcon: true,
//                            iconColor: .orange
//                        )
//                    }
//                    
//                    // Navigation Flow - Left column only
//                    NavigationLink(destination: NavigationFlowView()) {
//                        VStack(alignment: .center, spacing: 8) {
//                            Image(systemName: "arrow.triangle.branch")
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 60, height: 60)
//                                .foregroundColor(.blue)
//
//                            VStack(alignment: .center) {
//                                Text("Navigation Flow")
//                                    .font(.headline)
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
//                    
//                    // Empty space for right column in the last row
//                    Color.clear
//                        .frame(minHeight: 120)
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
//                    Button(action: navigateToHome) {
//                        Image(systemName: "house.fill")
//                            .foregroundColor(.blue)
//                    }
//                }
//            }
//            .presentPaywallIfNeeded(
//                requiredEntitlementIdentifier: "Pro",
//                presentationMode: .fullScreen
//            )
//            .onAppear {
//                // Clear navigation if we arrived here via home button
//                if shouldClearNavigation {
//                    clearNavigationStack()
//                }
//            }
//        }
//    }
//    
//    // MARK: - Navigation Actions
//    
//    private func clearNavigationStack() {
//        // Small delay to ensure view is fully loaded
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//            // Reset the navigation path
//            navigationPath = NavigationPath()
//            
//            // Also clear any local navigation state
//            navigateToGpxView = false
//            navigateToRouteDetails = false
//            selectedRoute = nil
//            routeAverageSpeed = ""
//            
//            // Try to clear the broader navigation context
//            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//               let window = windowScene.windows.first,
//               let rootViewController = window.rootViewController {
//                
//                clearNavigationHierarchy(from: rootViewController)
//            }
//        }
//    }
//    
//    private func clearNavigationHierarchy(from viewController: UIViewController) {
//        // If it's a navigation controller, pop to root
//        if let navController = viewController as? UINavigationController {
//            navController.popToRootViewController(animated: false)
//        }
//        
//        // Check for tab bar controllers
//        if let tabBarController = viewController as? UITabBarController,
//           let selectedNavController = tabBarController.selectedViewController as? UINavigationController {
//            selectedNavController.popToRootViewController(animated: false)
//        }
//        
//        // Recursively check child view controllers
//        for child in viewController.children {
//            clearNavigationHierarchy(from: child)
//        }
//    }
//    
//    private func navigateToHome() {
//        // Provide haptic feedback
//        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
//        impactGenerator.prepare()
//        impactGenerator.impactOccurred()
//        
//        // Reset the navigation path to go back to root
//        navigationPath = NavigationPath()
//        
//        // Reset any local navigation state
//        navigateToGpxView = false
//        navigateToRouteDetails = false
//        selectedRoute = nil
//        routeAverageSpeed = ""
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
//    let isSystemIcon: Bool
//    let iconColor: Color?
//
//    init(icon: String, title: String, action: @escaping () -> Void, isSystemIcon: Bool = false, iconColor: Color? = nil) {
//        self.icon = icon
//        self.title = title
//        self.action = action
//        self.isSystemIcon = isSystemIcon
//        self.iconColor = iconColor
//    }
//
//    var body: some View {
//        Button(action: action) {
//            NavigationButtonContent(icon: icon, title: title, isSystemIcon: isSystemIcon, iconColor: iconColor)
//        }
//        .buttonStyle(PlainButtonStyle())
//    }
//}
//
//struct NavigationButtonContent: View {
//    let icon: String
//    let title: String
//    let isSystemIcon: Bool
//    let iconColor: Color?
//
//    init(icon: String, title: String, isSystemIcon: Bool = false, iconColor: Color? = nil) {
//        self.icon = icon
//        self.title = title
//        self.isSystemIcon = isSystemIcon
//        self.iconColor = iconColor
//    }
//
//    var body: some View {
//        VStack(alignment: .center, spacing: 8) {
//            Group {
//                if isSystemIcon {
//                    Image(systemName: icon)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: 60, height: 60)
//                        .foregroundColor(iconColor ?? .accentColor)
//                } else {
//                    Image(icon)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: 67, height: 67)
//                }
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












import SwiftUI
import RevenueCat // Ensure RevenueCat is imported
import RevenueCatUI

struct MainView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var selectedRoute: GpxRoute? = nil
    @State private var routeAverageSpeed: String = ""
    @State private var navigateToGpxView = false
    @State private var navigateToRouteDetails = false
    @State private var navigationPath = NavigationPath()
    
    // Parameter to indicate if navigation should be cleared
    let shouldClearNavigation: Bool
    
    init(shouldClearNavigation: Bool = false) {
        self.shouldClearNavigation = shouldClearNavigation
    }

    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                            icon: "docksixseven",
                            title: "DOCKS"
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

                    // ROUTES button
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
                    
                    // CREW button
                    NavigationLink(destination: CrewManagementView()) {
                        NavigationButtonContent(
                            icon: "person.3.fill",
                            title: "CREW",
                            isSystemIcon: true,
                            iconColor: .orange
                        )
                    }
                    
                    // Navigation Flow - Left column
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
                                    .multilineTextAlignment(.center)
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
                    
                    // NAUTICAL MAP button - Right column, below CREW
                    NavigationLink(destination: NauticalMapView()) {
                        NavigationButtonContent(
                            icon: "map.fill",
                            title: "NAUTICAL MAP",
                            isSystemIcon: true,
                            iconColor: .blue
                        )
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
                    Button(action: navigateToHome) {
                        Image(systemName: "house.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .presentPaywallIfNeeded(
                requiredEntitlementIdentifier: "Pro",
                presentationMode: .fullScreen
            )
            .onAppear {
                // Clear navigation if we arrived here via home button
                if shouldClearNavigation {
                    clearNavigationStack()
                }
            }
        }
    }
    
    // MARK: - Navigation Actions
    
    private func clearNavigationStack() {
        // Small delay to ensure view is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Reset the navigation path
            navigationPath = NavigationPath()
            
            // Also clear any local navigation state
            navigateToGpxView = false
            navigateToRouteDetails = false
            selectedRoute = nil
            routeAverageSpeed = ""
            
            // Try to clear the broader navigation context
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                clearNavigationHierarchy(from: rootViewController)
            }
        }
    }
    
    private func clearNavigationHierarchy(from viewController: UIViewController) {
        // If it's a navigation controller, pop to root
        if let navController = viewController as? UINavigationController {
            navController.popToRootViewController(animated: false)
        }
        
        // Check for tab bar controllers
        if let tabBarController = viewController as? UITabBarController,
           let selectedNavController = tabBarController.selectedViewController as? UINavigationController {
            selectedNavController.popToRootViewController(animated: false)
        }
        
        // Recursively check child view controllers
        for child in viewController.children {
            clearNavigationHierarchy(from: child)
        }
    }
    
    private func navigateToHome() {
        // Provide haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
        
        // Reset the navigation path to go back to root
        navigationPath = NavigationPath()
        
        // Reset any local navigation state
        navigateToGpxView = false
        navigateToRouteDetails = false
        selectedRoute = nil
        routeAverageSpeed = ""
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
