//
//  NavUnitFavoritesView.swift
//  Mariner Studio
//
//  NavUnit Favorites View with comprehensive sync integration
//  Displays user's favorite navigation units with manual sync capability
//  Features sync status indication and error handling
//

import SwiftUI

struct NavUnitFavoritesView: View {
    @StateObject private var viewModel: NavUnitFavoritesViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    
    // Allow dependency injection for testing
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self._viewModel = StateObject(wrappedValue: NavUnitFavoritesViewModel(coreDataManager: coreDataManager))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.favorites.isEmpty {
                LoadingView()
            } else if !viewModel.errorMessage.isEmpty {
                ErrorView(errorMessage: viewModel.errorMessage) {
                    viewModel.loadFavorites()
                }
            } else if viewModel.favorites.isEmpty {
                EmptyFavoritesView()
            } else {
                FavoritesListView()
            }
        }
        .navigationTitle("Favorite Nav Units")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.blue, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withNotificationAndHome(sourceView: "Nav Unit Favorites")
        .onAppear {
            DebugLogger.shared.log("🎨 NAVUNIT_FAVORITES_VIEW: View appeared", category: "NAVUNIT_FAVORITES")
            viewModel.initialize(
                navUnitService: serviceProvider.navUnitService,
                locationService: serviceProvider.locationService
            )
            viewModel.loadFavorites()
        }
        .onDisappear {
            DebugLogger.shared.log("🎨 NAVUNIT_FAVORITES_VIEW: View disappeared", category: "NAVUNIT_FAVORITES")
            viewModel.cleanup()
        }
    }


    // MARK: - Loading View

    @ViewBuilder
    private func LoadingView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text("Loading favorites...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Error View

    @ViewBuilder
    private func ErrorView(errorMessage: String, onRetry: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Error Loading Favorites")
                .font(.title2)
                .fontWeight(.semibold)

            Text(errorMessage)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Empty State View

    @ViewBuilder
    private func EmptyFavoritesView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Favorite Nav Units")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add navigation units to your favorites from the nav units list or map view.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.caption)
                .padding(.horizontal, 40)

            NavigationLink(destination: NavUnitsView(
                navUnitService: serviceProvider.navUnitService,
                locationService: serviceProvider.locationService
            )) {
                HStack {
                    Image(systemName: "location.magnifyingglass")
                    Text("Browse All Nav Units")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Favorites List View

    @ViewBuilder
    private func FavoritesListView() -> some View {
        // List of favorites
        List {
                ForEach(viewModel.favorites) { navUnitWithDistance in
                    NavigationLink {
                        // Create NavUnitDetailsView with proper dependency injection
                        let detailsViewModel = NavUnitDetailsViewModel(
                            navUnit: navUnitWithDistance.station,
                            databaseService: serviceProvider.navUnitService,
                            favoritesService: serviceProvider.favoritesService,
                            noaaChartService: serviceProvider.noaaChartService,
                            coreDataManager: CoreDataManager.shared
                        )

                        NavUnitDetailsView(viewModel: detailsViewModel)
                    } label: {
                        FavoriteNavUnitRow(navUnitWithDistance: navUnitWithDistance)
                    }
                }
                .onDelete(perform: { offsets in
                    DebugLogger.shared.log("🗑️ NAVUNIT_FAVORITES_VIEW: Delete gesture triggered", category: "NAVUNIT_FAVORITES")
                    Task {
                        await viewModel.removeFavorite(at: offsets)
                    }
                })
            }
            .listStyle(.insetGrouped)
            .refreshable {
                DebugLogger.shared.log("🔄 NAVUNIT_FAVORITES_VIEW: Pull-to-refresh triggered", category: "NAVUNIT_FAVORITES")
                await viewModel.refreshFavorites()
            }
    }

}

// MARK: - Favorite Nav Unit Row

struct FavoriteNavUnitRow: View {
    let navUnitWithDistance: StationWithDistance<NavUnit>

    private var navUnit: NavUnit {
        navUnitWithDistance.station
    }

    private var distanceText: String {
        let distance = navUnitWithDistance.distanceFromUser

        if distance == Double.greatestFiniteMagnitude {
            return "Location unknown"
        } else if distance < 1.0 {
            return String(format: "%.1f mi", distance)
        } else {
            return String(format: "%.0f mi", distance)
        }
    }

    private var coordinatesText: String {
        if let latitude = navUnit.latitude, let longitude = navUnit.longitude {
            return "Coordinates: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))"
        } else {
            return "Coordinates: Not available"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Nav unit icon (consistent with NavUnitsView)
            Image("portfoureight")
                .resizable()
                .frame(width: 45, height: 45)

            // Nav unit info
            VStack(alignment: .leading, spacing: 4) {
                // Nav unit name
                Text(navUnit.navUnitName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                // Distance
                Text(distanceText)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)

                // Facility type
                if let facilityType = navUnit.facilityType, !facilityType.isEmpty {
                    Text(facilityType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Coordinates
                Text(coordinatesText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Favorite star icon (moved to right side)
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 16))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let syncStatus: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
