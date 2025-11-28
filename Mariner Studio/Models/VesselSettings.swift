//
//  VesselSettings.swift
//  Mariner Studio
//
//  Created for vessel configuration persistence
//

import Foundation
import Combine

class VesselSettings: ObservableObject {
    static let shared = VesselSettings()

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let vesselName = "vessel_name"
        static let vesselLength = "vessel_length"
        static let vesselWidth = "vessel_width"
        static let vesselDraft = "vessel_draft"
        static let vesselAverageSpeed = "vessel_average_speed"
    }

    // MARK: - Published Properties
    @Published var vesselName: String {
        didSet { UserDefaults.standard.set(vesselName, forKey: Keys.vesselName) }
    }

    @Published var vesselLength: Double {
        didSet { UserDefaults.standard.set(vesselLength, forKey: Keys.vesselLength) }
    }

    @Published var vesselWidth: Double {
        didSet { UserDefaults.standard.set(vesselWidth, forKey: Keys.vesselWidth) }
    }

    @Published var vesselDraft: Double {
        didSet { UserDefaults.standard.set(vesselDraft, forKey: Keys.vesselDraft) }
    }

    @Published var averageSpeed: Double {
        didSet { UserDefaults.standard.set(averageSpeed, forKey: Keys.vesselAverageSpeed) }
    }

    // MARK: - Computed Properties
    var hasVesselConfigured: Bool {
        return !vesselName.isEmpty || vesselLength > 0 || averageSpeed > 0
    }

    var averageSpeedString: String {
        return averageSpeed > 0 ? String(format: "%.1f", averageSpeed) : "10"
    }

    // MARK: - Display Formatted Properties
    var vesselLengthDisplay: String {
        return vesselLength > 0 ? "\(String(format: "%.1f", vesselLength)) ft" : "Not set"
    }

    var vesselWidthDisplay: String {
        return vesselWidth > 0 ? "\(String(format: "%.1f", vesselWidth)) ft" : "Not set"
    }

    var vesselDraftDisplay: String {
        return vesselDraft > 0 ? "\(String(format: "%.1f", vesselDraft)) ft" : "Not set"
    }

    var averageSpeedDisplay: String {
        return averageSpeed > 0 ? "\(String(format: "%.1f", averageSpeed)) kts" : "Not set"
    }

    // MARK: - Initialization
    private init() {
        self.vesselName = UserDefaults.standard.string(forKey: Keys.vesselName) ?? ""
        self.vesselLength = UserDefaults.standard.double(forKey: Keys.vesselLength)
        self.vesselWidth = UserDefaults.standard.double(forKey: Keys.vesselWidth)
        self.vesselDraft = UserDefaults.standard.double(forKey: Keys.vesselDraft)
        self.averageSpeed = UserDefaults.standard.double(forKey: Keys.vesselAverageSpeed)

        print("🚢 VesselSettings: Loaded - Name: '\(vesselName)', Length: \(vesselLength), Width: \(vesselWidth), Draft: \(vesselDraft), Speed: \(averageSpeed)")
    }

    // MARK: - Methods
    func resetToDefaults() {
        vesselName = ""
        vesselLength = 0
        vesselWidth = 0
        vesselDraft = 0
        averageSpeed = 0
        print("🚢 VesselSettings: Reset to defaults")
    }
}
