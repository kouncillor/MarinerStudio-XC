import SwiftUI
import CoreLocation

struct WeatherMapLocationView: View {
    // MARK: - Properties
    let latitude: Double
    let longitude: Double
    let locationName: String
    
    @StateObject private var viewModel = WeatherMapLocationViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
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
        .navigationTitle("\(locationName) Weather")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize with services from the provider and passed location data
            viewModel.initialize(
                weatherService: serviceProvider.openMeteoService,
                geocodingService: serviceProvider.geocodingService,
                databaseService: serviceProvider.weatherService,
                latitude: latitude,
                longitude: longitude,
                locationName: locationName
            )
            
            // Load weather data immediately when view appears
            viewModel.loadWeatherData()
        }
        .onDisappear {
            // Clean up resources when view disappears
            hourlyViewModel = nil
            showHourlyForecast = false
        }
        .background(
            colorScheme == .dark ?
                Color(UIColor.systemBackground) :
                Color(UIColor.systemGroupedBackground)
        )
    }
}

// MARK: - Preview
struct WeatherMapLocationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WeatherMapLocationView(
                latitude: 40.7128,
                longitude: -74.0060,
                locationName: "New York, NY"
            )
            .environmentObject(ServiceProvider())
        }
    }
}
