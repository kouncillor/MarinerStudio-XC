//
//  AISStreamService.swift
//  Mariner Studio
//
//  Created by Claude on 11/28/25.
//

import Foundation
import CoreLocation

// MARK: - AIS Vessel Model

struct AISVessel: Identifiable, Equatable {
    let id: String // MMSI
    let mmsi: Int
    var name: String
    var latitude: Double
    var longitude: Double
    var courseOverGround: Double? // Degrees
    var speedOverGround: Double? // Knots
    var heading: Double? // Degrees
    var shipType: Int?
    var destination: String?
    var lastUpdated: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var shipTypeDescription: String {
        guard let type = shipType else { return "Unknown" }
        switch type {
        case 20...29: return "Wing in Ground"
        case 30: return "Fishing"
        case 31, 32: return "Towing"
        case 33: return "Dredging"
        case 34: return "Diving Operations"
        case 35: return "Military Operations"
        case 36: return "Sailing"
        case 37: return "Pleasure Craft"
        case 40...49: return "High Speed Craft"
        case 50: return "Pilot Vessel"
        case 51: return "Search and Rescue"
        case 52: return "Tug"
        case 53: return "Port Tender"
        case 54: return "Anti-Pollution"
        case 55: return "Law Enforcement"
        case 60...69: return "Passenger"
        case 70...79: return "Cargo"
        case 80...89: return "Tanker"
        case 90...99: return "Other"
        default: return "Unknown (\(type))"
        }
    }

    static func == (lhs: AISVessel, rhs: AISVessel) -> Bool {
        lhs.mmsi == rhs.mmsi
    }
}

// MARK: - AIS Message Types

struct AISSubscriptionMessage: Codable {
    let APIKey: String
    let BoundingBoxes: [[[Double]]]
    let FilterMessageTypes: [String]?

    init(apiKey: String, boundingBoxes: [[[Double]]], filterMessageTypes: [String]? = nil) {
        self.APIKey = apiKey
        self.BoundingBoxes = boundingBoxes
        self.FilterMessageTypes = filterMessageTypes
    }
}

// MARK: - AIS Response Models

struct AISStreamMessage: Codable {
    let MessageType: String
    let MetaData: AISMetaData?
    let Message: AISMessageContent?
}

struct AISMetaData: Codable {
    let MMSI: Int?
    let MMSI_String: MMSIValue?
    let ShipName: String?
    let latitude: Double?
    let longitude: Double?
    let time_utc: String?
}

// MMSI_String can be either a String or Int in the API response
enum MMSIValue: Codable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(MMSIValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Int"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        }
    }

    var intValue: Int? {
        switch self {
        case .string(let s): return Int(s)
        case .int(let i): return i
        }
    }
}

struct AISMessageContent: Codable {
    let PositionReport: AISPositionReport?
    let ShipStaticData: AISShipStaticData?
    let StandardClassBPositionReport: AISStandardClassBPositionReport?
    let ExtendedClassBPositionReport: AISExtendedClassBPositionReport?
}

struct AISPositionReport: Codable {
    let Cog: Double?
    let Sog: Double?
    let TrueHeading: Int?
    let Latitude: Double?
    let Longitude: Double?
    let NavigationalStatus: Int?
}

struct AISStandardClassBPositionReport: Codable {
    let Cog: Double?
    let Sog: Double?
    let TrueHeading: Int?
    let Latitude: Double?
    let Longitude: Double?
}

struct AISExtendedClassBPositionReport: Codable {
    let Cog: Double?
    let Sog: Double?
    let TrueHeading: Int?
    let Latitude: Double?
    let Longitude: Double?
    let ShipType: Int?
    let Name: String?
}

struct AISShipStaticData: Codable {
    let Name: String?
    let ShipType: Int?
    let Destination: String?

    enum CodingKeys: String, CodingKey {
        case Name
        case ShipType = "Type"
        case Destination
    }
}

// MARK: - AIS Stream Service

protocol AISStreamServiceProtocol {
    var isConnected: Bool { get }
    var vessels: [AISVessel] { get }
    var onVesselsUpdated: (([AISVessel]) -> Void)? { get set }
    var onConnectionStateChanged: ((Bool) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }

    func connect(boundingBox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double))
    func disconnect()
    func updateBoundingBox(_ boundingBox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double))
}

class AISStreamService: NSObject, AISStreamServiceProtocol, URLSessionWebSocketDelegate {

    // MARK: - Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let apiKey: String

    private(set) var isConnected = false
    private(set) var vessels: [AISVessel] = []
    private var vesselDict: [Int: AISVessel] = [:] // MMSI -> Vessel for quick updates

    var onVesselsUpdated: (([AISVessel]) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?
    var onError: ((String) -> Void)?

    private var currentBoundingBox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var isReconnecting = false

    // MARK: - Initialization

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
    }

    // MARK: - Public Methods

    func connect(boundingBox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)) {
        // Don't reconnect if already connected
        guard !isConnected else { return }

        currentBoundingBox = boundingBox

        guard let url = URL(string: "wss://stream.aisstream.io/v0/stream") else {
            onError?("Invalid WebSocket URL")
            return
        }

        // Clean up any existing connection silently
        if webSocketTask != nil {
            webSocketTask?.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
        }

        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()

        print("🚢 AISStreamService: Connecting to AIS stream...")
    }

    func disconnect() {
        guard webSocketTask != nil else { return } // Don't do anything if already disconnected

        // Clear bounding box to prevent auto-reconnection
        currentBoundingBox = nil
        isReconnecting = false
        reconnectAttempts = 0

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        onConnectionStateChanged?(false)
        print("🚢 AISStreamService: Disconnected")
    }

    private var lastSubscriptionUpdate = Date.distantPast
    private let subscriptionUpdateInterval: TimeInterval = 2.0 // Minimum 2 seconds between subscription updates

    func updateBoundingBox(_ boundingBox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)) {
        // Throttle subscription updates
        let now = Date()
        guard now.timeIntervalSince(lastSubscriptionUpdate) >= subscriptionUpdateInterval else { return }

        currentBoundingBox = boundingBox
        if isConnected {
            lastSubscriptionUpdate = now
            sendSubscription()
        }
    }

    // MARK: - Private Methods

    private func sendSubscription() {
        guard let boundingBox = currentBoundingBox else { return }

        // AISStream expects bounding boxes as [[minLat, minLon], [maxLat, maxLon]]
        let bbox = [
            [
                [boundingBox.minLat, boundingBox.minLon],
                [boundingBox.maxLat, boundingBox.maxLon]
            ]
        ]

        let subscription = AISSubscriptionMessage(
            apiKey: apiKey,
            boundingBoxes: bbox,
            filterMessageTypes: ["PositionReport", "ShipStaticData", "StandardClassBPositionReport", "ExtendedClassBPositionReport"]
        )

        do {
            let jsonData = try JSONEncoder().encode(subscription)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let message = URLSessionWebSocketTask.Message.string(jsonString)
                webSocketTask?.send(message) { [weak self] error in
                    if let error = error {
                        print("🚢 AISStreamService: Failed to send subscription: \(error.localizedDescription)")
                        self?.onError?("Failed to subscribe: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("🚢 AISStreamService: Failed to encode subscription: \(error.localizedDescription)")
            onError?("Failed to encode subscription")
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }

                // Continue receiving messages
                self.receiveMessage()

            case .failure(let error):
                print("🚢 AISStreamService: Receive error: \(error.localizedDescription)")
                self.handleDisconnection()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        do {
            let message = try JSONDecoder().decode(AISStreamMessage.self, from: data)
            processAISMessage(message)
        } catch {
            // Silent fail for malformed messages - AIS stream can have varied formats
        }
    }

    private func processAISMessage(_ message: AISStreamMessage) {
        guard let metadata = message.MetaData,
              let mmsi = metadata.MMSI ?? metadata.MMSI_String?.intValue else {
            return
        }

        // Get or create vessel
        var vessel = vesselDict[mmsi] ?? AISVessel(
            id: String(mmsi),
            mmsi: mmsi,
            name: metadata.ShipName ?? "Unknown",
            latitude: metadata.latitude ?? 0,
            longitude: metadata.longitude ?? 0,
            lastUpdated: Date()
        )

        // Update vessel name if available
        if let name = metadata.ShipName, !name.isEmpty {
            vessel.name = name
        }

        // Update position from metadata
        if let lat = metadata.latitude, let lon = metadata.longitude {
            vessel.latitude = lat
            vessel.longitude = lon
        }

        // Process specific message types
        if let positionReport = message.Message?.PositionReport {
            if let lat = positionReport.Latitude, let lon = positionReport.Longitude {
                vessel.latitude = lat
                vessel.longitude = lon
            }
            vessel.courseOverGround = positionReport.Cog
            vessel.speedOverGround = positionReport.Sog
            if let heading = positionReport.TrueHeading, heading != 511 { // 511 = not available
                vessel.heading = Double(heading)
            }
        }

        if let classBReport = message.Message?.StandardClassBPositionReport {
            if let lat = classBReport.Latitude, let lon = classBReport.Longitude {
                vessel.latitude = lat
                vessel.longitude = lon
            }
            vessel.courseOverGround = classBReport.Cog
            vessel.speedOverGround = classBReport.Sog
            if let heading = classBReport.TrueHeading, heading != 511 {
                vessel.heading = Double(heading)
            }
        }

        if let extendedReport = message.Message?.ExtendedClassBPositionReport {
            if let lat = extendedReport.Latitude, let lon = extendedReport.Longitude {
                vessel.latitude = lat
                vessel.longitude = lon
            }
            vessel.courseOverGround = extendedReport.Cog
            vessel.speedOverGround = extendedReport.Sog
            if let heading = extendedReport.TrueHeading, heading != 511 {
                vessel.heading = Double(heading)
            }
            vessel.shipType = extendedReport.ShipType
            if let name = extendedReport.Name, !name.isEmpty {
                vessel.name = name
            }
        }

        if let staticData = message.Message?.ShipStaticData {
            if let name = staticData.Name, !name.isEmpty {
                vessel.name = name
            }
            vessel.shipType = staticData.ShipType
            vessel.destination = staticData.Destination
        }

        vessel.lastUpdated = Date()

        // Update vessel dictionary
        vesselDict[mmsi] = vessel

        // Update vessels array (throttled to prevent UI overload)
        updateVesselsArray()
    }

    private var lastVesselUpdate = Date()
    private let updateThrottleInterval: TimeInterval = 0.5 // Update UI at most every 0.5 seconds

    private func updateVesselsArray() {
        let now = Date()
        guard now.timeIntervalSince(lastVesselUpdate) >= updateThrottleInterval else { return }

        lastVesselUpdate = now

        // Remove stale vessels (older than 5 minutes)
        let staleThreshold = Date().addingTimeInterval(-300)
        vesselDict = vesselDict.filter { $0.value.lastUpdated > staleThreshold }

        vessels = Array(vesselDict.values).sorted { $0.name < $1.name }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onVesselsUpdated?(self.vessels)
        }
    }

    private func handleDisconnection() {
        // Prevent multiple simultaneous reconnection attempts
        guard !isReconnecting else { return }

        isConnected = false
        webSocketTask = nil
        onConnectionStateChanged?(false)

        // Only attempt reconnection if we have a bounding box (user initiated connection)
        guard currentBoundingBox != nil else { return }

        // Attempt reconnection
        if reconnectAttempts < maxReconnectAttempts {
            isReconnecting = true
            reconnectAttempts += 1
            let delay = Double(reconnectAttempts) * 2.0 // Exponential backoff
            print("🚢 AISStreamService: Reconnecting in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                self.isReconnecting = false

                // Make sure we still want to be connected
                guard let boundingBox = self.currentBoundingBox else { return }
                self.performConnect(boundingBox: boundingBox)
            }
        } else {
            reconnectAttempts = 0
            onError?("Connection lost. Please try again.")
        }
    }

    // Internal connect that bypasses the isConnected check (for reconnection)
    private func performConnect(boundingBox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)) {
        currentBoundingBox = boundingBox

        guard let url = URL(string: "wss://stream.aisstream.io/v0/stream") else {
            onError?("Invalid WebSocket URL")
            return
        }

        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("🚢 AISStreamService: WebSocket connected")
        isConnected = true
        reconnectAttempts = 0
        onConnectionStateChanged?(true)

        // Send subscription message
        sendSubscription()

        // Start receiving messages
        receiveMessage()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🚢 AISStreamService: WebSocket closed with code: \(closeCode)")
        handleDisconnection()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("🚢 AISStreamService: Task completed with error: \(error.localizedDescription)")
            handleDisconnection()
        }
    }
}
