import SwiftUI

struct TideFavoritesView: View {
    @StateObject private var viewModel = TideFavoritesViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Computed Properties
    
    private var isAuthenticationError: Bool {
        return viewModel.errorMessage.contains("User not authenticated") || 
               viewModel.errorMessage.contains("not authenticated")
    }

    var body: some View {
        ZStack {
            // Main content
            mainContentView
        }
        .navigationTitle("Favorite Tides")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.green, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withHomeButton()
        // ❌ REMOVED: Sync button - no longer needed with cloud-only approach

        .onAppear {
            print("🌊 VIEW: TideFavoritesView appeared (CLOUD-ONLY)")

            // Initialize location service
            viewModel.initialize(locationService: serviceProvider.locationService)

            // Load favorites from cloud
            Task {
                await viewModel.loadFavorites()
            }
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

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("🎨 VIEW: Loading view appeared")
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            // Check if this is an authentication error
            if isAuthenticationError {
                authenticationRequiredView
            } else {
                generalErrorView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("🎨 VIEW: Error view appeared with message: \(viewModel.errorMessage)")
        }
    }
    
    // MARK: - Authentication Required View
    
    private var authenticationRequiredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding()

            Text("Sign In Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("To access your favorite tide stations, please sign in to your account. Your favorites are synced across all your devices.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
                .font(.body)

            NavigationLink(destination: AppSettingsView().environmentObject(authViewModel)) {
                HStack {
                    Image(systemName: "person.circle")
                    Text("Go to Settings & Sign In")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - General Error View
    
    private var generalErrorView: some View {
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

            Button("Retry") {
                print("🔄 VIEW: Retry button tapped")
                Task {
                    await viewModel.loadFavorites()
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
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
                tideFavoritesCloudService: serviceProvider.tideFavoritesCloudService
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
        .onAppear {
            print("🎨 VIEW: Empty state view appeared")
        }
    }

    // MARK: - Favorites List View

    private var favoritesListView: some View {
        VStack(spacing: 0) {
            // ❌ REMOVED: Sync Status View - no longer needed with cloud-only approach

            List {
                ForEach(viewModel.favorites) { station in
                    NavigationLink {
                        TidalHeightPredictionView(
                            stationId: station.id,
                            stationName: station.name,
                            latitude: station.latitude,
                            longitude: station.longitude,
                            tideFavoritesCloudService: serviceProvider.tideFavoritesCloudService
                        )
                    } label: {
                        FavoriteStationRow(station: station)
                    }
                    .onAppear {
                        print("🎨 VIEW: Station row appeared for \(station.id)")
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            print("💛 VIEW: Unfavorite gesture triggered for station \(station.id)")
                            if let index = viewModel.favorites.firstIndex(where: { $0.id == station.id }) {
                                viewModel.removeFavorite(at: IndexSet(integer: index))
                            }
                        } label: {
                            Label("Unfavorite", systemImage: "star.slash")
                        }
                        .tint(.yellow)
                    }
                }
            }

            .listStyle(InsetGroupedListStyle())
            .refreshable {
                print("🔄 VIEW: Pull-to-refresh triggered (CLOUD-ONLY)")
                await viewModel.loadFavorites()
            }
        }
        .onAppear {
            print("🎨 VIEW: Favorites list view appeared with \(viewModel.favorites.count) stations")
        }
    }
    // ❌ REMOVED: SyncStatusView - no longer needed with cloud-only approach

}

// ❌ REMOVED: All sync-related UI components

struct FavoriteStationRow: View {
    let station: TidalHeightStation

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.up.arrow.down")
                .resizable().frame(width: 28, height: 28).foregroundColor(.green)
                .padding(8).background(Color.green.opacity(0.1)).clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                // Station name
                Text(station.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                // Distance from user
                if let distance = station.distanceFromUser {
                    Text("\(String(format: "%.1f", distance)) mi")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }

                // Coordinates if available
                if let latitude = station.latitude, let longitude = station.longitude {
                    Text("Coordinates: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 16))
        }
        .padding(.vertical, 12)
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
