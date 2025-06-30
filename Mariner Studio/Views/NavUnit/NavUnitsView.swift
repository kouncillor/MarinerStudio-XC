//
//  NavUnitsView.swift
//  Mariner Studio
//
//  Super simple nav units list - just names sorted by distance
//

import SwiftUI

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
                List(viewModel.navUnits) { navUnitWithDistance in
                    NavigationLink {
                        let detailsViewModel = NavUnitDetailsViewModel(
                            navUnit: navUnitWithDistance.station,
                            databaseService: serviceProvider.navUnitService,
                            photoService: serviceProvider.photoService,
                            navUnitFtpService: serviceProvider.navUnitFtpService,
                            imageCacheService: serviceProvider.imageCacheService,
                            favoritesService: serviceProvider.favoritesService,
                            photoCaptureService: serviceProvider.photoCaptureService,
                            fileStorageService: serviceProvider.fileStorageService,
                            iCloudSyncService: serviceProvider.iCloudSyncService,
                            noaaChartService: serviceProvider.noaaChartService
                        )
                        
                        NavUnitDetailsView(viewModel: detailsViewModel)
                    } label: {
                        Text(navUnitWithDistance.station.navUnitName)
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


