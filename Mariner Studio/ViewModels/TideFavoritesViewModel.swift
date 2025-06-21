
import Foundation
import Combine
import SwiftUI

@MainActor
class TideFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [TidalHeightStation] = []
    @Published var isLoading = false
    @Published var errorMessage: String = ""
    
    // MARK: - NEW: Sync Properties
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncErrorMessage: String?
    @Published var syncSuccessMessage: String?
    
    // MARK: - Properties
    private var tideStationService: TideStationDatabaseService?
    private var tidalHeightService: TidalHeightService?
    private var locationService: LocationService?
    private var loadTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        print("TideFavoritesViewModel initialized")
    }
    
    // Initialize with services
    func initialize(
        tideStationService: TideStationDatabaseService,
        tidalHeightService: TidalHeightService,
        locationService: LocationService
    ) {
        self.tideStationService = tideStationService
        self.tidalHeightService = tidalHeightService
        self.locationService = locationService
        print("✅ TideFavoritesViewModel initialized with services")
    }
    
    // MARK: - Public Methods
    
    func loadFavorites() {
        loadTask?.cancel()
        
        loadTask = Task { @MainActor in
            isLoading = true
            errorMessage = ""
            
            do {
                guard let tideStationService = tideStationService,
                      let tidalHeightService = tidalHeightService else {
                    throw NSError(domain: "TideFavorites", code: 1, userInfo: [NSLocalizedDescriptionKey: "Services not initialized"])
                }
                
                let response = try await tidalHeightService.getTidalHeightStations()
                let favoriteStations = await processStationsForFavorites(
                    allStations: response.stations,
                    tideStationService: tideStationService
                )
                
                self.favorites = favoriteStations
                
            } catch {
                print("❌ Error loading favorites: \(error)")
                errorMessage = "Failed to load favorites: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func removeFavorite(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let station = favorites[index]
                await removeStationFromFavorites(station)
            }
            
            // Reload the favorites list
            loadFavorites()
            
            // Auto-sync after removing favorites
            await performAutoSyncAfterChange()
        }
    }
    
    func cleanup() {
        loadTask?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - NEW: Sync Methods
    
    /// Perform full bidirectional sync with Supabase
    func syncWithCloud() async {
        guard !isSyncing else {
            print("🔄 VIEWMODEL: Sync already in progress, skipping")
            return
        }
        
        isSyncing = true
        syncErrorMessage = nil
        syncSuccessMessage = nil
        
        print("🔄 VIEWMODEL: Starting tide station sync from TideFavoritesViewModel")
        
        let result = await TideStationSyncService.shared.syncTideStationFavorites()
        
        switch result {
        case .success(let stats):
            lastSyncTime = Date()
            syncSuccessMessage = "Sync completed! \(stats.totalOperations) operations in \(String(format: "%.1f", stats.duration))s"
            print("✅ VIEWMODEL: Sync completed successfully")
            print("✅ SYNC STATS: \(stats.totalOperations) operations in \(String(format: "%.3f", stats.duration))s")
            
        case .failure(let error):
            syncErrorMessage = error.localizedDescription
            print("❌ VIEWMODEL: Sync failed - \(error.localizedDescription)")
            
        case .partialSuccess(let stats, let errors):
            lastSyncTime = Date()
            syncErrorMessage = "Sync completed with \(errors.count) errors"
            print("⚠️ VIEWMODEL: Partial sync - \(stats.totalOperations) operations, \(errors.count) errors")
        }
        
        isSyncing = false
        
        // Reload favorites after sync to show any changes
        loadFavorites()
        
        // Clear success message after 3 seconds
        if syncSuccessMessage != nil {
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                syncSuccessMessage = nil
            }
        }
    }
    
    /// Auto-sync when app becomes active (call this in onAppear)
    func performAutoSyncIfNeeded() async {
        // Only auto-sync if it's been more than 5 minutes since last sync
        if let lastSync = lastSyncTime,
           Date().timeIntervalSince(lastSync) < 300 {
            print("🔄 VIEWMODEL: Skipping auto-sync - recent sync completed at \(lastSync)")
            return
        }
        
        print("🔄 VIEWMODEL: Performing auto-sync on app appear")
        await syncWithCloud()
    }
    
    /// Auto-sync after user makes changes (adding/removing favorites)
    func performAutoSyncAfterChange() async {
        // Wait a short delay to avoid multiple rapid syncs
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard !isSyncing else {
            print("🔄 VIEWMODEL: Skipping auto-sync after change - sync already in progress")
            return
        }
        
        print("🔄 VIEWMODEL: Performing auto-sync after user made changes")
        await syncWithCloud()
    }
    
    /// Check if sync is available (user authenticated)
    func checkSyncAvailability() async -> Bool {
        return await TideStationSyncService.shared.canSync()
    }
    
    /// Get sync status for UI display
    var syncStatusText: String {
        if isSyncing {
            return "Syncing with cloud..."
        } else if let lastSync = lastSyncTime {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Last sync: \(formatter.string(from: lastSync))"
        } else {
            return "Not synced"
        }
    }
    
    var syncStatusIcon: String {
        if isSyncing {
            return "arrow.clockwise"
        } else if syncErrorMessage != nil {
            return "exclamationmark.icloud"
        } else if lastSyncTime != nil {
            return "checkmark.icloud.fill"
        } else {
            return "icloud.slash"
        }
    }
    
    var syncStatusColor: Color {
        if isSyncing {
            return .blue
        } else if syncErrorMessage != nil {
            return .orange
        } else if lastSyncTime != nil {
            return .green
        } else {
            return .gray
        }
    }
    
    // MARK: - Private Methods
    private func processStationsForFavorites(
        allStations: [TidalHeightStation],
        tideStationService: TideStationDatabaseService
    ) async -> [TidalHeightStation] {
        var favoriteStations: [TidalHeightStation] = []
        
        for station in allStations {
            let isFavorite = await tideStationService.isTideStationFavorite(id: station.id)
            if isFavorite {
                favoriteStations.append(station)
            }
        }
        
        return favoriteStations.sorted { $0.name < $1.name }
    }
    
    private func removeStationFromFavorites(_ station: TidalHeightStation) async {
        guard let tideStationService = tideStationService else { return }
        
        let success = await tideStationService.toggleTideStationFavorite(id: station.id)
        if !success {
            await MainActor.run {
                self.errorMessage = "Failed to remove station from favorites"
            }
        }
    }
}
