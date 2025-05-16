
import SwiftUI

struct BuoyFavoritesView: View {
    @StateObject private var viewModel = BuoyFavoritesViewModel()
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
                    
                    Text("No Favorite Buoys")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Buoy stations you mark as favorites will appear here.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Spacer().frame(height: 20)
                    
                    NavigationLink(destination: BuoyStationsView(
                        buoyService: BuoyServiceImpl(),
                        locationService: serviceProvider.locationService,
                        buoyDatabaseService: serviceProvider.buoyService
                    )) {
                        HStack {
                            Image("buoysixseven")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                            Text("Browse All Buoy Stations")
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
                        NavigationLink {
                            BuoyStationWebView(
                                station: station,
                                buoyDatabaseService: serviceProvider.buoyService
                            )
                        } label: {
                            FavoriteBuoyStationRow(station: station)
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
        .navigationTitle("Favorite Buoys")
        .onAppear {
            viewModel.initialize(
                buoyDatabaseService: serviceProvider.buoyService,
                buoyService: BuoyServiceImpl(),
                locationService: serviceProvider.locationService
            )
            viewModel.loadFavorites()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

struct FavoriteBuoyStationRow: View {
    let station: BuoyStation
    
    var body: some View {
        HStack(spacing: 16) {
            // Buoy icon - using the custom image from MainView
            Image("buoysixseven")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .padding(6)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            // Station info
            VStack(alignment: .leading, spacing: 4) {
                // Process the name to remove any ID prefix if present
                let displayName = station.name.isEmpty
                    ? "Unnamed Station"
                    : (station.name.contains("-")
                        ? station.name.components(separatedBy: "-").dropFirst().joined(separator: "-").trimmingCharacters(in: .whitespaces)
                        : station.name)
                
                Text(displayName)
                    .font(.headline)
                
                Text("Type: \(station.type)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Station ID: \(station.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Handle optional latitude and longitude
                if let latitude = station.latitude,
                   let longitude = station.longitude {
                    Text("Lat: \(String(format: "%.4f", latitude)), Long: \(String(format: "%.4f", longitude))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Show additional properties if available
                if let met = station.meteorological, met == "y" {
                    Text("Meteorological: Yes")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                if let currents = station.currents, currents == "y" {
                    Text("Current Data: Yes")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        BuoyFavoritesView()
            .environmentObject(ServiceProvider())
    }
}
