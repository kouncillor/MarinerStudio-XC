import Foundation
import SwiftUI

class TugsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var tugs: [Tug] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var searchText = ""
    @Published var totalTugs = 0

    // MARK: - Properties
    let vesselService: VesselDatabaseService
    private var allTugs: [Tug] = []

    // MARK: - Initialization
    init(vesselService: VesselDatabaseService) {
        self.vesselService = vesselService
        print("✅ TugsViewModel initialized.")
    }

    // MARK: - Public Methods
    func loadTugs() async {
        print("⏰ TugsViewModel: loadTugs() started at \(Date())")

        guard !isLoading else {
            print("⏰ TugsViewModel: loadTugs() exited early, already loading.")
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }

        do {
            print("⏰ TugsViewModel: Starting database call for tugs at \(Date())")
            let response = try await vesselService.getTugsAsync()
            print("⏰ TugsViewModel: Finished database call for tugs at \(Date()). Count: \(response.count)")

            // For now, we'll just use the tugId and vesselName
            let mappedTugs = response.map { databaseTug -> Tug in
                return Tug(
                    tugId: databaseTug.tugId,
                    vesselName: databaseTug.vesselName
                )
            }

            await MainActor.run {
                allTugs = mappedTugs
                filterTugs()
                isLoading = false
                print("⏰ TugsViewModel: UI state update complete at \(Date())")
            }
        } catch {
            print("❌ TugsViewModel: Error in loadTugs at \(Date()): \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to load tugs: \(error.localizedDescription)"
                allTugs = []
                tugs = []
                totalTugs = 0
                isLoading = false
            }
        }
        print("⏰ TugsViewModel: loadTugs() finished at \(Date())")
    }

    func refreshTugs() async {
        print("🔄 TugsViewModel: refreshTugs() called at \(Date())")
        await MainActor.run {
            tugs = []
            allTugs = []
            totalTugs = 0
        }
        await loadTugs()
    }

    func filterTugs() {
        print("🔄 TugsViewModel: filterTugs() called at \(Date())")
        let filtered = allTugs.filter { tug in
            searchText.isEmpty ||
            tug.vesselName.localizedCaseInsensitiveContains(searchText) ||
            tug.tugId.localizedCaseInsensitiveContains(searchText)
        }

        let sorted = filtered.sorted { first, second in
            first.vesselName.localizedCompare(second.vesselName) == .orderedAscending
        }

        DispatchQueue.main.async {
            self.tugs = sorted
            print("🔄 TugsViewModel: filterTugs() updated self.tugs on main thread at \(Date()). Count: \(sorted.count)")
            self.totalTugs = sorted.count
        }
    }

    func clearSearch() {
        searchText = ""
        filterTugs()
    }
}
