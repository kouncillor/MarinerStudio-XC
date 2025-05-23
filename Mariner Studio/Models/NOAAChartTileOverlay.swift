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
    
    // NOAA WMTS Service endpoints (more reliable than export service)
    private let noaaTraditionalWMTS = "https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/NOAAChartDisplay/MapServer/WMTS/tile/1.0.0/MCS_NOAAChartDisplay/default/default028mm/{z}/{y}/{x}.png"
    private let noaaECDISWMTS = "https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/ENCOnline/MapServer/WMTS/tile/1.0.0/MCS_ENCOnline/default/default028mm/{z}/{y}/{x}.png"
    
    init(chartType: NOAAChartType = .traditional) {
        // MUST set all stored properties BEFORE calling super.init()
        self.chartType = chartType
        
        // Now call the parent initializer
        super.init()
        
        // Configure tile overlay properties AFTER super.init()
        self.canReplaceMapContent = false
        self.minimumZ = 3
        self.maximumZ = 18
        self.tileSize = CGSize(width: 256, height: 256)
        
        print("🗺️ NOAAChartTileOverlay: Initialized with \(chartType == .traditional ? "Traditional" : "ECDIS") chart type")
    }
    
    required init?(coder: NSCoder) {
        self.chartType = .traditional
        super.init(coder: coder)
    }
    
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        // WMTS uses a different URL structure than the export service
        let templateURL = chartType == .traditional ? noaaTraditionalWMTS : noaaECDISWMTS
        
        let urlString = templateURL
            .replacingOccurrences(of: "{z}", with: "\(path.z)")
            .replacingOccurrences(of: "{y}", with: "\(path.y)")
            .replacingOccurrences(of: "{x}", with: "\(path.x)")
        
        guard let url = URL(string: urlString) else {
            print("❌ NOAAChartTileOverlay: Failed to construct URL for tile \(path.x),\(path.y),\(path.z)")
            return URL(string: "about:blank")!
        }
        
        print("🗺️ NOAAChartTileOverlay (\(chartType == .traditional ? "Traditional" : "ECDIS")): Requesting tile (\(path.x),\(path.y),\(path.z))")
        print("🔗 URL: \(url)")
        return url
    }
    
    // Fallback method: if WMTS fails, try the export service
    func createFallbackURL(forTilePath path: MKTileOverlayPath) -> URL {
        let bounds = tileBounds(for: path)
        let baseURL = "https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/NOAAChartDisplay/MapServer/export"
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "f", value: "image"),
            URLQueryItem(name: "format", value: "png"),
            URLQueryItem(name: "transparent", value: "true"),
            URLQueryItem(name: "size", value: "256,256"),
            URLQueryItem(name: "bbox", value: "\(bounds.minX),\(bounds.minY),\(bounds.maxX),\(bounds.maxY)"),
            URLQueryItem(name: "bboxSR", value: "4326"),
            URLQueryItem(name: "imageSR", value: "3857"),
            URLQueryItem(name: "layers", value: "show:0,1,2,3,4,5,6,7,8,9")
        ]
        
        return components.url ?? URL(string: "about:blank")!
    }
    
    // Convert tile path to geographic bounds (for fallback export service)
    private func tileBounds(for path: MKTileOverlayPath) -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        let z = Double(path.z)
        let x = Double(path.x)
        let y = Double(path.y)
        
        let n = pow(2.0, z)
        
        // Convert to longitude/latitude bounds
        let lonMin = x / n * 360.0 - 180.0
        let lonMax = (x + 1.0) / n * 360.0 - 180.0
        
        let latMinRad = atan(sinh(.pi * (1.0 - 2.0 * (y + 1.0) / n)))
        let latMaxRad = atan(sinh(.pi * (1.0 - 2.0 * y / n)))
        
        let latMin = latMinRad * 180.0 / .pi
        let latMax = latMaxRad * 180.0 / .pi
        
        return (minX: lonMin, minY: latMin, maxX: lonMax, maxY: latMax)
    }
}

