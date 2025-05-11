import SwiftUI

struct WeatherMenuView: View {
    // We'll use environment objects for service dependencies
    @EnvironmentObject var serviceProvider: ServiceProvider

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Local Weather - System Icon
                NavigationLink(destination: CurrentLocalWeatherView()) {
                    MenuButtonContent(
                        iconType: .system("location.fill"), // Specify system icon
                        title: "LOCAL",
                        color: .green
                    )
                }
                
                // Weather Map - System Icon
                NavigationLink(destination: WeatherMapView()) {
                    MenuButtonContent(
                        iconType: .system("map.fill"), // Specify system icon for map
                        title: "MAP",
                        color: .blue
                    )
                }

                // Radar - System Icon
                Button(action: {
                    openRadarWebsite()
                }) {
                    MenuButtonContent(
                        iconType: .system("antenna.radiowaves.left.and.right"), // Specify system icon
                        title: "RADAR",
                        color: .orange
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

    var body: some View {
        HStack {
            // Create the correct image based on type FIRST
            Group {
                 switch iconType {
                 case .system(let name):
                     Image(systemName: name)
                         .resizable() // Apply modifiers directly to Image
                         .aspectRatio(contentMode: .fit)
                         .foregroundColor(color) // Apply color
                 case .custom(let name):
                     Image(name)
                         .resizable() // Apply modifiers directly to Image
                         .aspectRatio(contentMode: .fit)
                         // Conditionally apply foregroundColor ONLY if it's a template image.
                         // For simplicity now, we apply it, but it might need adjustment
                         // based on your asset settings.
                         .foregroundColor(color) // Attempt to apply color
                 }
            }
            .frame(width: 40, height: 40) // Apply frame AFTER creating/modifying the image
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
