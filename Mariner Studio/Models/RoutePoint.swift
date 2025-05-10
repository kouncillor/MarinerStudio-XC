//
//  RoutePoint.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/10/25.
//


import Foundation
import Combine

class RoutePoint: ObservableObject, Identifiable {
    let id = UUID()
    
    @Published var name: String
    @Published var latitude: Double
    @Published var longitude: Double
    @Published var eta: Date
    @Published var distanceToNext: Double
    @Published var bearingToNext: Double
    
    init(name: String = "", latitude: Double = 0.0, longitude: Double = 0.0, 
         eta: Date = Date(), distanceToNext: Double = 0.0, bearingToNext: Double = 0.0) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.eta = eta
        self.distanceToNext = distanceToNext
        self.bearingToNext = bearingToNext
    }
    
    var coordinates: String {
        return "\(String(format: "%.6f", latitude))°, \(String(format: "%.6f", longitude))°"
    }
    
    var courseDisplay: String {
        return "\(String(format: "%.0f", bearingToNext))°"
    }
}