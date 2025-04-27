import Foundation
import SwiftUI

class TidalStationWebViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isFavorite = false
    
    // MARK: - Properties
    let stationId: String
    let stationName: String
    let stationUrl: URL
    
    // MARK: - Private Properties
    private let databaseService: DatabaseService
    
    // MARK: - Initialization
    init(
        stationId: String,
        stationName: String,
        databaseService: DatabaseService
    ) {
        self.stationId = stationId
        self.stationName = stationName
        self.databaseService = databaseService
        
        // Create URL for the station's NOAA page
        let urlString = "https://tidesandcurrents.noaa.gov/stationhome.html?id=\(stationId)"
        self.stationUrl = URL(string: urlString) ?? URL(string: "https://tidesandcurrents.noaa.gov")!
        
        // Check favorite status
        Task {
            await updateFavoriteStatus()
        }
    }
    
    // MARK: - Public Methods
    func toggleFavorite() async {
        do {
            let newValue = await databaseService.toggleTideStationFavorite(id: stationId)
            
            await MainActor.run {
                self.isFavorite = newValue
            }
        } catch {
            print("Failed to update favorite status: \(error.localizedDescription)")
        }
    }
    
    func shareStation() {
        let text = """
        NOAA Tide Station: \(stationName)
        URL: \(stationUrl.absoluteString)
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        // Find the current key window to present from
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            // Find the presented view controller
            var presentedViewController = rootViewController
            while let presented = presentedViewController.presentedViewController {
                presentedViewController = presented
            }
            
            // Present the share sheet
            presentedViewController.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Private Methods
    private func updateFavoriteStatus() async {
        let isFavorite = await databaseService.isTideStationFavorite(id: stationId)
        
        await MainActor.run {
            self.isFavorite = isFavorite
        }
    }
}
