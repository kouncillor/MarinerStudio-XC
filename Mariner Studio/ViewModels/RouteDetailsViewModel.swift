import Foundation
import Combine
import SwiftUI

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
    
    // MARK: - Initialization
    init(weatherService: WeatherService, routeCalculationService: RouteCalculationService) {
        self.weatherService = weatherService
        self.routeCalculationService = routeCalculationService
    }
    
    // MARK: - Public Methods
    func toggleSummary() {
        isSummaryVisible.toggle()
    }
    
    func applyRouteData(_ route: GpxRoute, averageSpeed: String) {
        isLoading = true
        errorMessage = ""
        
        // Set route information
        routeName = route.name
        
        guard !route.routePoints.isEmpty else {
            errorMessage = "Route has no waypoints"
            isLoading = false
            return
        }
        
        // Create waypoints from route points
        let waypointItems = route.routePoints.enumerated().map { index, point in
            createWaypoint(from: point, index: index + 1)
        }
        
        // Set the waypoints reference for each waypoint
        for waypoint in waypointItems {
            waypoint.waypoints = waypointItems
        }
        
        // Fetch weather and marine data for each waypoint
        let dispatchGroup = DispatchGroup()
        
        for waypoint in waypointItems {
            dispatchGroup.enter()
            
            Task {
                do {
                    // Fetch weather data
                    let weatherTask = Task { try await fetchWeatherDataForWaypoint(waypoint) }
                    
                    // Fetch marine data
                    let marineTask = Task { try await fetchMarineDataForWaypoint(waypoint) }
                    
                    // Wait for both tasks to complete
                    _ = try await weatherTask.value
                    _ = try await marineTask.value
                    
                    dispatchGroup.leave()
                } catch {
                    print("Data fetch error for waypoint \(waypoint.index): \(error.localizedDescription)")
                    dispatchGroup.leave()
                }
            }
        }
        
        // Process results when all data fetching is complete
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            if !waypointItems.isEmpty {
                // Store both the max values and the waypoints that contain them
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
            }
            
            self.waypoints = waypointItems
            self.isLoading = false
        }
    }
    
    // MARK: - Private Methods
    private func createWaypoint(from point: GpxRoutePoint, index: Int) -> WaypointItem {
        let waypoint = WaypointItem()
        waypoint.index = index
        waypoint.name = point.name ?? "Waypoint \(index)"
        waypoint.latitude = point.latitude
        waypoint.longitude = point.longitude
        waypoint.eta = point.eta
        waypoint.distanceToNext = point.distanceToNext
        waypoint.bearingToNext = point.bearingToNext
        waypoint.coordinates = "\(String(format: "%.6f", point.latitude))°, \(String(format: "%.6f", point.longitude))°"
        return waypoint
    }
    
    private func fetchWeatherDataForWaypoint(_ waypoint: WaypointItem) async throws {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: waypoint.eta)
        
        guard let year = components.year, let month = components.month, let day = components.day else {
            return
        }
        
        let weather = try await weatherService.getHourlyForecast(
            year: year,
            month: month,
            day: day,
            latitude: waypoint.latitude,
            longitude: waypoint.longitude
        )
        
        // Update waypoint with weather data
        await MainActor.run {
            let hourIndex = calendar.component(.hour, from: waypoint.eta)
            
            if hourIndex < weather.hourly.time.count {
                waypoint.weatherDataAvailable = true
                
                if hourIndex < weather.hourly.visibility.count {
                    waypoint.visibility = weather.hourly.visibility[hourIndex]
                }
                
                if hourIndex < weather.hourly.temperature.count {
                    waypoint.temperature = weather.hourly.temperature[hourIndex]
                }
                
                if let dewPoints = weather.hourly.dewPoint, hourIndex < dewPoints.count {
                    waypoint.dewPoint = dewPoints[hourIndex]
                }
                
                if let humidities = weather.hourly.relativeHumidity, hourIndex < humidities.count {
                    waypoint.relativeHumidity = humidities[hourIndex]
                }
                
                if hourIndex < weather.hourly.windSpeed.count {
                    waypoint.windSpeed = weather.hourly.windSpeed[hourIndex]
                }
                
                if hourIndex < weather.hourly.windGusts.count {
                    waypoint.windGusts = weather.hourly.windGusts[hourIndex]
                }
                
                if hourIndex < weather.hourly.windDirection.count {
                    waypoint.setWindDirectionFromDegrees(weather.hourly.windDirection[hourIndex])
                }
                
                // Set weather condition and icon
                if hourIndex < weather.hourly.weatherCode.count {
                    let weatherCode = weather.hourly.weatherCode[hourIndex]
                    waypoint.weatherCondition = WeatherConditionHelper.getWeatherDescription(weatherCode)
                    waypoint.weatherIcon = WeatherConditionHelper.getWeatherImage(weatherCode)
                }
            } else {
                waypoint.weatherDataAvailable = false
            }
        }
    }
    
    private func fetchMarineDataForWaypoint(_ waypoint: WaypointItem) async throws {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: waypoint.eta)
        
        guard let year = components.year, let month = components.month, let day = components.day else {
            return
        }
        
        if let marineData = try await weatherService.getMarineForecast(
            year: year,
            month: month,
            day: day,
            latitude: waypoint.latitude,
            longitude: waypoint.longitude
        ) {
            // Update waypoint with marine data
            await MainActor.run {
                let hourIndex = calendar.component(.hour, from: waypoint.eta)
                
                if hourIndex < marineData.hourly.time.count {
                    waypoint.marineDataAvailable = true
                    
                    if hourIndex < marineData.hourly.waveHeightFeet.count {
                        waypoint.waveHeight = marineData.hourly.waveHeightFeet[hourIndex]
                    }
                    
                    if hourIndex < marineData.hourly.waveDirection.count {
                        waypoint.waveDirection = marineData.hourly.waveDirection[hourIndex]
                    }
                    
                    if hourIndex < marineData.hourly.wavePeriod.count {
                        waypoint.wavePeriod = marineData.hourly.wavePeriod[hourIndex]
                    }
                    
                    if hourIndex < marineData.hourly.swellWaveHeightFeet.count {
                        waypoint.swellHeight = marineData.hourly.swellWaveHeightFeet[hourIndex]
                    }
                    
                    if hourIndex < marineData.hourly.swellWaveDirection.count {
                        waypoint.swellDirection = marineData.hourly.swellWaveDirection[hourIndex]
                    }
                    
                    if hourIndex < marineData.hourly.swellWavePeriod.count {
                        waypoint.swellPeriod = marineData.hourly.swellWavePeriod[hourIndex]
                    }
                    
                    if hourIndex < marineData.hourly.windWaveHeightFeet.count {
                        waypoint.windWaveHeight = marineData.hourly.windWaveHeightFeet[hourIndex]
                    }
                    
                    if hourIndex < marineData.hourly.windWaveDirection.count {
                        waypoint.windWaveDirection = marineData.hourly.windWaveDirection[hourIndex]
                    }
                    
                    waypoint.calculateRelativeWaveDirection()
                } else {
                    waypoint.marineDataAvailable = false
                }
            }
        } else {
            await MainActor.run {
                waypoint.marineDataAvailable = false
            }
        }
    }
}
