import SwiftUI
import MapKit

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

                            // Location Map
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "map")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("Location")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal)

                                LocationMapView(
                                    latitude: viewModel.latitude,
                                    longitude: viewModel.longitude,
                                    locationName: viewModel.locationDisplay
                                )
                                .frame(height: 300)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            .padding(.top, 8)
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

// MARK: - Location Map View
struct LocationMapView: View {
    let latitude: Double
    let longitude: Double
    let locationName: String

    @State private var region: MKCoordinateRegion

    init(latitude: Double, longitude: Double, locationName: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName

        // Initialize region centered on the coordinates
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        ))
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: [MapLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), name: locationName)]) { location in
            MapMarker(coordinate: location.coordinate, tint: .blue)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Map Location Helper
struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
}

// MARK: - Preview
#Preview {
    NavigationStack {
        HourlyWaveDetailView(
            viewModel: HourlyWaveDetailViewModel(
                hourlyForecasts: [],
                selectedHourIndex: 0,
                locationName: "Boston Harbor",
                date: Date(),
                latitude: 42.3601,
                longitude: -71.0589
            )
        )
    }
}
