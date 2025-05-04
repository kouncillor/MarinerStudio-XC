import SwiftUI

struct HourlyForecastView: View {
    @StateObject private var viewModel: HourlyForecastViewModel
    @Environment(\.presentationMode) var presentationMode
    
    init(viewModel: HourlyForecastViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Location and Day Navigation
            VStack(spacing: 4) {
                Text(viewModel.locationDisplay)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button(action: {
                        viewModel.previousDay()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(viewModel.canGoToPreviousDay ? .red : .gray)
                    }
                    .disabled(!viewModel.canGoToPreviousDay)
                    .padding(.horizontal)
                    
                    Text(viewModel.currentDayDisplay)
                        .font(.headline)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        viewModel.nextDay()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(viewModel.canGoToNextDay ? .green : .gray)
                    }
                    .disabled(!viewModel.canGoToNextDay)
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            .padding(.top, 8)
            .background(Color(UIColor.systemBackground))
            
            // Column Headers
            HStack(spacing: 0) {
                HeaderColumn(icon: "clock", title: "Time")
                HeaderColumn(icon: "thermometer", title: "Temp")
                HeaderColumn(icon: "wind", title: "Wind")
                HeaderColumn(icon: "eye", title: "Vis")
                HeaderColumn(icon: "barometer", title: "Press")
                HeaderColumn(icon: "drop", title: "Precip")
            }
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBlue).opacity(0.1))
            
            // Hourly Data
            ScrollView {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else if viewModel.currentDayHourlyForecasts.isEmpty {
                    Text("No hourly data available for this day")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.currentDayHourlyForecasts.enumerated()), id: \.element.id) { index, forecast in
                            HourlyForecastRow(
                                forecast: forecast,
                                isEvenRow: index % 2 == 0
                            )
                            
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
            }
        }
        .navigationBarTitle("Hourly Forecast", displayMode: .inline)
        .navigationBarBackButtonHidden(false)
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            viewModel.loadHourlyForecasts()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

// MARK: - Supporting Views

struct HeaderColumn: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HourlyForecastRow: View {
    let forecast: HourlyForecastItem
    let isEvenRow: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Time Column
            VStack(alignment: .center, spacing: 2) {
                Text(forecast.hour)
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            
            // Temperature Column
            VStack(alignment: .center, spacing: 2) {
                Text("\(Int(forecast.temperature.rounded()))°")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                
                Text("\(Int(forecast.dewPoint.rounded()))° DP")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
                Text("\(forecast.humidity)% RH")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity)
            
            // Wind Column
            VStack(alignment: .center, spacing: 2) {
                Text("\(forecast.cardinalDirection)")
                    .font(.system(size: 14, weight: .medium))
                
                Text("\(Int(forecast.windSpeed.rounded()))")
                    .font(.system(size: 14))
                
                Text("\(Int(forecast.windGusts.rounded()))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            // Visibility Column
            VStack(alignment: .center, spacing: 4) {
                Text(forecast.visibility)
                    .font(.system(size: 14))
                
                // Weather icon
                Image(systemName: weatherIconForCode(forecast.weatherCode, isNight: forecast.isNightTime))
                    .font(.system(size: 16))
                    .foregroundColor(colorForWeatherCode(forecast.weatherCode))
            }
            .frame(maxWidth: .infinity)
            
            // Pressure Column
            VStack(alignment: .center, spacing: 4) {
                Text(String(format: "%.2f", forecast.pressure))
                    .font(.system(size: 14))
                
                if let _ = forecast.previousPressure {
                    Image(systemName: forecast.pressureTrendIcon)
                        .font(.system(size: 14))
                        .foregroundColor(forecast.pressureTrendIcon == "arrow.up" ? .green :
                                         forecast.pressureTrendIcon == "arrow.down" ? .red : .gray)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Precipitation Column
            VStack(alignment: .center, spacing: 4) {
                Text("\(Int(forecast.precipitationChance.rounded()))%")
                    .font(.system(size: 14))
                
                Text(String(format: "%.2f\"", forecast.precipitation))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .background(
            isEvenRow ?
                Color(UIColor.secondarySystemBackground) :
                Color(UIColor.systemBackground)
        )
    }
    
    // Helper functions to map weather codes to SF Symbols
    private func weatherIconForCode(_ code: Int, isNight: Bool) -> String {
        return WeatherIconMapper.mapWeatherCode(code, isNight: isNight)
    }
    
    private func colorForWeatherCode(_ code: Int) -> Color {
        return WeatherIconMapper.colorForWeatherCode(code)
    }
}
// Create a preview
struct HourlyForecastView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HourlyForecastView(
                viewModel: createSampleViewModel()
            )
        }
    }
    
    static func createSampleViewModel() -> HourlyForecastViewModel {
        let viewModel = HourlyForecastViewModel()
        
        // Create sample dates
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: today)!
        
        viewModel.initialize(
            selectedDate: today,
            allDates: [today, tomorrow, dayAfter],
            latitude: 40.7128,
            longitude: -74.0060,
            locationName: "New York, NY"
        )
        
        // Add some sample forecast data
        let sampleForecasts1 = (0..<24).map { hour -> HourlyForecastItem in
            let time = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
            return createSampleForecast(time: time, rowIndex: hour)
        }
        
        let sampleForecasts2 = (0..<24).map { hour -> HourlyForecastItem in
            let time = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow)!
            return createSampleForecast(time: time, rowIndex: hour)
        }
        
        viewModel.dailyHourlyForecasts = [
            DailyHourlyForecast(date: today, hourlyForecasts: sampleForecasts1),
            DailyHourlyForecast(date: tomorrow, hourlyForecasts: sampleForecasts2)
        ]
        
        viewModel.updateCurrentDayForecasts()
        
        return viewModel
    }
    
    static func createSampleForecast(time: Date, rowIndex: Int) -> HourlyForecastItem {
        let isNight = time.hour >= 18 || time.hour < 6
        let temp = 65.0 + Double((rowIndex % 10) - 5)
        
        return HourlyForecastItem(
            time: time,
            hour: time.formatted(date: .omitted, time: .shortened),
            timeDisplay: time.formatted(date: .numeric, time: .standard),
            temperature: temp,
            humidity: 65 + (rowIndex % 20),
            precipitation: Double(rowIndex % 5) * 0.1,
            precipitationChance: Double((rowIndex * 3) % 100),
            windSpeed: 5.0 + Double(rowIndex % 8),
            windDirection: Double((rowIndex * 20) % 360),
            windGusts: 8.0 + Double(rowIndex % 10),
            dewPoint: temp - 10.0,
            pressure: 29.92 + (Double(rowIndex % 10) - 5) * 0.01,
            previousPressure: 29.90 + (Double((rowIndex - 1) % 10) - 5) * 0.01,
            visibilityMeters: 10000.0 - Double((rowIndex * 500) % 5000),
            weatherCode: (rowIndex % 5) * 2,
            isNightTime: isNight,
            cardinalDirection: ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][rowIndex % 8],
            weatherIcon: isNight ? "moon.stars" : "sun.max",
            moonPhase: "moonphase.full.moon"
        )
    }
    
    
    
    
    
}


