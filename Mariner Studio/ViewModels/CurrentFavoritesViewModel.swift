
//
//  CurrentFavoritesViewModel.swift
//  Mariner
//
//  Created by Timothy Russell on 2025-06-27.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

class CurrentFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var favorites: [TidalCurrentStation] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var lastLoadTime: Date?
    @Published var loadDuration: Double = 0.0
    @Published var debugInfo = ""
    
    // MARK: - NEW - Sync Properties
    @Published var isSyncing = false
    @Published var syncMessage = ""
    @Published var lastSyncTime: Date?

    // MARK: - Private Properties
    private var currentStationService: CurrentStationDatabaseService?
    private var tidalCurrentService: TidalCurrentService?
    private var locationService: LocationService?
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
    // Performance tracking
    private var startTime: Date?
    private var phaseStartTime: Date?
    
    // MARK: - Initialization
    func initialize(
        currentStationService: CurrentStationDatabaseService?,
        tidalCurrentService: TidalCurrentService?,
        locationService: LocationService?
    ) {
        self.currentStationService = currentStationService
        self.tidalCurrentService = tidalCurrentService
        self.locationService = locationService
    }
    
    deinit {
        loadTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func loadFavorites() {
        if let existingTask = loadTask {
            existingTask.cancel()
        }
        
        loadTask = Task { @MainActor in
            await performLoadFavorites()
        }
    }
    
    @MainActor
    private func performLoadFavorites() async {
        startTime = Date()
        
        guard let currentStationService = currentStationService else {
            await handleLoadError("CurrentStationDatabaseService not available", phase: "Service Check")
            return
        }
        
        do {
            isLoading = true
            errorMessage = ""
            
            let favoriteRecords = try await currentStationService.getCurrentStationFavoritesWithMetadata()
            
            var favoriteStations: [TidalCurrentStation] = favoriteRecords.map { $0.toTidalCurrentStation() }
            
            if let locationService = locationService {
                favoriteStations = await calculateDistances(for: favoriteStations, locationService: locationService)
            }
            
            let sortedStations = favoriteStations.sorted {
                if let dist1 = $0.distanceFromUser, let dist2 = $1.distanceFromUser {
                    return dist1 < dist2
                }
                if $0.distanceFromUser != nil && $1.distanceFromUser == nil { return true }
                if $0.distanceFromUser == nil && $1.distanceFromUser != nil { return false }
                return $0.name < $1.name
            }
            
            if !Task.isCancelled {
                favorites = sortedStations
                isLoading = false
                lastLoadTime = Date()
                if let startTime = startTime {
                    loadDuration = Date().timeIntervalSince(startTime)
                    updateDebugInfo("✅ Loaded \(sortedStations.count) favorites in \(String(format: "%.3f", loadDuration))s")
                }
            }
        } catch {
            await handleLoadError("Failed to load favorites: \(error.localizedDescription)", phase: "Load Operation")
        }
    }
    
    // MARK: - NEW - Sync Method
    @MainActor
    func syncFavorites() async {
        isSyncing = true
        syncMessage = "Syncing with cloud..."

        let result = await CurrentStationSyncService.shared.syncCurrentStationFavorites()

        switch result {
        case .success(let stats):
            lastSyncTime = Date()
            syncMessage = "Sync complete. Uploaded: \(stats.uploaded), Downloaded: \(stats.downloaded)."
            // After a successful sync, reload the local favorites to reflect changes
            await performLoadFavorites()
        case .failure(let error):
            syncMessage = "Sync failed: \(error.localizedDescription)"
        }
        
        isSyncing = false
    }

    // MARK: - Helper Methods
    
    @MainActor
    private func handleLoadError(_ message: String, phase: String) async {
        errorMessage = message
        isLoading = false
        updateDebugInfo("❌ Error in \(phase)")
        if let startTime = startTime {
            loadDuration = Date().timeIntervalSince(startTime)
        }
    }
    
    @MainActor
    private func updateDebugInfo(_ info: String) {
        debugInfo = info
    }
    
    private func calculateDistances(for stations: [TidalCurrentStation], locationService: LocationService) async -> [TidalCurrentStation] {
        guard let userLocation = await getUserLocation(locationService: locationService) else {
            return stations
        }
        
        return stations.map { station in
            if let lat = station.latitude, let lon = station.longitude {
                let stationLocation = CLLocation(latitude: lat, longitude: lon)
                let distance = userLocation.distance(from: stationLocation) * 0.000621371 // meters to miles
                return station.withDistance(distance)
            }
            return station
        }
    }
    
    private func getUserLocation(locationService: LocationService) async -> CLLocation? {
        if let currentLocation = locationService.currentLocation {
            return currentLocation
        }
        
        guard await locationService.requestLocationPermission() else { return nil }
        
        await MainActor.run {
            locationService.startUpdatingLocation()
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        return locationService.currentLocation
    }
    
    // MARK: - User Actions
    
    func removeFavorite(at indexSet: IndexSet) {
        Task {
            guard let currentStationService = currentStationService else { return }
            for index in indexSet {
                guard index < favorites.count else { continue }
                let favorite = favorites[index]
                
                _ = await currentStationService.toggleCurrentStationFavoriteWithMetadata(
                    id: favorite.id,
                    bin: favorite.currentBin ?? 0,
                    stationName: favorite.name,
                    latitude: favorite.latitude,
                    longitude: favorite.longitude,
                    depth: favorite.depth,
                    depthType: favorite.depthType
                )
            }
            await MainActor.run {
                loadFavorites()
            }
        }
    }
    
    func cleanup() {
        loadTask?.cancel()
    }
    
    // MARK: - UPDATED - Refresh Support
    
    func refreshFavorites() async {
        // The refresh action will now trigger a full sync.
        await syncFavorites()
    }
}
