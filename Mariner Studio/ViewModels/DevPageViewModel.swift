//
//  DevPageViewModel.swift
//  Mariner Studio
//
//  Created for development page logic and GPX import functionality.
//

import Foundation
import SwiftUI
#if canImport(SQLite)
import SQLite
#endif

#if DEBUG
@MainActor
class DevPageViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var statusMessage: String = ""
    @Published var showingFilePicker: Bool = false
    
    // MARK: - GPX Loading
    
    func loadGPXFiles() {
        statusMessage = "Opening file picker for GPX selection..."
        showingFilePicker = true
    }
    
    func importGPXFile(from url: URL) {
        isLoading = true
        statusMessage = "Importing GPX file: \(url.lastPathComponent)"
        
        Task {
            do {
                // Start accessing the security-scoped resource
                let _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                
                try await processGPXFile(from: url)
                
                await MainActor.run {
                    self.statusMessage = "✅ Successfully imported \(url.lastPathComponent) to base database!"
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "❌ Failed to import \(url.lastPathComponent): \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - GPX Processing Implementation
    
    private func processGPXFile(from url: URL) async throws {
        // 1. Load and parse GPX file
        let gpxData = try String(contentsOf: url, encoding: .utf8)
        let fileName = url.deletingPathExtension().lastPathComponent
        
        // 2. Parse GPX to extract metadata
        let gpxFile = try await parseGPXData(gpxData)
        
        // 3. Insert into base database (project's SS1.db)
        try await insertIntoBaseDatabase(
            name: fileName,
            gpxData: gpxData,
            waypointCount: gpxFile.route.routePoints.count,
            totalDistance: gpxFile.route.totalDistance
        )
        
        // 4. Optionally refresh user's database to see the new route
        try await refreshUserDatabase()
    }
    
    private func parseGPXData(_ gpxData: String) async throws -> GpxFile {
        // Use existing GPX service factory singleton to get the best available service
        let gpxService = GpxServiceFactory.shared.createServiceForReading()
        
        // Parse the GPX data using the existing service
        return try await gpxService.loadGpxFile(from: gpxData)
    }
    
    private func insertIntoBaseDatabase(name: String, gpxData: String, waypointCount: Int, totalDistance: Double) async throws {
        // Get path to project's base SS1.db file
        guard let projectBasePath = getProjectBaseDatabasePath() else {
            throw NSError(domain: "DevPageViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not locate project's base database"])
        }
        
        print("📊 DEV: Inserting route '\(name)' into base database at: \(projectBasePath)")
        print("📊 DEV: Route has \(waypointCount) waypoints, distance: \(totalDistance)")
        
        // Open connection to base database
        let connection = try Connection(projectBasePath)
        
        // Define table and columns (same as RouteFavoritesDatabaseService)
        let routeFavorites = SQLite.Table("RouteFavorites")
        let colId = SQLite.Expression<Int>("id")
        let colName = SQLite.Expression<String>("name")
        let colGpxData = SQLite.Expression<String>("gpx_data")
        let colWaypointCount = SQLite.Expression<Int>("waypoint_count")
        let colTotalDistance = SQLite.Expression<Double>("total_distance")
        let colCreatedAt = SQLite.Expression<Date>("created_at")
        let colLastAccessedAt = SQLite.Expression<Date>("last_accessed_at")
        let colTags = SQLite.Expression<String?>("tags")
        let colNotes = SQLite.Expression<String?>("notes")
        let colIsEmbedded = SQLite.Expression<Bool>("is_embedded")
        let colCategory = SQLite.Expression<String?>("category")
        
        // First, ensure the table has the new columns we need
        try await ensureEmbeddedColumnsExist(connection: connection, table: routeFavorites, colIsEmbedded: colIsEmbedded, colCategory: colCategory)
        
        // Insert the route with embedded flag
        let insert = routeFavorites.insert(
            colName <- name,
            colGpxData <- gpxData,
            colWaypointCount <- waypointCount,
            colTotalDistance <- totalDistance,
            colCreatedAt <- Date(),
            colLastAccessedAt <- Date(),
            colTags <- nil,
            colNotes <- "Imported via dev tools",
            colIsEmbedded <- true,
            colCategory <- "Imported Routes"
        )
        
        try connection.run(insert)
        print("📊 DEV: ✅ Successfully inserted route '\(name)' into base database")
    }
    
    private func ensureEmbeddedColumnsExist(connection: Connection, table: SQLite.Table, colIsEmbedded: SQLite.Expression<Bool>, colCategory: SQLite.Expression<String?>) async throws {
        // Add is_embedded column if it doesn't exist
        do {
            try connection.run(table.addColumn(colIsEmbedded, defaultValue: false))
            print("📊 DEV: Added 'is_embedded' column to RouteFavorites table")
        } catch {
            // Column might already exist, which is fine
            print("📊 DEV: 'is_embedded' column already exists or couldn't be added")
        }
        
        // Add category column if it doesn't exist
        do {
            try connection.run(table.addColumn(colCategory, defaultValue: nil))
            print("📊 DEV: Added 'category' column to RouteFavorites table")
        } catch {
            // Column might already exist, which is fine
            print("📊 DEV: 'category' column already exists or couldn't be added")
        }
    }
    
    private func getProjectBaseDatabasePath() -> String? {
        // In development, try to locate the project's SS1.db file
        // This should point to the source database in your Xcode project
        
        // Try to find the project directory and SS1.db file
        let fileManager = FileManager.default
        let currentPath = fileManager.currentDirectoryPath
        
        // Look for SS1.db in various locations relative to current path
        let possiblePaths = [
            "\(currentPath)/SS1.db",
            "\(currentPath)/Mariner Studio/SS1.db",
            "\(currentPath)/../SS1.db",
            "\(currentPath)/../Mariner Studio/SS1.db"
        ]
        
        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                print("📊 DEV: Found project database at: \(path)")
                return path
            }
        }
        
        // If not found, try to use Bundle.main as a reference
        if let bundlePath = Bundle.main.path(forResource: "SS1", ofType: "db") {
            print("📊 DEV: Using bundle database path: \(bundlePath)")
            return bundlePath
        }
        
        print("📊 DEV: Could not locate project's base database")
        return nil
    }
    
    private func refreshUserDatabase() async throws {
        // Copy updated base database to user's Documents directory
        // So developer can immediately see the new routes
        guard let basePath = getProjectBaseDatabasePath() else {
            throw NSError(domain: "DevPageViewModel", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot refresh - base database not found"])
        }
        
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let userDbPath = documentsDirectory.appendingPathComponent("SS1.db").path
        
        // Backup current user database
        let backupPath = documentsDirectory.appendingPathComponent("SS1_backup.db").path
        if fileManager.fileExists(atPath: userDbPath) {
            try? fileManager.removeItem(atPath: backupPath)
            try fileManager.copyItem(atPath: userDbPath, toPath: backupPath)
        }
        
        // Copy updated base database to user location
        try? fileManager.removeItem(atPath: userDbPath)
        try fileManager.copyItem(atPath: basePath, toPath: userDbPath)
        
        print("📊 DEV: ✅ Refreshed user database with updated base database")
        print("📊 DEV: Backup saved to: \(backupPath)")
    }
}
#endif