
//
//  CurrentFavoritesView.swift
//  Mariner
//
//  Created by Timothy Russell on 2025-06-27.
//

import SwiftUI

struct CurrentFavoritesView: View {
    @StateObject private var viewModel = CurrentFavoritesViewModel()
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
        .navigationTitle("Favorite Currents")
        .withHomeButton()
        .onAppear {
            viewModel.initialize(
                currentStationService: serviceProvider.currentStationService,
                tidalCurrentService: TidalCurrentServiceImpl(),
                locationService: serviceProvider.locationService
            )
            viewModel.loadFavorites()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // The sync button now correctly reflects the viewModel's syncing state
                if viewModel.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        Task {
                            await viewModel.refreshFavorites()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                    .disabled(viewModel.isLoading) // Disable while initial load is happening
                }
            }
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
    }
    
    // MARK: - Error View
    
    @ViewBuilder
    private func ErrorView(errorMessage: String, onRetry: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Error")
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
        .padding()
    }
    
    // MARK: - Empty Favorites View
    
    @ViewBuilder
    private func EmptyFavoritesView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Favorite Stations")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Pull down to refresh or browse all stations to add favorites.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.caption)
            
            NavigationLink(destination: TidalCurrentStationsView(
                tidalCurrentService: TidalCurrentServiceImpl(),
                locationService: serviceProvider.locationService,
                currentStationService: serviceProvider.currentStationService
            )) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Browse All Current Stations")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }
    
    // MARK: - Favorites List View
    
    @ViewBuilder
    private func FavoritesListView() -> some View {
        VStack(spacing: 0) {
            // NEW: Sync Status View
            SyncStatusView()

            List {
                ForEach(viewModel.favorites, id: \.uniqueId) { station in
                    NavigationLink {
                        TidalCurrentPredictionView(
                            stationId: station.id,
                            bin: station.currentBin ?? 0,
                            stationName: station.name,
                            currentStationService: serviceProvider.currentStationService
                        )
                    } label: {
                        EnhancedFavoriteCurrentStationRow(station: station)
                    }
                }
                .onDelete(perform: viewModel.removeFavorite)
            }
            .listStyle(InsetGroupedListStyle())
            .refreshable {
                await viewModel.refreshFavorites()
            }
        }
    }

    // MARK: - NEW - Sync Status View
    @ViewBuilder
    private func SyncStatusView() -> some View {
        if viewModel.isSyncing || !viewModel.syncMessage.isEmpty {
            VStack {
                HStack {
                    if viewModel.isSyncing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    Text(viewModel.syncMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGroupedBackground))
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Enhanced Station Row

struct EnhancedFavoriteCurrentStationRow: View {
    let station: TidalCurrentStation
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.left.arrow.right")
                .resizable().frame(width: 28, height: 28).foregroundColor(.blue)
                .padding(8).background(Color.blue.opacity(0.1)).clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name).font(.headline).lineLimit(2)
                HStack {
                    if let state = station.state, !state.isEmpty {
                        Text(state).font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    if let distance = station.distanceFromUser {
                        Text("\(String(format: "%.1f", distance)) mi").font(.subheadline).foregroundColor(.blue).fontWeight(.medium)
                    }
                }
                HStack {
                    if let depth = station.depth {
                        Text("Depth: \(String(format: "%.1f", depth)) ft").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if let bin = station.currentBin, bin > 0 {
                        Text("Bin \(bin)").font(.caption).foregroundColor(.blue)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(Color.blue.opacity(0.1)).cornerRadius(4)
                    }
                }
            }
            Spacer()
            Image(systemName: "star.fill").foregroundColor(.yellow).font(.system(size: 16))
        }
        .padding(.vertical, 12)
    }
}
