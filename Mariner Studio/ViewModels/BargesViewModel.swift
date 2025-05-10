//
//  BargesViewModel.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//


import Foundation
import SwiftUI

class BargesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var barges: [Barge] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var searchText = ""
    @Published var totalBarges = 0
    
    // MARK: - Properties
    let vesselService: VesselDatabaseService
    private var allBarges: [Barge] = []
    
    // MARK: - Initialization
    init(vesselService: VesselDatabaseService) {
        self.vesselService = vesselService
        print("✅ BargesViewModel initialized.")
    }
    
    // MARK: - Public Methods
    func loadBarges() async {
        print("⏰ BargesViewModel: loadBarges() started at \(Date())")
        
        guard !isLoading else {
            print("⏰ BargesViewModel: loadBarges() exited early, already loading.")
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            print("⏰ BargesViewModel: Starting database call for barges at \(Date())")
            let response = try await vesselService.getBargesAsync()
            print("⏰ BargesViewModel: Finished database call for barges at \(Date()). Count: \(response.count)")
            
            // Update mapping to include vesselNumber
            let mappedBarges = response.map { databaseBarge -> Barge in
                return Barge(
                    bargeId: databaseBarge.bargeId,
                    vesselName: databaseBarge.vesselName,
                    vesselNumber: databaseBarge.vesselNumber
                )
            }
            
            await MainActor.run {
                allBarges = mappedBarges
                filterBarges()
                isLoading = false
                print("⏰ BargesViewModel: UI state update complete at \(Date())")
            }
        } catch {
            print("❌ BargesViewModel: Error in loadBarges at \(Date()): \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to load barges: \(error.localizedDescription)"
                allBarges = []
                barges = []
                totalBarges = 0
                isLoading = false
            }
        }
        print("⏰ BargesViewModel: loadBarges() finished at \(Date())")
    }
    
    func refreshBarges() async {
        print("🔄 BargesViewModel: refreshBarges() called at \(Date())")
        await MainActor.run {
            barges = []
            allBarges = []
            totalBarges = 0
        }
        await loadBarges()
    }
    
    func filterBarges() {
        print("🔄 BargesViewModel: filterBarges() called at \(Date())")
        let filtered = allBarges.filter { barge in
            searchText.isEmpty ||
            barge.vesselName.localizedCaseInsensitiveContains(searchText) ||
            barge.bargeId.localizedCaseInsensitiveContains(searchText) ||
            (barge.vesselNumber?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        let sorted = filtered.sorted { first, second in
            first.vesselName.localizedCompare(second.vesselName) == .orderedAscending
        }
        
        DispatchQueue.main.async {
            self.barges = sorted
            print("🔄 BargesViewModel: filterBarges() updated self.barges on main thread at \(Date()). Count: \(sorted.count)")
            self.totalBarges = sorted.count
        }
    }
    
    func clearSearch() {
        searchText = ""
        filterBarges()
    }
}
