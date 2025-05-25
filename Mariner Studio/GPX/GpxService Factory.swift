
//
//  GpxServiceFactory.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/24/25.
//

import Foundation

// MARK: - Service Selection

enum GpxServiceType {
    case legacy
    case coreGpx
    case automatic
}

// MARK: - GPX Service Factory

class GpxServiceFactory {
    
    // MARK: - Singleton
    static let shared = GpxServiceFactory()
    
    // MARK: - Properties
    private var defaultType: GpxServiceType = .automatic
    private var cachedServices: [GpxServiceType: ExtendedGpxServiceProtocol] = [:]
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Interface
    
    func createGpxService(type: GpxServiceType = .automatic) -> ExtendedGpxServiceProtocol {
        let resolvedType = resolveServiceType(type)
        
        if let cached = cachedServices[resolvedType] {
            return cached
        }
        
        let service = instantiateService(resolvedType)
        cachedServices[resolvedType] = service
        return service
    }
    
    func getDefaultGpxService() -> ExtendedGpxServiceProtocol {
        return createGpxService(type: defaultType)
    }
    
    func setDefaultServiceType(_ type: GpxServiceType) {
        defaultType = type
        print("📦 GpxServiceFactory: Default service type set to \(type)")
    }
    
    func getAvailableServices() -> [GpxServiceType] {
        return [.legacy, .coreGpx, .automatic]
    }
    
    func isServiceTypeAvailable(_ type: GpxServiceType) -> Bool {
        switch type {
        case .legacy, .automatic:
            return true
        case .coreGpx:
            return true // Now available!
        }
    }
    
    // MARK: - Service Selection Logic
    
    func recommendServiceForTask(_ task: GpxTask) -> GpxServiceType {
        switch task {
        case .readSimpleRoute:
            return .legacy
        case .readComplexGpx:
            return .coreGpx
        case .writeGpxFile:
            return .coreGpx
        case .validateGpxFile:
            return .coreGpx
        }
    }
    
    // MARK: - Private Methods
    
    private func resolveServiceType(_ type: GpxServiceType) -> GpxServiceType {
        switch type {
        case .automatic:
            return chooseBestAvailableService()
        case .legacy:
            return .legacy
        case .coreGpx:
            return isServiceTypeAvailable(.coreGpx) ? .coreGpx : .legacy
        }
    }
    
    private func chooseBestAvailableService() -> GpxServiceType {
        // Smart service selection logic
        // For now, prefer CoreGPX if available, fallback to legacy
        if isServiceTypeAvailable(.coreGpx) {
            print("📦 GpxServiceFactory: Auto-selecting CoreGPX service")
            return .coreGpx
        } else {
            print("📦 GpxServiceFactory: Auto-selecting Legacy service")
            return .legacy
        }
    }
    
    private func instantiateService(_ type: GpxServiceType) -> ExtendedGpxServiceProtocol {
        switch type {
        case .legacy:
            print("📦 GpxServiceFactory: Creating Legacy GPX service")
            return LegacyGpxServiceWrapper()
        case .coreGpx:
            print("📦 GpxServiceFactory: Creating CoreGPX service")
            return CoreGpxService()
        case .automatic:
            // This should never happen due to resolveServiceType
            return LegacyGpxServiceWrapper()
        }
    }
}

// MARK: - Task Types

enum GpxTask {
    case readSimpleRoute
    case readComplexGpx
    case writeGpxFile
    case validateGpxFile
}

// MARK: - Convenience Methods

extension GpxServiceFactory {
    
    func createLegacyService() -> ExtendedGpxServiceProtocol {
        return createGpxService(type: .legacy)
    }
    
    func createCoreGpxService() -> ExtendedGpxServiceProtocol {
        return createGpxService(type: .coreGpx)
    }
    
    func createServiceForWriting() -> ExtendedGpxServiceProtocol {
        return createGpxService(type: .coreGpx)
    }
    
    func createServiceForReading() -> ExtendedGpxServiceProtocol {
        return createGpxService(type: .automatic)
    }
    
    // Reset cached services (useful for testing or configuration changes)
    func clearCache() {
        cachedServices.removeAll()
        print("📦 GpxServiceFactory: Service cache cleared")
    }
}

// MARK: - Debug and Monitoring

extension GpxServiceFactory {
    
    func getServiceInfo() -> [String: Any] {
        return [
            "defaultType": String(describing: defaultType),
            "availableServices": getAvailableServices().map { String(describing: $0) },
            "cachedServices": cachedServices.keys.map { String(describing: $0) }
        ]
    }
    
    func printServiceStatus() {
        let info = getServiceInfo()
        print("📊 GpxServiceFactory Status:")
        print("  Default Type: \(info["defaultType"] ?? "unknown")")
        print("  Available: \(info["availableServices"] ?? [])")
        print("  Cached: \(info["cachedServices"] ?? [])")
    }
}
