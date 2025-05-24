//
//  LegacyGpxServiceWrapper.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/24/25.
//


//
//  LegacyGpxServiceWrapper.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/24/25.
//

import Foundation

/// Clean wrapper around your existing GpxServiceImpl
class LegacyGpxServiceWrapper: ExtendedGpxServiceProtocol {
    
    // MARK: - Properties
    private let originalService: GpxServiceImpl
    
    var capabilities: GpxServiceCapabilities {
        return .legacyCapabilities
    }
    
    // MARK: - Initialization
    init() {
        self.originalService = GpxServiceImpl()
    }
    
    // MARK: - GpxServiceProtocol Implementation
    
    func loadGpxFile(from url: URL) async throws -> GpxFile {
        do {
            return try await originalService.loadGpxFile(from: url)
        } catch {
            throw convertToStandardError(error)
        }
    }
    
    // MARK: - ExtendedGpxServiceProtocol Implementation
    
    func writeGpxFile(_ gpxFile: GpxFile, to url: URL) async throws {
        throw GpxServiceError.writeNotSupported
    }
    
    func validateGpxFile(at url: URL) async throws -> Bool {
        do {
            _ = try await loadGpxFile(from: url)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func convertToStandardError(_ error: Error) -> GpxServiceError {
        if let xmlError = error as? XMLDecodingError {
            switch xmlError {
            case .parsingFailed:
                return .parsingFailed("XML parsing failed")
            case .noResult:
                return .noRouteData
            case .typeMismatch(let expected, let actual):
                return .parsingFailed("Type mismatch: expected \(expected), got \(actual)")
            }
        }
        
        if let nsError = error as NSError? {
            switch nsError.code {
            case NSFileReadNoSuchFileError:
                return .fileNotFound
            case NSFileReadNoPermissionError:
                return .fileAccessDenied
            default:
                return .parsingFailed(nsError.localizedDescription)
            }
        }
        
        return .parsingFailed(error.localizedDescription)
    }
}