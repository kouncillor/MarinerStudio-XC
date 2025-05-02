import SwiftUI

struct TidalHeightStationsView: View {
    // MARK: - Properties
    @StateObject private var viewModel: TidalHeightStationsViewModel
    @State private var isRefreshing = false
    private let databaseService: DatabaseService
    
    // MARK: - Initialization
    init(
        tidalHeightService: TidalHeightService = TidalHeightServiceImpl(),
        locationService: LocationService = LocationServiceImpl(),
        databaseService: DatabaseService
    ) {
        self.databaseService = databaseService
        _viewModel = StateObject(wrappedValue: TidalHeightStationsViewModel(
            tidalHeightService: tidalHeightService,
            locationService: locationService,
            databaseService: databaseService
        ))
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar and Filters
            searchAndFilterBar
            
            // Status Information
            statusBar
            
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
        .navigationTitle("Tidal Height Stations")
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
                    .onChange(of: viewModel.searchText) { _ in
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
    
    private var statusBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Total Stations: \(viewModel.totalStations)")
                    .font(.footnote)
                Spacer()
                Text("Location: \(viewModel.isLocationEnabled ? "Enabled" : "Disabled")")
                    .font(.footnote)
            }
            
            if viewModel.isLocationEnabled {
                HStack {
                    Text("Your Position: \(viewModel.userLatitude), \(viewModel.userLongitude)")
                        .font(.footnote)
                        .foregroundColor(.blue)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 5)
    }
    
    
    
    
    private var stationsList: some View {
        List {
            ForEach(viewModel.stations) { stationWithDistance in
                NavigationLink(destination: TidalHeightPredictionView(
                    stationId: stationWithDistance.station.id,
                    stationName: stationWithDistance.station.name,
                    databaseService: databaseService
                )) {
                    StationRow(
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

struct StationRow: View {
    let stationWithDistance: StationWithDistance<TidalHeightStation>
    let onToggleFavorite: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(stationWithDistance.station.name)
                    .font(.headline)
                Spacer()
                Button(action: onToggleFavorite) {
                    Image(systemName: stationWithDistance.station.isFavorite ? "star.fill" : "star")
                        .foregroundColor(stationWithDistance.station.isFavorite ? .yellow : .gray)
                }
            }
            
            if let state = stationWithDistance.station.state, !state.isEmpty {
                Text(state)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Text("Station ID: \(stationWithDistance.station.id)")
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack {
                Text("Lat: \(String(format: "%.4f", stationWithDistance.station.latitude)), Long: \(String(format: "%.4f", stationWithDistance.station.longitude))")
                    .font(.caption)
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
