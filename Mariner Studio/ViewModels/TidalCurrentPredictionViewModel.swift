// TidalCurrentPredictionViewModel.swift

import Foundation
import SwiftUI

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
    @Published var favoriteIcon: String = "star"
    @Published var currentExtremes: [CurrentExtreme] = []
    
    // MARK: - Private Properties
    private let predictionService: TidalCurrentPredictionService
    private let databaseService: DatabaseService
    private var stationId: String = ""
    private var bin: Int = 0
    private var currentPredictionIndex: Int = 0
    private var dayPredictions: [TidalCurrentPrediction] = []
    
    // MARK: - Initialization
    init(
        predictionService: TidalCurrentPredictionService,
        databaseService: DatabaseService
    ) {
        self.predictionService = predictionService
        self.databaseService = databaseService
    }
    
    // MARK: - Public Methods
    func initialize(stationId: String, bin: Int, stationName: String) async {
        self.stationId = stationId
        self.bin = bin
        self.stationName = stationName
        
        await updateFavoriteStatus()
        await loadPredictions()
    }
    
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
    
    private func updateCurrentPrediction() {
        if !allPredictions.isEmpty && currentPredictionIndex < allPredictions.count {
            currentPrediction = allPredictions[currentPredictionIndex]
            canGoForward = currentPredictionIndex < allPredictions.count - 1
            canGoBackward = currentPredictionIndex > 0
        }
    }
    
    func nextPrediction() {
        if currentPredictionIndex < allPredictions.count - 1 {
            currentPredictionIndex += 1
            updateCurrentPrediction()
        }
    }
    
    func previousPrediction() {
        if currentPredictionIndex > 0 {
            currentPredictionIndex -= 1
            updateCurrentPrediction()
        }
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
    
    func toggleFavorite() async {
        let newValue = await databaseService.toggleCurrentStationFavorite(id: stationId, bin: bin)
        
        await MainActor.run {
            favoriteIcon = newValue ? "star.fill" : "star"
        }
    }
    
    private func updateFavoriteStatus() async {
        let isFavorite = await databaseService.isCurrentStationFavorite(id: stationId, bin: bin)
        
        await MainActor.run {
            favoriteIcon = isFavorite ? "star.fill" : "star"
        }
    }
}
