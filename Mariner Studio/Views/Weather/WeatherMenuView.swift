import SwiftUI

struct WeatherMenuView: View {
    // We'll use environment objects for service dependencies
    @EnvironmentObject var serviceProvider: ServiceProvider
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var showSubscriptionPrompt = false
    @State private var showLocalWeatherView = false
    @State private var refreshTrigger = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Favorites - Premium feature
                if subscriptionService.hasAppAccess {
                    NavigationLink(destination: WeatherFavoritesView(
                        coreDataManager: serviceProvider.coreDataManager
                    )) {
                        MenuButtonContent(
                            iconType: .system("star.fill"), // Star icon for favorites
                            title: "FAVORITES",
                            color: .yellow
                        )
                    }
                } else {
                    Button(action: {
                        showSubscriptionPrompt = true
                    }) {
                        MenuButtonContent(
                            iconType: .system("star.fill"),
                            title: "FAVORITES",
                            color: .yellow,
                            isPremium: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Local Weather - Free with daily limit
                if subscriptionService.hasAppAccess {
                    // Unlimited access for subscribed/trial users
                    NavigationLink(destination: CurrentLocalWeatherView()) {
                        MenuButtonContent(
                            iconType: .system("location.fill"),
                            title: "LOCAL",
                            color: .green
                        )
                    }
                } else if subscriptionService.canAccessLocalWeather() {
                    // Free user with usage available - record usage and navigate
                    Button(action: {
                        subscriptionService.recordLocalWeatherUsage()
                        showLocalWeatherView = true
                    }) {
                        MenuButtonContent(
                            iconType: .system("location.fill"),
                            title: "LOCAL",
                            color: .green,
                            isDailyLimited: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Free user has used today - show subscription prompt
                    Button(action: {
                        showSubscriptionPrompt = true
                    }) {
                        MenuButtonContent(
                            iconType: .system("location.fill"),
                            title: "LOCAL",
                            color: .green,
                            isUsedToday: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Weather Map - Premium feature
                if subscriptionService.hasAppAccess {
                    NavigationLink(destination: WeatherMapView()) {
                        MenuButtonContent(
                            iconType: .system("map.fill"), // Specify system icon for map
                            title: "MAP",
                            color: .blue
                        )
                    }
                } else {
                    Button(action: {
                        showSubscriptionPrompt = true
                    }) {
                        MenuButtonContent(
                            iconType: .system("map.fill"),
                            title: "MAP",
                            color: .blue,
                            isPremium: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Radar - Premium feature
                if subscriptionService.hasAppAccess {
                    Button(action: {
                        openRadarWebsite()
                    }) {
                        MenuButtonContent(
                            iconType: .system("antenna.radiowaves.left.and.right"), // Specify system icon
                            title: "RADAR",
                            color: .orange
                        )
                    }
                } else {
                    Button(action: {
                        showSubscriptionPrompt = true
                    }) {
                        MenuButtonContent(
                            iconType: .system("antenna.radiowaves.left.and.right"),
                            title: "RADAR",
                            color: .orange,
                            isPremium: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .navigationTitle("Weather")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0.53, green: 0.81, blue: 0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withHomeButton()
        .sheet(isPresented: $showSubscriptionPrompt) {
            EnhancedPaywallView()
        }
        .navigationDestination(isPresented: $showLocalWeatherView) {
            CurrentLocalWeatherView()
        }
        .onAppear {
            // Force view refresh when returning to detect updated usage status
            refreshTrigger.toggle()
        }
        .onChange(of: refreshTrigger) { _ in
            // This will trigger a UI update when refreshTrigger changes
        }
    }

    // Opens the NOAA radar website using Safari
    private func openRadarWebsite() {
        Task {
            // Now using the main locationService instead of weatherLocationService
            if let location = serviceProvider.locationService.currentLocation {
                // Build settings for the NOAA radar URL
                let settings = [
                    "agenda": [
                        "id": "weather",
                        "center": [location.coordinate.longitude, location.coordinate.latitude],
                        "location": [location.coordinate.longitude, location.coordinate.latitude],
                        "zoom": 10.575874024810885,
                        "layer": "bref_qcd"
                    ],
                    "animating": false, "base": "standard", "artcc": false, "county": false,
                    "cwa": false, "rfc": false, "state": false, "menu": true, "shortFusedOnly": false,
                    "opacity": ["alerts": 0.8, "local": 0.6, "localStations": 0.8, "national": 0.6]
                ] as [String: Any]
                // Encode settings to URL
                if let settingsData = try? JSONSerialization.data(withJSONObject: settings),
                   let settingsBase64 = String(data: settingsData, encoding: .utf8)?
                    .data(using: .utf8)?.base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "") {
                    let url = "https://radar.weather.gov/?settings=v1_\(settingsBase64)"
                    if let radarURL = URL(string: url) { UIApplication.shared.open(radarURL) }
                }
            } else {
                // Fallback to standard radar URL if location is unavailable
                if let defaultURL = URL(string: "https://radar.weather.gov/") { UIApplication.shared.open(defaultURL) }
            }
        }
    }
}

// The rest of the code remains unchanged
struct MenuButtonContent: View {
    // Enum to define icon type
    enum IconType {
        case system(String) // Holds SF Symbol name
        case custom(String) // Holds custom Asset name
    }

    let iconType: IconType // Use the enum
    let title: String
    let color: Color
    let isPremium: Bool
    let isDailyLimited: Bool
    let isUsedToday: Bool
    
    init(iconType: IconType, title: String, color: Color, isPremium: Bool = false, isDailyLimited: Bool = false, isUsedToday: Bool = false) {
        self.iconType = iconType
        self.title = title
        self.color = color
        self.isPremium = isPremium
        self.isDailyLimited = isDailyLimited
        self.isUsedToday = isUsedToday
    }

    var body: some View {
        HStack {
            // Create the correct image based on type FIRST
            Group {
                 switch iconType {
                 case .system(let name):
                     Image(systemName: name)
                         .resizable() // Apply modifiers directly to Image
                         .aspectRatio(contentMode: .fit)
                         .foregroundColor(getIconColor()) 
                 case .custom(let name):
                     Image(name)
                         .resizable() // Apply modifiers directly to Image
                         .aspectRatio(contentMode: .fit)
                         .foregroundColor(getIconColor())
                 }
            }
            .frame(width: 40, height: 40) // Apply frame AFTER creating/modifying the image
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(getTextColor())
                
                if isPremium {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.pink)
                        
                        Text("PREMIUM")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.pink)
                    }
                } else if isDailyLimited && !isUsedToday {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("1 USE/DAY")
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
                    .foregroundColor(.pink)
                    .padding(.trailing, 10)
            } else if isUsedToday {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .padding(.trailing, 10)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .padding(.trailing, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(getBackgroundColor())
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(getBorderColor(), lineWidth: getBorderWidth())
                )
        )
    }
    
    // MARK: - Helper Methods
    
    private func getIconColor() -> Color {
        if isPremium || isUsedToday {
            return color.opacity(0.5)
        }
        return color
    }
    
    private func getTextColor() -> Color {
        if isPremium || isUsedToday {
            return .primary.opacity(0.7)
        }
        return .primary
    }
    
    private func getBackgroundColor() -> Color {
        if isPremium {
            return Color.pink.opacity(0.08)
        } else if isUsedToday {
            return Color.gray.opacity(0.05)
        } else if isDailyLimited {
            return Color.blue.opacity(0.05)
        }
        return Color(UIColor.secondarySystemBackground)
    }
    
    private func getBorderColor() -> Color {
        if isPremium {
            return Color.pink.opacity(0.4)
        } else if isUsedToday {
            return Color.gray.opacity(0.3)
        } else if isDailyLimited {
            return Color.blue.opacity(0.3)
        }
        return Color.clear
    }
    
    private func getBorderWidth() -> CGFloat {
        if isPremium || isUsedToday || isDailyLimited {
            return 2
        }
        return 0
    }
}
