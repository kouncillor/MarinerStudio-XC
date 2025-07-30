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
    private let tideFavoritesCloudService: TideFavoritesCloudService

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
        tideFavoritesCloudService: TideFavoritesCloudService
    ) {
        self.stationId = stationId
        self.stationName = stationName
        self.latitude = latitude
        self.longitude = longitude
        self.predictionService = predictionService
        self.tideFavoritesCloudService = tideFavoritesCloudService

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
        let result = await tideFavoritesCloudService.toggleFavorite(
            stationId: stationId,
            stationName: stationName,
            latitude: latitude,
            longitude: longitude
        )

        switch result {
        case .success(let newValue):
            await MainActor.run {
                self.isFavorite = newValue
            }
        case .failure(let error):
            print("❌ TidalHeightPrediction: Failed to toggle favorite: \(error)")
            // Keep current state if toggle fails
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
        let result = await tideFavoritesCloudService.isFavorite(stationId: stationId)

        switch result {
        case .success(let isFavorite):
            await MainActor.run {
                self.isFavorite = isFavorite
            }
        case .failure(let error):
            print("❌ TidalHeightPrediction: Failed to check favorite status: \(error)")
            await MainActor.run {
                self.isFavorite = false // Default to false if check fails
            }
        }
    }

    private func updateFormattedDate() {
        formattedSelectedDate = dateFormatter.string(from: selectedDate)
    }
}
