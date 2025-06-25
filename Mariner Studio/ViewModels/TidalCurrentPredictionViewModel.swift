import Foundation
import SwiftUI
import Combine

class TidalCurrentPredictionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var stationName: String = ""
    @Published var allPredictions: [TidalCurrentPrediction] = []
    @Published var selectedDate: Date = Date()
    @Published var currentPrediction: TidalCurrentPrediction?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var canGoForward: Bool = false
    @Published var canGoBackward: Bool = false
    @Published var isFavorite: Bool = false
    @Published var currentExtremes: [CurrentExtreme] = []
    
    // MARK: - Private Properties
    private let predictionService: TidalCurrentPredictionService
    private let currentStationService: CurrentStationDatabaseService
    private var stationId: String = ""
    private var bin: Int = 0
    private var currentPredictionIndex: Int = 0
    private var dateFormatter: DateFormatter
    private let stationLatitude: Double?
    private let stationLongitude: Double?
    private let stationDepth: Double?
    private let stationDepthType: String?
    
    // MARK: - Computed Properties
    var formattedSelectedDate: String {dateFormatter.string(from: selectedDate)}
    
    // MARK: - Initialization
    
        init(
            stationId: String,
            bin: Int,
            stationName: String,
            stationLatitude: Double? = nil,
            stationLongitude: Double? = nil,
            stationDepth: Double? = nil,
            stationDepthType: String? = nil,
            predictionService: TidalCurrentPredictionService,
            currentStationService: CurrentStationDatabaseService
        ) {
            self.stationId = stationId
            self.bin = bin
            self.stationName = stationName
            self.stationLatitude = stationLatitude
            self.stationLongitude = stationLongitude
            self.stationDepth = stationDepth
            self.stationDepthType = stationDepthType        
            self.predictionService = predictionService
            self.currentStationService = currentStationService
            
            dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            
            Task {
                await updateFavoriteStatus()
                await loadPredictions()
            }
        }
    
    // MARK: - Public Methods
    func loadPredictions() async {
        if isLoading { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            // Get regular predictions for the graph
            let response = try await predictionService.getPredictions(
                stationId: stationId,
                bin: bin,
                date: selectedDate
            )
            
            // Get max/slack predictions for the table
            let extremesResponse = try await predictionService.getExtremes(
                stationId: stationId,
                bin: bin,
                date: selectedDate
            )
            
            await MainActor.run {
                // Sort predictions by time
                self.allPredictions = response.predictions.sorted(by: { $0.timestamp < $1.timestamp })
                
                // Find the prediction closest to current time
                let currentTime = Date()
                self.currentPredictionIndex = 0
                
                var minTimeDiff = TimeInterval.greatestFiniteMagnitude
                for (i, prediction) in self.allPredictions.enumerated() {
                    let timeDiff = abs(prediction.timestamp.timeIntervalSince(currentTime))
                    if timeDiff < minTimeDiff {
                        minTimeDiff = timeDiff
                        self.currentPredictionIndex = i
                    }
                }
                
                self.updateCurrentPrediction()
                
                if !extremesResponse.predictions.isEmpty {
                    self.updateCurrentExtremes(extremesResponse.predictions)
                } else {
                    self.currentExtremes = []
                }
                
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error: \(error.localizedDescription)"
                self.allPredictions = []
                self.currentExtremes = []
                self.isLoading = false
            }
        }
    }
    
    // OPTIMIZED - No need to be @MainActor, avoids the whole UI update cycle
    func nextPrediction() {
        guard !allPredictions.isEmpty && currentPredictionIndex < allPredictions.count - 1 else { return }
        
        // Simply increment index and update without async/await
        currentPredictionIndex += 1
        updateCurrentPredictionFast()
    }
    
    // OPTIMIZED - No need to be @MainActor, avoids the whole UI update cycle
    func previousPrediction() {
        guard !allPredictions.isEmpty && currentPredictionIndex > 0 else { return }
        
        // Simply decrement index and update without async/await
        currentPredictionIndex -= 1
        updateCurrentPredictionFast()
    }
    
    func nextDay() async {
        await MainActor.run {
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        }
        await loadPredictions()
    }
    
    func previousDay() async {
        await MainActor.run {
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        }
        await loadPredictions()
    }

    // Updated toggle method to use stored metadata
       func toggleFavorite() async {
           print("⭐ PREDICTION_VM: Starting toggle for station \(stationId), bin \(bin)")
           print("📊 PREDICTION_VM: Using metadata - Name: \(stationName), Lat: \(stationLatitude?.description ?? "nil"), Lon: \(stationLongitude?.description ?? "nil")")
           
           let newValue = await currentStationService.toggleCurrentStationFavoriteWithMetadata(
               id: stationId,
               bin: bin,
               stationName: stationName.isEmpty ? nil : stationName,
               latitude: stationLatitude,
               longitude: stationLongitude,
               depth: stationDepth,
               depthType: stationDepthType
           )
           
           await MainActor.run {
               self.isFavorite = newValue
           }
           
           print("⭐ PREDICTION_VM: Toggle completed for station \(stationId), new status: \(newValue)")
       }
   
    
    func viewStationWebsite() {
        let urlString = "https://tidesandcurrents.noaa.gov/noaacurrents/predictions.html?id=\(stationId)_\(bin)"
        if let url = URL(string: urlString) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
    
    // MARK: - Private Methods
    private func updateCurrentPrediction() {
        if !allPredictions.isEmpty && currentPredictionIndex < allPredictions.count {
            currentPrediction = allPredictions[currentPredictionIndex]
            canGoForward = currentPredictionIndex < allPredictions.count - 1
            canGoBackward = currentPredictionIndex > 0
        }
    }
    
    // OPTIMIZED - Fast prediction update that minimizes UI updates and memory allocations
    private func updateCurrentPredictionFast() {
        guard !allPredictions.isEmpty && currentPredictionIndex < allPredictions.count else { return }
        
        // Batch all the updates together to minimize redraws
        DispatchQueue.main.async {
            self.currentPrediction = self.allPredictions[self.currentPredictionIndex]
            self.canGoForward = self.currentPredictionIndex < self.allPredictions.count - 1
            self.canGoBackward = self.currentPredictionIndex > 0
        }
    }
    
    private func updateCurrentExtremes(_ predictions: [TidalCurrentPrediction]) {
        if predictions.isEmpty { return }
        
        let sortedPredictions = predictions.sorted(by: { $0.timestamp < $1.timestamp })
        
        let extremes = sortedPredictions.map { prediction in
            return CurrentExtreme(
                time: prediction.timestamp,
                event: self.determineEventType(prediction, allPredictions: sortedPredictions),
                speed: abs(prediction.speed)
            )
        }
        
        updateTimeBasedFlags(extremes)
        
        self.currentExtremes = extremes
    }
    
    private func determineEventType(_ current: TidalCurrentPrediction, allPredictions: [TidalCurrentPrediction]) -> String {
        if let type = current.type?.lowercased(), type != "slack" {
            switch type {
            case "flood":
                return "Max Flood"
            case "ebb":
                return "Max Ebb"
            default:
                return ""
            }
        }
        
        // For slack water, determine if it's transitioning to flood or ebb
        if let index = allPredictions.firstIndex(where: { $0.timeString == current.timeString }) {
            if index < allPredictions.count - 1 {
                let nextPrediction = allPredictions[index + 1]
                if let nextType = nextPrediction.type?.lowercased() {
                    if nextType == "flood" {
                        return "Slack => Flood"
                    } else if nextType == "ebb" {
                        return "Slack => Ebb"
                    }
                }
            }
        }
        
        return "Slack"
    }
    
    private func updateTimeBasedFlags(_ extremes: [CurrentExtreme]) {
        let currentTime = Date()
        
        // Reset all flags first
        for extreme in extremes {
            extreme.isNextEvent = false
            extreme.isMostRecentPast = false
        }
        
        // Find most recent past event
        let pastEvents = extremes.filter { $0.time <= currentTime }
        if let lastPastEvent = pastEvents.sorted(by: { $0.time > $1.time }).first {
            lastPastEvent.isMostRecentPast = true
        }
        
        // Find next upcoming event
        let futureEvents = extremes.filter { $0.time > currentTime }
        if let nextEvent = futureEvents.sorted(by: { $0.time < $1.time }).first {
            nextEvent.isNextEvent = true
        }
    }
    
    private func updateFavoriteStatus() async {
        let isFavorite = await currentStationService.isCurrentStationFavorite(id: stationId, bin: bin)
        
        await MainActor.run {
            self.isFavorite = isFavorite
        }
    }
}
