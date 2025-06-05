
//
//  NOAAChartTileOverlay.swift
//  Mariner Studio
//
//  Created by Assistant on 5/22/25.
//

import Foundation
import MapKit

class NOAAChartTileOverlay: MKTileOverlay {
    
    private var selectedLayers: Set<Int>
    
    init(selectedLayers: Set<Int> = [0, 1, 2, 6]) {
        self.selectedLayers = selectedLayers
        
        // Use a dummy template - we'll override the URL method with the working service
        super.init(urlTemplate: "")
        
        // Configure tile overlay properties
        self.canReplaceMapContent = false
        self.minimumZ = 3
        self.maximumZ = 18
        self.tileSize = CGSize(width: 256, height: 256)
        
        print("🗺️ NOAAChartTileOverlay: Initialized with selected layers: \(selectedLayers.sorted())")
    }
    
    required init?(coder: NSCoder) {
        self.selectedLayers = [0, 1, 2, 6]
        super.init(urlTemplate: "")
        
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
    
    // Computed property to access current layer count
    var currentChartLayerCount: Int {
        return selectedLayers.count
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
        
        // Method 2: RNC Seamless service as backup
        let rncUrl = "https://seamlessrnc.nauticalcharts.noaa.gov/arcgis/rest/services/RNC/NOAA_RNC/MapServer/tile/\(path.z)/\(path.y)/\(path.x)"
        urls.append(rncUrl)
        
        return urls
    }
    
    private func buildMaritimeChartServiceUrl(for path: MKTileOverlayPath) -> String {
        let bounds = tileToGeographicBounds(for: path)
        let baseUrl = "https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/ENCOnline/MapServer/exts/MaritimeChartService/MapServer/export"
        
        // Format bounds as geographic coordinates (longitude, latitude) - EPSG:4326 format
        let bboxString = String(format: "%.6f,%.6f,%.6f,%.6f",
                               bounds.minLon, bounds.minLat, bounds.maxLon, bounds.maxLat)
        
        // Build layer string based on selected layers
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
            URLQueryItem(name: "bboxSR", value: "4326"),        // INPUT is EPSG:4326 (WGS84)
            URLQueryItem(name: "imageSR", value: "3857"),        // OUTPUT should be EPSG:3857 (Web Mercator)
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
        
        // Calculate longitude bounds (unchanged - this should be correct)
        let minLon = (x / n) * 360.0 - 180.0
        let maxLon = ((x + 1.0) / n) * 360.0 - 180.0
        
        // Calculate latitude bounds using STANDARD Web Mercator (no Y-flip)
        let maxLatRad = atan(sinh(.pi * (1.0 - 2.0 * y / n)))
        let minLatRad = atan(sinh(.pi * (1.0 - 2.0 * (y + 1.0) / n)))
        
        let maxLat = maxLatRad * 180.0 / .pi
        let minLat = minLatRad * 180.0 / .pi
        
        print("🗺️ Tile \(path.x),\(path.y),\(path.z) -> bounds: \(minLat),\(minLon) to \(maxLat),\(maxLon)")
        
        return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }
}
