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
                    
                    // Favorites list
                    List {
                        ForEach(filteredFavorites) { favorite in
                            AllRouteFavoriteRow(
                                route: favorite,
                                onTap: {
                                    // Do nothing when tapping the main card
                                },
                                onToggleFavorite: {
                                    if favorite.isFavorite {
                                        routeToUnfavorite = favorite
                                        showingUnfavoriteConfirmation = true
                                    } else {
                                        toggleFavorite(favorite)
                                    }
                                }
                            )
                            .swipeActions(edge: .leading) {
                                // Voyage Plan button (green) - rightmost on left side
                                Button {
                                    loadRoute(favorite)
                                } label: {
                                    Label("Voyage Plan", systemImage: "map")
                                }
                                .tint(.green)
                                
                                // Details button (blue) - leftmost on left side
                                Button {
                                    showRouteDetails(favorite)
                                } label: {
                                    Label("Details", systemImage: "info.circle")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                // Delete button (red) - rightmost
                                Button(role: .destructive) {
                                    routeToDelete = favorite
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                // Favorite button (yellow) - leftmost on right side
                                Button {
                                    if favorite.isFavorite {
                                        routeToUnfavorite = favorite
                                        showingUnfavoriteConfirmation = true
                                    } else {
                                        toggleFavorite(favorite)
                                    }
                                } label: {
                                    Label(
                                        favorite.isFavorite ? "Unfavorite" : "Favorite",
                                        systemImage: favorite.isFavorite ? "star.fill" : "star"
                                    )
                                }
                                .tint(.yellow)
                            }
                        }
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
    @State private var showLeftChevron = false
    @State private var showRightChevron = false
    
    var body: some View {
        HStack {
            // Left chevron indicator for swipe left (voyage plan)
            SwipeIndicator(direction: .left, isVisible: showLeftChevron)
            
            VStack(alignment: .leading, spacing: 4) {
                // Source type indicator - moved to its own row above the title
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
                
                // Route name gets its own row
                Text(route.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                HStack(spacing: 16) {
                    Label(route.waypointCountText, systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(route.formattedDistance, systemImage: "ruler")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onToggleFavorite) {
                Image(systemName: route.isFavorite ? "star.fill" : "star")
                    .foregroundColor(route.isFavorite ? .yellow : .gray)
                    .font(.title3)
            }
            
            // Right chevron indicator for swipe right (actions)
            SwipeIndicator(direction: .right, isVisible: showRightChevron)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            startPulsingAnimation()
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
    
    private func startPulsingAnimation() {
        // Start pulsing animation after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                showLeftChevron = true
                showRightChevron = true
            }
        }
    }
}

// MARK: - SwipeIndicator Component

struct SwipeIndicator: View {
    enum Direction {
        case left, right
    }
    
    let direction: Direction
    let isVisible: Bool
    
    var body: some View {
        Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
            .font(.title3)
            .foregroundColor(.secondary)
            .opacity(isVisible ? 0.6 : 0.0)
            .animation(.easeInOut(duration: 0.8), value: isVisible)
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

// MARK: - Preview

#Preview {
    // Create mock service provider for preview
    let mockServiceProvider = ServiceProvider()
    
    RouteFavoritesView()
        .environmentObject(mockServiceProvider)
}
