//
//  BargeDetailsViewModel.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//

import Foundation
import SwiftUI

class BargeDetailsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var barge: Barge?
    @Published var errorMessage = ""
    @Published var isLoading = false

    // MARK: - Formatted Display Properties
    @Published var formattedHorsepower = ""
    @Published var formattedDimensions = ""
    @Published var formattedDraft = ""
    @Published var formattedYear = ""
    @Published var formattedCapacity = ""

    // MARK: - Services
    private let vesselService: VesselDatabaseService

    // MARK: - Initialization
    init(barge: Barge, vesselService: VesselDatabaseService) {
        self.barge = barge
        self.vesselService = vesselService
        updateDisplayProperties()

        // Load complete barge details
        Task {
            await loadBargeDetails()
        }
    }

    // MARK: - Private Methods
    private func loadBargeDetails() async {
        guard let id = barge?.bargeId else { return }

        await MainActor.run {
            isLoading = true
        }

        do {
            // Load the full barge details
            if let detailedBarge = try await vesselService.getBargeDetailsAsync(bargeId: id) {
                await MainActor.run {
                    self.barge = detailedBarge
                    updateDisplayProperties()
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error loading barge details: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func updateDisplayProperties() {
        guard let barge = barge else { return }

        // Format horsepower
        if let horsepower = barge.horsepower, !horsepower.isEmpty {
            formattedHorsepower = "\(horsepower) HP"
        } else {
            formattedHorsepower = "Not available"
        }

        // Format dimensions
        var dimensions: [String] = []
        if let length = barge.overallLength, !length.isEmpty {
            dimensions.append("Length: \(length)")
        }
        if let breadth = barge.overallBreadth, !breadth.isEmpty {
            dimensions.append("Breadth: \(breadth)")
        }
        formattedDimensions = dimensions.isEmpty ? "Not available" : dimensions.joined(separator: ", ")

        // Format draft
        var drafts: [String] = []
        if let loadDraft = barge.loadDraft, !loadDraft.isEmpty {
            drafts.append("Load: \(loadDraft)")
        }
        if let lightDraft = barge.lightDraft, !lightDraft.isEmpty {
            drafts.append("Light: \(lightDraft)")
        }
        formattedDraft = drafts.isEmpty ? "Not available" : drafts.joined(separator: ", ")

        // Format year information
        if let year = barge.year, !year.isEmpty {
            formattedYear = year
            if let yearRebuilt = barge.yearRebuilt, !yearRebuilt.isEmpty {
                formattedYear += " (Rebuilt: \(yearRebuilt))"
            }
        } else {
            formattedYear = "Not available"
        }

        // Format capacity
        var capacities: [String] = []
        if let tonnageCapacity = barge.tonnageCapacity, !tonnageCapacity.isEmpty {
            capacities.append("Tonnage: \(tonnageCapacity)")
        }
        if let passengerCapacity = barge.passengerCapacity, !passengerCapacity.isEmpty {
            capacities.append("Passengers: \(passengerCapacity)")
        }
        formattedCapacity = capacities.isEmpty ? "Not available" : capacities.joined(separator: ", ")
    }

    // MARK: - Public Methods

    func shareBarge() {
        guard let barge = barge else { return }

        // Create a text representation of the barge information
        var shareText = "Barge Information\n\n"
        shareText += "Name: \(barge.vesselName)\n"
        shareText += "ID: \(barge.bargeId)\n"

        if let vesselNumber = barge.vesselNumber, !vesselNumber.isEmpty {
            shareText += "Vessel Number: \(vesselNumber)\n"
        }

        if let cgNumber = barge.cgNumber, !cgNumber.isEmpty {
            shareText += "Coast Guard Number: \(cgNumber)\n"
        }

        shareText += "\nSpecifications:\n"
        shareText += "Capacity: \(formattedCapacity)\n"
        shareText += "Dimensions: \(formattedDimensions)\n"
        shareText += "Draft: \(formattedDraft)\n"
        shareText += "Year: \(formattedYear)\n"

        if let operator_ = barge.operator_, !operator_.isEmpty {
            shareText += "\nOperator: \(operator_)\n"
        }

        if let basePort = barge.basePort1, !basePort.isEmpty {
            shareText += "Base Port: \(basePort)\n"
        }

        if let state = barge.state, !state.isEmpty {
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
        print("Show notes for barge \(barge?.bargeId ?? "unknown")")
        // This would navigate to a notes view in a full implementation
    }
}
