import SwiftUI

struct WeatherFavoritesView: View {
    @StateObject private var viewModel = WeatherFavoritesViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    
    // State for navigation
    @State private var selectedFavorite: WeatherLocationFavorite?
    @State private var showWeatherDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Sync Status View
            syncStatusView
            
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading favorites...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !viewModel.errorMessage.isEmpty {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text(viewModel.errorMessage)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
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
                        await viewModel.performManualSync()
                    }
                }
            }
        }
        .navigationTitle("Favorites")
        .withHomeButton()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        Task {
                            await viewModel.performManualSync()
                        }
                    }) {
                        Image(systemName: viewModel.syncStatusIcon)
                            .foregroundColor(viewModel.syncStatusColor)
                            .rotationEffect(.degrees(viewModel.isSyncing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: viewModel.isSyncing)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
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
            viewModel.initialize(databaseService: serviceProvider.weatherService)
            viewModel.loadFavorites()
            
            // Perform initial sync on app launch
            Task {
                await viewModel.performManualSync()
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    // MARK: - Sync Status View
    @ViewBuilder
    private var syncStatusView: some View {
        if viewModel.isSyncing {
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Syncing weather favorites...")
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .transition(.move(edge: .top).combined(with: .opacity))
            
        } else if let errorMessage = viewModel.syncErrorMessage {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync Error")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Retry") {
                    Task {
                        await viewModel.performManualSync()
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
            .transition(.move(edge: .top).combined(with: .opacity))
            
        } else if let successMessage = viewModel.syncSuccessMessage {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(successMessage)
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1))
            .transition(.move(edge: .top).combined(with: .opacity))
            
        } else if let lastSyncTime = viewModel.lastSyncTime {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
                Text("Last synced: \(formatLastSyncTime(lastSyncTime))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Sync Now") {
                    Task {
                        await viewModel.performManualSync()
                    }
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.05))
        }
    }
    
    private func formatLastSyncTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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