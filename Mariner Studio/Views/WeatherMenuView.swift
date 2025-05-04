
import SwiftUI

struct WeatherMenuView: View {
    // We'll use environment objects for service dependencies
    @EnvironmentObject var serviceProvider: ServiceProvider
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Favorites
                NavigationLink(destination: WeatherFavoritesView()) {
                    MenuButtonContent(
                        icon: "heart.fill",
                        title: "FAVORITES"
                    )
                }
                
                // Local Weather
                NavigationLink(destination: CurrentLocalWeatherView()) {
                    MenuButtonContent(
                        icon: "location.fill",
                        title: "LOCAL"
                    )
                }
                
                // Weather Map
                NavigationLink(destination: WeatherMapView()) {
                    MenuButtonContent(
                        icon: "map.fill",
                        title: "MAP"
                    )
                }
                
                // Radar
                Button(action: {
                    openRadarWebsite()
                }) {
                    MenuButtonContent(
                        icon: "radar",
                        title: "RADAR"
                    )
                }
                
                // Settings
                NavigationLink(destination: WeatherSettingsView()) {
                    MenuButtonContent(
                        icon: "gearshape.fill",
                        title: "SETTINGS"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Weather")
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
                    "animating": false,
                    "base": "standard",
                    "artcc": false,
                    "county": false,
                    "cwa": false,
                    "rfc": false,
                    "state": false,
                    "menu": true,
                    "shortFusedOnly": false,
                    "opacity": [
                        "alerts": 0.8,
                        "local": 0.6,
                        "localStations": 0.8,
                        "national": 0.6
                    ]
                ] as [String: Any]
                
                // Encode settings to URL
                if let settingsData = try? JSONSerialization.data(withJSONObject: settings),
                   let settingsBase64 = String(data: settingsData, encoding: .utf8)?
                    .data(using: .utf8)?
                    .base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "") {
                    
                    let url = "https://radar.weather.gov/?settings=v1_\(settingsBase64)"
                    
                    if let radarURL = URL(string: url) {
                        UIApplication.shared.open(radarURL)
                    }
                }
            } else {
                // Fallback to standard radar URL if location is unavailable
                if let defaultURL = URL(string: "https://radar.weather.gov/") {
                    UIApplication.shared.open(defaultURL)
                }
            }
        }
    }
}

// MenuButtonContent component - custom styled buttons for the menu
struct MenuButtonContent: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(.blue)
                .padding(.horizontal, 20)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// Placeholder for WeatherMapView
struct WeatherMapView: View {
    var body: some View {
        VStack {
            Text("Weather Map")
                .font(.largeTitle)
                .padding()
            
            Text("Map feature coming soon")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Weather Map")
    }
}

// Placeholder for WeatherFavoritesView
struct WeatherFavoritesView: View {
    var body: some View {
        VStack {
            Text("Weather Favorites")
                .font(.largeTitle)
                .padding()
            
            Text("Favorites feature coming soon")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Favorites")
    }
}

