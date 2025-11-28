import Foundation
import Combine
import SwiftUI
import CoreLocation

class RouteDetailsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isSummaryVisible = true
    @Published var maxWindSpeed = ""
    @Published var maxWaveHeight = ""
    @Published var maxHumidity = ""
    @Published var lowestVisibility = ""
    @Published var routeName = ""
    @Published var departureTime = ""
    @Published var arrivalTime = ""
    @Published var totalDistance = ""
    @Published var averageSpeed = ""
    @Published var duration = ""
    @Published var waypoints: [WaypointItem] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    // References to waypoints with max values
    @Published var maxWindWaypoint: WaypointItem?
    @Published var maxWaveWaypoint: WaypointItem?
    @Published var maxHumidityWaypoint: WaypointItem?
    @Published var minVisibilityWaypoint: WaypointItem?

    // MARK: - Private Properties
    private let weatherService: WeatherService
    private let routeCalculationService: RouteCalculationService
    private var cancellables = Set<AnyCancellable>()
    private var originalWaypoints: [WaypointItem] = [] // Store original waypoints for recalculation
    private var currentAverageSpeed: Double = 0.0

    // MARK: - Initialization
    init(weatherService: WeatherService, routeCalculationService: RouteCalculationService) {
        self.weatherService = weatherService
        self.routeCalculationService = routeCalculationService
        print("📊 RouteDetailsViewModel: Initialized with services")
    }

    // MARK: - Public Methods
    func toggleSummary() {
        isSummaryVisible.toggle()
    }

    /// Add intermediate waypoints between original waypoints at the specified time interval
    func addIntermediatePoints(intervalMinutes: Int) {
        guard originalWaypoints.count >= 2 else {
            print("⚠️ RouteDetailsViewModel: Not enough waypoints for intermediate points")
            return
        }

        isLoading = true
        print("📍 RouteDetailsViewModel: Adding intermediate points with \(intervalMinutes) minute interval")

        let intervalSeconds = TimeInterval(intervalMinutes * 60)
        var allWaypoints: [WaypointItem] = []
        var waypointIndex = 1

        for i in 0..<originalWaypoints.count - 1 {
            let startWaypoint = originalWaypoints[i]
            let endWaypoint = originalWaypoints[i + 1]

            // Add the original start waypoint (with updated index)
            let originalCopy = copyWaypoint(startWaypoint)
            originalCopy.index = waypointIndex
            originalCopy.isIntermediate = false
            allWaypoints.append(originalCopy)
            waypointIndex += 1

            // Calculate leg duration
            let legDuration = endWaypoint.eta.timeIntervalSince(startWaypoint.eta)

            // Calculate how many intermediate points to add
            let numberOfIntermediates = Int(legDuration / intervalSeconds) - 1

            if numberOfIntermediates > 0 {
                let startCoord = CLLocationCoordinate2D(latitude: startWaypoint.latitude, longitude: startWaypoint.longitude)
                let bearing = startWaypoint.bearingToNext

                // Distance per interval (in nautical miles)
                let distancePerInterval = currentAverageSpeed * (Double(intervalMinutes) / 60.0)

                for j in 1...numberOfIntermediates {
                    // Calculate intermediate position
                    let distanceFromStart = distancePerInterval * Double(j)
                    let intermediateCoord = routeCalculationService.interpolatePosition(
                        from: startCoord,
                        bearing: bearing,
                        distance: distanceFromStart
                    )

                    // Calculate intermediate ETA
                    let intermediateETA = startWaypoint.eta.addingTimeInterval(intervalSeconds * Double(j))

                    // Create intermediate waypoint
                    let intermediateWaypoint = createIntermediateWaypoint(
                        latitude: intermediateCoord.latitude,
                        longitude: intermediateCoord.longitude,
                        eta: intermediateETA,
                        index: waypointIndex,
                        bearing: bearing
                    )

                    allWaypoints.append(intermediateWaypoint)
                    waypointIndex += 1

                    print("📍 Added intermediate point \(j) between \(startWaypoint.name) and \(endWaypoint.name) at \(intermediateETA)")
                }
            }
        }

        // Add the final original waypoint
        let finalWaypoint = copyWaypoint(originalWaypoints.last!)
        finalWaypoint.index = waypointIndex
        finalWaypoint.isIntermediate = false
        allWaypoints.append(finalWaypoint)

        print("📍 RouteDetailsViewModel: Created \(allWaypoints.count) total waypoints (\(originalWaypoints.count) original + \(allWaypoints.count - originalWaypoints.count) intermediate)")

        // Set the waypoints reference for each waypoint
        for waypoint in allWaypoints {
            waypoint.waypoints = allWaypoints
        }

        // Fetch weather data for new intermediate waypoints only
        let intermediateWaypoints = allWaypoints.filter { $0.isIntermediate }
        fetchWeatherForIntermediateWaypoints(intermediateWaypoints, allWaypoints: allWaypoints)
    }

    private func copyWaypoint(_ source: WaypointItem) -> WaypointItem {
        let copy = WaypointItem()
        copy.index = source.index
        copy.name = source.name
        copy.latitude = source.latitude
        copy.longitude = source.longitude
        copy.eta = source.eta
        copy.coordinates = source.coordinates
        copy.distanceToNext = source.distanceToNext
        copy.bearingToNext = source.bearingToNext
        copy.isIntermediate = source.isIntermediate
        copy.weatherDataAvailable = source.weatherDataAvailable
        copy.temperature = source.temperature
        copy.dewPoint = source.dewPoint
        copy.relativeHumidity = source.relativeHumidity
        copy.windDirection = source.windDirection
        copy.windSpeed = source.windSpeed
        copy.windGusts = source.windGusts
        copy.weatherCondition = source.weatherCondition
        copy.weatherIcon = source.weatherIcon
        copy.visibility = source.visibility
        copy.marineDataAvailable = source.marineDataAvailable
        copy.waveHeight = source.waveHeight
        copy.waveDirection = source.waveDirection
        copy.wavePeriod = source.wavePeriod
        copy.swellHeight = source.swellHeight
        copy.swellDirection = source.swellDirection
        copy.swellPeriod = source.swellPeriod
        copy.windWaveHeight = source.windWaveHeight
        copy.windWaveDirection = source.windWaveDirection
        copy.relativeWaveDirection = source.relativeWaveDirection
        return copy
    }

    private func fetchWeatherForIntermediateWaypoints(_ intermediateWaypoints: [WaypointItem], allWaypoints: [WaypointItem]) {
        let dispatchGroup = DispatchGroup()

        for waypoint in intermediateWaypoints {
            dispatchGroup.enter()

            Task {
                do {
                    print("🌤️ Fetching data for intermediate waypoint \(waypoint.index)")

                    let weatherTask = Task {
                        try await fetchWeatherDataForWaypoint(waypoint)
                    }

                    let marineTask = Task {
                        try await fetchMarineDataForWaypoint(waypoint)
                    }

                    _ = try await weatherTask.value
                    _ = try await marineTask.value

                    dispatchGroup.leave()
                } catch {
                    print("❌ Error fetching data for intermediate waypoint \(waypoint.index): \(error.localizedDescription)")
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            // Update summary stats with all waypoints
            self.updateSummaryStats(allWaypoints)

            self.waypoints = allWaypoints
            self.isLoading = false
            print("✅ RouteDetailsViewModel: Intermediate points added and weather data fetched")
        }
    }

    private func updateSummaryStats(_ waypointItems: [WaypointItem]) {
        self.maxWindWaypoint = waypointItems.max(by: { $0.windSpeed < $1.windSpeed })
        if let maxWind = self.maxWindWaypoint {
            self.maxWindSpeed = "Max Wind: \(String(format: "%.1f", maxWind.windSpeed)) mph @ \(maxWind.name)"
        }

        self.maxWaveWaypoint = waypointItems.max(by: { $0.waveHeight < $1.waveHeight })
        if let maxWave = self.maxWaveWaypoint {
            self.maxWaveHeight = "Max Wave: \(String(format: "%.1f", maxWave.waveHeight)) ft @ \(maxWave.name)"
        }

        self.maxHumidityWaypoint = waypointItems.max(by: { $0.relativeHumidity < $1.relativeHumidity })
        if let maxHumidity = self.maxHumidityWaypoint {
            self.maxHumidity = "Max Humidity: \(maxHumidity.relativeHumidity)% @ \(maxHumidity.name)"
        }

        self.minVisibilityWaypoint = waypointItems.min(by: { $0.visibility < $1.visibility })
        if let minVisibility = self.minVisibilityWaypoint {
            let visibilityMiles = minVisibility.visibility / 1609.34
            self.lowestVisibility = "Min Visibility: \(String(format: "%.1f", visibilityMiles)) mi @ \(minVisibility.name)"
        }
    }

    func applyRouteData(_ route: GpxRoute, averageSpeed: String) {
        isLoading = true
        errorMessage = ""
        print("🛣️ RouteDetailsViewModel: Applying route data for route: \(route.name)")
        print("🛣️ RouteDetailsViewModel: Route has \(route.routePoints.count) waypoints")

        // Store average speed for intermediate point calculations
        currentAverageSpeed = Double(averageSpeed) ?? 10.0

        // Set route information
        routeName = route.name

        guard !route.routePoints.isEmpty else {
            errorMessage = "Route has no waypoints"
            isLoading = false
            print("❌ RouteDetailsViewModel: Error - Route has no waypoints")
            return
        }

        // Create waypoints from route points
        let waypointItems = route.routePoints.enumerated().map { index, point in
            createWaypoint(from: point, index: index + 1, isIntermediate: false)
        }

        // Store original waypoints for later intermediate point calculations
        originalWaypoints = waypointItems

        // Set the waypoints reference for each waypoint
        for waypoint in waypointItems {
            waypoint.waypoints = waypointItems
        }

        print("🛣️ RouteDetailsViewModel: Created \(waypointItems.count) waypoint items")

        // Fetch weather and marine data for each waypoint
        let dispatchGroup = DispatchGroup()

        for waypoint in waypointItems {
            dispatchGroup.enter()

            Task {
                do {
                    print("🌤️ RouteDetailsViewModel: Starting data fetch for waypoint \(waypoint.index): \(waypoint.name)")

                    // Fetch weather data
                    let weatherTask = Task {
                        print("🌤️ RouteDetailsViewModel: Fetching weather data for waypoint \(waypoint.index)")
                        try await fetchWeatherDataForWaypoint(waypoint)
                    }

                    // Fetch marine data
                    let marineTask = Task {
                        print("🌊 RouteDetailsViewModel: Fetching marine data for waypoint \(waypoint.index)")
                        try await fetchMarineDataForWaypoint(waypoint)
                    }

                    // Wait for both tasks to complete
                    _ = try await weatherTask.value
                    print("✅ RouteDetailsViewModel: Weather data fetch complete for waypoint \(waypoint.index)")

                    _ = try await marineTask.value
                    print("✅ RouteDetailsViewModel: Marine data fetch complete for waypoint \(waypoint.index)")

                    dispatchGroup.leave()
                } catch {
                    print("❌ RouteDetailsViewModel: Data fetch error for waypoint \(waypoint.index): \(error.localizedDescription)")
                    dispatchGroup.leave()
                }
            }
        }

        // Process results when all data fetching is complete
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            print("📊 RouteDetailsViewModel: All data fetching complete, processing results...")

            if !waypointItems.isEmpty {
                // Store both the max values and the waypoints that contain them
                self.maxWindWaypoint = waypointItems.max(by: { $0.windSpeed < $1.windSpeed })
                if let maxWind = self.maxWindWaypoint {
                    print("💨 RouteDetailsViewModel: Max wind speed: \(maxWind.windSpeed) mph at waypoint \(maxWind.name)")
                    self.maxWindSpeed = "Max Wind: \(String(format: "%.1f", maxWind.windSpeed)) mph @ \(maxWind.name)"
                }

                self.maxWaveWaypoint = waypointItems.max(by: { $0.waveHeight < $1.waveHeight })
                if let maxWave = self.maxWaveWaypoint {
                    print("🌊 RouteDetailsViewModel: Max wave height: \(maxWave.waveHeight) ft at waypoint \(maxWave.name)")
                    self.maxWaveHeight = "Max Wave: \(String(format: "%.1f", maxWave.waveHeight)) ft @ \(maxWave.name)"
                }

                self.maxHumidityWaypoint = waypointItems.max(by: { $0.relativeHumidity < $1.relativeHumidity })
                if let maxHumidity = self.maxHumidityWaypoint {
                    print("💧 RouteDetailsViewModel: Max humidity: \(maxHumidity.relativeHumidity)% at waypoint \(maxHumidity.name)")
                    self.maxHumidity = "Max Humidity: \(maxHumidity.relativeHumidity)% @ \(maxHumidity.name)"
                }

                self.minVisibilityWaypoint = waypointItems.min(by: { $0.visibility < $1.visibility })
                if let minVisibility = self.minVisibilityWaypoint {
                    let visibilityMiles = minVisibility.visibility / 1609.34
                    print("👁️ RouteDetailsViewModel: Min visibility: \(visibilityMiles) mi at waypoint \(minVisibility.name)")
                    self.lowestVisibility = "Min Visibility: \(String(format: "%.1f", visibilityMiles)) mi @ \(minVisibility.name)"
                }

                // Keep existing timing and distance calculations
                let firstWaypoint = waypointItems.first!
                let lastWaypoint = waypointItems.last!

                // Format departure and arrival times
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MM/dd/yy HH:mm"
                self.departureTime = dateFormatter.string(from: firstWaypoint.eta)
                self.arrivalTime = dateFormatter.string(from: lastWaypoint.eta)

                // Calculate total distance
                let totalDistanceValue = route.routePoints.reduce(0.0) { $0 + $1.distanceToNext }
                self.totalDistance = "\(String(format: "%.1f", totalDistanceValue)) nm"

                self.averageSpeed = "\(averageSpeed) kts"

                // Calculate duration
                let duration = lastWaypoint.eta.timeIntervalSince(firstWaypoint.eta)
                self.duration = self.routeCalculationService.formatDuration(duration)

                print("⏱️ RouteDetailsViewModel: Route timing - Departure: \(self.departureTime), Arrival: \(self.arrivalTime), Duration: \(self.duration)")
                print("📏 RouteDetailsViewModel: Route distance: \(self.totalDistance), Speed: \(self.averageSpeed)")
            }

            self.waypoints = waypointItems
            self.isLoading = false
            print("✅ RouteDetailsViewModel: Route details processing complete")
        }
    }

    // MARK: - Private Methods
    private func createWaypoint(from point: GpxRoutePoint, index: Int, isIntermediate: Bool) -> WaypointItem {
        let waypoint = WaypointItem()
        waypoint.index = index
        waypoint.name = point.name ?? "Waypoint \(index)"
        waypoint.latitude = point.latitude
        waypoint.longitude = point.longitude
        waypoint.eta = point.eta
        waypoint.distanceToNext = point.distanceToNext
        waypoint.bearingToNext = point.bearingToNext
        waypoint.coordinates = "\(String(format: "%.6f", point.latitude))°, \(String(format: "%.6f", point.longitude))°"
        waypoint.isIntermediate = isIntermediate
        return waypoint
    }

    private func createIntermediateWaypoint(latitude: Double, longitude: Double, eta: Date, index: Int, bearing: Double) -> WaypointItem {
        let waypoint = WaypointItem()
        waypoint.index = index
        waypoint.name = "Intermediate \(index)"
        waypoint.latitude = latitude
        waypoint.longitude = longitude
        waypoint.eta = eta
        waypoint.bearingToNext = bearing
        waypoint.coordinates = "\(String(format: "%.6f", latitude))°, \(String(format: "%.6f", longitude))°"
        waypoint.isIntermediate = true
        return waypoint
    }

    private func fetchWeatherDataForWaypoint(_ waypoint: WaypointItem) async throws {
        print("🌤️ Fetching weather data for waypoint \(waypoint.index) at coordinates: \(waypoint.coordinates)")

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: waypoint.eta)

        guard let year = components.year, let month = components.month, let day = components.day else {
            print("❌ Invalid date components for waypoint \(waypoint.index)")
            return
        }

        print("🌤️ Weather request with date: \(year)-\(month)-\(day), coordinates: (\(waypoint.latitude), \(waypoint.longitude))")

        do {
            let weather = try await weatherService.getHourlyForecast(
                year: year,
                month: month,
                day: day,
                latitude: waypoint.latitude,
                longitude: waypoint.longitude
            )

            print("✅ Weather data received for waypoint \(waypoint.index)")

            // Update waypoint with weather data
            await MainActor.run {
                let hourIndex = calendar.component(.hour, from: waypoint.eta)
                print("⏱️ Hour index for this waypoint: \(hourIndex)")

                if hourIndex < weather.hourly.time.count {
                    waypoint.weatherDataAvailable = true
                    print("✅ Weather data is available at hour index \(hourIndex)")

                    if hourIndex < weather.hourly.visibility.count {
                        waypoint.visibility = weather.hourly.visibility[hourIndex]
                        print("👁️ Visibility: \(weather.hourly.visibility[hourIndex]) meters")
                    } else {
                        print("⚠️ No visibility data at index \(hourIndex)")
                    }

                    if hourIndex < weather.hourly.temperature.count {
                        waypoint.temperature = weather.hourly.temperature[hourIndex]
                        print("🌡️ Temperature: \(weather.hourly.temperature[hourIndex])°")
                    } else {
                        print("⚠️ No temperature data at index \(hourIndex)")
                    }

                    if let dewPoints = weather.hourly.dewPoint, hourIndex < dewPoints.count {
                        waypoint.dewPoint = dewPoints[hourIndex]
                        print("💧 Dew point: \(dewPoints[hourIndex])°")
                    } else {
                        print("⚠️ No dew point data available")
                    }

                    if let humidities = weather.hourly.relativeHumidity, hourIndex < humidities.count {
                        waypoint.relativeHumidity = humidities[hourIndex]
                        print("💧 Relative humidity: \(humidities[hourIndex])%")
                    } else {
                        print("⚠️ No humidity data available")
                    }

                    if hourIndex < weather.hourly.windSpeed.count {
                        waypoint.windSpeed = weather.hourly.windSpeed[hourIndex]
                        print("💨 Wind speed: \(weather.hourly.windSpeed[hourIndex]) mph")
                    } else {
                        print("⚠️ No wind speed data at index \(hourIndex)")
                    }

                    if hourIndex < weather.hourly.windGusts.count {
                        waypoint.windGusts = weather.hourly.windGusts[hourIndex]
                        print("💨 Wind gusts: \(weather.hourly.windGusts[hourIndex]) mph")
                    } else {
                        print("⚠️ No wind gusts data at index \(hourIndex)")
                    }

                    if hourIndex < weather.hourly.windDirection.count {
                        waypoint.setWindDirectionFromDegrees(weather.hourly.windDirection[hourIndex])
                        print("🧭 Wind direction: \(weather.hourly.windDirection[hourIndex])° (\(waypoint.windDirection))")
                    } else {
                        print("⚠️ No wind direction data at index \(hourIndex)")
                    }

                    // Set weather condition and icon
                    if hourIndex < weather.hourly.weatherCode.count {
                        let weatherCode = weather.hourly.weatherCode[hourIndex]
                        waypoint.weatherCondition = WeatherConditionHelper.getWeatherDescription(weatherCode)
                        waypoint.weatherIcon = WeatherConditionHelper.getWeatherImage(weatherCode)
                        print("🌤️ Weather condition: \(waypoint.weatherCondition) (code: \(weatherCode), icon: \(waypoint.weatherIcon))")
                    } else {
                        print("⚠️ No weather code data at index \(hourIndex)")
                    }
                } else {
                    waypoint.weatherDataAvailable = false
                    print("⚠️ Hour index \(hourIndex) is out of range for weather data (max: \(weather.hourly.time.count - 1))")
                }
            }
        } catch {
            print("❌ Error fetching weather data: \(error.localizedDescription)")
            throw error
        }
    }

    private func fetchMarineDataForWaypoint(_ waypoint: WaypointItem) async throws {
        print("🌊 Fetching marine data for waypoint \(waypoint.index) at coordinates: \(waypoint.coordinates)")

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: waypoint.eta)

        guard let year = components.year, let month = components.month, let day = components.day else {
            print("❌ Invalid date components for marine data at waypoint \(waypoint.index)")
            await MainActor.run {
                waypoint.marineDataAvailable = false
            }
            return
        }

        print("🌊 Marine data request with date: \(year)-\(month)-\(day), coordinates: (\(waypoint.latitude), \(waypoint.longitude))")

        do {
            let marineData = try await weatherService.getMarineForecast(
                year: year,
                month: month,
                day: day,
                latitude: waypoint.latitude,
                longitude: waypoint.longitude
            )

            if let marineData = marineData {
                print("✅ Marine data successfully received for waypoint \(waypoint.index)")
                print("🌊 Marine data details:")
                print("  - Time entries: \(marineData.hourly.time.count)")
                print("  - Wave heights: \(marineData.hourly.waveHeight.count) values")

                // Update waypoint with marine data
                await MainActor.run {
                    let hourIndex = calendar.component(.hour, from: waypoint.eta)
                    print("⏱️ Marine data hour index: \(hourIndex)")

                    if hourIndex < marineData.hourly.time.count &&
                       hourIndex < marineData.hourly.waveHeight.count {

                        waypoint.marineDataAvailable = true
                        print("✅ Marine data is available at hour index \(hourIndex)")

                        // Get wave height (convert meters to feet)
                        let waveHeightInFeet = marineData.hourly.waveHeightFeet[hourIndex]
                        waypoint.waveHeight = waveHeightInFeet
                        print("🌊 Wave height: \(waveHeightInFeet) ft")

                        // Get wave direction
                        if hourIndex < marineData.hourly.waveDirection.count {
                            waypoint.waveDirection = marineData.hourly.waveDirection[hourIndex]
                            print("🧭 Wave direction: \(marineData.hourly.waveDirection[hourIndex])°")
                        }

                        // Get wave period
                        if hourIndex < marineData.hourly.wavePeriod.count {
                            waypoint.wavePeriod = marineData.hourly.wavePeriod[hourIndex]
                            print("⏱️ Wave period: \(marineData.hourly.wavePeriod[hourIndex]) seconds")
                        }

                        // Get swell height
                        if hourIndex < marineData.hourly.swellWaveHeightFeet.count {
                            waypoint.swellHeight = marineData.hourly.swellWaveHeightFeet[hourIndex]
                            print("🌊 Swell height: \(marineData.hourly.swellWaveHeightFeet[hourIndex]) ft")
                        }

                        // Get swell direction
                        if hourIndex < marineData.hourly.swellWaveDirection.count {
                            waypoint.swellDirection = marineData.hourly.swellWaveDirection[hourIndex]
                            print("🧭 Swell direction: \(marineData.hourly.swellWaveDirection[hourIndex])°")
                        }

                        // Get swell period
                        if hourIndex < marineData.hourly.swellWavePeriod.count {
                            waypoint.swellPeriod = marineData.hourly.swellWavePeriod[hourIndex]
                            print("⏱️ Swell period: \(marineData.hourly.swellWavePeriod[hourIndex]) seconds")
                        }

                        // Get wind wave height
                        if hourIndex < marineData.hourly.windWaveHeightFeet.count {
                            waypoint.windWaveHeight = marineData.hourly.windWaveHeightFeet[hourIndex]
                            print("🌊 Wind wave height: \(marineData.hourly.windWaveHeightFeet[hourIndex]) ft")
                        }

                        // Get wind wave direction
                        if hourIndex < marineData.hourly.windWaveDirection.count {
                            waypoint.windWaveDirection = marineData.hourly.windWaveDirection[hourIndex]
                            print("🧭 Wind wave direction: \(marineData.hourly.windWaveDirection[hourIndex])°")
                        }

                        // Calculate relative wave direction
                        waypoint.calculateRelativeWaveDirection()
                        print("🧭 Calculated relative wave direction: \(waypoint.relativeWaveDirection)°")
                    } else {
                        waypoint.marineDataAvailable = false
                        print("⚠️ Hour index \(hourIndex) is out of range for marine data (max: \(marineData.hourly.time.count - 1))")
                    }
                }
            } else {
                print("⚠️ No marine data returned for waypoint \(waypoint.index) - this is expected for inland locations")
                await MainActor.run {
                    waypoint.marineDataAvailable = false
                }
            }
            print("✅ RouteDetailsViewModel: Marine data fetch complete for waypoint \(waypoint.index)")
        } catch {
            print("❌ Error fetching marine data for waypoint \(waypoint.index): \(error.localizedDescription)")
            await MainActor.run {
                waypoint.marineDataAvailable = false
            }
        }
    }

}
