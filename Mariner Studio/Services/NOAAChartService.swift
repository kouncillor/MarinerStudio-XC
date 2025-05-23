//
//  NOAAChartService.swift
//  Mariner Studio
//
//  Created by Assistant on 5/22/25.
//

import Foundation
import MapKit
import CoreLocation

enum NOAAChartType {
    case traditional  // NOAA Chart Display Service (traditional paper chart style)
    case ecdis       // NOAA ECDIS Display Service (S-52 compliant)
}

protocol NOAAChartService {
    func createChartTileOverlay(chartType: NOAAChartType) -> MKTileOverlay
    func getAvailableChartLayers() -> [NOAAChartLayer]
    func getAvailableChartTypes() -> [NOAAChartType]
}

struct NOAAChartLayer {
    let id: String
    let name: String
    let description: String
    let isVisible: Bool
}

class NOAAChartServiceImpl: NOAAChartService {
    
    // Available NOAA chart layers
    private let availableLayers = [
        NOAAChartLayer(id: "0", name: "ENC", description: "Electronic Navigational Charts", isVisible: true),
        NOAAChartLayer(id: "1", name: "Approaches", description: "Harbor and approach charts", isVisible: true),
        NOAAChartLayer(id: "2", name: "Coastal", description: "Coastal charts", isVisible: true),
        NOAAChartLayer(id: "3", name: "General", description: "General charts", isVisible: true),
        NOAAChartLayer(id: "4", name: "Overview", description: "Overview charts", isVisible: true)
    ]
    
    init() {
        print("🗺️ NOAAChartService: Initialized")
    }
    
    func createChartTileOverlay(chartType: NOAAChartType = .traditional) -> MKTileOverlay {
        let overlay = NOAAChartTileOverlay(chartType: chartType)
        print("🗺️ NOAAChartService: Created NOAA \(chartType == .traditional ? "Traditional" : "ECDIS") chart tile overlay")
        return overlay
    }
    
    func getAvailableChartTypes() -> [NOAAChartType] {
        return [.traditional, .ecdis]
    }
    
    func getAvailableChartLayers() -> [NOAAChartLayer] {
        return availableLayers
    }
}
