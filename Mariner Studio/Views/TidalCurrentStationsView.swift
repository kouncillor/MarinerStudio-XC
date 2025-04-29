import SwiftUI

struct TidalCurrentStationsView: View {
    // MARK: - Properties
    @StateObject private var viewModel: TidalCurrentStationsViewModel
    
    // MARK: - Initialization
    init(
        tidalCurrentService: TidalCurrentService = TidalCurrentServiceImpl(),
        locationService: LocationService = LocationServiceImpl(),
        databaseService: DatabaseService
    ) {
        _viewModel = StateObject(wrappedValue: TidalCurrentStationsViewModel(
            tidalCurrentService: tidalCurrentService,
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
        .navigationTitle("Tidal Current Stations")
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
                Image(systemName: viewModel.favoritesFilterIcon)
                    .foregroundColor(viewModel.showOnlyFavorites ? .yellow : .gray)
                    .frame(width: 44, height: 44)
            }
        }
        .padding([.horizontal, .top])
    }
    
    private var statusBar: some View {
        HStack {
            Text("Total Stations: \(viewModel.totalStations)")
                .font(.footnote)
            Spacer()
            Text("Location: \(viewModel.isLocationEnabled ? "Enabled" : "Disabled")")
                .font(.footnote)
        }
        .padding(.horizontal)
        .padding(.bottom, 5)
    }
    
    private var stationsList: some View {
        List {
            ForEach(viewModel.stations) { stationWithDistance in
                NavigationLink(destination: TidalCurrentPredictionView(
                    stationId: stationWithDistance.station.id,
                    bin: stationWithDistance.station.currentBin ?? 0,
                    stationName: stationWithDistance.station.name,
                    databaseService: viewModel.databaseService
                )) {
                    CurrentStationRow(stationWithDistance: stationWithDistance)
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await viewModel.refreshStations()
        }
    }
}

struct CurrentStationRow: View {
    let stationWithDistance: StationWithDistance<TidalCurrentStation>
    
    var formattedDepth: String {
        guard let depth = stationWithDistance.station.depth else { return "" }
        let depthText = String(format: "%.1f ft", depth)
        return depthText
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(stationWithDistance.station.name)\(formattedDepth.isEmpty ? "" : " (\(formattedDepth))")")
                    .font(.headline)
                Spacer()
                if stationWithDistance.station.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
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

