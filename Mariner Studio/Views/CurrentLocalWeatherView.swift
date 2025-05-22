

import SwiftUI
import CoreLocation

struct CurrentLocalWeatherView: View {
    @StateObject private var viewModel = CurrentLocalWeatherViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    
    // State for hourly forecast navigation
    @State private var hourlyViewModel: HourlyForecastViewModel?
    @State private var showHourlyForecast = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    LoadingView()
                } else if !viewModel.errorMessage.isEmpty {
                    ErrorView(errorMessage: viewModel.errorMessage)
                } else {
                    // Location display
                    Text(viewModel.locationDisplay)
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Favorite toggle button
                    FavoriteButton(
                        isFavorite: viewModel.isFavorite,
                        action: { viewModel.toggleFavorite() }
                    )
                    
                    // Main weather info
                    WeatherHeaderView(
                        temperature: viewModel.temperature,
                        feelsLike: viewModel.feelsLike,
                        weatherDescription: viewModel.weatherDescription,
                        weatherImage: viewModel.weatherImage
                    )
                    
                    // Current weather details
                    WeatherDetailsView(
                        windSpeed: viewModel.windSpeed,
                        windDirection: viewModel.windDirection,
                        windGusts: viewModel.windGusts,
                        visibility: viewModel.visibility,
                        pressure: viewModel.pressure,
                        humidity: viewModel.humidity,
                        dewPoint: viewModel.dewPoint,
                        precipitation: viewModel.precipitation
                    )
                    
                    // 7-Day forecast with navigation to hourly view
                    DailyForecastView(
                        forecasts: viewModel.forecastPeriods,
                        onForecastSelected: { forecast in
                            print("🕐 Selected forecast for date: \(forecast.date), isToday: \(forecast.isToday)")
                            
                            // Always force navigation to close first (if open)
                            showHourlyForecast = false
                            
                            // Reset the view model reference
                            hourlyViewModel = nil
                            
                            // Create delay to ensure proper state reset
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                // Create a brand new hourly forecast view model each time
                                hourlyViewModel = HourlyForecastViewModel(
                                    weatherService: serviceProvider.openMeteoService,
                                    databaseService: serviceProvider.weatherService
                                )
                                
                                // Initialize with the selected forecast date
                                hourlyViewModel?.initialize(
                                    selectedDate: forecast.date,
                                    allDates: viewModel.forecastPeriods.map { $0.date },
                                    latitude: viewModel.latitude,
                                    longitude: viewModel.longitude,
                                    locationName: viewModel.locationDisplay
                                )
                                
                                // Trigger navigation
                                showHourlyForecast = true
                            }
                        }
                    )
                    .background(
                        NavigationLink(
                            destination: Group {
                                if let viewModel = hourlyViewModel {
                                    HourlyForecastView(viewModel: viewModel)
                                }
                            },
                            isActive: $showHourlyForecast,
                            label: { EmptyView() }
                        )
                    )
                    
                    // Attribution
                    Text(viewModel.attribution)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                }
            }
            .padding()
        }
        .navigationTitle("Current Weather")
        .withHomeButton()
        
        .onAppear {
            // Initialize with services from the provider, but not the location service
            viewModel.initialize(
                currentLocalWeatherService: serviceProvider.currentLocalWeatherService,
                geocodingService: serviceProvider.geocodingService,
                databaseService: serviceProvider.weatherService
            )
            
            // Load weather data (now includes location permission request)
            viewModel.loadWeatherData()
        }
        .onDisappear {
            // Cancel any ongoing tasks when view disappears
            // This prevents stale tasks from continuing when we return
            viewModel.cleanup()
        }
        .background(
            colorScheme == .dark ?
                Color(UIColor.systemBackground) :
                Color(UIColor.systemGroupedBackground)
        )
    }
}

// Supporting views remain unchanged
struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
            impactGenerator.prepare()
            impactGenerator.impactOccurred()
            action()
        }) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(isFavorite ? .yellow : .gray)
                .padding()
                .background(Color(UIColor.tertiarySystemBackground))
                .clipShape(Circle())
                .shadow(radius: 2)
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading weather data...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
}

struct ErrorView: View {
    let errorMessage: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title)
                .foregroundColor(.primary)
            
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.vertical, 40)
    }
}

