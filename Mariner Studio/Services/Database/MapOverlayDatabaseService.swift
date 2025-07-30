//
//  MapOverlayDatabaseService.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/23/25.
//

import Foundation
#if canImport(SQLite)
import SQLite
#endif

class MapOverlayDatabaseService {
    // MARK: - Table Definitions
    private let mapOverlaySettings = Table("MapOverlaySettings")

    // MARK: - Column Definitions
    private let colViewId = Expression<String>("view_id")
    private let colIsOverlayEnabled = Expression<Bool>("is_overlay_enabled")
    private let colSelectedLayers = Expression<String>("selected_layers") // JSON string of layer IDs
    private let colLastModified = Expression<Date>("last_modified")

    // MARK: - Properties
    private let databaseCore: DatabaseCore

    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }

    // MARK: - Methods

    // Initialize map overlay settings table
    func initializeMapOverlaySettingsTableAsync() async throws {
        do {
            let db = try databaseCore.ensureConnection()

            try db.run(mapOverlaySettings.create(ifNotExists: true) { table in
                table.column(colViewId, primaryKey: true)
                table.column(colIsOverlayEnabled)
                table.column(colSelectedLayers)
                table.column(colLastModified)
            })

            print("📊 MapOverlayDatabaseService: Successfully initialized MapOverlaySettings table")
        } catch {
            print("❌ MapOverlayDatabaseService: Error creating MapOverlaySettings table: \(error.localizedDescription)")
            throw error
        }
    }

    // Get overlay settings for a specific view
    func getOverlaySettingsAsync(viewId: String) async throws -> MapOverlaySettings? {
        do {
            let db = try databaseCore.ensureConnection()

            let query = mapOverlaySettings.filter(colViewId == viewId)

            if let row = try db.pluck(query) {
                let selectedLayersString = row[colSelectedLayers]
                let selectedLayers = parseLayersFromJson(selectedLayersString)

                let settings = MapOverlaySettings(
                    viewId: row[colViewId],
                    isOverlayEnabled: row[colIsOverlayEnabled],
                    selectedLayers: selectedLayers,
                    lastModified: row[colLastModified]
                )

                print("📊 MapOverlayDatabaseService: Retrieved settings for view \(viewId): enabled=\(settings.isOverlayEnabled), layers=\(settings.selectedLayers)")
                return settings
            }

            print("📊 MapOverlayDatabaseService: No settings found for view \(viewId)")
            return nil
        } catch {
            print("❌ MapOverlayDatabaseService: Error retrieving overlay settings: \(error.localizedDescription)")
            throw error
        }
    }

    // Save overlay settings for a specific view
    func saveOverlaySettingsAsync(settings: MapOverlaySettings) async throws {
        do {
            let db = try databaseCore.ensureConnection()

            let selectedLayersJson = convertLayersToJson(settings.selectedLayers)
            let now = Date()

            let query = mapOverlaySettings.filter(colViewId == settings.viewId)

            if try db.pluck(query) != nil {
                // Update existing record
                try db.run(query.update(
                    colIsOverlayEnabled <- settings.isOverlayEnabled,
                    colSelectedLayers <- selectedLayersJson,
                    colLastModified <- now
                ))
                print("📊 MapOverlayDatabaseService: Updated settings for view \(settings.viewId)")
            } else {
                // Insert new record
                try db.run(mapOverlaySettings.insert(
                    colViewId <- settings.viewId,
                    colIsOverlayEnabled <- settings.isOverlayEnabled,
                    colSelectedLayers <- selectedLayersJson,
                    colLastModified <- now
                ))
                print("📊 MapOverlayDatabaseService: Created new settings for view \(settings.viewId)")
            }

            try await databaseCore.flushDatabaseAsync()
            print("📊 MapOverlayDatabaseService: Successfully saved settings for view \(settings.viewId): enabled=\(settings.isOverlayEnabled), layers=\(settings.selectedLayers)")
        } catch {
            print("❌ MapOverlayDatabaseService: Error saving overlay settings: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Helper Methods

    private func convertLayersToJson(_ layers: Set<Int>) -> String {
        do {
            let layersArray = Array(layers).sorted()
            let jsonData = try JSONSerialization.data(withJSONObject: layersArray, options: [])
            return String(data: jsonData, encoding: .utf8) ?? "[]"
        } catch {
            print("❌ MapOverlayDatabaseService: Error converting layers to JSON: \(error.localizedDescription)")
            return "[]"
        }
    }

    private func parseLayersFromJson(_ jsonString: String) -> Set<Int> {
        do {
            guard let jsonData = jsonString.data(using: .utf8) else { return [] }
            let layersArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [Int] ?? []
            return Set(layersArray)
        } catch {
            print("❌ MapOverlayDatabaseService: Error parsing layers from JSON: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Data Model
struct MapOverlaySettings {
    let viewId: String
    let isOverlayEnabled: Bool
    let selectedLayers: Set<Int>
    let lastModified: Date

    init(viewId: String, isOverlayEnabled: Bool, selectedLayers: Set<Int>, lastModified: Date = Date()) {
        self.viewId = viewId
        self.isOverlayEnabled = isOverlayEnabled
        self.selectedLayers = selectedLayers
        self.lastModified = lastModified
    }
}
