//
//  AllRoutesDatabaseService.swift
//  Mariner Studio
//
//  Created for managing all routes in a unified database table.
//

import Foundation
#if canImport(SQLite)
import SQLite
#endif

class AllRoutesDatabaseService {
    // MARK: - Table Definitions
    private let allRoutes = Table("AllRoutes")
    
    // MARK: - Column Definitions
    private let colId = Expression<Int>("id")
    private let colName = Expression<String>("name")
    private let colGpxData = Expression<String>("gpx_data")
    private let colWaypointCount = Expression<Int>("waypoint_count")
    private let colTotalDistance = Expression<Double>("total_distance")
    private let colSourceType = Expression<String>("source_type")
    private let colIsFavorite = Expression<Bool>("is_favorite")
    private let colCreatedAt = Expression<Date>("created_at")
    private let colLastAccessedAt = Expression<Date>("last_accessed_at")
    private let colTags = Expression<String?>("tags")
    private let colNotes = Expression<String?>("notes")
    
    // MARK: - Properties
    private let databaseCore: DatabaseCore
    
    // MARK: - Initialization
    init(databaseCore: DatabaseCore) {
        self.databaseCore = databaseCore
    }
    
    // MARK: - Methods
    
    // Add a route to AllRoutes
    func addRouteAsync(route: AllRoute) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 Adding route: \(route.name) (source: \(route.sourceType))")
            
            let insert = allRoutes.insert(
                colName <- route.name,
                colGpxData <- route.gpxData,
                colWaypointCount <- route.waypointCount,
                colTotalDistance <- route.totalDistance,
                colSourceType <- route.sourceType,
                colIsFavorite <- route.isFavorite,
                colCreatedAt <- route.createdAt,
                colLastAccessedAt <- route.lastAccessedAt,
                colTags <- route.tags,
                colNotes <- route.notes
            )
            
            let rowId = try db.run(insert)
            try await databaseCore.flushDatabaseAsync()
            
            print("📊 Successfully added route with ID: \(rowId)")
            return Int(rowId)
        } catch {
            print("❌ Error adding route: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Get all routes
    func getAllRoutesAsync() async throws -> [AllRoute] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = allRoutes.order(colLastAccessedAt.desc)
            var results: [AllRoute] = []
            
            for row in try db.prepare(query) {
                let route = AllRoute(
                    id: row[colId],
                    name: row[colName],
                    gpxData: row[colGpxData],
                    waypointCount: row[colWaypointCount],
                    totalDistance: row[colTotalDistance],
                    sourceType: row[colSourceType],
                    isFavorite: row[colIsFavorite],
                    createdAt: row[colCreatedAt],
                    lastAccessedAt: row[colLastAccessedAt],
                    tags: row[colTags],
                    notes: row[colNotes]
                )
                results.append(route)
            }
            
            print("📊 Retrieved \(results.count) total routes")
            return results
        } catch {
            print("❌ Error fetching all routes: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Get favorite routes only
    func getFavoriteRoutesAsync() async throws -> [AllRoute] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = allRoutes
                .filter(colIsFavorite == true)
                .order(colLastAccessedAt.desc)
            
            var results: [AllRoute] = []
            
            for row in try db.prepare(query) {
                let route = AllRoute(
                    id: row[colId],
                    name: row[colName],
                    gpxData: row[colGpxData],
                    waypointCount: row[colWaypointCount],
                    totalDistance: row[colTotalDistance],
                    sourceType: row[colSourceType],
                    isFavorite: row[colIsFavorite],
                    createdAt: row[colCreatedAt],
                    lastAccessedAt: row[colLastAccessedAt],
                    tags: row[colTags],
                    notes: row[colNotes]
                )
                results.append(route)
            }
            
            print("📊 Retrieved \(results.count) favorite routes")
            return results
        } catch {
            print("❌ Error fetching favorite routes: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Get routes by source type
    func getRoutesBySourceAsync(sourceType: String) async throws -> [AllRoute] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = allRoutes
                .filter(colSourceType == sourceType)
                .order(colLastAccessedAt.desc)
            
            var results: [AllRoute] = []
            
            for row in try db.prepare(query) {
                let route = AllRoute(
                    id: row[colId],
                    name: row[colName],
                    gpxData: row[colGpxData],
                    waypointCount: row[colWaypointCount],
                    totalDistance: row[colTotalDistance],
                    sourceType: row[colSourceType],
                    isFavorite: row[colIsFavorite],
                    createdAt: row[colCreatedAt],
                    lastAccessedAt: row[colLastAccessedAt],
                    tags: row[colTags],
                    notes: row[colNotes]
                )
                results.append(route)
            }
            
            print("📊 Retrieved \(results.count) routes with source type: \(sourceType)")
            return results
        } catch {
            print("❌ Error fetching routes by source: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Check if a route already exists (by name and waypoint count)
    func routeExistsAsync(name: String, waypointCount: Int) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = allRoutes.filter(colName == name && colWaypointCount == waypointCount)
            let exists = try db.pluck(query) != nil
            
            print("📊 Route existence check for '\(name)': \(exists)")
            return exists
        } catch {
            print("❌ Error checking route existence: \(error.localizedDescription)")
            return false
        }
    }
    
    // Toggle favorite status
    func toggleFavoriteAsync(routeId: Int) async throws {
        do {
            let db = try databaseCore.ensureConnection()
            
            // Get current favorite status
            let query = allRoutes.filter(colId == routeId)
            guard let currentRow = try db.pluck(query) else {
                throw DatabaseError.routeNotFound
            }
            
            let currentIsFavorite = currentRow[colIsFavorite]
            let newIsFavorite = !currentIsFavorite
            
            // Update favorite status
            try db.run(query.update(colIsFavorite <- newIsFavorite))
            try await databaseCore.flushDatabaseAsync()
            
            print("📊 Toggled favorite status for route ID \(routeId): \(currentIsFavorite) → \(newIsFavorite)")
        } catch {
            print("❌ Error toggling favorite status: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Update last accessed time
    func updateLastAccessedAsync(routeId: Int) async throws {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = allRoutes.filter(colId == routeId)
            try db.run(query.update(colLastAccessedAt <- Date()))
            try await databaseCore.flushDatabaseAsync()
            
            print("📊 Updated last accessed time for route ID: \(routeId)")
        } catch {
            print("❌ Error updating last accessed time: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Delete a route
    func deleteRouteAsync(routeId: Int) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = allRoutes.filter(colId == routeId)
            let affectedRows = try db.run(query.delete())
            try await databaseCore.flushDatabaseAsync()
            
            print("📊 Deleted route with ID: \(routeId)")
            return affectedRows
        } catch {
            print("❌ Error deleting route: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Search routes by name
    func searchRoutesAsync(searchText: String) async throws -> [AllRoute] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = allRoutes
                .filter(colName.like("%\(searchText)%"))
                .order(colLastAccessedAt.desc)
            
            var results: [AllRoute] = []
            
            for row in try db.prepare(query) {
                let route = AllRoute(
                    id: row[colId],
                    name: row[colName],
                    gpxData: row[colGpxData],
                    waypointCount: row[colWaypointCount],
                    totalDistance: row[colTotalDistance],
                    sourceType: row[colSourceType],
                    isFavorite: row[colIsFavorite],
                    createdAt: row[colCreatedAt],
                    lastAccessedAt: row[colLastAccessedAt],
                    tags: row[colTags],
                    notes: row[colNotes]
                )
                results.append(route)
            }
            
            print("📊 Search for '\(searchText)' returned \(results.count) results")
            return results
        } catch {
            print("❌ Error searching routes: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Data Model

struct AllRoute: Identifiable {
    let id: Int
    let name: String
    let gpxData: String
    let waypointCount: Int
    let totalDistance: Double
    let sourceType: String // "public", "imported", "created"
    let isFavorite: Bool
    let createdAt: Date
    let lastAccessedAt: Date
    let tags: String?
    let notes: String?
    
    init(id: Int = 0, name: String, gpxData: String, waypointCount: Int, totalDistance: Double, sourceType: String, isFavorite: Bool = false, createdAt: Date = Date(), lastAccessedAt: Date = Date(), tags: String? = nil, notes: String? = nil) {
        self.id = id
        self.name = name
        self.gpxData = gpxData
        self.waypointCount = waypointCount
        self.totalDistance = totalDistance
        self.sourceType = sourceType
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.tags = tags
        self.notes = notes
    }
    
    // Computed properties for display
    var formattedDistance: String {
        return String(format: "%.1f nm", totalDistance)
    }
    
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }
    
    var waypointCountText: String {
        return waypointCount == 1 ? "1 waypoint" : "\(waypointCount) waypoints"
    }
    
    var sourceTypeDisplayName: String {
        switch sourceType {
        case "public":
            return "Public Route"
        case "imported":
            return "Imported Route"
        case "created":
            return "Created Route"
        default:
            return "Unknown"
        }
    }
    
    var sourceTypeIcon: String {
        switch sourceType {
        case "public":
            return "icloud.and.arrow.down"
        case "imported":
            return "folder"
        case "created":
            return "plus.circle"
        default:
            return "questionmark.circle"
        }
    }
}

// MARK: - Custom Errors

enum DatabaseError: Error {
    case routeNotFound
    
    var localizedDescription: String {
        switch self {
        case .routeNotFound:
            return "Route not found in database"
        }
    }
}