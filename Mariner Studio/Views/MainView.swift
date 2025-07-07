
import SwiftUI
import RevenueCat
import RevenueCatUI

struct MainView: View {
    // 1. ACCESS THE VIEWMODEL
    // We get the authViewModel from the environment to call signOut()
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var navigationPath = NavigationPath()
    
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
                    // Row 1: Map/Weather
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

                    // Row 2: Docks/Routes
                    NavigationLink(destination: NavUnitMenuView()) {
                        NavigationButtonContent(
                            icon: "docksixseven",
                            title: "DOCKS"
                        )
                    }

                    NavigationLink(destination: RouteMenuView()) {
                        NavigationButtonContent(
                            icon: "greencompasssixseven",
                            title: "ROUTES"
                        )
                    }

                    // Row 3: Tides/Currents
                    NavigationLink(destination: TideMenuView()) {
                        NavigationButtonContent(
                            icon: "water.waves",
                            title: "TIDES",
                            isSystemIcon: true,
                            iconColor: .green
                        )
                    }
                    
                    NavigationLink(destination: CurrentMenuView()) {
                        NavigationButtonContent(
                            icon: "arrow.right.arrow.left",
                            title: "CURRENTS",
                            isSystemIcon: true,
                            iconColor: .red
                        )
                    }
                    
                    // Row 4: Tugs/Barges
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

                    // Row 5: Buoys/Dev Tools
                    NavigationLink(destination: BuoyMenuView()) {
                        NavigationButtonContent(
                            icon: "buoysixseven",
                            title: "BUOYS"
                        )
                    }
                    
                    #if DEBUG
                    NavigationLink(destination: DevPageView()) {
                        NavigationButtonContent(
                            icon: "gear.badge",
                            title: "DEV TOOLS",
                            isSystemIcon: true,
                            iconColor: .orange
                        )
                    }
                    #endif
                }
                .padding()
            }
            .navigationTitle("Mariner Studio")
            .toolbar {
                // 2. ADD THE SIGN OUT BUTTON
                // This button will appear in the top-left for development builds.
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign Out (Dev)") {
                        Task {
                            await authViewModel.signOut()
                        }
                    }
                    .tint(.red)
                }

                // This is your existing home button
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: navigateToHome) {
                        Image(systemName: "house.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            // 3. REMOVE THE PAYWALL
            // The .presentPaywallIfNeeded modifier has been deleted from here.
            .onAppear {
                if shouldClearNavigation {
                    clearNavigationStack()
                }
            }
        }
    }
    
    private func navigateToHome() {
        navigationPath = NavigationPath()
    }
    
    // The rest of your functions (clearNavigationStack, etc.) and helper structs
    // (NavigationButton, NavigationButtonContent) remain unchanged below.
    
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







