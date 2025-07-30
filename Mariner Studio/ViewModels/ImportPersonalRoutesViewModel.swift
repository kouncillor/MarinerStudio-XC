//
//  ImportPersonalRoutesViewModel.swift
//  Mariner Studio
//
//  Created for importing personal route files from various sources.
//

import Foundation
import SwiftUI

@MainActor
class ImportPersonalRoutesViewModel: ObservableObject {
    @Published var isImporting = false
    @Published var successMessage: String = ""
    @Published var errorMessage: String = ""
    @Published var importedRoutes: [String] = []

    // MARK: - Dependencies
    private let allRoutesService: AllRoutesDatabaseService
    private let gpxService: ExtendedGpxServiceProtocol
    private let routeCalculationService: RouteCalculationService

    init(allRoutesService: AllRoutesDatabaseService? = nil, gpxService: ExtendedGpxServiceProtocol? = nil, routeCalculationService: RouteCalculationService? = nil) {
        // Use provided services or create fallbacks
        if let routesService = allRoutesService {
            self.allRoutesService = routesService
            print("📥 IMPORT: ✅ Using provided AllRoutesDatabaseService")
        } else {
            let databaseCore = DatabaseCore()
            self.allRoutesService = AllRoutesDatabaseService(databaseCore: databaseCore)
            print("📥 IMPORT: ⚠️ Creating fallback AllRoutesDatabaseService")
        }

        if let gpxSvc = gpxService {
            self.gpxService = gpxSvc
            print("📥 IMPORT: ✅ Using provided GPX service")
        } else {
            self.gpxService = GpxServiceFactory.shared.getDefaultGpxService()
            print("📥 IMPORT: ⚠️ Using default GPX service from factory")
        }

        if let calcService = routeCalculationService {
            self.routeCalculationService = calcService
            print("📥 IMPORT: ✅ Using provided RouteCalculationService")
        } else {
            self.routeCalculationService = RouteCalculationServiceImpl()
            print("📥 IMPORT: ⚠️ Creating fallback RouteCalculationService")
        }
    }

    // MARK: - Import Methods

    func importRouteFromFilePicker() {
        print("📥 IMPORT: Starting file picker import")
        isImporting = true
        errorMessage = ""
        successMessage = ""

        Task {
            do {
                // Present file picker for route files
                let fileUrl = try await DocumentPickerService.shared.presentMultiFormatFilePicker()

                print("📥 IMPORT: File selected: \(fileUrl.lastPathComponent)")

                // Import the selected file
                try await importRouteFile(from: fileUrl)

                await MainActor.run {
                    self.successMessage = "Successfully imported '\(fileUrl.lastPathComponent)'"
                    self.importedRoutes.append(fileUrl.lastPathComponent)
                    self.isImporting = false
                    print("📥 IMPORT: ✅ Successfully imported route file")
                }

            } catch DocumentPickerImportError.cancelled {
                await MainActor.run {
                    self.isImporting = false
                    print("📥 IMPORT: ⚠️ User cancelled file selection")
                }
            } catch {
                print("📥 IMPORT: ❌ Failed to import route: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to import route: \(error.localizedDescription)"
                    self.isImporting = false
                }
            }
        }
    }

    // MARK: - Private Import Logic

    private func importRouteFile(from url: URL) async throws {
        print("📥 IMPORT: Processing file: \(url.lastPathComponent)")

        // Start accessing security-scoped resource
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
                print("📥 IMPORT: 🔓 Stopped accessing security-scoped resource")
            }
        }

        // Determine file type and parse accordingly
        let fileExtension = url.pathExtension.lowercased()
        print("📥 IMPORT: File extension: \(fileExtension)")

        var gpxFile: GpxFile

        switch fileExtension {
        case "gpx", "xml":
            // Parse GPX/XML file
            gpxFile = try await parseGpxFile(from: url)
        default:
            // For other formats, try to parse as GPX first
            do {
                gpxFile = try await parseGpxFile(from: url)
            } catch {
                print("📥 IMPORT: ❌ Unsupported file format: \(fileExtension)")
                throw ImportError.unsupportedFileFormat(fileExtension)
            }
        }

        // Check for duplicate route
        let routeExists = await allRoutesService.routeExistsAsync(
            name: gpxFile.route.name,
            waypointCount: gpxFile.route.routePoints.count
        )

        if routeExists {
            print("📥 IMPORT: ⚠️ Route already exists: \(gpxFile.route.name)")
            throw ImportError.duplicateRoute(gpxFile.route.name)
        }

        // Save to AllRoutes database
        try await saveImportedRoute(gpxFile: gpxFile, originalFileName: url.lastPathComponent)
    }

    private func parseGpxFile(from url: URL) async throws -> GpxFile {
        print("📥 IMPORT: Parsing GPX file from URL")

        do {
            let gpxFile = try await gpxService.loadGpxFile(from: url)
            print("📥 IMPORT: ✅ GPX parsed successfully")
            print("📥 IMPORT: - Route name: \(gpxFile.route.name)")
            print("📥 IMPORT: - Waypoints: \(gpxFile.route.routePoints.count)")
            print("📥 IMPORT: - Distance: \(gpxFile.route.totalDistance)")
            return gpxFile
        } catch {
            print("📥 IMPORT: ❌ Failed to parse GPX file: \(error)")
            throw ImportError.parsingFailed(error.localizedDescription)
        }
    }

    private func saveImportedRoute(gpxFile: GpxFile, originalFileName: String) async throws {
        print("📥 IMPORT: Saving imported route to database")

        // Read the GPX data from the original source to store raw XML
        var gpxData: String = ""

        // If we have access to raw GPX data, use it; otherwise generate from parsed data
        // For now, we'll generate GPX data from the parsed file
        // TODO: In future, preserve original GPX data if needed
        gpxData = generateGpxData(from: gpxFile)

        // Calculate total distance from route points
        let calculatedDistance = routeCalculationService.calculateTotalDistance(from: gpxFile.route.routePoints)

        // Create AllRoute object for imported route
        let allRoute = AllRoute(
            name: gpxFile.route.name.isEmpty ? originalFileName : gpxFile.route.name,
            gpxData: gpxData,
            waypointCount: gpxFile.route.routePoints.count,
            totalDistance: calculatedDistance,
            sourceType: "imported",
            isFavorite: false,
            createdAt: Date(),
            lastAccessedAt: Date(),
            tags: "Imported",
            notes: "Imported from \(originalFileName)"
        )

        print("📥 IMPORT: Creating database entry")
        print("📥 IMPORT: - Route Name: \(allRoute.name)")
        print("📥 IMPORT: - Source Type: imported")
        print("📥 IMPORT: - Waypoints: \(allRoute.waypointCount)")
        print("📥 IMPORT: - Distance: \(allRoute.totalDistance) nm")
        print("📥 IMPORT: - GPX Data Size: \(gpxData.count) characters")

        // Save to AllRoutes database
        let savedId = try await allRoutesService.addRouteAsync(route: allRoute)
        print("📥 IMPORT: ✅ Route saved to database with ID: \(savedId)")
    }

    private func generateGpxData(from gpxFile: GpxFile) -> String {
        // Generate basic GPX XML from the parsed route
        var gpxXml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Mariner Studio" xmlns="http://www.topografix.com/GPX/1/1">
          <rte>
            <name>\(gpxFile.route.name)</name>
        """

        for point in gpxFile.route.routePoints {
            gpxXml += """

            <rtept lat="\(point.latitude)" lon="\(point.longitude)">
              <name>\(point.name)</name>
            </rtept>
            """
        }

        gpxXml += """

          </rte>
        </gpx>
        """

        return gpxXml
    }

    // MARK: - Helper Methods

    func clearMessages() {
        successMessage = ""
        errorMessage = ""
    }
}

// MARK: - Custom Errors

enum ImportError: Error, LocalizedError {
    case unsupportedFileFormat(String)
    case duplicateRoute(String)
    case parsingFailed(String)
    case databaseError(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileFormat(let format):
            return "Unsupported file format: .\(format)"
        case .duplicateRoute(let routeName):
            return "Route '\(routeName)' already exists in your collection"
        case .parsingFailed(let details):
            return "Failed to parse route file: \(details)"
        case .databaseError(let details):
            return "Database error: \(details)"
        }
    }
}
