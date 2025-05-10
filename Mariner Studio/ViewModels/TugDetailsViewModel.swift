

import Foundation
import SwiftUI

class TugDetailsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var tug: Tug?
    @Published var errorMessage = ""
    @Published var isLoading = false
    
    // MARK: - Formatted Display Properties
    @Published var formattedHorsepower = ""
    @Published var formattedDimensions = ""
    @Published var formattedDraft = ""
    @Published var formattedYear = ""
    
    // MARK: - Services
    private let vesselService: VesselDatabaseService
    
    // MARK: - Initialization
    init(tug: Tug, vesselService: VesselDatabaseService) {
        self.tug = tug
        self.vesselService = vesselService
        updateDisplayProperties()
        
        // Load complete tug details
        Task {
            await loadTugDetails()
        }
    }
    
    // MARK: - Private Methods
    private func loadTugDetails() async {
        guard let id = tug?.tugId else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Load the full tug details
            if let detailedTug = try await vesselService.getTugDetailsAsync(tugId: id) {
                await MainActor.run {
                    self.tug = detailedTug
                    updateDisplayProperties()
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error loading tug details: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Private Methods
    private func updateDisplayProperties() {
        guard let tug = tug else { return }
        
        // Format horsepower
        if let horsepower = tug.horsepower, !horsepower.isEmpty {
            formattedHorsepower = "\(horsepower) HP"
        } else {
            formattedHorsepower = "Not available"
        }
        
        // Format dimensions
        var dimensions: [String] = []
        if let length = tug.overallLength, !length.isEmpty {
            dimensions.append("Length: \(length)")
        }
        if let breadth = tug.overallBreadth, !breadth.isEmpty {
            dimensions.append("Breadth: \(breadth)")
        }
        formattedDimensions = dimensions.isEmpty ? "Not available" : dimensions.joined(separator: ", ")
        
        // Format draft
        var drafts: [String] = []
        if let loadDraft = tug.loadDraft, !loadDraft.isEmpty {
            drafts.append("Load: \(loadDraft)")
        }
        if let lightDraft = tug.lightDraft, !lightDraft.isEmpty {
            drafts.append("Light: \(lightDraft)")
        }
        formattedDraft = drafts.isEmpty ? "Not available" : drafts.joined(separator: ", ")
        
        // Format year information
        if let year = tug.year, !year.isEmpty {
            formattedYear = year
            if let yearRebuilt = tug.yearRebuilt, !yearRebuilt.isEmpty {
                formattedYear += " (Rebuilt: \(yearRebuilt))"
            }
        } else {
            formattedYear = "Not available"
        }
    }
    
    // MARK: - Public Methods
    
    func shareTug() {
        guard let tug = tug else { return }
        
        // Create a text representation of the tug information
        var shareText = "Tug Information\n\n"
        shareText += "Name: \(tug.vesselName)\n"
        shareText += "ID: \(tug.tugId)\n"
        
        if let vesselNumber = tug.vesselNumber, !vesselNumber.isEmpty {
            shareText += "Vessel Number: \(vesselNumber)\n"
        }
        
        if let cgNumber = tug.cgNumber, !cgNumber.isEmpty {
            shareText += "Coast Guard Number: \(cgNumber)\n"
        }
        
        shareText += "\nSpecifications:\n"
        shareText += "Horsepower: \(formattedHorsepower)\n"
        shareText += "Dimensions: \(formattedDimensions)\n"
        shareText += "Draft: \(formattedDraft)\n"
        shareText += "Year: \(formattedYear)\n"
        
        if let operator_ = tug.operator_, !operator_.isEmpty {
            shareText += "\nOperator: \(operator_)\n"
        }
        
        if let basePort = tug.basePort1, !basePort.isEmpty {
            shareText += "Base Port: \(basePort)\n"
        }
        
        if let state = tug.state, !state.isEmpty {
            shareText += "State: \(state)\n"
        }
        
        // Create activity view controller for sharing
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        // Present the view controller
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let rootViewController = windowScene?.windows.first?.rootViewController
        rootViewController?.present(activityViewController, animated: true, completion: nil)
    }
    
    // Placeholder for notes functionality - can be expanded later
    func showNotes() {
        print("Show notes for tug \(tug?.tugId ?? "unknown")")
        // This would navigate to a notes view in a full implementation
    }
}
