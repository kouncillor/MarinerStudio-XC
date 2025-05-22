import SwiftUI
import CoreLocation

struct CurrentLocalWeatherViewForMap: View {
    @StateObject private var viewModel = CurrentLocalWeatherViewModelForMap()
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
                    LoadingViewForMap()
                } else if !viewModel.errorMessage.isEmpty {
                    ErrorViewForMap(errorMessage: viewModel.errorMessage)
                } else {
                    // Location display
                    Text(viewModel.locationDisplay)
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Favorite toggle button
                    FavoriteButtonForMap(
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
                    WeatherDetailsForMapView(
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
                    DailyForecastViewForMap(
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

// MARK: - Supporting Views

struct FavoriteButtonForMap: View {
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

struct LoadingViewForMap: View {
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

struct ErrorViewForMap: View {
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

struct WeatherDetailsForMapView: View {
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
                // Wind - using SF Symbol with blue color
                DetailRowForMap(
                    iconSource: .system("wind", .blue),
                    title: "Wind",
                    subtitle: windDirection,
                    value: windSpeed
                )
                
                // Gusts - using SF Symbol with red color
                DetailRowForMap(
                    iconSource: .system("wind", .red),
                    title: "Gusts",
                    value: windGusts
                )
                
                // Visibility - using custom image
                DetailRowForMap(
                    iconSource: .custom("visibilitysixseven"),
                    title: "Visibility",
                    value: visibility
                )
                
                // Pressure - using custom image with purple color
                DetailRowForMap(
                    iconSource: .custom("pressuresixseven", .purple),
                    title: "Pressure",
                    value: "\(pressure)\""
                )
                
                // Humidity - using SF Symbol with cyan color
                DetailRowForMap(
                    iconSource: .system("humidity", .cyan),
                    title: "Humidity",
                    value: "\(humidity)%"
                )
                
                // Dew Point - using SF Symbol with orange color
                DetailRowForMap(
                    iconSource: .system("drop", .orange),
                    title: "Dew Point",
                    value: "\(dewPoint)°"
                )
                
                // Precipitation - using SF Symbol with default color
                DetailRowForMap(
                    iconSource: .system("cloud.rain"),
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

struct DetailRowForMap: View {
    let iconSource: IconSourceForMap
    let title: String
    var subtitle: String? = nil
    let value: String
    
    var body: some View {
        HStack {
            // Display either SF Symbol or custom image based on iconSource
            Group {
                switch iconSource {
                case .system(let name, let color):
                    Image(systemName: name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(color ?? .primary.opacity(0.8))
                case .custom(let name, let color):
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(color ?? .primary.opacity(0.8))
                }
            }
            .frame(width: 24, height: 24)
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

// Icon source enum for map
enum IconSourceForMap {
    case system(String, Color? = nil)
    case custom(String, Color? = nil)
}

struct DailyForecastViewForMap: View {
    let forecasts: [DailyForecastItem]
    let onForecastSelected: (DailyForecastItem) -> Void
    
    @State private var expandedForecastId: UUID? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("7-DAY FORECAST")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.vertical, 4)
            
            // Forecast header row
            ForecastHeaderRowForMap()
            
            // Forecast items
            if forecasts.isEmpty {
                Text("No forecast data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(forecasts) { forecast in
                    DailyForecastRowViewForMap(
                        forecast: forecast,
                        isExpanded: forecast.id == expandedForecastId,
                        isToday: forecast.isToday
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if expandedForecastId == forecast.id {
                                expandedForecastId = nil
                            } else {
                                expandedForecastId = forecast.id
                            }
                        }
                        
                        // Also trigger the navigation callback
                        onForecastSelected(forecast)
                    }
                    
                    if forecast.id != forecasts.last?.id {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(radius: 2)
        )
    }
}

struct ForecastHeaderRowForMap: View {
    var body: some View {
        HStack {
            Text("Date")
                .frame(width: 60, alignment: .leading)
            
            Image(systemName: "thermometer")
                .frame(width: 60)
                .foregroundColor(.orange)
            
            Image(systemName: "moon.stars")
                .frame(width: 40)
                .foregroundColor(.yellow)
            
            Image(systemName: "wind")
                .frame(width: 40)
                .foregroundColor(.blue)
            
            Image(systemName: "eye")
                .frame(width: 40)
                .foregroundColor(.green)
            
            Image(systemName: "arrow.down.to.line")
                .frame(width: 40)
                .foregroundColor(.purple)
        }
        .font(.caption)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(UIColor.systemBlue).opacity(0.1))
        .cornerRadius(8)
    }
}

struct DailyForecastRowViewForMap: View {
    let forecast: DailyForecastItem
    let isExpanded: Bool
    let isToday: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row content
            HStack(alignment: .center) {
                // Date column
                VStack(alignment: .leading, spacing: 2) {
                    Text(forecast.dayOfWeek)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(forecast.dateDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isToday {
                        Text("TODAY")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                .frame(width: 60, alignment: .leading)
                
                // Temperature column
                VStack(spacing: 4) {
                    TemperaturePillForMap(
                        temperature: Int(forecast.high.rounded()),
                        isHigh: true
                    )
                    
                    TemperaturePillForMap(
                        temperature: Int(forecast.low.rounded()),
                        isHigh: false
                    )
                }
                .frame(width: 60)
                
                // Moon phase column
                VStack(spacing: 6) {
                    moonPhaseIconForMap
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: forecast.isWaxingMoon ? "arrow.up" : "arrow.down")
                        .foregroundColor(forecast.isWaxingMoon ? .green : .red)
                        .font(.caption)
                }
                .frame(width: 40)
                
                // Wind column
                VStack(alignment: .center, spacing: 2) {
                    Text(forecast.windDirection)
                        .font(.caption)
                    
                    Text("\(Int(forecast.windSpeed))")
                        .font(.caption)
                    
                    Text("\(Int(forecast.windGusts))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 40)
                
                // Visibility column
                VStack(alignment: .center, spacing: 4) {
                    Text(forecast.visibility)
                        .font(.caption)
                    
                    weatherIconForMap
                        .frame(width: 24, height: 24)
                }
                .frame(width: 40)
                
                // Pressure column
                VStack(alignment: .center, spacing: 2) {
                    Text(String(format: "%.1f", forecast.pressure))
                        .font(.caption)
                    
                    Text("inHg")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 40)
            }
            .padding(.vertical, 8)
            .background(
                isToday ?
                    Color.green.opacity(0.1) :
                    (forecast.rowIndex % 2 == 0 ?
                        Color(UIColor.secondarySystemBackground) :
                        Color.clear)
            )
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tap for hourly forecast")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    if !forecast.description.isEmpty {
                        Text(forecast.description)
                            .font(.callout)
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(UIColor.systemGray6))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .cornerRadius(8)
    }
    
    // Dynamic weather icon based on weather code
    private var weatherIconForMap: some View {
        Group {
            if forecast.weatherImage.contains("sun") {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.yellow)
            } else if forecast.weatherImage.contains("fewclouds") {
                Image(systemName: "cloud.sun.fill")
                    .foregroundColor(.gray)
            } else if forecast.weatherImage.contains("cloud") || forecast.weatherImage.contains("overcast") {
                Image(systemName: "cloud.fill")
                    .foregroundColor(.gray)
            } else if forecast.weatherImage.contains("rain") || forecast.weatherImage.contains("drizzle") {
                Image(systemName: "cloud.rain.fill")
                    .foregroundColor(.blue)
            } else if forecast.weatherImage.contains("snow") {
                Image(systemName: "snowflake")
                    .foregroundColor(.cyan)
            } else if forecast.weatherImage.contains("storm") || forecast.weatherImage.contains("thunder") {
                Image(systemName: "cloud.bolt.fill")
                    .foregroundColor(.purple)
            } else if forecast.weatherImage.contains("fog") {
                Image(systemName: "cloud.fog.fill")
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Dynamic moon phase icon
    private var moonPhaseIconForMap: some View {
        Group {
            if forecast.moonPhaseIcon.contains("newmoon") {
                Image(systemName: "moonphase.new.moon")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("waxingcrescent") {
                Image(systemName: "moonphase.waxing.crescent")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("firstquarter") {
                Image(systemName: "moonphase.first.quarter")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("waxinggibbous") {
                Image(systemName: "moonphase.waxing.gibbous")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("fullmoon") {
                Image(systemName: "moonphase.full.moon")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("waninggibbous") {
                Image(systemName: "moonphase.waning.gibbous")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("lastquarter") {
                Image(systemName: "moonphase.last.quarter")
                    .foregroundColor(.indigo)
            } else if forecast.moonPhaseIcon.contains("waningcrescent") {
                Image(systemName: "moonphase.waning.crescent")
                    .foregroundColor(.indigo)
            } else {
                Image(systemName: "moonphase.new.moon")
                    .foregroundColor(.indigo)
            }
        }
    }
}

struct TemperaturePillForMap: View {
    let temperature: Int
    let isHigh: Bool
    
    var body: some View {
        Text("\(temperature)°")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHigh ? Color.green : Color.blue)
            )
            .frame(width: 40)
    }
}

#Preview {
    NavigationView {
        CurrentLocalWeatherViewForMap(
            latitude: 37.7749,
            longitude: -122.4194
        )
        .environmentObject(ServiceProvider())
    }
}



