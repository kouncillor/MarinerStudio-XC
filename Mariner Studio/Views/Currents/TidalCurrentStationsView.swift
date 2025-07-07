
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
            
            // REMOVED: Favorites filter button entirely - no more star button
            // This eliminates any UI that would trigger favorite database calls
            
            Spacer()
            
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
                    TidalCurrentStationRow(stationWithDistance: stationWithDistance)
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
        .listStyle(PlainListStyle())
        .refreshable {
            print("🔄 VIEW: Pull-to-refresh triggered")
            await viewModel.refreshStations()
        }
    }
    
    struct TidalCurrentStationRow: View {
        let stationWithDistance: StationWithDistance<TidalCurrentStation>
        // REMOVED: onToggleFavorite parameter entirely
        
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
                    
                    // REMOVED: Star button entirely - no more favorite toggle
                    // This completely eliminates any database interaction from the list
                }
                
                if let state = stationWithDistance.station.state, !state.isEmpty {
                    Text(state)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("ID: \(stationWithDistance.station.id)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let bin = stationWithDistance.station.currentBin {
                        Text("• Bin: \(bin)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                HStack {
                    if let depth = stationWithDistance.station.depth {
                        Text("Depth: \(String(format: "%.1f", depth)) ft")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if !stationWithDistance.distanceDisplay.isEmpty {
                        Text("• \(stationWithDistance.distanceDisplay)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.vertical, 5)
        }
    }
}
