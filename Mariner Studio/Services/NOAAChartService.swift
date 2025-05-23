
//
//  NOAAChartService.swift
//  Mariner Studio
//
//  Created by Assistant on 5/22/25.
//

import Foundation
import MapKit
import CoreLocation

protocol NOAAChartService {
    func createChartTileOverlay(selectedLayers: Set<Int>) -> NOAAChartTileOverlay
    func getAvailableChartLayers() -> [NOAAChartLayer]
    func testNOAAConnection() async -> Bool
}

struct NOAAChartLayer {
    let id: String
    let name: String
    let description: String
    let isVisible: Bool
}

class NOAAChartServiceImpl: NOAAChartService {
    
    // Available NOAA chart layers with descriptions
    private let availableLayers = [
        NOAAChartLayer(id: "0", name: "Chart Framework", description: "Basic chart outline and geographic framework", isVisible: true),
        NOAAChartLayer(id: "1", name: "Land Areas", description: "Coastlines and land mass features", isVisible: true),
        NOAAChartLayer(id: "2", name: "Hydrography", description: "Water areas and basic depth information", isVisible: true),
        NOAAChartLayer(id: "3", name: "Depth Contours", description: "Depth contour lines", isVisible: true),
        NOAAChartLayer(id: "4", name: "Soundings", description: "Individual depth measurements", isVisible: true),
        NOAAChartLayer(id: "5", name: "Navigation Aids", description: "Buoys, beacons, and lights", isVisible: true),
        NOAAChartLayer(id: "6", name: "Harbors & Ports", description: "Harbor infrastructure and port facilities", isVisible: true),
        NOAAChartLayer(id: "7", name: "Hazards", description: "Rocks, wrecks, and underwater obstructions", isVisible: true),
        NOAAChartLayer(id: "8", name: "Restricted Areas", description: "Anchorage areas and restricted zones", isVisible: true),
        NOAAChartLayer(id: "9", name: "Seabed Features", description: "Bottom characteristics and features", isVisible: true),
        NOAAChartLayer(id: "10", name: "Traffic Schemes", description: "Traffic separation schemes and routing", isVisible: true),
        NOAAChartLayer(id: "11", name: "Text & Labels", description: "Place names and chart annotations", isVisible: true),
        NOAAChartLayer(id: "12", name: "Additional Features", description: "Supplementary chart information", isVisible: true),
        NOAAChartLayer(id: "13", name: "Deep Water Routes", description: "Deep water routing information", isVisible: true),
        NOAAChartLayer(id: "14", name: "Quality of Data", description: "Data quality indicators", isVisible: true)
    ]
    
    init() {
        print("🗺️ NOAAChartService: Initialized with layer selection support")
        
        // Test NOAA connection in background
        Task {
            let connectionResult = await testNOAAConnection()
            print("🌐 NOAAChartService: Connection test result: \(connectionResult ? "SUCCESS" : "FAILED")")
        }
    }
    
    func createChartTileOverlay(selectedLayers: Set<Int>) -> NOAAChartTileOverlay {
        let overlay = NOAAChartTileOverlay(selectedLayers: selectedLayers)
        print("🗺️ NOAAChartService: Created NOAA chart tile overlay with layers: \(selectedLayers.sorted())")
        return overlay
    }
    
    func getAvailableChartLayers() -> [NOAAChartLayer] {
        return availableLayers
    }
    
    func testNOAAConnection() async -> Bool {
        // Test if we can reach NOAA's chart service
        let testUrls = [
            "https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/ENCOnline/MapServer/exts/MaritimeChartService/MapServer?f=json",
            "https://seamlessrnc.nauticalcharts.noaa.gov/arcgis/rest/services/RNC/NOAA_RNC/MapServer?f=json"
        ]
        
        for urlString in testUrls {
            guard let url = URL(string: urlString) else { continue }
            
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    print("✅ NOAAChartService: Successfully connected to \(urlString)")
                    return true
                }
            } catch {
                print("❌ NOAAChartService: Failed to connect to \(urlString): \(error.localizedDescription)")
            }
        }
        
        return false
    }
}
