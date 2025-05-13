

//
//  CurrentLocalWeatherView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/11/25.
//

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
                            viewModel.navigateToHourlyForecast(forecast: forecast)
                            
                            // Create the hourly forecast view model
                            let hourlyVM = HourlyForecastViewModel(
                                weatherService: serviceProvider.openMeteoService,
                                databaseService: serviceProvider.weatherService
                            )
                            
                            hourlyVM.initialize(
                                selectedDate: forecast.date,
                                allDates: viewModel.forecastPeriods.map { $0.date },
                                latitude: viewModel.latitude,
                                longitude: viewModel.longitude,
                                locationName: viewModel.locationDisplay
                            )
                            
                            // Store the view model and trigger navigation
                            hourlyViewModel = hourlyVM
                            showHourlyForecast = true
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
        .onAppear {
            // Initialize with services from the provider
            viewModel.initialize(
                currentLocalWeatherService: serviceProvider.currentLocalWeatherService,
                geocodingService: serviceProvider.geocodingService,
                databaseService: serviceProvider.weatherService
            )
            
            // Load weather data (now includes location permission request)
            viewModel.loadWeatherData()
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
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(isFavorite ? .red : .gray)
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

#Preview {
    NavigationView {
        CurrentLocalWeatherView()
            .environmentObject(ServiceProvider())
    }
}
