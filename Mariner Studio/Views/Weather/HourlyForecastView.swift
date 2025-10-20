import SwiftUI

struct HourlyForecastView: View {
    @StateObject private var viewModel: HourlyForecastViewModel
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var showingWaveDetail = false
    @State private var selectedHourIndex: Int?
    @State private var selectedDate: Date?
    @State private var selectedLocationName: String?
    @State private var selectedForecasts: [HourlyForecastItem] = []
    @State private var selectedLatitude: Double = 0.0
    @State private var selectedLongitude: Double = 0.0

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
            .background(Color(UIColor.systemGroupedBackground))

            // Column Headers
            HStack(spacing: 0) {
                HeaderColumn(iconSource: .system("clock", .orange), title: "Time")
                HeaderColumn(iconSource: .system("thermometer", .red), title: "Temp")
                HeaderColumn(iconSource: .custom("visibilitysixseven", .green), title: "Vis")
                HeaderColumn(iconSource: .system("wind", .blue), title: "Wind")
                HeaderColumn(iconSource: .system("water.waves", .teal), title: "Wave")
                HeaderColumn(iconSource: .system("drop", .cyan), title: "Precip")
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
                                isEvenRow: index % 2 == 0,
                                onWaveTap: {
                                    // Capture data before navigation (before cleanup can run)
                                    selectedHourIndex = index
                                    selectedForecasts = viewModel.currentDayHourlyForecasts
                                    selectedLocationName = viewModel.locationDisplay
                                    selectedLatitude = viewModel.latitude
                                    selectedLongitude = viewModel.longitude
                                    if viewModel.currentDayIndex < viewModel.availableDates.count {
                                        selectedDate = viewModel.availableDates[viewModel.currentDayIndex]
                                    }
                                    showingWaveDetail = true
                                }
                            )

                            Divider()
                                .padding(.leading)
                        }
                    }
                }
            }
        }
        .navigationBarTitle("Hourly Forecast", displayMode: .inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0.53, green: 0.81, blue: 0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withNotificationAndHome(sourceView: "Hourly Forecast")

        .navigationBarBackButtonHidden(false)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationDestination(isPresented: $showingWaveDetail) {
            if let hourIndex = selectedHourIndex,
               let date = selectedDate,
               let locationName = selectedLocationName,
               !selectedForecasts.isEmpty {
                let waveViewModel = HourlyWaveDetailViewModel(
                    hourlyForecasts: selectedForecasts,
                    selectedHourIndex: hourIndex,
                    locationName: locationName,
                    date: date,
                    latitude: selectedLatitude,
                    longitude: selectedLongitude,
                    tidalCurrentService: serviceProvider.tidalCurrentService,
                    tidalCurrentPredictionService: serviceProvider.tidalCurrentPredictionService
                )
                HourlyWaveDetailView(viewModel: waveViewModel)
            }
        }
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
    let iconSource: IconSource
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            // Display either SF Symbol or custom image based on iconSource
            Group {
                switch iconSource {
                case .system(let name, let color):
                    Image(systemName: name)
                        .font(.system(size: 16))
                        .foregroundColor(color ?? .primary)
                case .custom(let name, let color):
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(color ?? .primary)
                }
            }

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
    let onWaveTap: () -> Void

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

            // Wave Column (Tappable)
            Button(action: {
                if forecast.marineDataAvailable {
                    onWaveTap()
                }
            }) {
                VStack(alignment: .center, spacing: 2) {
                    if forecast.marineDataAvailable {
                        Text(forecast.waveDirectionCardinal)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.teal)

                        Text("\(String(format: "%.1f", forecast.waveHeight)) ft")
                            .font(.system(size: 14))
                            .foregroundColor(.teal)

                        Text("\(Int(forecast.wavePeriod.rounded()))s")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text("N/A")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!forecast.marineDataAvailable)

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
