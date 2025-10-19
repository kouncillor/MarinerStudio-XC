import SwiftUI

struct BuoyFavoritesView: View {
    @StateObject private var viewModel: BuoyFavoritesViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Computed Properties
    
    private var isAuthenticationError: Bool {
        return viewModel.errorMessage.contains("User not authenticated") || 
               viewModel.errorMessage.contains("not authenticated")
    }

    init(coreDataManager: CoreDataManager) {
        print("🏗️ VIEW: Initializing BuoyFavoritesView (CORE DATA + CLOUDKIT)")
        print("🏗️ VIEW: Injecting CoreDataManager: \(type(of: coreDataManager))")

        _viewModel = StateObject(wrappedValue: BuoyFavoritesViewModel(
            coreDataManager: coreDataManager
        ))

        print("✅ VIEW: BuoyFavoritesView initialization complete (CORE DATA + CLOUDKIT)")
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading favorites...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !viewModel.errorMessage.isEmpty {
                    errorView
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
                            buoyService: serviceProvider.buoyApiservice,
                            locationService: serviceProvider.locationService,
                            coreDataManager: serviceProvider.coreDataManager
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
                                    coreDataManager: serviceProvider.coreDataManager
                                )
                            } label: {
                                FavoriteBuoyStationRow(station: station)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    if let index = viewModel.favorites.firstIndex(where: { $0.id == station.id }) {
                                        viewModel.removeFavorite(at: IndexSet(integer: index))
                                    }
                                } label: {
                                    Label("Unfavorite", systemImage: "star.fill")
                                }
                                .tint(.yellow)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .refreshable {
                        await viewModel.loadFavorites()
                    }
                }
            }
        }
        .navigationTitle("Favorite Buoys")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.purple, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withNotificationAndHome(sourceView: "Buoy Favorites")

        .onAppear {
            viewModel.initialize(
                buoyFavoritesCloudService: serviceProvider.coreDataManager,
                locationService: serviceProvider.locationService
            )
            Task {
                await viewModel.loadFavorites()
            }
        }
        .onDisappear {
            viewModel.cleanup()
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

            Text("To access your favorite buoy stations, please sign in to your account. Your favorites are synced across all your devices.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
                .font(.body)

            NavigationLink(destination: AppSettingsView()) {
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
        BuoyFavoritesView(
            coreDataManager: CoreDataManager.shared
        )
        .environmentObject(ServiceProvider())
        .environmentObject(CloudKitManager.shared)
    }
}
