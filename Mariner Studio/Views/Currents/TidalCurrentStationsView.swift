
import SwiftUI

struct TidalCurrentStationsView: View {
    @StateObject var viewModel: TidalCurrentStationsViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    
    init(tidalCurrentService: TidalCurrentService, locationService: LocationService, currentStationService: CurrentStationDatabaseService) {
        print("🏗️ VIEW: Initializing TidalCurrentStationsView")
        print("🏗️ VIEW: Injecting services - TidalCurrentService: \(type(of: tidalCurrentService))")
        print("🏗️ VIEW: Injecting services - LocationService: \(type(of: locationService))")
        print("🏗️ VIEW: Injecting services - CurrentStationService: \(type(of: currentStationService))")
        
        _viewModel = StateObject(wrappedValue: TidalCurrentStationsViewModel(
            tidalCurrentService: tidalCurrentService,
            locationService: locationService,
            currentStationService: currentStationService
        ))
        
        print("✅ VIEW: TidalCurrentStationsView initialization complete")
    }
    
    var body: some View {
        print("🖼️ VIEW: Building TidalCurrentStationsView body")
        
        return NavigationStack {
            VStack(spacing: 0) {
                headerControls
                contentView
            }
            .navigationTitle("Current Stations")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.red, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .withHomeButton()
            .onAppear {
                print("\n👁️ VIEW: ===== VIEW APPEARED =====")
                print("👁️ VIEW: TidalCurrentStationsView appeared at \(Date())")
                print("🔄 VIEW: Triggering loadStations() on appear")
                
                Task {
                    await viewModel.loadStations()
                }
                
                print("👁️ VIEW: ===== VIEW APPEAR COMPLETE =====\n")
            }
        }
    }
    
    private var headerControls: some View {
        print("🏗️ VIEW: Building header controls")
        
        return HStack {
            searchBar
            
            Button(action: {
                viewModel.toggleFavorites()
            }) {
                Image(systemName: viewModel.showOnlyFavorites ? "star.fill" : "star")
                    .foregroundColor(viewModel.showOnlyFavorites ? .yellow : .gray)
                    .frame(width: 44, height: 44)
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 8)
            }
        }
        .padding([.horizontal, .top])
    }
    
    private var searchBar: some View {
        print("🔍 VIEW: Building search bar")
        
        return HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search stations...", text: $viewModel.searchText)
                .onChange(of: viewModel.searchText) { newValue in
                    print("🔍 VIEW: Search text changed to: '\(newValue)'")
                    print("🔍 VIEW: Triggering filterStations() from search change")
                    viewModel.filterStations()
                }
            
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    print("🗑️ VIEW: Clear search button tapped")
                    viewModel.clearSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var contentView: some View {
        print("🖼️ VIEW: Building content view")
        
        if viewModel.isLoading {
            print("⏳ VIEW: Showing loading state")
            return AnyView(
                VStack {
                    ProgressView("Loading stations...")
                        .padding()
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        } else if !viewModel.errorMessage.isEmpty {
            print("❌ VIEW: Showing error state: \(viewModel.errorMessage)")
            return AnyView(
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text(viewModel.errorMessage)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Retry") {
                        print("🔄 VIEW: Retry button tapped")
                        Task {
                            await viewModel.refreshStations()
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        } else {
            print("📋 VIEW: Showing stations list with \(viewModel.stations.count) stations")
            return AnyView(stationsList)
        }
    }
    
    private var stationsList: some View {
        print("📋 VIEW: Building stations list")
        print("📋 VIEW: List will show \(viewModel.stations.count) stations")
        print("🚫 VIEW: NO favorite checking will occur in this list")
        
        return List {
            ForEach(viewModel.stations, id: \.station.uniqueId) { stationWithDistance in
                NavigationLink(destination: TidalCurrentPredictionView(
                    stationId: stationWithDistance.station.id,
                    bin: stationWithDistance.station.currentBin ?? 0,
                    stationName: stationWithDistance.station.name,
                    stationLatitude: stationWithDistance.station.latitude,      // ← ADD
                    stationLongitude: stationWithDistance.station.longitude,    // ← ADD
                    stationDepth: stationWithDistance.station.depth,            // ← ADD
                    stationDepthType: stationWithDistance.station.depthType,    // ← ADD
                    currentStationService: viewModel.currentStationService
                )) {
                    TidalCurrentStationRow(
                        stationWithDistance: stationWithDistance,
                        onToggleFavorite: {
                            Task {
                                await viewModel.toggleStationFavorite(stationId: stationWithDistance.station.id)
                            }
                        }
                    )
                        .onAppear {
                            // Only log for first few items to avoid spam
                            if stationWithDistance.station.id.hasSuffix("01") || stationWithDistance.station.id.hasSuffix("02") {
                                print("👁️ VIEW: Displaying station row for \(stationWithDistance.station.id) - \(stationWithDistance.station.name)")
                                print("🚫 VIEW: NO database calls made for this row")
                            }
                        }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            print("🔄 VIEW: Pull-to-refresh triggered")
            await viewModel.refreshStations()
        }
    }
    
    struct TidalCurrentStationRow: View {
        let stationWithDistance: StationWithDistance<TidalCurrentStation>
        let onToggleFavorite: () -> Void
        
        var body: some View {
            // Log only for first few stations to avoid spam
            if stationWithDistance.station.id.hasSuffix("01") {
                print("🏗️ VIEW: Building row for station \(stationWithDistance.station.id)")
            }
            
            return VStack(alignment: .leading, spacing: 5) {
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
                
                
                if !stationWithDistance.distanceDisplay.isEmpty {
                    Text(stationWithDistance.distanceDisplay)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                if let depth = stationWithDistance.station.depth {
                    Text("Depth: \(String(format: "%.1f", depth)) ft")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 5)
        }
    }
}
