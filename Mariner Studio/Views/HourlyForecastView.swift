

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
                        .padding(.horizontal)
                        .id("day-\(viewModel.currentDayIndex)") // Add ID to force refresh when day changes
                    
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
            // Each time the view appears, reload data
            print("🕐 HourlyForecastView appeared - loading forecasts for day \(viewModel.currentDayIndex) - \(viewModel.currentDayDisplay)")
            viewModel.loadHourlyForecasts()
        }
        .onDisappear {
            // Properly clean up resources when view disappears
            print("🕐 HourlyForecastView disappeared - cleaning up resources")
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
