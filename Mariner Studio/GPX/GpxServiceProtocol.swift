
//
//  GpxServiceProtocol.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/24/25.
//

import Foundation

// MARK: - Main GPX Service Protocol

protocol GpxServiceProtocol {
    func loadGpxFile(from url: URL) async throws -> GpxFile
}

// MARK: - Extended GPX Service Protocol

protocol ExtendedGpxServiceProtocol: GpxServiceProtocol {
    var capabilities: GpxServiceCapabilities { get }
    func writeGpxFile(_ gpxFile: GpxFile, to url: URL) async throws
    func validateGpxFile(at url: URL) async throws -> Bool
}

// MARK: - GPX Service Errors

enum GpxServiceError: Error, LocalizedError {
    case fileNotFound
    case invalidFileFormat
    case parsingFailed(String)
    case unsupportedVersion
    case noRouteData
    case fileAccessDenied
    case writeNotSupported
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "GPX file not found"
        case .invalidFileFormat:
            return "Invalid GPX file format"
        case .parsingFailed(let details):
            return "Failed to parse GPX file: \(details)"
        case .unsupportedVersion:
            return "Unsupported GPX version"
        case .noRouteData:
            return "No route data found in GPX file"
        case .fileAccessDenied:
            return "Access to GPX file denied"
        case .writeNotSupported:
            return "Writing GPX files is not supported by this service"
        }
    }
}

// MARK: - GPX Service Capabilities

struct GpxServiceCapabilities {
    let canRead: Bool
    let canWrite: Bool
    let supportsRoutes: Bool
    let supportsTracks: Bool
    let supportsWaypoints: Bool
    let supportsExtensions: Bool
    let supportedVersions: [String]
    let serviceName: String
    
    static let legacyCapabilities = GpxServiceCapabilities(
        canRead: true,
        canWrite: false,
        supportsRoutes: true,
        supportsTracks: false,
        supportsWaypoints: false,
        supportsExtensions: false,
        supportedVersions: ["1.1"],
        serviceName: "Legacy GPX Service"
    )
    
    static let coreGpxCapabilities = GpxServiceCapabilities(
        canRead: true,
        canWrite: true,
        supportsRoutes: true,
        supportsTracks: true,
        supportsWaypoints: true,
        supportsExtensions: true,
        supportedVersions: ["1.0", "1.1"],
        serviceName: "CoreGPX Service"
    )
}
