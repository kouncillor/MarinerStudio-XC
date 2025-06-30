//
//  NavUnitsViewModel.swift
//  Mariner Studio
//
//  Minimal ViewModel for simple nav units list
//

import Foundation
import SwiftUI
//
//class NavUnitsViewModel: ObservableObject {
//    @Published var navUnits: [StationWithDistance<NavUnit>] = []
//    @Published var isLoading = false
//    
//    private let navUnitService: NavUnitDatabaseService
//    private let locationService: LocationService
//    
//    init(navUnitService: NavUnitDatabaseService, locationService: LocationService) {
//        self.navUnitService = navUnitService
//        self.locationService = locationService
//    }
//    
////    func loadNavUnits() async {
////        await MainActor.run {
////            isLoading = true
////        }
////        
////        do {
////            // Get all nav units
////            let units = try await navUnitService.getNavUnitsAsync()
////            
////            // Calculate distances
////            let currentLocation = locationService.currentLocation
////            let unitsWithDistance = units.map { unit in
////                StationWithDistance<NavUnit>.create(
////                    station: unit,
////                    userLocation: currentLocation
////                )
////            }
////            
////            // Sort by distance
////            let sortedUnits = unitsWithDistance.sorted { first, second in
////                let noLocationDistance = Double.greatestFiniteMagnitude
////                
////                if first.distanceFromUser == noLocationDistance && second.distanceFromUser == noLocationDistance {
////                    return first.station.navUnitName < second.station.navUnitName
////                }
////                if first.distanceFromUser == noLocationDistance {
////                    return false
////                }
////                if second.distanceFromUser == noLocationDistance {
////                    return true
////                }
////                return first.distanceFromUser < second.distanceFromUser
////            }
////            
////            await MainActor.run {
////                navUnits = sortedUnits
////                isLoading = false
////            }
////            
////        } catch {
////            print("Error loading nav units: \(error)")
////            await MainActor.run {
////                isLoading = false
////            }
////        }
////    }
////
//    
//    
//    
//    
//   
//    func loadNavUnits() async {
//        await MainActor.run {
//            isLoading = true
//        }
//        
//        do {
//            // Get current location
//            let currentLocation = locationService.currentLocation
//            
//            if let location = currentLocation {
//                print("📍 Using user location for database distance calculation: \(location.coordinate.latitude), \(location.coordinate.longitude)")
//                
//                // Use NEW database method that calculates distances in SQLite
//                let navUnitsWithDistance = try await navUnitService.getNavUnitsWithDistanceAsync(
//                    userLatitude: location.coordinate.latitude,
//                    userLongitude: location.coordinate.longitude
//                )
//                
//                await MainActor.run {
//                    navUnits = navUnitsWithDistance
//                    isLoading = false
//                }
//                
//            } else {
//                print("⚠️ No user location available - loading units without distance sorting")
//                
//                // No location available - get units without distance calculation
//                let units = try await navUnitService.getNavUnitsAsync()
//                
//                // Create StationWithDistance objects with max distance (no Swift calculation)
//                let unitsWithoutDistance = units.map { unit in
//                    StationWithDistance<NavUnit>(
//                        station: unit,
//                        distanceFromUser: Double.greatestFiniteMagnitude
//                    )
//                }
//                
//                // Sort alphabetically since we can't sort by distance
//                let sortedUnits = unitsWithoutDistance.sorted { $0.station.navUnitName < $1.station.navUnitName }
//                
//                await MainActor.run {
//                    navUnits = sortedUnits
//                    isLoading = false
//                }
//            }
//            
//        } catch {
//            print("Error loading nav units: \(error)")
//            await MainActor.run {
//                isLoading = false
//            }
//        }
//    }
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//}
class NavUnitsViewModel: ObservableObject {
    @Published var navUnitListItems: [NavUnitListItem] = []  // Changed from navUnits
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
            // Get current location
            let currentLocation = locationService.currentLocation
            
            if let location = currentLocation {
                print("📍 Using user location for minimal database loading: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                
                // Use NEW minimal database method
                let navUnitItems = try await navUnitService.getNavUnitListItemsWithDistanceAsync(
                    userLatitude: location.coordinate.latitude,
                    userLongitude: location.coordinate.longitude
                )
                
                await MainActor.run {
                    navUnitListItems = navUnitItems
                    isLoading = false
                }
                
            } else {
                print("⚠️ No user location available - loading minimal items without distance")
                
                // Fallback: get minimal items without distance calculation
                let navUnitItems = try await navUnitService.getNavUnitListItemsAsync()
                
                await MainActor.run {
                    navUnitListItems = navUnitItems
                    isLoading = false
                }
            }
            
        } catch {
            print("Error loading nav unit list items: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
