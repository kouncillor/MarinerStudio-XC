
import SwiftUI

struct RouteFavoritesView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var routeFavorites: [RouteFavorite] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showingGpxView = false
    @State private var selectedGpxFile: GpxFile?
    @State private var selectedRouteName: String = ""
    
    var filteredFavorites: [RouteFavorite] {
        if searchText.isEmpty {
            return routeFavorites
        } else {
            return routeFavorites.filter { favorite in
                favorite.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading favorites...")
                            .padding(.top)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if routeFavorites.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Favorite Routes")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Routes you add to favorites will appear here.\nOpen a GPX file and tap the star to add it.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Search bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                    
                    // Favorites list
                    List {
                        ForEach(filteredFavorites) { favorite in
                            RouteFavoriteRow(
                                favorite: favorite,
                                onTap: {
                                    loadRoute(favorite)
                                }
                            )
                        }
                        .onDelete(perform: deleteFavorites)
                    }
                    .listStyle(PlainListStyle())
                }
                
                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding()
                }
            }
            .navigationTitle("Route Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await loadFavorites()
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await loadFavorites()
                }
            }
            .navigationDestination(isPresented: $showingGpxView) {
                if let gpxFile = selectedGpxFile {
                    GpxView(
                        serviceProvider: serviceProvider,
                        preLoadedRoute: gpxFile,
                        routeName: selectedRouteName
                    )
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func loadFavorites() async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            let favorites = try await serviceProvider.routeFavoritesService.getRouteFavoritesAsync()
            
            await MainActor.run {
                routeFavorites = favorites
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load favorites: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func loadRoute(_ favorite: RouteFavorite) {
        Task {
            do {
                // Update last accessed time
                try await serviceProvider.routeFavoritesService.updateLastAccessedAsync(favoriteId: favorite.id)
                
                // Parse GPX data from database
                let gpxFile = try await serviceProvider.gpxService.loadGpxFile(from: favorite.gpxData)
                
                await MainActor.run {
                    // Set up navigation to GpxView with pre-loaded data
                    selectedGpxFile = gpxFile
                    selectedRouteName = favorite.name
                    showingGpxView = true
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load route: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteFavorites(offsets: IndexSet) {
        Task {
            do {
                for index in offsets {
                    let favorite = filteredFavorites[index]
                    try await serviceProvider.routeFavoritesService.deleteRouteFavoriteAsync(favoriteId: favorite.id)
                }
                
                // Reload favorites
                await loadFavorites()
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete favorite: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search favorites...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .foregroundColor(.blue)
            }
        }
    }
}

struct RouteFavoriteRow: View {
    let favorite: RouteFavorite
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Route name
            Text(favorite.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Route details
            HStack(spacing: 16) {
                Label(favorite.waypointCountText, systemImage: "location")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label(favorite.formattedDistance, systemImage: "ruler")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Date created
            Text("Created: \(favorite.formattedCreatedDate)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
