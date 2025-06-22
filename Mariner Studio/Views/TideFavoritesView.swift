import SwiftUI

struct TideFavoritesView: View {
    @StateObject private var viewModel = TideFavoritesViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    
    // Debug UI state
    @State private var showDebugPanel = false
    @State private var debugSelectedTab = 0
    
    var body: some View {
        ZStack {
            // Main content
            mainContentView
            
            // Debug overlay
            if showDebugPanel {
                debugOverlay
            }
        }
        .navigationTitle("Favorite Tides")
        .withHomeButton()
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Debug toggle button
                Button(action: {
                    print("🐛 DEBUG: Toggling debug panel (currently \(showDebugPanel))")
                    showDebugPanel.toggle()
                }) {
                    Image(systemName: "ant.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(showDebugPanel ? .orange : .gray)
                }
                
                // Sync button
                Button(action: {
                    print("☁️ UI: Manual sync button tapped")
                    Task {
                        await viewModel.syncWithCloud()
                    }
                }) {
                    Image(systemName: viewModel.syncStatusIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewModel.syncStatusColor)
                        .rotationEffect(.degrees(viewModel.isSyncing ? 360 : 0))
                        .animation(
                            viewModel.isSyncing ?
                            .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                            value: viewModel.isSyncing
                        )
                }
            }
        }
        
        
        
        
        
        
        
        
        
        
        
        
        .onAppear {
            print("🌊 VIEW: TideFavoritesView appeared")
            print("🌊 VIEW: Current thread = \(Thread.current)")
            print("🌊 VIEW: Is main thread = \(Thread.isMainThread)")
            
            // Initialize services if needed
            if viewModel.tideStationService == nil {
                print("🔧 VIEW: Initializing ViewModel with services")
                print("🔧 VIEW: ServiceProvider available = \(serviceProvider)")
                
                viewModel.initialize(
                    tideStationService: serviceProvider.tideStationService,
                    tidalHeightService: TidalHeightServiceImpl(),
                    locationService: serviceProvider.locationService
                )
            }
            
            print("📱 VIEW: Starting loadFavorites()")
            viewModel.loadFavorites()
            
        }
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        .onDisappear {
            print("🌊 VIEW: TideFavoritesView disappeared")
            viewModel.cleanup()
        }
    }
    
    // MARK: - Main Content View
    
    @ViewBuilder
    private var mainContentView: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if !viewModel.errorMessage.isEmpty {
                errorView
            } else if viewModel.favorites.isEmpty {
                emptyStateView
            } else {
                favoritesListView
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading favorites...")
                .font(.headline)
            
            // Show current loading phase
            Text(viewModel.loadingPhase)
                .font(.caption)
                .foregroundColor(.secondary)
                .animation(.easeInOut, value: viewModel.loadingPhase)
            
            // Performance preview while loading
            if !viewModel.performanceMetrics.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance:")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    
                    ForEach(viewModel.performanceMetrics.suffix(3), id: \.self) { metric in
                        Text(metric)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("🎨 VIEW: Loading view appeared")
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
                .padding()
            
            Text("Error Loading Favorites")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(viewModel.errorMessage)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            // Debug info for errors
            if !viewModel.debugInfo.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug Info:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    ForEach(viewModel.debugInfo.suffix(5), id: \.self) { info in
                        Text(info)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            Button("Retry") {
                print("🔄 VIEW: Retry button tapped")
                viewModel.loadFavorites()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("🎨 VIEW: Error view appeared with message: \(viewModel.errorMessage)")
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
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
            
            // Debug summary for empty state
            if !viewModel.debugInfo.isEmpty || !viewModel.performanceMetrics.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Load Summary:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if let lastMetric = viewModel.performanceMetrics.last {
                        Text(lastMetric)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastDebug = viewModel.debugInfo.last {
                        Text(lastDebug)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("🎨 VIEW: Empty state view appeared")
        }
    }
    
    // MARK: - Favorites List View
    
    private var favoritesListView: some View {
        VStack(spacing: 0) {
            // Sync Status Bar
            SyncStatusBar(viewModel: viewModel)
            
            // Quick stats header
            HStack {
                Text("\(viewModel.favorites.count) favorite stations")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let lastMetric = viewModel.performanceMetrics.last {
                    Text(lastMetric)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
        
            
            // This shows the updated NavigationLink section in TideFavoritesView.swift

            List {
                ForEach(viewModel.favorites) { station in
                    NavigationLink {
                        TidalHeightPredictionView(
                            stationId: station.id,
                            stationName: station.name,
                            latitude: station.latitude,
                            longitude: station.longitude,
                            tideStationService: serviceProvider.tideStationService
                        )
                    } label: {
                        FavoriteStationRow(station: station)
                    }
                    .onAppear {
                        print("🎨 VIEW: Station row appeared for \(station.id)")
                    }
                }
                .onDelete(perform: { offsets in
                    print("🗑️ VIEW: Delete gesture triggered for offsets \(Array(offsets))")
                    viewModel.removeFavorite(at: offsets)
                })
            }
            
            
            
            
            
            
            
            
            
            .listStyle(InsetGroupedListStyle())
            .refreshable {
                print("🔄 VIEW: Pull-to-refresh triggered")
                viewModel.loadFavorites()
            }
        }
        .onAppear {
            print("🎨 VIEW: Favorites list view appeared with \(viewModel.favorites.count) stations")
        }
    }
    
    // MARK: - Debug Overlay
    
    private var debugOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                // Debug header
                HStack {
                    Text("Debug Panel")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button("✕") {
                        showDebugPanel = false
                    }
                    .foregroundColor(.red)
                    .font(.title2)
                }
                .padding()
                .background(Color(.systemGray5))
                
                // Tab selection
                Picker("Debug Tab", selection: $debugSelectedTab) {
                    Text("Performance").tag(0)
                    Text("Debug Log").tag(1)
                    Text("Database").tag(2)
                    Text("State").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                
                // Tab content
                ScrollView {
                    debugTabContent
                        .padding()
                }
                .frame(maxHeight: 300)
                .background(Color(.systemBackground))
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding()
        }
        .background(Color.black.opacity(0.3))
        .onTapGesture {
            showDebugPanel = false
        }
        .onAppear {
            print("🐛 DEBUG: Debug panel opened")
        }
        .onDisappear {
            print("🐛 DEBUG: Debug panel closed")
        }
    }
    
    @ViewBuilder
    private var debugTabContent: some View {
        switch debugSelectedTab {
        case 0:
            performanceTab
        case 1:
            debugLogTab
        case 2:
            databaseTab
        case 3:
            stateTab
        default:
            Text("Unknown tab")
        }
    }
    
    // MARK: - Debug Tab Views
    
    private var performanceTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Metrics")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if viewModel.performanceMetrics.isEmpty {
                Text("No performance data available")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(viewModel.performanceMetrics, id: \.self) { metric in
                    HStack {
                        Text("•")
                            .foregroundColor(.blue)
                        Text(metric)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
            
            Divider()
            
            // Current state metrics
            VStack(alignment: .leading, spacing: 4) {
                Text("Current State:")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("Loading: \(viewModel.isLoading ? "YES" : "NO")")
                    .font(.caption2)
                Text("Phase: \(viewModel.loadingPhase)")
                    .font(.caption2)
                Text("Favorites Count: \(viewModel.favorites.count)")
                    .font(.caption2)
                Text("Error: \(viewModel.errorMessage.isEmpty ? "NONE" : viewModel.errorMessage)")
                    .font(.caption2)
                    .foregroundColor(viewModel.errorMessage.isEmpty ? .green : .red)
            }
        }
    }
    
    private var debugLogTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Log")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if viewModel.debugInfo.isEmpty {
                Text("No debug information available")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(viewModel.debugInfo, id: \.self) { info in
                    HStack(alignment: .top) {
                        Text("•")
                            .foregroundColor(.orange)
                        Text(info)
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var databaseTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Database Statistics")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if viewModel.databaseStats.isEmpty {
                Text("No database statistics available")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(viewModel.databaseStats, id: \.self) { stat in
                    HStack {
                        Text("•")
                            .foregroundColor(.green)
                        Text(stat)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
            
            Divider()
            
            // Manual database operations
            VStack(spacing: 8) {
                Text("Manual Operations:")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Button("Reload Favorites") {
                    print("🐛 DEBUG: Manual reload triggered")
                    viewModel.loadFavorites()
                }
                .font(.caption)
                .padding(8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
                
                Button("Force Sync") {
                    print("🐛 DEBUG: Manual sync triggered")
                    Task {
                        await viewModel.syncWithCloud()
                    }
                }
                .font(.caption)
                .padding(8)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
        }
    }
    
    private var stateTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ViewModel State")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Group {
                Text("Services Initialized:")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("• TideStationService: \(viewModel.tideStationService != nil ? "✅" : "❌")")
                    .font(.caption2)
                Text("• TidalHeightService: \(viewModel.tidalHeightService != nil ? "✅" : "❌")")
                    .font(.caption2)
                Text("• LocationService: \(viewModel.locationService != nil ? "✅" : "❌")")
                    .font(.caption2)
                
                Divider()
                
                Text("Sync State:")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("• Is Syncing: \(viewModel.isSyncing ? "YES" : "NO")")
                    .font(.caption2)
                    .foregroundColor(viewModel.isSyncing ? .blue : .primary)
                
                if let lastSync = viewModel.lastSyncTime {
                    Text("• Last Sync: \(DateFormatter.shortTime.string(from: lastSync))")
                        .font(.caption2)
                } else {
                    Text("• Last Sync: Never")
                        .font(.caption2)
                }
                
                if let syncError = viewModel.syncErrorMessage {
                    Text("• Sync Error: \(syncError)")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                
                if let syncSuccess = viewModel.syncSuccessMessage {
                    Text("• Sync Success: \(syncSuccess)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SyncStatusBar: View {
    @ObservedObject var viewModel: TideFavoritesViewModel
    
    var body: some View {
        HStack {
            if viewModel.isSyncing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Syncing...")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            } else if let errorMessage = viewModel.syncErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } else if let successMessage = viewModel.syncSuccessMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "cloud")
                        .foregroundColor(.gray)
                    Text("Ready to sync")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if let lastSync = viewModel.lastSyncTime {
                Text("Last: \(DateFormatter.shortTime.string(from: lastSync))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }
}

struct FavoriteStationRow: View {
    let station: TidalHeightStation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(station.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Text("ID: \(station.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let state = station.state, state != "Unknown" {
                    Text("• \(state)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Show coordinate info if available
            if let latitude = station.latitude, let longitude = station.longitude {
                Text("Coordinates: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

