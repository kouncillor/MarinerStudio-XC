
import SwiftUI

struct CurrentFavoritesView: View {
    @StateObject private var viewModel = CurrentFavoritesViewModel()
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
                    
                    Text("Current stations you mark as favorites will appear here.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
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
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    // Use uniqueId for ForEach identifier instead of just id
                    ForEach(viewModel.favorites, id: \.uniqueId) { station in
                        NavigationLink {
                            TidalCurrentPredictionView(
                                stationId: station.id,
                                bin: station.currentBin ?? 0,
                                stationName: station.name,
                                currentStationService: serviceProvider.currentStationService
                            )
                        } label: {
                            FavoriteCurrentStationRow(station: station)
                        }
                    }
                    .onDelete(perform: viewModel.removeFavorite)
                }
                .listStyle(InsetGroupedListStyle())
                .refreshable {
                    viewModel.loadFavorites()
                }
            }
        }
        .navigationTitle("Favorite Current Stations")
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
    }
}

struct FavoriteCurrentStationRow: View {
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
                
                if let state = station.state, !state.isEmpty {
                    Text(state)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Station ID: \(station.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Add depth information with bin value
                if let depth = station.depth, let bin = station.currentBin {
                    Text("Depth: \(String(format: "%.1f", depth)) ft (Bin: \(bin))")
                        .font(.caption)
                        .foregroundColor(.blue) // Make it stand out with a different color
                } else if let bin = station.currentBin {
                    Text("Bin: \(bin)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if let latitude = station.latitude, let longitude = station.longitude {
                    Text("Coordinates: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Navigate icon
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        CurrentFavoritesView()
            .environmentObject(ServiceProvider())
    }
}
