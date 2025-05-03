import SwiftUI

struct WeatherMenuView: View {
    // We'll use environment objects for service dependencies
    @EnvironmentObject var serviceProvider: ServiceProvider
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Favorites
                NavigationButton(
                    icon: "favoritesixseven",
                    title: "FAVORITES",
                    action: { navigateToWeatherFavorites() }
                )
                
                // Local Weather
                NavigationButton(
                    icon: "currentlocalweathersixseven",
                    title: "LOCAL",
                    action: { navigateToLocalWeather() }
                )
                
                // Weather Map
                NavigationButton(
                    icon: "earthsixfour",
                    title: "MAP",
                    action: { navigateToWeatherMap() }
                )
                
                // Radar
                NavigationButton(
                    icon: "radarsixseven",
                    title: "RADAR",
                    action: { navigateToRadarMap() }
                )
            }
            .padding()
        }
        .navigationTitle("Weather")
    }
    
    // Navigation Methods
    private func navigateToWeatherFavorites() {
        print("Navigate to Weather Favorites")
        // This would navigate to WeatherFavoritesView in a complete implementation
    }
    
    private func navigateToLocalWeather() {
        print("Navigate to Local Weather")
        // This would navigate to LocalWeatherView in a complete implementation
    }
    
    private func navigateToWeatherMap() {
        print("Navigate to Weather Map")
        // This would navigate to WeatherMapView in a complete implementation
    }
    
    private func navigateToRadarMap() {
        print("Navigate to Radar Map")
        // This would navigate to RadarMapView in a complete implementation
    }
}

// To maintain consistency with the existing app, I'll reuse the NavigationButton component
// already defined in MainView.swift
