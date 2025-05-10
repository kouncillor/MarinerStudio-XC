//
//  BuoyService.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//


import Foundation

protocol BuoyService {
    func getBuoyStations() async throws -> BuoyStationResponse
}

class BuoyServiceImpl: BuoyService {
    // MARK: - Properties
    private let activeStationsUrl = "https://www.ndbc.noaa.gov/activestations.xml"
    
    // MARK: - BuoyService Protocol
    func getBuoyStations() async throws -> BuoyStationResponse {
        print("⏰ BuoyService: getBuoyStations() started at \(Date())")
        
        guard let url = URL(string: activeStationsUrl) else {
            print("❌ BuoyService: Invalid URL")
            throw URLError(.badURL)
        }
        
        do {
            print("⏰ BuoyService: Starting API call at \(Date())")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("❌ BuoyService: Bad response")
                throw URLError(.badServerResponse)
            }
            
            print("⏰ BuoyService: API call succeeded at \(Date())")
            
            // Parse XML
            let parser = XMLParser(data: data)
            let buoyXMLParser = BuoyXMLParser()
            parser.delegate = buoyXMLParser
            
            if parser.parse() {
                let response = BuoyStationResponse(stations: buoyXMLParser.stations)
                print("⏰ BuoyService: Parsed \(response.stations.count) stations at \(Date())")
                return response
            } else {
                print("❌ BuoyService: XML parsing failed")
                throw NSError(domain: "BuoyService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse XML data"])
            }
        } catch {
            print("❌ BuoyService: Error fetching or parsing buoy stations: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - XML Parser
class BuoyXMLParser: NSObject, XMLParserDelegate {
    var stations: [BuoyStation] = []
    private var currentElement = ""
    
    // XMLParserDelegate methods
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        
        if elementName == "station" {
            // Create a station from the attributes
            let id = attributeDict["id"] ?? ""
            let name = attributeDict["name"] ?? ""
            
            var latitude: Double? = nil
            if let latString = attributeDict["lat"], let lat = Double(latString) {
                latitude = lat
            }
            
            var longitude: Double? = nil
            if let lonString = attributeDict["lon"], let lon = Double(lonString) {
                longitude = lon
            }
            
            var elevation: Double? = nil
            if let elevString = attributeDict["elev"], let elev = Double(elevString) {
                elevation = elev
            }
            
            let station = BuoyStation(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                elevation: elevation,
                type: attributeDict["type"] ?? "",
                meteorological: attributeDict["met"],
                currents: attributeDict["currents"],
                waterQuality: attributeDict["waterquality"],
                dart: attributeDict["dart"]
            )
            
            stations.append(station)
        }
    }
}