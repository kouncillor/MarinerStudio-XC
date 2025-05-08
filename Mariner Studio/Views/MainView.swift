import SwiftUI
import RevenueCat // Ensure RevenueCat is imported
import RevenueCatUI

struct MainView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // In MainView.swift, update the NavigationLink for MAP:
                    NavigationLink(destination: MapClusteringView(
                        navUnitService: serviceProvider.navUnitService,
                        tideStationService: serviceProvider.tideStationService,
                        currentStationService: serviceProvider.currentStationService,
                        locationService: serviceProvider.locationService
                    )) {
                        NavigationButtonContent(
                            icon: "earthsixfour",
                            title: "MAP"
                        )
                    }

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
                NavigationView { // Consider using .fullScreenCover or if NavigationView is essential here
                    WeatherSettingsView()
                        .navigationBarItems(trailing: Button("Done") {
                            showSettings = false
                        })
                }
            }
        }
        // Apply the .presentPaywallIfNeeded modifier to the NavigationStack
        // This will present the paywall if the "Pro" entitlement is not active
        // when MainView appears.
     //   .presentPaywallIfNeeded(requiredEntitlementIdentifier: "Pro")
        
        
        
        
        
        .presentPaywallIfNeeded(
                    requiredEntitlementIdentifier: "Pro",
                    
                    presentationMode: .fullScreen
                )
    
    }
}

// Your existing NavigationButton, NavigationButtonContent, and RouteButton structs remain the same:

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

struct RouteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image("tsixseven") // Assuming this is an intended placeholder or actual image
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

// Make sure you have placeholders or actual implementations for:
// ServiceProvider, MapClusteringView, WeatherMenuView, TidalHeightStationsView,
// TidalCurrentStationsView, NavUnitsView, WeatherSettingsView,
// TidalHeightServiceImpl, TidalCurrentServiceImpl, and any services they depend on.

// Also, ensure RevenueCat SDK is configured, typically in your App's init or onAppear:
// Purchases.configure(withAPIKey: "your_api_key")
// And that you have defined an entitlement named "Pro" in your RevenueCat dashboard.
