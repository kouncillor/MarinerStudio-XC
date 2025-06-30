////
////  NavUnitsView.swift
////  Mariner Studio
////
////  Super simple nav units list - just names sorted by distance
////
//
//import SwiftUI
//
//struct NavUnitsView: View {
//    @StateObject private var viewModel: NavUnitsViewModel
//    @EnvironmentObject var serviceProvider: ServiceProvider
//    
//    init(navUnitService: NavUnitDatabaseService, locationService: LocationService) {
//        _viewModel = StateObject(wrappedValue: NavUnitsViewModel(
//            navUnitService: navUnitService,
//            locationService: locationService
//        ))
//    }
//    
//    var body: some View {
//        Group {
//            if viewModel.isLoading {
//                ProgressView("Loading...")
//            } else {
//                List(viewModel.navUnits) { navUnitWithDistance in
//                    NavigationLink {
//                        let detailsViewModel = NavUnitDetailsViewModel(
//                            navUnit: navUnitWithDistance.station,
//                            databaseService: serviceProvider.navUnitService,
//                            photoService: serviceProvider.photoService,
//                            navUnitFtpService: serviceProvider.navUnitFtpService,
//                            imageCacheService: serviceProvider.imageCacheService,
//                            favoritesService: serviceProvider.favoritesService,
//                            photoCaptureService: serviceProvider.photoCaptureService,
//                            fileStorageService: serviceProvider.fileStorageService,
//                            iCloudSyncService: serviceProvider.iCloudSyncService,
//                            noaaChartService: serviceProvider.noaaChartService
//                        )
//                        
//                        NavUnitDetailsView(viewModel: detailsViewModel)
//                    } label: {
//                        Text(navUnitWithDistance.station.navUnitName)
//                            .padding(.vertical, 4)
//                    }
//                }
//            }
//        }
//        .navigationTitle("Navigation Units")
//        .onAppear {
//            Task {
//                await viewModel.loadNavUnits()
//            }
//        }
//    }
//}
//
//





//
//  NavUnitsView.swift
//  Mariner Studio
//
//  Super simple nav units list - just names sorted by distance
//
//
//import SwiftUI
//
//struct NavUnitsView: View {
//    @StateObject private var viewModel: NavUnitsViewModel
//    @EnvironmentObject var serviceProvider: ServiceProvider
//    
//    init(navUnitService: NavUnitDatabaseService, locationService: LocationService) {
//        _viewModel = StateObject(wrappedValue: NavUnitsViewModel(
//            navUnitService: navUnitService,
//            locationService: locationService
//        ))
//    }
//    
//    var body: some View {
//        Group {
//            if viewModel.isLoading {
//                ProgressView("Loading...")
//            } else {
//                List(viewModel.navUnits) { navUnitWithDistance in
//                    NavigationLink(
//                        destination: LazyNavUnitDetailsView(
//                            navUnit: navUnitWithDistance.station,
//                            serviceProvider: serviceProvider
//                        )
//                    ) {
//                        Text(navUnitWithDistance.station.navUnitName)
//                            .padding(.vertical, 4)
//                    }
//                }
//            }
//        }
//        .navigationTitle("Navigation Units")
//        .onAppear {
//            Task {
//                await viewModel.loadNavUnits()
//            }
//        }
//    }
//}
//
//// MARK: - Lazy Details View
//
//struct LazyNavUnitDetailsView: View {
//    let navUnit: NavUnit
//    let serviceProvider: ServiceProvider
//    
//    var body: some View {
//        // Only create the heavy view model when this view is actually instantiated
//        let detailsViewModel = NavUnitDetailsViewModel(
//            navUnit: navUnit,
//            databaseService: serviceProvider.navUnitService,
//            photoService: serviceProvider.photoService,
//            navUnitFtpService: serviceProvider.navUnitFtpService,
//            imageCacheService: serviceProvider.imageCacheService,
//            favoritesService: serviceProvider.favoritesService,
//            photoCaptureService: serviceProvider.photoCaptureService,
//            fileStorageService: serviceProvider.fileStorageService,
//            iCloudSyncService: serviceProvider.iCloudSyncService,
//            noaaChartService: serviceProvider.noaaChartService
//        )
//        
//        NavUnitDetailsView(viewModel: detailsViewModel)
//    }
//}










//
//  NavUnitsView.swift
//  Mariner Studio
//
//  Super simple nav units list - just names sorted by distance
//

import SwiftUI

// MARK: - Minimal Nav Unit Model for List Display

struct NavUnitListItem: Identifiable {
    let id: String // navUnitId
    let name: String // navUnitName
    let distanceFromUser: Double
    
    var distanceDisplay: String {
        if distanceFromUser == Double.greatestFiniteMagnitude {
            return ""
        }
        
        let miles = distanceFromUser * 0.000621371 // Convert meters to miles
        return String(format: "%.1f mi", miles)
    }
}

struct NavUnitsView: View {
    @StateObject private var viewModel: NavUnitsViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    
    init(navUnitService: NavUnitDatabaseService, locationService: LocationService) {
        _viewModel = StateObject(wrappedValue: NavUnitsViewModel(
            navUnitService: navUnitService,
            locationService: locationService
        ))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else {
                List(viewModel.navUnitListItems) { navUnitItem in
                    // Stubbed navigation link - no destination for now
                    Button(action: {
                        print("Tapped nav unit: \(navUnitItem.name) (ID: \(navUnitItem.id))")
                        // TODO: Navigate to details view with navUnitItem.id
                    }) {
                        HStack {
                            Text(navUnitItem.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if !navUnitItem.distanceDisplay.isEmpty {
                                Text(navUnitItem.distanceDisplay)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Navigation Units")
        .onAppear {
            Task {
                await viewModel.loadNavUnits()
            }
        }
    }
}
