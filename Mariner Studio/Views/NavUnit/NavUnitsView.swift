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
    let latitude: Double?
    let longitude: Double?
    let isFavorite: Bool

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
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.blue, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withNotificationAndHome(sourceView: "Nav Units List")
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
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .padding(.trailing, 8)

            Button(action: {
                viewModel.toggleFavorites()
            }) {
                Image(systemName: viewModel.showOnlyFavorites ? "star.fill" : "star")
                    .foregroundColor(viewModel.showOnlyFavorites ? .yellow : .gray)
                    .frame(width: 44, height: 44)
            }
        }
        .padding([.horizontal, .top])
        .background(Color(.secondarySystemBackground))
    }

    private var navUnitsList: some View {
        List(viewModel.navUnitListItems) { navUnitItem in
            NavigationLink(
                destination: LazyNavUnitDetailsView(
                    navUnitId: navUnitItem.id,
                    serviceProvider: serviceProvider
                )
            ) {
                HStack(spacing: 12) {
                    // Nav unit icon
                    Image("portfoureight")
                  // Image("rigfoureight")
                   //   Image("refinerysixseven")
                        .resizable()
                        .frame(width: 45, height: 45)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(navUnitItem.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if !navUnitItem.distanceDisplay.isEmpty {
                            Text(navUnitItem.distanceDisplay)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }

                        // Coordinates - always show if available
                        if let latitude = navUnitItem.latitude,
                           let longitude = navUnitItem.longitude {
                            Text("Coordinates: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    // Star icon to show favorite status
                    if navUnitItem.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 16))
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .listStyle(InsetGroupedListStyle())
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
