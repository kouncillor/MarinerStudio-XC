


import SwiftUI

struct BuoyStationsView: View {
    // MARK: - Properties
    @StateObject private var viewModel: BuoyStationsViewModel
    
    // MARK: - Initialization
    init(
        buoyService: BuoyApiService = BuoyServiceImpl(),
        locationService: LocationService = LocationServiceImpl(),
        buoyDatabaseService: BuoyDatabaseService
    ) {
        _viewModel = StateObject(wrappedValue: BuoyStationsViewModel(
            buoyService: buoyService,
            locationService: locationService,
            buoyDatabaseService: buoyDatabaseService
        ))
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar and Filters
            searchAndFilterBar
            
            // Main Content
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    stationsList
                }
            }
        }
        .navigationTitle("Buoy Stations")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.purple, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withHomeButton()
        
        .task {
            await viewModel.loadStations()
        }
    }
    
    // MARK: - View Components
    private var searchAndFilterBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search stations...", text: $viewModel.searchText)
                    .onChange(of: viewModel.searchText) {
                        viewModel.filterStations()
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
    }
    
    private var stationsList: some View {
        List {
            ForEach(viewModel.stations) { stationWithDistance in
                NavigationLink(destination: BuoyStationWebView(
                    station: stationWithDistance.station,
                    buoyDatabaseService: viewModel.buoyDatabaseService
                )) {
                    BuoyStationRow(
                        stationWithDistance: stationWithDistance,
                        onToggleFavorite: {
                            Task {
                                await viewModel.toggleStationFavorite(stationId: stationWithDistance.station.id)
                            }
                        }
                    )
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await viewModel.refreshStations()
        }
    }
}

struct BuoyStationRow: View {
    let stationWithDistance: StationWithDistance<BuoyStation>
    let onToggleFavorite: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                // Process the name to remove any ID prefix if present
                // This handles cases where the name might be formatted as "ID-Name" or empty
                let displayName = stationWithDistance.station.name.isEmpty
                    ? "Unnamed Station"
                    : (stationWithDistance.station.name.contains("-")
                        ? stationWithDistance.station.name.components(separatedBy: "-").dropFirst().joined(separator: "-").trimmingCharacters(in: .whitespaces)
                        : stationWithDistance.station.name)
                
                Text(displayName)
                    .font(.headline)
                Spacer()
                Button(action: onToggleFavorite) {
                    Image(systemName: stationWithDistance.station.isFavorite ? "star.fill" : "star")
                        .foregroundColor(stationWithDistance.station.isFavorite ? .yellow : .gray)
                }
            }
            
            Text("Type: \(stationWithDistance.station.type)")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Station ID: \(stationWithDistance.station.id)")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Handle optional latitude and longitude
            if let latitude = stationWithDistance.station.latitude,
               let longitude = stationWithDistance.station.longitude {
                Text("Lat: \(String(format: "%.4f", latitude)), Long: \(String(format: "%.4f", longitude))")
                    .font(.caption)
            }
            
            // Show additional properties if available
            if let met = stationWithDistance.station.meteorological, met == "y" {
                Text("Meteorological: Yes")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            if let currents = stationWithDistance.station.currents, currents == "y" {
                Text("Current Data: Yes")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            if !stationWithDistance.distanceDisplay.isEmpty {
                Text("Distance: \(stationWithDistance.distanceDisplay)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 5)
    }
}
