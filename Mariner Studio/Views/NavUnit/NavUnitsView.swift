
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
                    NavigationLink(
                        destination: LazyNavUnitDetailsView(
                            navUnitId: navUnitItem.id,
                            serviceProvider: serviceProvider
                        )
                    ) {
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
        .withHomeButton()
        .onAppear {
            Task {
                await viewModel.loadNavUnits()
            }
        }
    }
}

// MARK: - Lazy Details View

struct LazyNavUnitDetailsView: View {
    let navUnitId: String
    let serviceProvider: ServiceProvider
    
    var body: some View {
        // Create details view that will load the full model by ID
        NavUnitDetailsView(
            navUnitId: navUnitId,
            serviceProvider: serviceProvider
        )
    }
}
