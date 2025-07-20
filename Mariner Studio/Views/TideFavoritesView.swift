import SwiftUI

struct TideFavoritesView: View {
    @StateObject private var viewModel = TideFavoritesViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Main content
            mainContentView
        }
        .navigationTitle("Favorite Tides")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.green, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withHomeButton()
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Sync button
                Button(action: {
                    print("☁️ UI: Manual sync button tapped")
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
                            .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                            value: viewModel.isSyncing
                        )
                }
            }
        }
        
        .onAppear {
            print("🌊 VIEW: TideFavoritesView appeared")
            print("🌊 VIEW: Current thread = \(Thread.current)")
            print("🌊 VIEW: Is main thread = \(Thread.isMainThread)")
            
            // Initialize services if needed
            if viewModel.tideStationService == nil {
                print("🔧 VIEW: Initializing ViewModel with services")
                print("🔧 VIEW: ServiceProvider available = \(serviceProvider)")
                
                viewModel.initialize(
                    tideStationService: serviceProvider.tideStationService,
                    tidalHeightService: TidalHeightServiceImpl(),
                    locationService: serviceProvider.locationService
                )
            }
            
            print("📱 VIEW: Starting loadFavorites()")
            viewModel.loadFavorites()
            
        }
        
        .onDisappear {
            print("🌊 VIEW: TideFavoritesView disappeared")
            viewModel.cleanup()
        }
    }
    
    // MARK: - Main Content View
    
    @ViewBuilder
    private var mainContentView: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if !viewModel.errorMessage.isEmpty {
                errorView
            } else if viewModel.favorites.isEmpty {
                emptyStateView
            } else {
                favoritesListView
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading favorites...")
                .font(.headline)
            
            // Show current loading phase
            Text(viewModel.loadingPhase)
                .font(.caption)
                .foregroundColor(.secondary)
                .animation(.easeInOut, value: viewModel.loadingPhase)
            
            // Performance preview while loading
            if !viewModel.performanceMetrics.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance:")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    
                    ForEach(viewModel.performanceMetrics.suffix(3), id: \.self) { metric in
                        Text(metric)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("🎨 VIEW: Loading view appeared")
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
                .padding()
            
            Text("Error Loading Favorites")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(viewModel.errorMessage)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            // Debug info for errors
            if !viewModel.debugInfo.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug Info:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    ForEach(viewModel.debugInfo.suffix(5), id: \.self) { info in
                        Text(info)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            Button("Retry") {
                print("🔄 VIEW: Retry button tapped")
                viewModel.loadFavorites()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("🎨 VIEW: Error view appeared with message: \(viewModel.errorMessage)")
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
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
            
            // Debug summary for empty state
            if !viewModel.debugInfo.isEmpty || !viewModel.performanceMetrics.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Load Summary:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if let lastMetric = viewModel.performanceMetrics.last {
                        Text(lastMetric)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastDebug = viewModel.debugInfo.last {
                        Text(lastDebug)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("🎨 VIEW: Empty state view appeared")
        }
    }
    
    // MARK: - Favorites List View
    
    private var favoritesListView: some View {
        VStack(spacing: 0) {
            // Sync Status Bar
        //    SyncStatusBar(viewModel: viewModel)
            
            // Quick stats header
            HStack {
                Text("\(viewModel.favorites.count) favorite stations")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let lastMetric = viewModel.performanceMetrics.last {
                    Text(lastMetric)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
        
            
            // This shows the updated NavigationLink section in TideFavoritesView.swift

            List {
                ForEach(viewModel.favorites) { station in
                    NavigationLink {
                        TidalHeightPredictionView(
                            stationId: station.id,
                            stationName: station.name,
                            latitude: station.latitude,
                            longitude: station.longitude,
                            tideStationService: serviceProvider.tideStationService
                        )
                    } label: {
                        FavoriteStationRow(station: station)
                    }
                    .onAppear {
                        print("🎨 VIEW: Station row appeared for \(station.id)")
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            print("💛 VIEW: Unfavorite gesture triggered for station \(station.id)")
                            if let index = viewModel.favorites.firstIndex(where: { $0.id == station.id }) {
                                viewModel.removeFavorite(at: IndexSet(integer: index))
                            }
                        } label: {
                            Label("Unfavorite", systemImage: "star.slash")
                        }
                        .tint(.yellow)
                    }
                }
            }
            
            .listStyle(InsetGroupedListStyle())
            .refreshable {
                print("🔄 VIEW: Pull-to-refresh triggered")
                viewModel.loadFavorites()
            }
        }
        .onAppear {
            print("🎨 VIEW: Favorites list view appeared with \(viewModel.favorites.count) stations")
        }
    }

}

// MARK: - Supporting Views
//
//struct SyncStatusBar: View {
//    @ObservedObject var viewModel: TideFavoritesViewModel
//    
//    var body: some View {
//        HStack {
//            if viewModel.isSyncing {
//                HStack(spacing: 8) {
//                    ProgressView()
//                        .scaleEffect(0.7)
//                    Text("Syncing...")
//                        .font(.caption)
//                }
//                .foregroundColor(.blue)
//            } else if let errorMessage = viewModel.syncErrorMessage {
//                HStack(spacing: 8) {
//                    Image(systemName: "exclamationmark.triangle.fill")
//                        .foregroundColor(.red)
//                    Text(errorMessage)
//                        .font(.caption)
//                        .foregroundColor(.red)
//                }
//            } else if let successMessage = viewModel.syncSuccessMessage {
//                HStack(spacing: 8) {
//                    Image(systemName: "checkmark.circle.fill")
//                        .foregroundColor(.green)
//                    Text(successMessage)
//                        .font(.caption)
//                        .foregroundColor(.green)
//                }
//            } else {
//                HStack(spacing: 8) {
//                    Image(systemName: "cloud")
//                        .foregroundColor(.gray)
//                    Text("Ready to sync")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                }
//            }
//            
//            Spacer()
//            
//            if let lastSync = viewModel.lastSyncTime {
//                Text("Last: \(DateFormatter.shortTime.string(from: lastSync))")
//                    .font(.caption2)
//                    .foregroundColor(.secondary)
//            }
//        }
//        .padding(.horizontal)
//        .padding(.vertical, 6)
//        .background(Color(.systemGray6))
//    }
//}
















struct FavoriteStationRow: View {
    let station: TidalHeightStation
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.up.arrow.down")
                .resizable().frame(width: 28, height: 28).foregroundColor(.green)
                .padding(8).background(Color.green.opacity(0.1)).clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text("ID: \(station.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let state = station.state, state != "Unknown" {
                        Text("• \(state)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Show coordinate info if available
                if let latitude = station.latitude, let longitude = station.longitude {
                    Text("Coordinates: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 16))
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

