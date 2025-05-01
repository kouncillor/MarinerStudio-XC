import SwiftUI

struct TidalCurrentStationsView: View {
    // MARK: - Properties
    @StateObject private var viewModel: TidalCurrentStationsViewModel
    @State private var isRefreshing = false
    private let databaseService: DatabaseService
    
    // MARK: - Initialization
    init(
        tidalCurrentService: TidalCurrentService = TidalCurrentServiceImpl(),
        locationService: LocationService = LocationServiceImpl(),
        databaseService: DatabaseService
    ) {
        self.databaseService = databaseService
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
                    .foregroundColor(viewModel.
