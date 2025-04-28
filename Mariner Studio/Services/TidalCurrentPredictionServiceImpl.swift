// TidalCurrentPredictionServiceImpl.swift

import Foundation

class TidalCurrentPredictionServiceImpl: TidalCurrentPredictionService {
    // MARK: - Constants
    private let baseUrl = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
    
    // MARK: - Properties
    private let urlSession: URLSession
    
    // MARK: - Initialization
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    // MARK: - TidalCurrentPredictionService Methods
    func getPredictions(stationId: String, bin: Int, date: Date) async throws -> TidalCurrentPredictionResponse {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: date)
        
        let urlString = "\(baseUrl)?begin_date=\(dateString)" +
                        "&end_date=\(dateString)" +
                        "&station=\(stationId)" +
                        "&product=currents_predictions" +
                        "&bin=\(bin)" +
                        "&interval=10" +
                        "&time_zone=lst_ldt" +
                        "&units=english" +
                        "&format=xml"
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let content = String(data: data, encoding: .utf8) ?? ""
        
        if content.contains("Error") {
            throw NetworkError.serverError(statusCode: 0)
        }
        
        do {
            let parser = XMLParser(data: data)
            let xmlParser = XMLParserHelper()
            parser.delegate = xmlParser
            if parser.parse() {
                if let predictionResponse = xmlParser.currentPredictionResponse {
                    return predictionResponse
                }
            }
            throw NetworkError.parsingError
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    func getExtremes(stationId: String, bin: Int, date: Date) async throws -> TidalCurrentPredictionResponse {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: date)
        
        let urlString = "\(baseUrl)?begin_date=\(dateString)" +
                        "&end_date=\(dateString)" +
                        "&station=\(stationId)" +
                        "&product=currents_predictions" +
                        "&bin=\(bin)" +
                        "&time_zone=lst_ldt" +
                        "&interval=MAX_SLACK" +
                        "&units=english" +
                        "&format=xml"
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let content = String(data: data, encoding: .utf8) ?? ""
        
        if content.contains("Error") {
            throw NetworkError.serverError(statusCode: 0)
        }
        
        do {
            let parser = XMLParser(data: data)
            let xmlParser = XMLParserHelper()
            parser.delegate = xmlParser
            if parser.parse() {
                if let predictionResponse = xmlParser.currentPredictionResponse {
                    return predictionResponse
                }
            }
            throw NetworkError.parsingError
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    func getStationType(stationId: String, bin: Int) async throws -> TidalCurrentStationType {
        let urlString = "\(baseUrl)?begin_date=today" +
                        "&end_date=today" +
                        "&station=\(stationId)" +
                        "&product=currents_predictions" +
                        "&bin=\(bin)" +
                        "&interval=MAX_SLACK_MIN" +
                        "&units=english" +
                        "&time_zone=lst_ldt" +
                        "&format=xml"
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let content = String(data: data, encoding: .utf8) ?? ""
        
        if content.contains("Error") {
            return .unknown
        }
        
        return .maxSlackMin
    }
}

// MARK: - XML Parser Helper
class XMLParserHelper: NSObject, XMLParserDelegate {
    var currentPredictionResponse: TidalCurrentPredictionResponse?
    
    private var currentElement = ""
    private var units = ""
    private var predictions: [TidalCurrentPrediction] = []
    
    private var currentRegularSpeed: Double?
    private var currentVelocityMajor: Double?
    private var currentBin: Int = 0
    private var currentTimeString: String = ""
    private var currentDirection: Double = 0
    private var currentMeanFloodDirection: Double = 0
    private var currentMeanEbbDirection: Double = 0
    private var currentDepth: Double = 0
    private var currentType: String?
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        
        if elementName == "cp" {
            // Reset current prediction values
            currentRegularSpeed = nil
            currentVelocityMajor = nil
            currentBin = 0
            currentTimeString = ""
            currentDirection = 0
            currentMeanFloodDirection = 0
            currentMeanEbbDirection = 0
            currentDepth = 0
            currentType = nil
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let data = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !data.isEmpty {
            switch currentElement {
            case "units":
                units = data
            case "Speed":
                currentRegularSpeed = Double(data)
            case "Velocity_Major":
                currentVelocityMajor = Double(data)
            case "Bin":
                currentBin = Int(data) ?? 0
            case "Time":
                currentTimeString = data
            case "Direction":
                currentDirection = Double(data) ?? 0
            case "meanFloodDir":
                currentMeanFloodDirection = Double(data) ?? 0
            case "meanEbbDir":
                currentMeanEbbDirection = Double(data) ?? 0
            case "Depth":
                currentDepth = Double(data) ?? 0
            case "Type":
                currentType = data
            default:
                break
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "cp" {
            let prediction = TidalCurrentPrediction(
                regularSpeed: currentRegularSpeed,
                velocityMajor: currentVelocityMajor,
                bin: currentBin,
                timeString: currentTimeString,
                direction: currentDirection,
                meanFloodDirection: currentMeanFloodDirection,
                meanEbbDirection: currentMeanEbbDirection,
                depth: currentDepth,
                type: currentType
            )
            predictions.append(prediction)
        } else if elementName == "current_predictions" {
            currentPredictionResponse = TidalCurrentPredictionResponse(
                units: units,
                predictions: predictions
            )
        }
    }
}

// Remove the extension that was causing the conflict
// MARK: - Extend NetworkError with new error types
// extension NetworkError {
//     static let parsingError = NetworkError(0, "Failed to parse response")
// }
