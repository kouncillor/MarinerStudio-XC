import SwiftUI

struct MainView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var showSettings = false

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
                    NavigationLink(destination: WeatherMenuView()) {
                        NavigationButtonContent(
                            icon: "weathersixseventwo",
                            title: "WEATHER"
                        )
                    }

                    // TIDES
                    NavigationLink(destination: TidalHeightStationsView(
                        tidalHeightService: TidalHeightServiceImpl(),
                        locationService: serviceProvider.locationService,
                        tideStationService: serviceProvider.tideStationService
                    )) {
                        NavigationButtonContent(
                            icon: "tsixseven",
                            title: "TIDES"
                        )
                    }

                    // CURRENTS
                    NavigationLink(destination: TidalCurrentStationsView(
                        tidalCurrentService: TidalCurrentServiceImpl(),
                        locationService: serviceProvider.locationService,
                        currentStationService: serviceProvider.currentStationService
                    )) {
                        NavigationButtonContent(
                            icon: "csixseven",
                            title: "CURRENTS"
                        )
                    }

                    // NAV UNITS
                    NavigationLink(destination: NavUnitsView(
                        navUnitService: serviceProvider.navUnitService,
                        locationService: serviceProvider.locationService
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationView {
                    WeatherSettingsView()
                        .navigationBarItems(trailing: Button("Done") {
                            showSettings = false
                        })
                }
            }
        }
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
                Image("tsixseven")
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

// Preview
#Preview {
    let previewServiceProvider = ServiceProvider()
    return MainView()
        .environmentObject(previewServiceProvider)
}
