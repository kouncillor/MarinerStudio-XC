
import SwiftUI

struct TidalHeightStationsView: View {
    // MARK: - Properties
    @StateObject private var viewModel: TidalHeightStationsViewModel
    @State private var isRefreshing = false
    
    // MARK: - Initialization
    init(
        tidalHeightService: TidalHeightService = TidalHeightServiceImpl(),
        locationService: LocationService = LocationServiceImpl(),
        tideStationService: TideStationDatabaseService
    ) {
        _viewModel = StateObject(wrappedValue: TidalHeightStationsViewModel(
            tidalHeightService: tidalHeightService,
            locationService: locationService,
            tideStationService: tideStationService
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
        .navigationTitle("Tidal Height Stations")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.green, for: .navigationBar)
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
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .padding(.trailing, 8)
            
            Button(action: {
                viewModel.toggleFavorites()
            }) {
                Image(systemName: viewModel.showOnlyFavorites ? "star.fill" : "star")
                    .foregroundColor(viewModel.showOnlyFavorites ? .yellow : .gray)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 5)
        .background(Color(.systemGroupedBackground))
    }

    // This shows only the updated NavigationLink section that needs to change
    // in TidalHeightStationsView.swift

    private var stationsList: some View {
        List {
            ForEach(viewModel.stations) { stationWithDistance in
                NavigationLink(destination: TidalHeightPredictionView(
                    stationId: stationWithDistance.station.id,
                    stationName: stationWithDistance.station.name,
                    latitude: stationWithDistance.station.latitude,
                    longitude: stationWithDistance.station.longitude,
                    tideStationService: viewModel.tideStationService
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
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            await viewModel.loadStations()
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
            
            
            // Distance from user (matching favorites view style)
            if !stationWithDistance.distanceDisplay.isEmpty {
                Text(stationWithDistance.distanceDisplay)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }
            
            // Coordinates (matching favorites view format)
            if let latitude = stationWithDistance.station.latitude,
               let longitude = stationWithDistance.station.longitude {
                Text("Coordinates: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 5)
    }
}
