


import SwiftUI

struct TideMenuView: View {
    // We'll use environment objects for service dependencies
    @EnvironmentObject var serviceProvider: ServiceProvider

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Favorites - Star Icon
                NavigationLink(destination: TideFavoritesView()) {
                    MenuButtonContentTide(
                        iconType: .system("heart.fill"), // Using star instead of heart to differentiate from weather
                        title: "FAVORITES",
                        color: .red
                    )
                }
                
                // Local Tides - System Icon
                NavigationLink(destination: TidalHeightStationsView(
                    tidalHeightService: TidalHeightServiceImpl(),
                    locationService: serviceProvider.locationService,
                    tideStationService: serviceProvider.tideStationService
                )) {
                    MenuButtonContentTide(
                        iconType: .system("location.fill"), // Specify system icon
                        title: "LOCAL",
                        color: .green
                    )
                }
                
                // Tide Map - System Icon
                NavigationLink(destination: EmptyView()) {
                    MenuButtonContentTide(
                        iconType: .system("map.fill"), // Specify system icon for map
                        title: "MAP",
                        color: .blue
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Tides")
    }
}

// Replicating the MenuButtonContent structure but with a different name to avoid conflicts
struct MenuButtonContentTide: View {
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

#Preview {
    NavigationView {
        TideMenuView()
            .environmentObject(ServiceProvider())
    }
}
