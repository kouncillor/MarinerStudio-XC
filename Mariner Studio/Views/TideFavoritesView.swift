


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
                List {
                    ForEach(viewModel.favorites) { station in
                        // New NavigationLink style that doesn't use isActive or destination
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
                }
            }
        }
        .navigationTitle("Favorite Tides")
        .onAppear {
            viewModel.initialize(
                tideStationService: serviceProvider.tideStationService,
                tidalHeightService: TidalHeightServiceImpl(),
                locationService: serviceProvider.locationService
            )
            viewModel.loadFavorites()
        }
        .onDisappear {
            viewModel.cleanup()
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
