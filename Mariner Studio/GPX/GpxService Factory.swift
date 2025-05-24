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
    private var defaultType: GpxServiceType = .legacy
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
    }
    
    func getAvailableServices() -> [GpxServiceType] {
        return [.legacy] // Will expand when CoreGPX is added
    }
    
    func isServiceTypeAvailable(_ type: GpxServiceType) -> Bool {
        switch type {
        case .legacy, .automatic:
            return true
        case .coreGpx:
            return false // Will be true in Phase 2
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
        // Future logic: choose based on requirements
        // For now, always use legacy
        return .legacy
    }
    
    private func instantiateService(_ type: GpxServiceType) -> ExtendedGpxServiceProtocol {
        switch type {
        case .legacy, .automatic:
            return LegacyGpxServiceWrapper()
        case .coreGpx:
            fatalError("CoreGPX service not implemented yet")
        }
    }
}

// MARK: - Convenience Methods

extension GpxServiceFactory {
    
    func createLegacyService() -> ExtendedGpxServiceProtocol {
        return createGpxService(type: .legacy)
    }
    
    func createCoreGpxService() -> ExtendedGpxServiceProtocol {
        return createGpxService(type: .coreGpx)
    }
}
