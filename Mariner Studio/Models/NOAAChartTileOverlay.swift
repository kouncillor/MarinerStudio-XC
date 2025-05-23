
//
//  NOAAChartTileOverlay.swift
//  Mariner Studio
//
//  Created by Assistant on 5/22/25.
//

import Foundation
import MapKit

class NOAAChartTileOverlay: MKTileOverlay {
    
    private let chartType: NOAAChartType
    private var selectedLayers: Set<Int>
    
    init(chartType: NOAAChartType = .traditional, selectedLayers: Set<Int> = [0, 1, 2, 6]) {
        self.chartType = chartType
        self.selectedLayers = selectedLayers
        
        // Use a dummy template - we'll override the URL method with the working service
        super.init(urlTemplate: "")
        
        // Configure tile overlay properties
        self.canReplaceMapContent = false
        self.minimumZ = 3
        self.maximumZ = 18
        self.tileSize = CGSize(width: 256, height: 256)
        
        print("🗺️ NOAAChartTileOverlay: Initialized with \(chartType == .traditional ? "Traditional" : "ECDIS") chart type, showing layers: \(selectedLayers.sorted())")
    }
    
    // Legacy init for backwards compatibility
    init(chartType: NOAAChartType = .traditional, maxLayers: Int = 1) {
        self.chartType = chartType
        self.selectedLayers = Set(0..<maxLayers)
        
        super.init(urlTemplate: "")
        
        self.canReplaceMapContent = false
        self.minimumZ = 3
        self.maximumZ = 18
        self.tileSize = CGSize(width: 256, height: 256)
        
        print("🗺️ NOAAChartTileOverlay: Initialized with \(chartType == .traditional ? "Traditional" : "ECDIS") chart type, showing \(maxLayers) layers")
    }
    
    required init?(coder: NSCoder) {
        self.chartType = .traditional
        self.selectedLayers = [0, 1, 2, 6]
        super.init()
        
        self.canReplaceMapContent = false
        self.minimumZ = 3
        self.maximumZ = 18
        self.tileSize = CGSize(width: 256, height: 256)
    }
    
    // Method to update selected layers
    func updateSelectedLayers(_ newSelectedLayers: Set<Int>) {
        self.selectedLayers = newSelectedLayers
        print("🔄 NOAAChartTileOverlay: Updated to show layers: \(selectedLayers.sorted())")
    }
    
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        print("🔍 NOAAChartTileOverlay: Requesting tile at z:\(path.z) x:\(path.x) y:\(path.y) with layers: \(selectedLayers.sorted())")
        
        // Try the working NOAA services
        let urls = generateWorkingNOAAUrls(for: path)
        
        for (index, urlString) in urls.enumerated() {
            if let url = URL(string: urlString) {
                print("🌐 NOAAChartTileOverlay: Trying endpoint \(index + 1): \(urlString)")
                return url
            }
        }
        
        // Fallback to blank tile
        print("❌ NOAAChartTileOverlay: All endpoints failed, returning blank tile")
        return URL(string: "about:blank")!
    }
    
    private func generateWorkingNOAAUrls(for path: MKTileOverlayPath) -> [String] {
        var urls: [String] = []
        
        // Method 1: Working NOAA Maritime Chart Service (ENC Online)
        let encMaritimeUrl = buildMaritimeChartServiceUrl(for: path)
        urls.append(encMaritimeUrl)
        
        // Method 2: Traditional Chart Display Service (if available)
        if chartType == .traditional {
            let traditionalUrl = buildTraditionalChartServiceUrl(for: path)
            urls.append(traditionalUrl)
        }
        
        // Method 3: RNC Seamless service as backup
        let rncUrl = "https://seamlessrnc.nauticalcharts.noaa.gov/arcgis/rest/services/RNC/NOAA_RNC/MapServer/tile/\(path.z)/\(path.y)/\(path.x)"
        urls.append(rncUrl)
        
        return urls
    }
    
    private func buildMaritimeChartServiceUrl(for path: MKTileOverlayPath) -> String {
        let bounds = tileToGeographicBounds(for: path)
        let baseUrl = "https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/ENCOnline/MapServer/exts/MaritimeChartService/MapServer/export"
        
        // Format bounds as geographic coordinates (longitude, latitude)
        let bboxString = String(format: "%.6f,%.6f,%.6f,%.6f",
                               bounds.minLon, bounds.minLat, bounds.maxLon, bounds.maxLat)
        
        // Build layer string based on current maxLayers setting
        let layerString = buildLayerString()
        
        print("📍 NOAAChartTileOverlay: Geographic bounds for tile \(path.x),\(path.y),\(path.z): \(bboxString)")
        print("🗂️ NOAAChartTileOverlay: Using layers: \(layerString)")
        
        var components = URLComponents(string: baseUrl)!
        components.queryItems = [
            URLQueryItem(name: "f", value: "image"),
            URLQueryItem(name: "format", value: "png"),
            URLQueryItem(name: "transparent", value: "true"),
            URLQueryItem(name: "size", value: "256,256"),
            URLQueryItem(name: "bbox", value: bboxString),
            URLQueryItem(name: "bboxSR", value: "4326"),
            URLQueryItem(name: "imageSR", value: "4326"),
            URLQueryItem(name: "layers", value: layerString),
            URLQueryItem(name: "dpi", value: "96")
        ]
        
        return components.url?.absoluteString ?? baseUrl
    }
    
    private func buildTraditionalChartServiceUrl(for path: MKTileOverlayPath) -> String {
        let bounds = tileToGeographicBounds(for: path)
        let baseUrl = "https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/NOAAChartDisplay/MapServer/export"
        
        let bboxString = String(format: "%.6f,%.6f,%.6f,%.6f",
                               bounds.minLon, bounds.minLat, bounds.maxLon, bounds.maxLat)
        
        let layerString = buildLayerString()
        
        var components = URLComponents(string: baseUrl)!
        components.queryItems = [
            URLQueryItem(name: "f", value: "image"),
            URLQueryItem(name: "format", value: "png"),
            URLQueryItem(name: "transparent", value: "true"),
            URLQueryItem(name: "size", value: "256,256"),
            URLQueryItem(name: "bbox", value: bboxString),
            URLQueryItem(name: "bboxSR", value: "4326"),
            URLQueryItem(name: "imageSR", value: "4326"),
            URLQueryItem(name: "layers", value: layerString),
            URLQueryItem(name: "dpi", value: "96")
        ]
        
        return components.url?.absoluteString ?? baseUrl
    }
    
    private func buildLayerString() -> String {
        // Create layer string from selected layers
        let sortedLayers = selectedLayers.sorted().map { String($0) }
        return "show:" + sortedLayers.joined(separator: ",")
    }
    
    private func tileToGeographicBounds(for path: MKTileOverlayPath) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let z = Double(path.z)
        let x = Double(path.x)
        let y = Double(path.y)
        
        let n = pow(2.0, z)
        
        // Calculate longitude bounds
        let minLon = (x / n) * 360.0 - 180.0
        let maxLon = ((x + 1.0) / n) * 360.0 - 180.0
        
        // Calculate latitude bounds using Web Mercator to Geographic conversion
        let maxLatRad = atan(sinh(.pi * (1.0 - 2.0 * y / n)))
        let minLatRad = atan(sinh(.pi * (1.0 - 2.0 * (y + 1.0) / n)))
        
        let maxLat = maxLatRad * 180.0 / .pi
        let minLat = minLatRad * 180.0 / .pi
        
        return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }
}
