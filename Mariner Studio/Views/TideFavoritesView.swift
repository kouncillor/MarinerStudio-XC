//
//import SwiftUI
//
//struct TideFavoritesView: View {
//    @StateObject private var viewModel = TideFavoritesViewModel()
//    @EnvironmentObject var serviceProvider: ServiceProvider
//    @Environment(\.colorScheme) var colorScheme
//    
//    var body: some View {
//        Group {
//            if viewModel.isLoading {
//                ProgressView("Loading favorites...")
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//            } else if !viewModel.errorMessage.isEmpty {
//                VStack {
//                    Image(systemName: "exclamationmark.triangle")
//                        .font(.largeTitle)
//                        .foregroundColor(.orange)
//                        .padding()
//                    
//                    Text(viewModel.errorMessage)
//                        .multilineTextAlignment(.center)
//                        .padding()
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//            } else if viewModel.favorites.isEmpty {
//                VStack(spacing: 16) {
//                    Image(systemName: "star.slash")
//                        .font(.system(size: 60))
//                        .foregroundColor(.gray)
//                        .padding()
//                    
//                    Text("No Favorite Stations")
//                        .font(.title2)
//                        .fontWeight(.semibold)
//                    
//                    Text("Tide stations you mark as favorites will appear here.")
//                        .multilineTextAlignment(.center)
//                        .foregroundColor(.secondary)
//                    
//                    Spacer().frame(height: 20)
//                    
//                    NavigationLink(destination: TidalHeightStationsView(
//                        tidalHeightService: TidalHeightServiceImpl(),
//                        locationService: serviceProvider.locationService,
//                        tideStationService: serviceProvider.tideStationService
//                    )) {
//                        HStack {
//                            Image(systemName: "water.waves")
//                            Text("Browse All Tide Stations")
//                        }
//                        .padding()
//                        .background(Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                    }
//                }
//                .padding()
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//            } else {
//                VStack(spacing: 0) {
//                    // NEW: Sync Status Bar
//                    SyncStatusBar(viewModel: viewModel)
//                    
//                    List {
//                        ForEach(viewModel.favorites) { station in
//                            NavigationLink {
//                                TidalHeightPredictionView(
//                                    stationId: station.id,
//                                    stationName: station.name,
//                                    tideStationService: serviceProvider.tideStationService
//                                )
//                            } label: {
//                                FavoriteStationRow(station: station)
//                            }
//                        }
//                        .onDelete(perform: viewModel.removeFavorite)
//                    }
//                    .listStyle(InsetGroupedListStyle())
//                    .refreshable {
//                        viewModel.loadFavorites()
//                        // Also trigger sync on pull-to-refresh
//                        await viewModel.syncWithCloud()
//                    }
//                }
//            }
//        }
//        .navigationTitle("Favorite Tides")
//        .withHomeButton()
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: {
//                    Task {
//                        await viewModel.syncWithCloud()
//                    }
//                }) {
//                    Image(systemName: viewModel.syncStatusIcon)
//                        .font(.system(size: 16, weight: .medium))
//                        .foregroundColor(viewModel.syncStatusColor)
//                        .rotationEffect(.degrees(viewModel.isSyncing ? 360 : 0))
//                        .animation(
//                            viewModel.isSyncing ?
//                            Animation.linear(duration: 1).repeatForever(autoreverses: false) :
//                            .default,
//                            value: viewModel.isSyncing
//                        )
//                }
//                .disabled(viewModel.isSyncing)
//            }
//        }
//        .onAppear {
//            viewModel.initialize(
//                tideStationService: serviceProvider.tideStationService,
//                tidalHeightService: TidalHeightServiceImpl(),
//                locationService: serviceProvider.locationService
//            )
//            viewModel.loadFavorites()
//            
//            // Perform auto-sync when view appears
//            Task {
//                await viewModel.performAutoSyncIfNeeded()
//            }
//        }
//        .onDisappear {
//            viewModel.cleanup()
//        }
//    }
//}
//
//// MARK: - NEW: Sync Status Bar Component
//struct SyncStatusBar: View {
//    @ObservedObject var viewModel: TideFavoritesViewModel
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Sync status row
//            HStack(spacing: 12) {
//                Image(systemName: viewModel.syncStatusIcon)
//                    .foregroundColor(viewModel.syncStatusColor)
//                    .font(.caption)
//                    .frame(width: 16)
//                
//                Text(viewModel.syncStatusText)
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                
//                Spacer()
//                
//                if viewModel.isSyncing {
//                    ProgressView()
//                        .scaleEffect(0.8)
//                } else {
//                    Button(action: {
//                        Task {
//                            await viewModel.syncWithCloud()
//                        }
//                    }) {
//                        HStack(spacing: 4) {
//                            Image(systemName: "arrow.clockwise")
//                                .font(.caption)
//                            Text("Sync")
//                                .font(.caption)
//                        }
//                        .foregroundColor(.blue)
//                    }
//                    .disabled(viewModel.isSyncing)
//                }
//            }
//            .padding(.horizontal, 16)
//            .padding(.vertical, 8)
//            .background(Color(.systemGray6))
//            
//            // Success message
//            if let successMessage = viewModel.syncSuccessMessage {
//                HStack {
//                    Image(systemName: "checkmark.circle.fill")
//                        .foregroundColor(.green)
//                        .font(.caption)
//                    
//                    Text(successMessage)
//                        .font(.caption)
//                        .foregroundColor(.green)
//                    
//                    Spacer()
//                    
//                    Button("Dismiss") {
//                        viewModel.syncSuccessMessage = nil
//                    }
//                    .font(.caption)
//                    .foregroundColor(.blue)
//                }
//                .padding(.horizontal, 16)
//                .padding(.vertical, 8)
//                .background(Color.green.opacity(0.1))
//            }
//            
//            // Error message
//            if let errorMessage = viewModel.syncErrorMessage {
//                HStack {
//                    Image(systemName: "exclamationmark.triangle.fill")
//                        .foregroundColor(.orange)
//                        .font(.caption)
//                    
//                    Text(errorMessage)
//                        .font(.caption)
//                        .foregroundColor(.orange)
//                        .multilineTextAlignment(.leading)
//                    
//                    Spacer()
//                    
//                    Button("Dismiss") {
//                        viewModel.syncErrorMessage = nil
//                    }
//                    .font(.caption)
//                    .foregroundColor(.blue)
//                }
//                .padding(.horizontal, 16)
//                .padding(.vertical, 8)
//                .background(Color.orange.opacity(0.1))
//            }
//        }
//    }
//}
//
//struct FavoriteStationRow: View {
//    let station: TidalHeightStation
//    
//    var body: some View {
//        HStack(spacing: 16) {
//            // Station icon
//            Image(systemName: "water.waves")
//                .resizable()
//                .frame(width: 28, height: 28)
//                .foregroundColor(.blue)
//                .padding(8)
//                .background(Color.blue.opacity(0.1))
//                .clipShape(Circle())
//            
//            // Station info
//            VStack(alignment: .leading, spacing: 4) {
//                Text(station.name)
//                    .font(.headline)
//                
//                if let state = station.state, !state.isEmpty {
//                    Text(state)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
//                
//                Text("Station ID: \(station.id)")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                
//                if let latitude = station.latitude, let longitude = station.longitude {
//                    Text("Coordinates: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                }
//            }
//            
//            Spacer()
//        }
//        .padding(.vertical, 8)
//    }
//}
//
//#Preview {
//    NavigationView {
//        TideFavoritesView()
//            .environmentObject(ServiceProvider())
//    }
//}



























import SwiftUI

struct TideFavoritesView: View {
    @StateObject private var viewModel = TideFavoritesViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading favorites...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.errorMessage.isEmpty {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text(viewModel.errorMessage)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.favorites.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                        .padding()
                    
                    Text("No Favorite Stations")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Tide stations you mark as favorites will appear here.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Spacer().frame(height: 20)
                    
                    NavigationLink(destination: TidalHeightStationsView(
                        tidalHeightService: TidalHeightServiceImpl(),
                        locationService: serviceProvider.locationService,
                        tideStationService: serviceProvider.tideStationService
                    )) {
                        HStack {
                            Image(systemName: "water.waves")
                            Text("Browse All Tide Stations")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Sync Status Bar
                    SyncStatusBar(viewModel: viewModel)
                    
                    List {
                        ForEach(viewModel.favorites) { station in
                            NavigationLink {
                                TidalHeightPredictionView(
                                    stationId: station.id,
                                    stationName: station.name,
                                    tideStationService: serviceProvider.tideStationService
                                )
                            } label: {
                                FavoriteStationRow(station: station)
                            }
                        }
                        .onDelete(perform: viewModel.removeFavorite)
                    }
                    .listStyle(InsetGroupedListStyle())
                    .refreshable {
                        viewModel.loadFavorites()
                        // Only reload data - no automatic sync on pull-to-refresh
                    }
                }
            }
        }
        .navigationTitle("Favorite Tides")
        .withHomeButton()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.syncWithCloud()
                    }
                }) {
                    Image(systemName: viewModel.syncStatusIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewModel.syncStatusColor)
                        .rotationEffect(.degrees(viewModel.isSyncing ? 360 : 0))
                        .animation(
                            viewModel.isSyncing ?
                            Animation.linear(duration: 1).repeatForever(autoreverses: false) :
                            .default,
                            value: viewModel.isSyncing
                        )
                }
                .disabled(viewModel.isSyncing)
            }
        }
        .onAppear {
            viewModel.initialize(
                tideStationService: serviceProvider.tideStationService,
                tidalHeightService: TidalHeightServiceImpl(),
                locationService: serviceProvider.locationService
            )
            viewModel.loadFavorites()
            
            // Always sync on app appear (no throttling)
            Task {
                await viewModel.performAppLaunchSync()
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

// MARK: - Sync Status Bar Component
struct SyncStatusBar: View {
    @ObservedObject var viewModel: TideFavoritesViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Sync status row
            HStack(spacing: 12) {
                Image(systemName: viewModel.syncStatusIcon)
                    .foregroundColor(viewModel.syncStatusColor)
                    .font(.caption)
                    .frame(width: 16)
                
                Text(viewModel.syncStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        Task {
                            await viewModel.syncWithCloud()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                            Text("Sync")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(viewModel.isSyncing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Success message
            if let successMessage = viewModel.syncSuccessMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        viewModel.syncSuccessMessage = nil
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
            }
            
            // Error message
            if let errorMessage = viewModel.syncErrorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        viewModel.syncErrorMessage = nil
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }
        }
    }
}

struct FavoriteStationRow: View {
    let station: TidalHeightStation
    
    var body: some View {
        HStack(spacing: 16) {
            // Station icon
            Image(systemName: "water.waves")
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundColor(.blue)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            // Station info
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.headline)
                
                if let state = station.state, !state.isEmpty {
                    Text(state)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Station ID: \(station.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let latitude = station.latitude, let longitude = station.longitude {
                    Text("Coordinates: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        TideFavoritesView()
            .environmentObject(ServiceProvider())
    }
}
