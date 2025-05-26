//
//  RouteFavoritesDatabaseService.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/26/25.
//


import Foundation
#if canImport(SQLite)
import SQLite
#endif

class RouteFavoritesDatabaseService {
    // MARK: - Table Definitions
    private let routeFavorites = Table("RouteFavorites")
    
    // MARK: - Column Definitions
    private let colId = Expression<Int>("id")
    private let colName = Expression<String>("name")
    private let colGpxData = Expression<String>("gpx_data")
    private let colWaypointCount = Expression<Int>("waypoint_count")
    private let colTotalDistance = Expression<Double>("total_distance")
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
    
    // Initialize route favorites table
    func initializeRouteFavoritesTableAsync() async throws {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 Creating RouteFavorites table if it doesn't exist")
            
            // Create table
            try db.run(routeFavorites.create(ifNotExists: true) { table in
                table.column(colId, primaryKey: .autoincrement)
                table.column(colName)
                table.column(colGpxData)
                table.column(colWaypointCount)
                table.column(colTotalDistance)
                table.column(colCreatedAt)
                table.column(colLastAccessedAt)
                table.column(colTags)
                table.column(colNotes)
            })
            
            print("📊 RouteFavorites table created or already exists")
            
            // Test write capability
            let testQuery = routeFavorites.filter(colName == "TEST_INIT")
            if try db.pluck(testQuery) == nil {
                try db.run(routeFavorites.insert(or: .replace,
                    colName <- "TEST_INIT",
                    colGpxData <- "<gpx></gpx>",
                    colWaypointCount <- 0,
                    colTotalDistance <- 0.0,
                    colCreatedAt <- Date(),
                    colLastAccessedAt <- Date()
                ))
                
                // Clean up test record
                try db.run(testQuery.delete())
                print("📊 Successfully tested RouteFavorites table write capability")
            }
        } catch {
            print("❌ Error creating RouteFavorites table: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Add a route to favorites
    func addRouteFavoriteAsync(favorite: RouteFavorite) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            print("📊 Adding route favorite: \(favorite.name)")
            
            let insert = routeFavorites.insert(
                colName <- favorite.name,
                colGpxData <- favorite.gpxData,
                colWaypointCount <- favorite.waypointCount,
                colTotalDistance <- favorite.totalDistance,
                colCreatedAt <- favorite.createdAt,
                colLastAccessedAt <- favorite.lastAccessedAt,
                colTags <- favorite.tags,
                colNotes <- favorite.notes
            )
            
            let rowId = try db.run(insert)
            try await databaseCore.flushDatabaseAsync()
            
            print("📊 Successfully added route favorite with ID: \(rowId)")
            return Int(rowId)
        } catch {
            print("❌ Error adding route favorite: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Get all route favorites
    func getRouteFavoritesAsync() async throws -> [RouteFavorite] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = routeFavorites.order(colLastAccessedAt.desc)
            var results: [RouteFavorite] = []
            
            for row in try db.prepare(query) {
                let favorite = RouteFavorite(
                    id: row[colId],
                    name: row[colName],
                    gpxData: row[colGpxData],
                    waypointCount: row[colWaypointCount],
                    totalDistance: row[colTotalDistance],
                    createdAt: row[colCreatedAt],
                    lastAccessedAt: row[colLastAccessedAt],
                    tags: row[colTags],
                    notes: row[colNotes]
                )
                results.append(favorite)
            }
            
            print("📊 Retrieved \(results.count) route favorites")
            return results
        } catch {
            print("❌ Error fetching route favorites: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Check if a route is already favorited (by name and waypoint count)
    func isRouteFavoriteAsync(name: String, waypointCount: Int) async -> Bool {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = routeFavorites.filter(colName == name && colWaypointCount == waypointCount)
            let exists = try db.pluck(query) != nil
            
            print("📊 Route favorite check for '\(name)': \(exists)")
            return exists
        } catch {
            print("❌ Error checking route favorite: \(error.localizedDescription)")
            return false
        }
    }
    
    // Delete a route favorite
    func deleteRouteFavoriteAsync(favoriteId: Int) async throws -> Int {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = routeFavorites.filter(colId == favoriteId)
            let affectedRows = try db.run(query.delete())
            try await databaseCore.flushDatabaseAsync()
            
            print("📊 Deleted route favorite with ID: \(favoriteId)")
            return affectedRows
        } catch {
            print("❌ Error deleting route favorite: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Update last accessed time for a favorite
    func updateLastAccessedAsync(favoriteId: Int) async throws {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = routeFavorites.filter(colId == favoriteId)
            try db.run(query.update(colLastAccessedAt <- Date()))
            try await databaseCore.flushDatabaseAsync()
            
            print("📊 Updated last accessed time for favorite ID: \(favoriteId)")
        } catch {
            print("❌ Error updating last accessed time: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Search route favorites by name
    func searchRouteFavoritesAsync(searchText: String) async throws -> [RouteFavorite] {
        do {
            let db = try databaseCore.ensureConnection()
            
            let query = routeFavorites
                .filter(colName.like("%\(searchText)%"))
                .order(colLastAccessedAt.desc)
            
            var results: [RouteFavorite] = []
            
            for row in try db.prepare(query) {
                let favorite = RouteFavorite(
                    id: row[colId],
                    name: row[colName],
                    gpxData: row[colGpxData],
                    waypointCount: row[colWaypointCount],
                    totalDistance: row[colTotalDistance],
                    createdAt: row[colCreatedAt],
                    lastAccessedAt: row[colLastAccessedAt],
                    tags: row[colTags],
                    notes: row[colNotes]
                )
                results.append(favorite)
            }
            
            print("📊 Search for '\(searchText)' returned \(results.count) results")
            return results
        } catch {
            print("❌ Error searching route favorites: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Data Model

struct RouteFavorite: Identifiable {
    let id: Int
    let name: String
    let gpxData: String
    let waypointCount: Int
    let totalDistance: Double
    let createdAt: Date
    let lastAccessedAt: Date
    let tags: String?
    let notes: String?
    
    init(id: Int = 0, name: String, gpxData: String, waypointCount: Int, totalDistance: Double, createdAt: Date = Date(), lastAccessedAt: Date = Date(), tags: String? = nil, notes: String? = nil) {
        self.id = id
        self.name = name
        self.gpxData = gpxData
        self.waypointCount = waypointCount
        self.totalDistance = totalDistance
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
}