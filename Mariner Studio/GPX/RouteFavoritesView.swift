import SwiftUI

struct RouteFavoritesView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var favoriteRoutes: [AllRoute] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showingGpxView = false
    @State private var selectedGpxFile: GpxFile?
    @State private var selectedRouteName: String = ""
    
    var filteredFavorites: [AllRoute] {
        if searchText.isEmpty {
            return favoriteRoutes
        } else {
            return favoriteRoutes.filter { favorite in
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
                } else if favoriteRoutes.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Favorite Routes")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Routes you mark as favorites will appear here.\nDownload or import routes and tap the heart to add them.")
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
                            AllRouteFavoriteRow(
                                route: favorite,
                                onTap: {
                                    loadRoute(favorite)
                                },
                                onToggleFavorite: {
                                    toggleFavorite(favorite)
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
            .navigationTitle("Favorite Routes")
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
            let favorites = try await serviceProvider.allRoutesService.getFavoriteRoutesAsync()
            
            await MainActor.run {
                favoriteRoutes = favorites
                isLoading = false
                print("⭐ FAVORITES: Loaded \(favorites.count) favorite routes")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load favorites: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func loadRoute(_ favorite: AllRoute) {
        Task {
            do {
                // Update last accessed time
                try await serviceProvider.allRoutesService.updateLastAccessedAsync(routeId: favorite.id)
                
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
            for index in offsets {
                let favorite = filteredFavorites[index]
                do {
                    try await serviceProvider.allRoutesService.deleteRouteAsync(routeId: favorite.id)
                    
                    await MainActor.run {
                        favoriteRoutes.removeAll { $0.id == favorite.id }
                        print("⭐ FAVORITES: Deleted route '\(favorite.name)'")
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to delete favorite: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func toggleFavorite(_ route: AllRoute) {
        Task {
            do {
                try await serviceProvider.allRoutesService.toggleFavoriteAsync(routeId: route.id)
                // Reload favorites to reflect the change
                await loadFavorites()
                print("⭐ FAVORITES: Toggled favorite for '\(route.name)'")
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update favorite: \(error.localizedDescription)"
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

struct AllRouteFavoriteRow: View {
    let route: AllRoute
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(route.name)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    // Source type indicator
                    HStack(spacing: 4) {
                        Image(systemName: route.sourceTypeIcon)
                            .font(.caption2)
                        Text(route.sourceTypeDisplayName)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(sourceTypeColor.opacity(0.2))
                    .foregroundColor(sourceTypeColor)
                    .cornerRadius(4)
                }
                
                HStack(spacing: 16) {
                    Label(route.waypointCountText, systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(route.formattedDistance, systemImage: "ruler")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let notes = route.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button(action: onToggleFavorite) {
                Image(systemName: route.isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(route.isFavorite ? .red : .gray)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var sourceTypeColor: Color {
        switch route.sourceType {
        case "public":
            return .blue
        case "imported":
            return .purple
        case "created":
            return .orange
        default:
            return .gray
        }
    }
}

// Legacy support for old RouteFavorite if needed elsewhere
struct RouteFavoriteRow: View {
    let favorite: RouteFavorite
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                HStack(spacing: 16) {
                    Label(favorite.waypointCountText, systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(favorite.formattedDistance, systemImage: "ruler")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}