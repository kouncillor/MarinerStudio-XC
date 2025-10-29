import SwiftUI
import RevenueCat
import RevenueCatUI

struct MainView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var navigationPath = NavigationPath()
    @State private var showSubscriptionPrompt = false
    @State private var showFeedback = false
    @State private var showMapView = false
    @State private var showWeatherMenu = false
    @State private var showTideMenu = false
    @State private var showCurrentMenu = false
    @State private var showNavUnitMenu = false
    @State private var showBuoyMenu = false
    @State private var showRouteMenu = false
    @State private var refreshTrigger = false

    let shouldClearNavigation: Bool

    init(shouldClearNavigation: Bool = false) {
        self.shouldClearNavigation = shouldClearNavigation
    }

    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12)
    ]

    private var coreNavigationButtons: some View {
        Group {
            // MAP
            if subscriptionService.hasAppAccess {
                NavigationLink(destination: MapClusteringView()) {
                    NavigationButtonContent(
                        icon: "earthsixfour",
                        title: "MAP"
                    )
                }
            } else if subscriptionService.canAccessMapMenu() {
                Button(action: {
                    subscriptionService.recordMapMenuUsage()
                    showMapView = true
                }) {
                    NavigationButtonContent(
                        icon: "earthsixfour",
                        title: "MAP",
                        isDailyLimited: true,
                        dailyUsageLimit: subscriptionService.getRemainingMapMenuUses()
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    showSubscriptionPrompt = true
                }) {
                    NavigationButtonContent(
                        icon: "earthsixfour",
                        title: "MAP",
                        isUsedToday: true
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // WEATHER
            if subscriptionService.hasAppAccess {
                NavigationLink(destination: WeatherMenuView()) {
                    NavigationButtonContent(
                        icon: "weathersunsixseven",
                        title: "WEATHER"
                    )
                }
            } else if subscriptionService.canAccessWeatherMenu() {
                Button(action: {
                    subscriptionService.recordWeatherMenuUsage()
                    showWeatherMenu = true
                }) {
                    NavigationButtonContent(
                        icon: "weathersunsixseven",
                        title: "WEATHER",
                        isDailyLimited: true,
                        dailyUsageLimit: subscriptionService.getRemainingWeatherMenuUses()
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    showSubscriptionPrompt = true
                }) {
                    NavigationButtonContent(
                        icon: "weathersunsixseven",
                        title: "WEATHER",
                        isUsedToday: true
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // TIDES
            if subscriptionService.hasAppAccess {
                NavigationLink(destination: TideMenuView()) {
                    NavigationButtonContent(
                        icon: "tsixseven",
                        title: "TIDES"
                    )
                }
            } else if subscriptionService.canAccessTideMenu() {
                Button(action: {
                    subscriptionService.recordTideMenuUsage()
                    showTideMenu = true
                }) {
                    NavigationButtonContent(
                        icon: "tsixseven",
                        title: "TIDES",
                        isDailyLimited: true,
                        dailyUsageLimit: subscriptionService.getRemainingTideMenuUses()
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    showSubscriptionPrompt = true
                }) {
                    NavigationButtonContent(
                        icon: "tsixseven",
                        title: "TIDES",
                        isUsedToday: true
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var additionalNavigationButtons: some View {
        Group {
            // CURRENTS
            if subscriptionService.hasAppAccess {
                NavigationLink(destination: CurrentMenuView()) {
                    NavigationButtonContent(
                        icon: "csixseven",
                        title: "CURRENTS"
                    )
                }
            } else if subscriptionService.canAccessCurrentMenu() {
                Button(action: {
                    subscriptionService.recordCurrentMenuUsage()
                    showCurrentMenu = true
                }) {
                    NavigationButtonContent(
                        icon: "csixseven",
                        title: "CURRENTS",
                        isDailyLimited: true,
                        dailyUsageLimit: subscriptionService.getRemainingCurrentMenuUses()
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    showSubscriptionPrompt = true
                }) {
                    NavigationButtonContent(
                        icon: "csixseven",
                        title: "CURRENTS",
                        isUsedToday: true
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // NAV UNITS
            if subscriptionService.hasAppAccess {
                NavigationLink(destination: NavUnitMenuView()) {
                    NavigationButtonContent(
                        icon: "nsixseven",
                        title: "NAV UNITS"
                    )
                }
            } else if subscriptionService.canAccessNavUnitMenu() {
                Button(action: {
                    subscriptionService.recordNavUnitMenuUsage()
                    showNavUnitMenu = true
                }) {
                    NavigationButtonContent(
                        icon: "nsixseven",
                        title: "NAV UNITS",
                        isDailyLimited: true,
                        dailyUsageLimit: subscriptionService.getRemainingNavUnitMenuUses()
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    showSubscriptionPrompt = true
                }) {
                    NavigationButtonContent(
                        icon: "nsixseven",
                        title: "NAV UNITS",
                        isUsedToday: true
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // BUOYS
            if subscriptionService.hasAppAccess {
                NavigationLink(destination: BuoyMenuView()) {
                    NavigationButtonContent(
                        icon: "bsixseven",
                        title: "BUOYS"
                    )
                }
            } else if subscriptionService.canAccessBuoyMenu() {
                Button(action: {
                    subscriptionService.recordBuoyMenuUsage()
                    showBuoyMenu = true
                }) {
                    NavigationButtonContent(
                        icon: "bsixseven",
                        title: "BUOYS",
                        isDailyLimited: true,
                        dailyUsageLimit: subscriptionService.getRemainingBuoyMenuUses()
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    showSubscriptionPrompt = true
                }) {
                    NavigationButtonContent(
                        icon: "bsixseven",
                        title: "BUOYS",
                        isUsedToday: true
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // ROUTES
            if subscriptionService.hasAppAccess {
                NavigationLink(destination: RouteMenuView()) {
                    NavigationButtonContent(
                        icon: "rsixseven",
                        title: "ROUTES"
                    )
                }
            } else if subscriptionService.canAccessRouteMenu() {
                Button(action: {
                    subscriptionService.recordRouteMenuUsage()
                    showRouteMenu = true
                }) {
                    NavigationButtonContent(
                        icon: "rsixseven",
                        title: "ROUTES",
                        isDailyLimited: true,
                        dailyUsageLimit: subscriptionService.getRemainingRouteMenuUses()
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    showSubscriptionPrompt = true
                }) {
                    NavigationButtonContent(
                        icon: "rsixseven",
                        title: "ROUTES",
                        isUsedToday: true
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // TESTING TOOLS - Only visible in debug builds, always accessible
            #if DEBUG
            NavigationLink(destination: TestingToolsView()) {
                NavigationButtonContent(
                    icon: "wrench.and.screwdriver",
                    title: "TESTING",
                    isSystemIcon: true,
                    iconColor: .orange
                )
            }
            #endif
        }
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color.white
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var mainContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 3) {
                coreNavigationButtons
                additionalNavigationButtons
            }
            .padding()
        }
        .background(backgroundGradient)
        .navigationTitle("Mariner Studio")
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if DEBUG
        // Debug paywall toggle button (leftmost)
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Reset for Testing (Logout)") {
                    Purchases.shared.logOut { customerInfo, error in
                        Task { @MainActor in
                            await subscriptionService.determineSubscriptionStatus()
                        }
                    }
                }

                Divider()

                Button("Refresh Status") {
                    Task {
                        await subscriptionService.determineSubscriptionStatus()
                    }
                }

                Button("Restore Purchases") {
                    Task {
                        await subscriptionService.restorePurchases()
                    }
                }
            } label: {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundColor(.orange)
            }
        }
        #endif
        
        // Feedback button
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: {
                showFeedback = true
            }) {
                Image(systemName: "pencil.and.list.clipboard")
                    .foregroundColor(.primary)
            }
        }

        // Settings button - Always available (rightmost)
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(destination: AppSettingsView()
                .environmentObject(subscriptionService)
                .environmentObject(cloudKitManager)) {
                Image(systemName: "gear")
                    .foregroundColor(.primary)
            }
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
                .toolbar {
                    toolbarContent
                }
                .onAppear {
                    if shouldClearNavigation {
                        clearNavigationStack()
                    }
                    // Force view refresh when returning to detect updated usage status
                    refreshTrigger.toggle()
                }
                .onChange(of: refreshTrigger) { _ in
                    // This will trigger a UI update when refreshTrigger changes
                }
                .sheet(isPresented: $showSubscriptionPrompt) {
                    PaywallView()
                        .onPurchaseCompleted { customerInfo in
                            showSubscriptionPrompt = false
                        }
                }
                .sheet(isPresented: $showFeedback) {
                    FeedbackView(sourceView: "Main Menu")
                }
                .navigationDestination(isPresented: $showMapView) {
                    MapClusteringView()
                }
                .navigationDestination(isPresented: $showWeatherMenu) {
                    WeatherMenuView()
                }
                .navigationDestination(isPresented: $showTideMenu) {
                    TideMenuView()
                }
                .navigationDestination(isPresented: $showCurrentMenu) {
                    CurrentMenuView()
                }
                .navigationDestination(isPresented: $showNavUnitMenu) {
                    NavUnitMenuView()
                }
                .navigationDestination(isPresented: $showBuoyMenu) {
                    BuoyMenuView()
                }
                .navigationDestination(isPresented: $showRouteMenu) {
                    RouteMenuView()
                }
        }
    }

    private func navigateToHome() {
        navigationPath = NavigationPath()
    }

    private func clearNavigationStack() {
         // Small delay to ensure view is fully loaded
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
             // Reset the navigation path
             navigationPath = NavigationPath()

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
     
}

// These helper structs remain the same
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
    let isPremium: Bool
    let isDailyLimited: Bool
    let isUsedToday: Bool
    let dailyUsageLimit: Int

    init(icon: String, title: String, isSystemIcon: Bool = false, iconColor: Color? = nil, isPremium: Bool = false, isDailyLimited: Bool = false, isUsedToday: Bool = false, dailyUsageLimit: Int = 1) {
        self.icon = icon
        self.title = title
        self.isSystemIcon = isSystemIcon
        self.iconColor = iconColor
        self.isPremium = isPremium
        self.isDailyLimited = isDailyLimited
        self.isUsedToday = isUsedToday
        self.dailyUsageLimit = dailyUsageLimit
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Group {
                if isSystemIcon {
                    Image(systemName: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .foregroundColor(getIconColor())
                } else {
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .opacity(getIconOpacity())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.largeTitle)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(getTextColor())

                if isPremium {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Text("PREMIUM")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                } else if isDailyLimited {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.blue)

                        Text("\(dailyUsageLimit) \(dailyUsageLimit == 1 ? "USE" : "USES")/DAY")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                } else if isUsedToday {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text("USED TODAY")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            if isPremium {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            } else if isUsedToday {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(27)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(getBorderColor(), lineWidth: getBorderWidth())
                .background(RoundedRectangle(cornerRadius: 10).fill(getBackgroundColor()))
        )
        .frame(minHeight: 110)
    }

    // Helper methods for styling
    private func getIconColor() -> Color {
        if isPremium || isUsedToday {
            return (iconColor ?? .accentColor).opacity(0.5)
        }
        return iconColor ?? .accentColor
    }

    private func getIconOpacity() -> Double {
        return (isPremium || isUsedToday) ? 0.5 : 1.0
    }

    private func getTextColor() -> Color {
        return (isPremium || isUsedToday) ? .primary.opacity(0.7) : .primary
    }

    private func getBorderColor() -> Color {
        if isPremium {
            return Color.orange.opacity(0.3)
        } else if isUsedToday {
            return Color.gray.opacity(0.3)
        } else if isDailyLimited {
            return Color.blue.opacity(0.3)
        }
        return Color.gray.opacity(0.4)
    }

    private func getBorderWidth() -> CGFloat {
        return (isPremium || isDailyLimited || isUsedToday) ? 2 : 1
    }

    private func getBackgroundColor() -> Color {
        if isPremium {
            return Color.orange.opacity(0.05)
        } else if isUsedToday {
            return Color.gray.opacity(0.05)
        } else if isDailyLimited {
            return Color.blue.opacity(0.05)
        }
        return Color.white
    }
}

