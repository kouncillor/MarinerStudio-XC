//
//import SwiftUI
//
//struct CurrentFavoritesView: View {
//    @StateObject private var viewModel = CurrentFavoritesViewModel()
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
//                    Text("Current stations you mark as favorites will appear here.")
//                        .multilineTextAlignment(.center)
//                        .foregroundColor(.secondary)
//                    
//                    Spacer().frame(height: 20)
//                    
//                    NavigationLink(destination: TidalCurrentStationsView(
//                        tidalCurrentService: TidalCurrentServiceImpl(),
//                        locationService: serviceProvider.locationService,
//                        currentStationService: serviceProvider.currentStationService
//                    )) {
//                        HStack {
//                            Image(systemName: "arrow.left.arrow.right")
//                            Text("Browse All Current Stations")
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
//                List {
//                    // Use uniqueId for ForEach identifier instead of just id
//                    ForEach(viewModel.favorites, id: \.uniqueId) { station in
//                        NavigationLink {
//                            TidalCurrentPredictionView(
//                                stationId: station.id,
//                                bin: station.currentBin ?? 0,
//                                stationName: station.name,
//                                currentStationService: serviceProvider.currentStationService
//                            )
//                        } label: {
//                            FavoriteCurrentStationRow(station: station)
//                        }
//                    }
//                    .onDelete(perform: viewModel.removeFavorite)
//                }
//                .listStyle(InsetGroupedListStyle())
//                .refreshable {
//                    viewModel.loadFavorites()
//                }
//            }
//        }
//        .navigationTitle("Favorite Currents")
//        .withHomeButton()
//        
//        .onAppear {
//            viewModel.initialize(
//                currentStationService: serviceProvider.currentStationService,
//                tidalCurrentService: TidalCurrentServiceImpl(),
//                locationService: serviceProvider.locationService
//            )
//            viewModel.loadFavorites()
//        }
//        .onDisappear {
//            viewModel.cleanup()
//        }
//    }
//}
//
//struct FavoriteCurrentStationRow: View {
//    let station: TidalCurrentStation
//    
//    var body: some View {
//        HStack(spacing: 16) {
//            // Station icon
//            Image(systemName: "arrow.left.arrow.right")
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
//                // Modified to only show depth without bin number
//                if let depth = station.depth {
//                    Text("Depth: \(String(format: "%.1f", depth)) ft")
//                        .font(.caption)
//                        .foregroundColor(.blue)
//                }
//            }
//            
//            Spacer()
//            
//    
//        }
//        .padding(.vertical, 12)
//    }
//}
//
//
//
//
//



import SwiftUI

struct CurrentFavoritesView: View {
    @StateObject private var viewModel = CurrentFavoritesViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if viewModel.isLoading {
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
            print("🎬 CURRENT_FAVORITES_VIEW: View appeared")
            viewModel.initialize(
                currentStationService: serviceProvider.currentStationService,
                tidalCurrentService: TidalCurrentServiceImpl(),
                locationService: serviceProvider.locationService
            )
            viewModel.loadFavorites()
        }
        .onDisappear {
            print("👋 CURRENT_FAVORITES_VIEW: View disappeared")
            viewModel.cleanup()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        print("🔄 CURRENT_FAVORITES_VIEW: Manual refresh button tapped")
                        Task {
                            await viewModel.refreshFavorites()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
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
            
            if !viewModel.debugInfo.isEmpty {
                Text(viewModel.debugInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    @ViewBuilder
    private func ErrorView(errorMessage: String, onRetry: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .padding()
            
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
            
            if !viewModel.debugInfo.isEmpty {
                Text("Debug: \(viewModel.debugInfo)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty Favorites View
    
    @ViewBuilder
    private func EmptyFavoritesView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding()
            
            Text("No Favorite Stations")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Current stations you mark as favorites will appear here.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Text("Pull down to refresh or browse all stations to add favorites.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.caption)
            
            Spacer().frame(height: 20)
            
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
            
            // Debug info for empty state
            if !viewModel.debugInfo.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug Information:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.debugInfo)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    if let lastLoadTime = viewModel.lastLoadTime {
                        Text("Last loaded: \(lastLoadTime, style: .time)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    if viewModel.loadDuration > 0 {
                        Text("Load time: \(String(format: "%.3f", viewModel.loadDuration))s")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Favorites List View
    
    @ViewBuilder
    private func FavoritesListView() -> some View {
        VStack(spacing: 0) {
            // Status bar with load information
            StatusBar()
            
            // Favorites list
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
                print("🔄 CURRENT_FAVORITES_VIEW: Pull-to-refresh triggered")
                await viewModel.refreshFavorites()
            }
        }
    }
    
    // MARK: - Status Bar
    
    @ViewBuilder
    private func StatusBar() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.favorites.count) Favorites")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if let lastLoadTime = viewModel.lastLoadTime {
                    Text("Updated: \(lastLoadTime, style: .time)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Not loaded")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if viewModel.loadDuration > 0 {
                    Text("Load: \(String(format: "%.3f", viewModel.loadDuration))s")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if !viewModel.debugInfo.isEmpty {
                    Text(viewModel.debugInfo)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Enhanced Station Row

struct EnhancedFavoriteCurrentStationRow: View {
    let station: TidalCurrentStation
    
    var body: some View {
        HStack(spacing: 16) {
            // Station icon
            Image(systemName: "arrow.left.arrow.right")
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
                    .lineLimit(2)
                
                // State and distance row
                HStack {
                    if let state = station.state, !state.isEmpty {
                        Text(state)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let distance = station.distanceFromUser {
                        Text("\(String(format: "%.1f", distance)) mi")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
                
                // Additional details row
                HStack {
                    // Depth information
                    if let depth = station.depth {
                        Text("Depth: \(String(format: "%.1f", depth)) ft")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Current bin information
                    if let bin = station.currentBin, bin > 0 {
                        Text("Bin \(bin)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // Favorite indicator
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 16))
        }
        .padding(.vertical, 12)
        .contextMenu {
            Button(action: {
                print("🗑️ CURRENT_FAVORITES_VIEW: Context menu remove tapped for \(station.name)")
                // This could trigger a direct removal action
            }) {
                Label("Remove from Favorites", systemImage: "star.slash")
            }
            
            Button(action: {
                print("ℹ️ CURRENT_FAVORITES_VIEW: Context menu info tapped for \(station.name)")
                // This could show more details about the station
            }) {
                Label("Station Details", systemImage: "info.circle")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        CurrentFavoritesView()
            .environmentObject(ServiceProvider())
    }
}
