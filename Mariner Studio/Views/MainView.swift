
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
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    // MAP
                    NavigationLink(destination: MapClusteringView()) {
                        NavigationButtonContent(
                            icon: "earthsixfour",
                            title: "MAP"
                        )
                    }

                    // WEATHER
                    NavigationLink(destination: WeatherMenuView()) {
                        NavigationButtonContent(
                           // icon: "weathersixseventwo",
                            icon: "weathersunsixseven",
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
                    
                    // CURRENTS
                    NavigationLink(destination: CurrentMenuView()) {
                        NavigationButtonContent(
                            icon: "csixseven",
                            title: "CURRENTS"
                        )
                    }
                    
                    // DOCKS
                    NavigationLink(destination: NavUnitMenuView()) {
                        NavigationButtonContent(
                            icon: "nsixseven",
                            title: "NAV UNITS"
                        )
                    }
                    
                    // BUOYS
                    NavigationLink(destination: BuoyMenuView()) {
                        NavigationButtonContent(
                            icon: "bsixseven",
                            title: "BUOYS"
                        )
                    }

                    // ROUTES
                    NavigationLink(destination: RouteMenuView()) {
                        NavigationButtonContent(
                            icon: "rsixseven",
                            title: "ROUTES"
                        )
                    }

                    // TUGS
                    NavigationLink(destination: TugsView(
                        vesselService: serviceProvider.vesselService
                    )) {
                        NavigationButtonContent(
                            icon: "tugboatsixseven",
                            title: "TUGS"
                        )
                    }

                    // BARGES
                    NavigationLink(destination: BargesView(
                        vesselService: serviceProvider.vesselService
                    )) {
                        NavigationButtonContent(
                            icon: "bargesixseventwo",
                            title: "BARGES"
                        )
                    }

                    // DEV TOOLS
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
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color.white
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Mariner Studio")
            .toolbar {
                #if DEBUG
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
                #endif
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
        HStack(alignment: .center, spacing: 16) {
            Group {
                if isSystemIcon {
                    Image(systemName: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .foregroundColor(iconColor ?? .accentColor)
                } else {
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                }
            }

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(red: 0.0, green: 0.0, blue: 0.5), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
        .frame(minHeight: 80)
    }
}







