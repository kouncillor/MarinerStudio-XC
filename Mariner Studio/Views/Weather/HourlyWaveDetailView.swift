import SwiftUI

struct HourlyWaveDetailView: View {
    @StateObject private var viewModel: HourlyWaveDetailViewModel
    @Environment(\.presentationMode) var presentationMode

    init(viewModel: HourlyWaveDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Location and Date Header
            VStack(spacing: 4) {
                Text(viewModel.locationDisplay)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(viewModel.dateDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(Color(UIColor.systemGroupedBackground))

            // Hour Navigation
            VStack(spacing: 4) {
                HStack {
                    Button(action: {
                        viewModel.previousHour()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(viewModel.canGoToPreviousHour ? .blue : .gray)
                    }
                    .disabled(!viewModel.canGoToPreviousHour)
                    .padding(.horizontal)

                    VStack(spacing: 2) {
                        Text(viewModel.currentHourDisplay)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text(viewModel.currentTimeDisplay)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .id("hour-\(viewModel.currentHourIndex)") // Force refresh when hour changes

                    Button(action: {
                        viewModel.nextHour()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(viewModel.canGoToNextHour ? .blue : .gray)
                    }
                    .disabled(!viewModel.canGoToNextHour)
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            .background(Color(UIColor.systemGroupedBackground))

            Divider()

            // Wave Data Content
            ScrollView {
                if let forecast = viewModel.currentForecast {
                    if forecast.marineDataAvailable {
                        VStack(spacing: 16) {
                            // Total Wave Card
                            TotalWaveCard(
                                height: "\(String(format: "%.1f", forecast.waveHeight)) ft",
                                direction: forecast.waveDirectionCardinal,
                                period: "\(Int(forecast.wavePeriod))s period"
                            )
                            .padding(.horizontal)
                            .padding(.top, 16)

                            // Swell Card
                            SwellCard(forecast: forecast)
                                .padding(.horizontal)

                            // Wind Wave Card
                            WindWaveCard(forecast: forecast)
                                .padding(.horizontal)
                        }
                        .padding(.bottom, 20)
                    } else {
                        // No marine data available
                        VStack(spacing: 16) {
                            Image(systemName: "water.waves.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text("No Marine Data Available")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Wave data is not available for this location or time.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 60)
                    }
                } else {
                    Text("No forecast data available")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
        .navigationTitle("Wave Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0.53, green: 0.81, blue: 0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width > 0 {
                        // Swiped right - go to previous hour
                        viewModel.previousHour()
                    } else {
                        // Swiped left - go to next hour
                        viewModel.nextHour()
                    }
                }
        )
    }
}

// MARK: - Swell Card
struct SwellCard: View {
    let forecast: HourlyForecastItem

    var body: some View {
        MarineDataCard(
            title: "Swell",
            icon: "water.waves",
            height: forecast.swellHeightDisplay,
            direction: forecast.swellDirectionCardinal,
            period: "\(Int(forecast.swellPeriod))s period",
            cardColor: Color.blue.opacity(0.5),
            accentColor: Color.blue
        )
    }
}

// MARK: - Wind Wave Card
struct WindWaveCard: View {
    let forecast: HourlyForecastItem

    var body: some View {
        MarineDataCard(
            title: "Wind Wave",
            icon: "wind",
            height: forecast.windWaveHeightDisplay,
            direction: forecast.windWaveDirectionCardinal,
            period: nil,
            cardColor: Color.cyan.opacity(0.5),
            accentColor: Color.cyan
        )
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        HourlyWaveDetailView(
            viewModel: HourlyWaveDetailViewModel(
                hourlyForecasts: [],
                selectedHourIndex: 0,
                locationName: "Boston Harbor",
                date: Date()
            )
        )
    }
}
