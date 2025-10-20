import Foundation
import SwiftUI
import CoreLocation

class HourlyWaveDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentHourIndex: Int
    @Published var hourlyForecasts: [HourlyForecastItem]
    @Published var locationDisplay: String
    @Published var dateDisplay: String
    @Published var latitude: Double
    @Published var longitude: Double
    @Published var nearestCurrentStations: [TidalCurrentStation] = []
    @Published var selectedCurrentStation: TidalCurrentStation?
    @Published var currentDirection: Double?

    // MARK: - Computed Properties
    var currentForecast: HourlyForecastItem? {
        guard currentHourIndex >= 0 && currentHourIndex < hourlyForecasts.count else {
            return nil
        }
        return hourlyForecasts[currentHourIndex]
    }

    var currentTimeDisplay: String {
        guard let forecast = currentForecast else { return "" }
        return forecast.timeDisplay
    }

    var currentHourDisplay: String {
        guard let forecast = currentForecast else { return "" }
        return forecast.hour
    }

    var canGoToPreviousHour: Bool {
        return currentHourIndex > 0
    }

    var canGoToNextHour: Bool {
        return currentHourIndex < hourlyForecasts.count - 1
    }

    var hasMarineData: Bool {
        return currentForecast?.marineDataAvailable ?? false
    }

    // MARK: - Services
    private var tidalCurrentService: TidalCurrentService?
    private var tidalCurrentPredictionService: TidalCurrentPredictionService?

    // MARK: - Initialization
    init(hourlyForecasts: [HourlyForecastItem], selectedHourIndex: Int, locationName: String, date: Date, latitude: Double, longitude: Double, tidalCurrentService: TidalCurrentService? = nil, tidalCurrentPredictionService: TidalCurrentPredictionService? = nil) {
        self.hourlyForecasts = hourlyForecasts
        self.currentHourIndex = selectedHourIndex
        self.locationDisplay = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.tidalCurrentService = tidalCurrentService
        self.tidalCurrentPredictionService = tidalCurrentPredictionService

        // Format date display
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        self.dateDisplay = formatter.string(from: date)

        print("🌊 HourlyWaveDetailViewModel: Initialized with \(hourlyForecasts.count) forecasts, starting at index \(selectedHourIndex)")
        print("🗺️ HourlyWaveDetailViewModel: Location coordinates: \(latitude), \(longitude)")

        // Load nearest current stations
        Task {
            await loadNearestCurrentStations()
        }
    }

    // MARK: - Public Methods
    func nextHour() {
        guard canGoToNextHour else { return }

        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()

        currentHourIndex += 1
        print("🌊 HourlyWaveDetailViewModel: Moved to next hour, index: \(currentHourIndex)")
    }

    func previousHour() {
        guard canGoToPreviousHour else { return }

        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()

        currentHourIndex -= 1
        print("🌊 HourlyWaveDetailViewModel: Moved to previous hour, index: \(currentHourIndex)")
    }

    // MARK: - Current Station Methods
    @MainActor
    func loadNearestCurrentStations() async {
        guard let service = tidalCurrentService else {
            print("⚠️ HourlyWaveDetailViewModel: No tidal current service available")
            return
        }

        do {
            let response = try await service.getTidalCurrentStations()
            let userLocation = CLLocation(latitude: latitude, longitude: longitude)

            // Calculate distances and sort
            let stationsWithDistance = response.stations.compactMap { station -> TidalCurrentStation? in
                guard let lat = station.latitude, let lon = station.longitude else { return nil }
                let stationLocation = CLLocation(latitude: lat, longitude: lon)
                let distance = userLocation.distance(from: stationLocation) / 1609.34 // Convert to miles
                return station.withDistance(distance)
            }

            // Get 3 nearest
            nearestCurrentStations = Array(stationsWithDistance.sorted { ($0.distanceFromUser ?? Double.infinity) < ($1.distanceFromUser ?? Double.infinity) }.prefix(3))

            print("🗺️ HourlyWaveDetailViewModel: Found \(nearestCurrentStations.count) nearest current stations")
            for station in nearestCurrentStations {
                print("   - \(station.name): \(station.formattedDistance)")
            }
        } catch {
            print("❌ HourlyWaveDetailViewModel: Error loading current stations: \(error)")
        }
    }

    @MainActor
    func selectCurrentStation(_ station: TidalCurrentStation) async {
        selectedCurrentStation = station
        await fetchCurrentDirection(for: station)
    }

    @MainActor
    private func fetchCurrentDirection(for station: TidalCurrentStation) async {
        guard let service = tidalCurrentPredictionService else {
            print("⚠️ HourlyWaveDetailViewModel: No prediction service available")
            return
        }

        guard let bin = station.currentBin else {
            print("⚠️ HourlyWaveDetailViewModel: Station \(station.name) has no current bin")
            return
        }

        do {
            // Get predictions for current time
            let response = try await service.getPredictions(stationId: station.id, bin: bin, date: Date())

            // Find the prediction closest to current time
            let now = Date()
            if let closestPrediction = response.predictions.min(by: { abs($0.timestamp.timeIntervalSince(now)) < abs($1.timestamp.timeIntervalSince(now)) }) {
                // Get the direction (use actual direction if non-zero, otherwise use mean flood/ebb)
                let direction: Double
                if closestPrediction.direction != 0 {
                    direction = closestPrediction.direction
                } else {
                    direction = closestPrediction.speed >= 0 ? closestPrediction.meanFloodDirection : closestPrediction.meanEbbDirection
                }

                currentDirection = direction
                print("🌊 HourlyWaveDetailViewModel: Current direction for \(station.name): \(String(format: "%.0f", direction))°")
            }
        } catch {
            print("❌ HourlyWaveDetailViewModel: Error fetching current direction: \(error)")
        }
    }

    func clearCurrentSelection() {
        selectedCurrentStation = nil
        currentDirection = nil
    }
}
