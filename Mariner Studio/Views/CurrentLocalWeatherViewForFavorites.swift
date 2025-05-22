//
//  CurrentLocalWeatherViewForFavorites.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/21/25.
//


import SwiftUI
import CoreLocation

struct CurrentLocalWeatherViewForFavorites: View {
    @StateObject private var viewModel = CurrentLocalWeatherViewModelForFavorites()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    // Input parameters
    let latitude: Double
    let longitude: Double
    
    // State for hourly forecast navigation
    @State private var hourlyViewModel: HourlyForecastViewModel?
    @State private var showHourlyForecast = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    LoadingViewForFavorites()
                } else if !viewModel.errorMessage.isEmpty {
                    ErrorViewForFavorites(errorMessage: viewModel.errorMessage)
                } else {
                    // Location display
                    Text(viewModel.locationDisplay)
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Favorite toggle button
                    FavoriteButtonForFavorites(
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
                    WeatherDetailsForFavoritesView(
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
                    DailyForecastViewForFavorites(
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
        .navigationTitle("Weather")
        .onAppear {
            // Initialize with services and location coordinates
            viewModel.initialize(
                latitude: latitude,
                longitude: longitude,
                weatherService: serviceProvider.currentLocalWeatherService as? CurrentLocalWeatherServiceForMap
                    ?? CurrentLocalWeatherServiceForMapImpl(), // Fallback to new instance if needed
                geocodingService: serviceProvider.geocodingService,
                databaseService: serviceProvider.weatherService
            )
            
            viewModel.loadWeatherData()
        }
        .background(
            colorScheme == .dark ?
                Color(UIColor.systemBackground) :
                Color(UIColor.systemGroupedBackground)
        )
    }
}

// MARK: - Supporting Views

struct FavoriteButtonForFavorites: View {
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

struct LoadingViewForFavorites: View {
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

struct ErrorViewForFavorites: View {
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

// Adding the DailyForecastViewForFavorites which is needed for displaying the forecast
struct DailyForecastViewForFavorites: View {
    let forecasts: [DailyForecastItem]
    let onForecastSelected: (DailyForecastItem) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("7-Day Forecast")
                .font(.headline)
                .padding(.top, 8)
            
            Divider()
            
            if forecasts.isEmpty {
                Text("Forecast data unavailable")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(forecasts) { forecast in
                    ForecastRowForFavorites(forecast: forecast)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onForecastSelected(forecast)
                        }
                    
                    if forecast.id != forecasts.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(radius: 2)
        )
    }
}

struct ForecastRowForFavorites: View {
    let forecast: DailyForecastItem
    
    var body: some View {
        HStack {
            // Day of week
            VStack(alignment: .leading) {
                Text(forecast.isToday ? "Today" : forecast.dayOfWeek)
                    .font(.headline)
                Text(forecast.dateDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70, alignment: .leading)
            
            // Weather icon
            Image(systemName: WeatherIconMapper.mapImageName(forecast.weatherImage))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .foregroundColor(WeatherIconMapper.colorForWeatherCode(forecast.weatherCode))
                .padding(.horizontal, 8)
            
            // High/Low temperatures
            VStack(alignment: .trailing) {
                Text("\(Int(forecast.high.rounded()))°")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(Int(forecast.low.rounded()))°")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70)
            
            Spacer()
            
            // Weather details
            VStack(alignment: .trailing) {
                HStack(spacing: 4) {
                    Image(systemName: "wind")
                        .imageScale(.small)
                    Text("\(Int(forecast.windSpeed.rounded())) mph")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "drop")
                        .imageScale(.small)
                    Text(forecast.description)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            // Navigation chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .padding(.leading, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}

struct WeatherDetailsForFavoritesView: View {
    let windSpeed: String
    let windDirection: String
    let windGusts: String
    let visibility: String
    let pressure: String
    let humidity: String
    let dewPoint: String
    let precipitation: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Current Conditions")
                .font(.headline)
                .padding(.top, 8)
            
            Divider()
            
            // Weather detail grid
            VStack(spacing: 25) {
                // Wind
                DetailRowForFavorites(
                    icon: "wind",
                    title: "Wind",
                    subtitle: windDirection,
                    value: windSpeed
                )
                
                // Gusts
                DetailRowForFavorites(
                    icon: "wind.snow",
                    title: "Gusts",
                    value: windGusts
                )
                
                // Visibility
                DetailRowForFavorites(
                    icon: "eye",
                    title: "Visibility",
                    value: visibility
                )
                
                // Pressure
                DetailRowForFavorites(
                    icon: "arrow.down.to.line",
                    title: "Pressure",
                    value: "\(pressure)\""
                )
                
                // Humidity
                DetailRowForFavorites(
                    icon: "humidity",
                    title: "Humidity",
                    value: "\(humidity)%"
                )
                
                // Dew Point
                DetailRowForFavorites(
                    icon: "drop",
                    title: "Dew Point",
                    value: "\(dewPoint)°"
                )
                
                // Precipitation
                DetailRowForFavorites(
                    icon: "cloud.rain",
                    title: "24-hr Precip Estimate",
                    value: "\(precipitation) in"
                )
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(radius: 2)
        )
    }
}

struct DetailRowForFavorites: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(.primary.opacity(0.8))
                .padding(.trailing, 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    NavigationView {
        CurrentLocalWeatherViewForFavorites(
            latitude: 37.7749,
            longitude: -122.4194
        )
        .environmentObject(ServiceProvider())
    }
}