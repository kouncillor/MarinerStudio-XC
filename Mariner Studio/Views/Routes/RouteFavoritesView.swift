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
    @State private var showingRouteDetails = false
    @State private var selectedRouteForDetails: AllRoute?
    @State private var showingDeleteConfirmation = false
    @State private var routeToDelete: AllRoute?
    @State private var showingUnfavoriteConfirmation = false
    @State private var routeToUnfavorite: AllRoute?
    
    var filteredFavorites: [AllRoute] {
        if searchText.isEmpty {
            return favoriteRoutes
        } else {
            return favoriteRoutes.filter { favorite in
                favorite.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Favorite Routes")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !favoriteRoutes.isEmpty {
                    Text("\(filteredFavorites.count) of \(favoriteRoutes.count) routes")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .background(Color.orange)
    }
    
    var body: some View {
        NavigationStack {
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
                        
                        Text("Routes you mark as favorites will appear here.\nDownload or import routes and tap the star to add them.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Search bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Favorites list
                    List(filteredFavorites) { favorite in
                        FavoriteRouteRowView(
                            route: favorite,
                            onVoyagePlan: { loadRoute(favorite) },
                            onDetails: { showRouteDetails(favorite) },
                            onToggleFavorite: {
                                if favorite.isFavorite {
                                    routeToUnfavorite = favorite
                                    showingUnfavoriteConfirmation = true
                                } else {
                                    toggleFavorite(favorite)
                                }
                            },
                            onDelete: {
                                routeToDelete = favorite
                                showingDeleteConfirmation = true
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    }
                    .listStyle(InsetGroupedListStyle())
                    .background(Color(.systemGroupedBackground))
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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Favorite Routes")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.orange, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .withHomeButton()
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
            .navigationDestination(isPresented: $showingRouteDetails) {
                if let route = selectedRouteForDetails {
                    SimpleRouteDetailsView(route: route)
                        .environmentObject(serviceProvider)
                }
            }
            .alert("Delete Route Permanently?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    routeToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let route = routeToDelete {
                        Task {
                            await deleteFavorite(route)
                        }
                    }
                    routeToDelete = nil
                }
            } message: {
                if let route = routeToDelete {
                    Text("This will permanently delete '\(route.name)' and all its waypoint data from your device. This action cannot be undone.")
                }
            }
            .alert("Remove from Favorites?", isPresented: $showingUnfavoriteConfirmation) {
                Button("Cancel", role: .cancel) {
                    routeToUnfavorite = nil
                }
                Button("Remove", role: .destructive) {
                    if let route = routeToUnfavorite {
                        toggleFavorite(route)
                    }
                    routeToUnfavorite = nil
                }
            } message: {
                if let route = routeToUnfavorite {
                    Text("This will remove '\(route.name)' from your favorites list. The route will still be available in All Routes.")
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
    
    private func showRouteDetails(_ route: AllRoute) {
        selectedRouteForDetails = route
        showingRouteDetails = true
    }
    
    private func deleteFavorite(_ route: AllRoute) async {
        do {
            try await serviceProvider.allRoutesService.deleteRouteAsync(routeId: route.id)
            
            await MainActor.run {
                favoriteRoutes.removeAll { $0.id == route.id }
                print("⭐ FAVORITES: Deleted route '\(route.name)'")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete favorite: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Supporting Views

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search favorites...", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Favorite Route Row View

struct FavoriteRouteRowView: View {
    let route: AllRoute
    let onVoyagePlan: () -> Void
    let onDetails: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Route Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
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
                
                Spacer()
                
                // Show favorite indicator (always filled since this is favorites view)
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)
            }
            
            // Route Stats
            routeStatsView
            
            // Action Bar
            actionBarView
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
    
    private var routeStatsView: some View {
        HStack(spacing: 20) {
            statItem(
                icon: "point.3.connected.trianglepath.dotted",
                label: "Waypoints",
                value: "\(route.waypointCount)"
            )
            
            statItem(
                icon: "ruler",
                label: "Distance",
                value: route.formattedDistance
            )
        }
    }
    
    private var actionBarView: some View {
        HStack(spacing: 8) {
            // Voyage Plan Button
            Button(action: onVoyagePlan) {
                HStack(spacing: 4) {
                    Image(systemName: "map")
                        .font(.caption)
                    Text("Voyage Plan")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            // Details Button
            Button(action: onDetails) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text("Details")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Remove from Favorites Button (since this is favorites view, change text to "Remove")
            Button(action: onToggleFavorite) {
                Image(systemName: "star.slash")
                    .font(.caption)
                    .padding(8)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .padding(8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}


// MARK: - Preview

#Preview {
    // Create mock service provider for preview
    let mockServiceProvider = ServiceProvider()
    
    RouteFavoritesView()
        .environmentObject(mockServiceProvider)
}
