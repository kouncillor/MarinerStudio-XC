
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
        VStack(spacing: 0) {
            // Search Bar
            searchBar
            
            // Main Content
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else {
                    navUnitsList
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
    
    // MARK: - View Components
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search navigation units...", text: $viewModel.searchText)
                    .onChange(of: viewModel.searchText) {
                        viewModel.filterNavUnits()
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
        .padding([.horizontal, .top])
    }
    
    private var navUnitsList: some View {
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
        .listStyle(PlainListStyle())
        .refreshable {
            await viewModel.loadNavUnits()
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
