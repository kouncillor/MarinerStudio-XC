//
//  GpxService.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//


import Foundation

protocol GpxService {
    func loadGpxFile(from url: URL) async throws -> GpxFile
}

class GpxServiceImpl: GpxService {
    func loadGpxFile(from url: URL) async throws -> GpxFile {
        let data = try Data(contentsOf: url)
        
        // Parse XML into a GpxFile object
        let parser = XMLParser(data: data)
        let delegate = GPXParserDelegate()
        parser.delegate = delegate
        
        let success = parser.parse()
        
        if !success {
            if let error = parser.parserError {
                throw error
            } else if let delegateError = delegate.error {
                throw delegateError
            } else {
                throw XMLDecodingError.parsingFailed
            }
        }
        
        guard let gpxFile = delegate.gpxFile else {
            throw XMLDecodingError.noResult
        }
        
        return gpxFile
    }
}

class GPXParserDelegate: NSObject, XMLParserDelegate {
    var gpxFile: GpxFile?
    var error: Error?
    
    private var currentElement = ""
    private var currentRoute: GpxRoute?
    private var currentRoutePoints: [GpxRoutePoint] = []
    private var currentRoutePoint: GpxRoutePoint?
    private var routeName: String?
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        
        switch elementName {
        case "gpx":
            // Start of GPX file
            break
        case "rte":
            // Start of a route
            currentRoute = GpxRoute(name: "", routePoints: [])
        case "rtept":
            // Start of a route point
            if let latStr = attributeDict["lat"], let lonStr = attributeDict["lon"],
               let lat = Double(latStr), let lon = Double(lonStr) {
                currentRoutePoint = GpxRoutePoint(latitude: lat, longitude: lon)
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "rte":
            // End of route - add to result
            if var route = currentRoute {
                route.name = routeName ?? "Route"
                route.routePoints = currentRoutePoints
                currentRoute = route
                
                // Create the GpxFile with the route
                gpxFile = GpxFile(route: route)
            }
        case "rtept":
            // End of route point - add to current route points
            if var routePoint = currentRoutePoint {
                currentRoutePoints.append(routePoint)
                currentRoutePoint = nil
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let data = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !data.isEmpty {
            switch currentElement {
            case "name":
                if currentRoutePoint != nil {
                    // This is a waypoint name
                    currentRoutePoint?.name = data
                } else {
                    // This is a route name
                    routeName = data
                }
            default:
                break
            }
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        error = parseError
    }
}

enum XMLDecodingError: Error {
    case parsingFailed
    case noResult
    case typeMismatch(expected: Any.Type, actual: Any.Type)
}
