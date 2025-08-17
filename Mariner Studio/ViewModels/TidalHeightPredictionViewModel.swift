import Foundation
import SwiftUI

@MainActor
class TidalHeightPredictionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var predictions: [TidalHeightPrediction] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var selectedDate = Date()
    @Published var formattedSelectedDate = ""
    @Published var isFavorite = false

    // MARK: - Properties
    let stationId: String
    let stationName: String
    let latitude: Double?
    let longitude: Double?
    private let predictionService: TidalHeightPredictionService
    private let coreDataManager: CoreDataManager

    // MARK: - Private Properties
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()

    // MARK: - Initialization
    init(
        stationId: String,
        stationName: String,
        latitude: Double?,
        longitude: Double?,
        predictionService: TidalHeightPredictionService,
        coreDataManager: CoreDataManager
    ) {
        self.stationId = stationId
        self.stationName = stationName
        self.latitude = latitude
        self.longitude = longitude
        self.predictionService = predictionService
        self.coreDataManager = coreDataManager

        updateFormattedDate()

        Task {
            await updateFavoriteStatus()
        }
    }

    // MARK: - Methods
    func loadPredictions() async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }

        do {
            let response = try await predictionService.getPredictions(
                stationId: stationId,
                date: selectedDate
            )

            let predictions = response.predictions

            await MainActor.run {
                self.predictions = predictions
                print("🌊 Loaded \(predictions.count) predictions")
            }
            isLoading = false
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
        let currentlyFavorite = isFavorite
        
        if currentlyFavorite {
            coreDataManager.removeTideFavorite(stationId: stationId)
        } else {
            coreDataManager.addTideFavorite(
                stationId: stationId,
                name: stationName,
                latitude: latitude,
                longitude: longitude
            )
        }
        
        let newValue = !currentlyFavorite
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
        let tideFavorites = coreDataManager.getTideFavorites()
        let isFavorite = tideFavorites.contains { $0.stationId == stationId }

        await MainActor.run {
            self.isFavorite = isFavorite
        }
    }

    private func updateFormattedDate() {
        formattedSelectedDate = dateFormatter.string(from: selectedDate)
    }
}
