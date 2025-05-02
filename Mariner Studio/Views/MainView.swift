import SwiftUI

struct MainView: View {

    @EnvironmentObject var serviceProvider: ServiceProvider

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // MAP
                    NavigationButton(
                        icon: "earthsixfour",
                        title: "MAP",
                        action: { print("Map tapped") }
                    )

                    // WEATHER
                    NavigationButton(
                        icon: "weathersixseventwo",
                        title: "WEATHER",
                        action: { print("Weather tapped") }
                    )

                    // TIDES - MODIFIED NavigationLink
                    NavigationLink(destination: TidalHeightStationsView(
                        // Explicitly pass services from the environment's ServiceProvider
                        // Keep default for services not managed by ServiceProvider (if any)
                        tidalHeightService: TidalHeightServiceImpl(), // Assuming this isn't in ServiceProvider yet
                        locationService: serviceProvider.locationService, // Pass the shared instance
                        databaseService: serviceProvider.databaseService // Pass the shared instance
                    )) {
                        NavigationButtonContent(
                            icon: "tsixseven",
                            title: "TIDES"
                        )
                    }

                    // CURRENTS - MODIFIED NavigationLink
                    NavigationLink(destination: TidalCurrentStationsView(
                        // Explicitly pass services from the environment's ServiceProvider
                        tidalCurrentService: TidalCurrentServiceImpl(), // Assuming this isn't in ServiceProvider yet
                        locationService: serviceProvider.locationService, // Pass the shared instance
                        databaseService: serviceProvider.databaseService // Pass the shared instance
                    )) {
                        NavigationButtonContent(
                            icon: "csixseven",
                            title: "CURRENTS"
                        )
                    }

                    // NAV UNITS - MODIFIED NavigationLink
                    NavigationLink(destination: NavUnitsView(
                        // Explicitly pass services from the environment's ServiceProvider
                        databaseService: serviceProvider.databaseService, // Pass the shared instance
                        locationService: serviceProvider.locationService // Pass the shared instance
                    )) {
                        NavigationButtonContent(
                            icon: "nsixseven",
                            title: "NAV UNITS"
                        )
                    }

                    // BUOYS
                    NavigationButton(
                        icon: "buoysixseven",
                        title: "BUOYS",
                        action: { print("Buoys tapped") }
                    )

                    // TUGS
                    NavigationButton(
                        icon: "tugboatsixseven",
                        title: "TUGS",
                        action: { print("Tugs tapped") }
                    )

                    // BARGES
                    NavigationButton(
                        icon: "bargesixseventwo",
                        title: "BARGES",
                        action: { print("Barges tapped") }
                    )

                    // ROUTE
                    RouteButton(action: { print("Route tapped") })

                }
                .padding()
            }
            .navigationTitle("Mariner Studio")
        }
        // NOTE: The .environmentObject modifier for the *actual app*
        // should be in your Mariner_StudioApp.swift file, attaching to MainView() there.
    }
}

// NavigationButton struct remains the same
struct NavigationButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NavigationButtonContent(icon: icon, title: title)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// NavigationButtonContent struct remains the same
struct NavigationButtonContent: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 67, height: 67)
                .padding(.leading, 5)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.largeTitle)
            }
            .padding(.leading, 20)
            .frame(height: 67)
            .padding(.vertical, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
    }
}

// RouteButton struct remains the same
struct RouteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image("tsixseven") // Consider updating this icon if needed
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 67, height: 67)
                    .padding(.leading, 5)

                VStack(alignment: .leading) {
                    Text("Route")
                        .font(.headline)
                    Text("View Route from GPX File")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.leading, 10)
                .frame(height: 67)
                .padding(.vertical, 10)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// Preview needs the EnvironmentObject now
#Preview {
    // Create a ServiceProvider instance specifically for the preview
    let previewServiceProvider = ServiceProvider()
    return MainView()
        // Inject the preview ServiceProvider into the preview environment
        .environmentObject(previewServiceProvider)
}
