import SwiftUI

struct WeatherFavoritesView: View {
    @StateObject private var viewModel: WeatherFavoritesViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Computed Properties
    
    private var isAuthenticationError: Bool {
        return viewModel.errorMessage.contains("User not authenticated") || 
               viewModel.errorMessage.contains("not authenticated")
    }

    init(weatherFavoritesCloudService: WeatherFavoritesCloudService) {
        print("🏗️ VIEW: Initializing WeatherFavoritesView (CLOUD-ONLY)")
        print("🏗️ VIEW: Injecting WeatherFavoritesCloudService: \(type(of: weatherFavoritesCloudService))")

        _viewModel = StateObject(wrappedValue: WeatherFavoritesViewModel(
            weatherFavoritesCloudService: weatherFavoritesCloudService
        ))

        print("✅ VIEW: WeatherFavoritesView initialization complete (CLOUD-ONLY)")
    }

    // State for navigation
    @State private var selectedFavorite: WeatherLocationFavorite?
    @State private var showWeatherDetail = false

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
                        Image(systemName: "heart.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                            .padding()

                        Text("No Favorite Locations")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Locations you mark as favorites will appear here.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        Spacer().frame(height: 20)

                        NavigationLink(destination: WeatherMapView()) {
                            HStack {
                                Image(systemName: "map")
                                Text("Open Weather Map")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }

                        NavigationLink(destination: CurrentLocalWeatherView()) {
                            HStack {
                                Image(systemName: "location")
                                Text("Check Local Weather")
                            }
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.favorites) { favorite in
                            FavoriteLocationRow(favorite: favorite)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedFavorite = favorite
                                    showWeatherDetail = true
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        if let index = viewModel.favorites.firstIndex(where: { $0.id == favorite.id }) {
                                            viewModel.removeFavorite(at: IndexSet(integer: index))
                                        }
                                    } label: {
                                        Label("Unfavorite", systemImage: "star.fill")
                                    }
                                    .tint(.yellow)
                                    .disabled(viewModel.operationInProgress.contains("\(favorite.latitude),\(favorite.longitude)"))
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        viewModel.prepareForEditing(favorite: favorite)
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    .tint(.blue)
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
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0.53, green: 0.81, blue: 0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withHomeButton()
        .sheet(isPresented: $viewModel.isEditingName) {
            // Reset values when sheet is dismissed
            viewModel.favoriteToEdit = nil
            viewModel.newLocationName = ""
        } content: {
            if let favorite = viewModel.favoriteToEdit {
                RenameLocationView(
                    locationName: $viewModel.newLocationName,
                    isPresented: $viewModel.isEditingName,
                    onSave: {
                        Task {
                            await viewModel.updateLocationName(
                                favorite: favorite,
                                newName: viewModel.newLocationName
                            )
                        }
                    }
                )
            }
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let favorite = selectedFavorite {
                        CurrentLocalWeatherViewForFavorites(
                            latitude: favorite.latitude,
                            longitude: favorite.longitude
                        )
                    }
                },
                isActive: $showWeatherDetail,
                label: { EmptyView() }
            )
        )
        .onAppear {
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

            Text("To access your favorite weather locations, please sign in to your account. Your favorites are synced across all your devices.")
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

// MARK: - RenameLocationView
struct RenameLocationView: View {
    @Binding var locationName: String
    @Binding var isPresented: Bool
    var onSave: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Name")) {
                    TextField("Enter location name", text: $locationName)
                        .autocapitalization(.words)
                }
            }
            .navigationTitle("Rename Location")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    onSave()
                    isPresented = false
                }
                .disabled(locationName.isEmpty)
            )
        }
    }
}

// MARK: - FavoriteLocationRow
struct FavoriteLocationRow: View {
    let favorite: WeatherLocationFavorite

    var body: some View {
        HStack(spacing: 16) {
            // Location icon
            Image("weathersixseventwo")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundColor(.red)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())

            // Location info
            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.locationName)
                    .font(.headline)

                Text("Lat: \(String(format: "%.4f", favorite.latitude)), Lon: \(String(format: "%.4f", favorite.longitude))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Added: \(formatDate(favorite.createdAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Navigate icon
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
