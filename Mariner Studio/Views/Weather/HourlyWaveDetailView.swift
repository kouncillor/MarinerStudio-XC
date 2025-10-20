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
                                    locationName: viewModel.locationDisplay,
                                    windDirection: forecast.windDirection,
                                    waveDirection: forecast.waveDirection,
                                    viewModel: viewModel
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
    let windDirection: Double
    let waveDirection: Double
    @ObservedObject var viewModel: HourlyWaveDetailViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                WaveDetailMapViewRepresentable(
                    centerCoordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    currentStations: viewModel.nearestCurrentStations,
                    onStationTapped: { station in
                        Task {
                            await viewModel.selectCurrentStation(station)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

                // Wind Direction Arrow
                DirectionArrow(
                    direction: windDirection,
                    label: "WIND",
                    color: .green,
                    mapSize: geometry.size
                )

                // Wave Direction Arrow
                DirectionArrow(
                    direction: waveDirection,
                    label: "WAVE",
                    color: .blue,
                    mapSize: geometry.size
                )

                // Current Direction Arrow (if station selected)
                if let currentDir = viewModel.currentDirection {
                    DirectionArrow(
                        direction: currentDir,
                        label: "CURRENT",
                        color: .orange,
                        mapSize: geometry.size
                    )
                }
            }
        }
    }
}

// MARK: - Wave Detail Map View Representable
struct WaveDetailMapViewRepresentable: UIViewRepresentable {
    let centerCoordinate: CLLocationCoordinate2D
    let currentStations: [TidalCurrentStation]
    let onStationTapped: (TidalCurrentStation) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsUserLocation = false

        // Register annotation view
        mapView.register(TidalCurrentStationAnnotationView.self, forAnnotationViewWithReuseIdentifier: TidalCurrentStationAnnotationView.ReuseID)

        // Set initial region
        mapView.setRegion(MKCoordinateRegion(
            center: centerCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        ), animated: false)

        // Add center marker
        let centerAnnotation = MKPointAnnotation()
        centerAnnotation.coordinate = centerCoordinate
        centerAnnotation.title = "Weather Location"
        mapView.addAnnotation(centerAnnotation)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update current station annotations
        let existingAnnotations = mapView.annotations.compactMap { $0 as? CurrentStationAnnotation }
        mapView.removeAnnotations(existingAnnotations)

        let newAnnotations = currentStations.compactMap { station -> CurrentStationAnnotation? in
            guard let lat = station.latitude, let lon = station.longitude else { return nil }
            return CurrentStationAnnotation(station: station, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        mapView.addAnnotations(newAnnotations)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onStationTapped: onStationTapped)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        let onStationTapped: (TidalCurrentStation) -> Void

        init(onStationTapped: @escaping (TidalCurrentStation) -> Void) {
            self.onStationTapped = onStationTapped
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is CurrentStationAnnotation {
                return mapView.dequeueReusableAnnotationView(withIdentifier: TidalCurrentStationAnnotationView.ReuseID, for: annotation)
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation as? CurrentStationAnnotation {
                onStationTapped(annotation.station)
            }
        }
    }
}

// MARK: - Current Station Annotation
class CurrentStationAnnotation: NSObject, MKAnnotation {
    let station: TidalCurrentStation
    let coordinate: CLLocationCoordinate2D

    var title: String? {
        return station.name
    }

    init(station: TidalCurrentStation, coordinate: CLLocationCoordinate2D) {
        self.station = station
        self.coordinate = coordinate
    }
}

// MARK: - Direction Arrow Component
struct DirectionArrow: View {
    let direction: Double  // 0-360 degrees, 0 = North
    let label: String      // "WIND" or "WAVE"
    let color: Color
    let mapSize: CGSize

    // Convert degrees to cardinal direction
    private var cardinalDirection: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int(((direction + 11.25) / 22.5).truncatingRemainder(dividingBy: 16))
        return directions[index]
    }

    // Calculate position on map perimeter based on direction
    private var arrowPosition: CGPoint {
        let centerX = mapSize.width / 2
        let centerY = mapSize.height / 2
        let radius = min(mapSize.width, mapSize.height) / 2 - 40 // 40pt padding from edge

        // For CURRENT, position is opposite of flow direction (showing where it's coming from)
        // For WIND/WAVE, position is at the source direction
        let positionDirection = label == "CURRENT" ? direction + 180 : direction

        // Convert degrees to radians
        let radians = positionDirection * .pi / 180

        // Calculate position (0° = North = top)
        let x = centerX + radius * sin(radians)
        let y = centerY - radius * cos(radians)

        return CGPoint(x: x, y: y)
    }

    // Arrow rotation to point toward center (for wind/wave) or toward flow direction (for current)
    private var arrowRotation: Double {
        // For CURRENT, arrow points in the flow direction
        // For WIND/WAVE, arrow points toward center (from source)
        return label == "CURRENT" ? direction - 180 : direction
    }

    var body: some View {
        ZStack {
            VStack(spacing: 2) {
                // Arrow pointing toward center (larger, like voyage plan)
                VStack(spacing: 0) {
                    // Arrow Head
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 20))
                        .foregroundColor(color)

                    // Arrow Shaft
                    Rectangle()
                        .frame(width: 4, height: 45)
                        .foregroundColor(color)
                }
                .rotationEffect(.degrees(arrowRotation))

                // Label with direction
                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(color)
                    Text("from \(cardinalDirection)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(color.opacity(0.9))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.95))
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            }
        }
        .position(arrowPosition)
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
    let sampleForecast = HourlyForecastItem(
        time: Date(),
        hour: "2:00 PM",
        timeDisplay: "Oct 20, 2025 at 2:00 PM",
        temperature: 68.0,
        humidity: 65,
        precipitation: 0.0,
        precipitationChance: 10.0,
        windSpeed: 12.0,
        windDirection: 270.0,  // From West
        windGusts: 18.0,
        dewPoint: 55.0,
        pressure: 1013.0,
        previousPressure: 1012.5,
        visibilityMeters: 16000.0,
        weatherCode: 1,
        isNightTime: false,
        cardinalDirection: "W",
        weatherIcon: "cloud.sun.fill",
        moonPhase: "moon.fill",
        marineDataAvailable: true,
        waveHeight: 2.5,
        waveDirection: 180.0,  // From South
        wavePeriod: 6.0,
        swellHeight: 1.8,
        swellDirection: 190.0,
        swellPeriod: 8.0,
        windWaveHeight: 0.8,
        windWaveDirection: 270.0
    )

    NavigationStack {
        HourlyWaveDetailView(
            viewModel: HourlyWaveDetailViewModel(
                hourlyForecasts: [sampleForecast],
                selectedHourIndex: 0,
                locationName: "Boston Harbor",
                date: Date(),
                latitude: 42.3601,
                longitude: -71.0589
            )
        )
    }
}
