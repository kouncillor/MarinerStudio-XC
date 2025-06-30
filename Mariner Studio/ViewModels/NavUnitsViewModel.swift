//
//  NavUnitsViewModel.swift
//  Mariner Studio
//
//  Minimal ViewModel for simple nav units list
//

import Foundation
import SwiftUI

class NavUnitsViewModel: ObservableObject {
    @Published var navUnits: [StationWithDistance<NavUnit>] = []
    @Published var isLoading = false
    
    private let navUnitService: NavUnitDatabaseService
    private let locationService: LocationService
    
    init(navUnitService: NavUnitDatabaseService, locationService: LocationService) {
        self.navUnitService = navUnitService
        self.locationService = locationService
    }
    
    func loadNavUnits() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Get all nav units
            let units = try await navUnitService.getNavUnitsAsync()
            
            // Calculate distances
            let currentLocation = locationService.currentLocation
            let unitsWithDistance = units.map { unit in
                StationWithDistance<NavUnit>.create(
                    station: unit,
                    userLocation: currentLocation
                )
            }
            
            // Sort by distance
            let sortedUnits = unitsWithDistance.sorted { first, second in
                let noLocationDistance = Double.greatestFiniteMagnitude
                
                if first.distanceFromUser == noLocationDistance && second.distanceFromUser == noLocationDistance {
                    return first.station.navUnitName < second.station.navUnitName
                }
                if first.distanceFromUser == noLocationDistance {
                    return false
                }
                if second.distanceFromUser == noLocationDistance {
                    return true
                }
                return first.distanceFromUser < second.distanceFromUser
            }
            
            await MainActor.run {
                navUnits = sortedUnits
                isLoading = false
            }
            
        } catch {
            print("Error loading nav units: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
