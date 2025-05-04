import Foundation
import SwiftUI

class TidalHeightPredictionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var predictions: [TidalHeightPrediction] = []
    @Published var selectedDate = Date()
    @Published var errorMessage = ""
    @Published var isLoading = false
    @Published var isFavorite = false
    @Published var formattedSelectedDate: String = ""
    
    // MARK: - Properties
    let stationId: String
    let stationName: String
    
    // MARK: - Private Properties
    private let predictionService: TidalHeightPredictionService
    private let tideStationService: TideStationDatabaseService
    private let dateFormatter: DateFormatter
    
    // MARK: - Initialization
    init(
        stationId: String,
        stationName: String,
        predictionService: TidalHeightPredictionService,
        tideStationService: TideStationDatabaseService
    ) {
        print("🌊 Initializing view model for station: \(stationId) - \(stationName)")
        self.stationId = stationId
        self.stationName = stationName
        self.predictionService = predictionService
        self.tideStationService = tideStationService
        
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        updateFormattedDate()
        
        Task {
            await updateFavoriteStatus()
        }
    }
    
    // MARK: - Public Methods
    func loadPredictions() async {
        print("🌊 Loading predictions for station \(stationId) on \(dateFormatter.string(from: selectedDate))")
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            let response = try await predictionService.getPredictions(
                stationId: stationId,
                date: selectedDate
            )
            
            await MainActor.run {
                if response.predictions.isEmpty {
                    errorMessage = "No predictions available for this date"
                } else {
                    predictions = response.predictions.sorted(by: { $0.timestamp < $1.timestamp })
                    print("🌊 Loaded \(predictions.count) predictions")
                }
                isLoading = false
            }
        } catch let error as ApiError {
            await MainActor.run {
                errorMessage = error.message
                predictions = []
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load predictions: \(error.localizedDescription)"
                predictions = []
                isLoading = false
            }
        }
    }
    
    func toggleFavorite() async {
        // Since toggleTideStationFavorite doesn't throw, we don't need a do-catch block
        let newValue = await tideStationService.toggleTideStationFavorite(id: stationId)
        
        await MainActor.run {
            self.isFavorite = newValue
        }
    }
    
    func nextDay() async {
        await MainActor.run {
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            updateFormattedDate()
        }
        
        await loadPredictions()
    }
    
    func previousDay() async {
        await MainActor.run {
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            updateFormattedDate()
        }
        
        await loadPredictions()
    }
    
    func viewStationWebsite() {
        let urlString = "https://tidesandcurrents.noaa.gov/stationhome.html?id=\(stationId)"
        if let url = URL(string: urlString) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
    
    // MARK: - Private Methods
    private func updateFavoriteStatus() async {
        let isFavorite = await tideStationService.isTideStationFavorite(id: stationId)
        
        await MainActor.run {
            self.isFavorite = isFavorite
        }
    }
    
    private func updateFormattedDate() {
        formattedSelectedDate = dateFormatter.string(from: selectedDate)
    }
}
