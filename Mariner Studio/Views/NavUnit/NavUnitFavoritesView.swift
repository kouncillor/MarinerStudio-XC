
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
    @StateObject private var viewModel = NavUnitFavoritesViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    
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
        .withHomeButton()
        .onAppear {
            print("🎨 NavUnitFavoritesView: View appeared")
            viewModel.initialize(
                navUnitService: serviceProvider.navUnitService,
                locationService: serviceProvider.locationService,
                syncService: serviceProvider.navUnitSyncService
            )
            viewModel.loadFavorites()
        }
        .onDisappear {
            print("🎨 NavUnitFavoritesView: View disappeared")
            viewModel.cleanup()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Sync button in the same position as CurrentFavoritesView
                SyncButton()
            }
        }
    }
    
    // MARK: - Sync Button
    
    @ViewBuilder
    private func SyncButton() -> some View {
        if viewModel.isSyncing {
            // Show progress indicator when syncing
            ProgressView()
                .scaleEffect(0.8)
                .foregroundColor(.blue)
        } else {
            // Show sync button when not syncing
            Button(action: {
                print("🔄 NavUnitFavoritesView: Manual sync button tapped")
                Task {
                    await viewModel.performManualSync()
                }
            }) {
                Image(systemName: syncIconName)
                    .foregroundColor(syncIconColor)
            }
            .disabled(viewModel.isLoading) // Disable while initial load is happening
        }
    }
    
    // MARK: - Sync Icon State
    
    private var syncIconName: String {
        return "arrow.clockwise"
    }
    
    private var syncIconColor: Color {
        return .white
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
        VStack(spacing: 0) {
            // NEW: Sync Status View (like CurrentFavoritesView)
            SyncStatusView()
            
            
            // List of favorites
            List {
                ForEach(viewModel.favorites) { navUnitWithDistance in
                    NavigationLink {
                        // Create NavUnitDetailsView with proper dependency injection
                        let detailsViewModel = NavUnitDetailsViewModel(
                            navUnit: navUnitWithDistance.station,
                            databaseService: serviceProvider.navUnitService,
                            favoritesService: serviceProvider.favoritesService,
                            noaaChartService: serviceProvider.noaaChartService
                        )
                        
                        NavUnitDetailsView(viewModel: detailsViewModel)
                    } label: {
                        FavoriteNavUnitRow(navUnitWithDistance: navUnitWithDistance)
                    }
                    .onAppear {
                        print("🎨 NavUnitFavoritesView: Nav unit row appeared for \(navUnitWithDistance.station.navUnitId)")
                    }
                }
                .onDelete(perform: { offsets in
                    print("🗑️ NavUnitFavoritesView: Delete gesture triggered for offsets \(Array(offsets))")
                    Task {
                        await viewModel.removeFavorite(at: offsets)
                    }
                })
            }
            .listStyle(.insetGrouped)
            .refreshable {
                print("🔄 NavUnitFavoritesView: Pull-to-refresh triggered")
                await viewModel.refreshFavorites()
            }
        }
    }
    
    // MARK: - Sync Status View
    
    @ViewBuilder
    private func SyncStatusView() -> some View {
        if viewModel.isSyncing {
            // Show syncing status
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Syncing nav unit favorites...")
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
        } else if let errorMessage = viewModel.syncErrorMessage {
            // Show sync error
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                Spacer()
                
                Button("Retry") {
                    Task {
                        await viewModel.performManualSync()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
        } else if let successMessage = viewModel.syncSuccessMessage {
            // Show sync success (auto-dismiss after 3 seconds)
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(successMessage)
                    .font(.caption)
                    .foregroundColor(.green)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1))
            .onAppear {
                // Auto-dismiss success message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    viewModel.clearSyncMessages()
                }
            }
        } else if let lastSyncTime = viewModel.lastSyncTime {
            // Show last sync time
            HStack {
                Image(systemName: "checkmark.icloud.fill")
                    .foregroundColor(.green)
                Text("Last sync: \(DateFormatter.syncStatus.string(from: lastSyncTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                
                Button("Sync") {
                    Task {
                        await viewModel.performManualSync()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
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
