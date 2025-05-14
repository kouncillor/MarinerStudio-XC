import SwiftUI

struct CurrentMenuView: View {
    // We'll use environment objects for service dependencies
    @EnvironmentObject var serviceProvider: ServiceProvider

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Favorites - Star Icon
                NavigationLink(destination: CurrentFavoritesView()) {
                    MenuButtonContentCurrent(
                        iconType: .system("heart.fill"),
                        title: "FAVORITES",
                        color: .red
                    )
                }
                
                // Local Currents - System Icon
                NavigationLink(destination: TidalCurrentStationsView(
                    tidalCurrentService: TidalCurrentServiceImpl(),
                    locationService: serviceProvider.locationService,
                    currentStationService: serviceProvider.currentStationService
                )) {
                    MenuButtonContentCurrent(
                        iconType: .system("location.fill"),
                        title: "LOCAL",
                        color: .green
                    )
                }
                
                // Current Map - System Icon
                NavigationLink(destination: EmptyView()) {
                    MenuButtonContentCurrent(
                        iconType: .system("map.fill"),
                        title: "MAP",
                        color: .blue
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Currents")
    }
}

// Replicating the MenuButtonContent structure but with a different name to avoid conflicts
struct MenuButtonContentCurrent: View {
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
        CurrentMenuView()
            .environmentObject(ServiceProvider())
    }
}
