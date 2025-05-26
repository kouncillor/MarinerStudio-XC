import SwiftUI

struct RouteFavoritesView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var routeFavorites: [RouteFavorite] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showingRouteDetails = false
    @State private var selectedRouteDetailsViewModel: RouteDetailsViewModel?
    @State private var showingExportSuccess = false
    @State private var exportMessage = ""
    
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
                                },
                                onExport: {
                                    exportRoute(favorite)
                                }
                            )
                        }
                        .onDelete(perform: deleteFavorites)
                    }
                    .listStyle(PlainListStyle())
                }
                
                // Export success message
                if showingExportSuccess {
                    VStack {
                        Spacer()
                        Text(exportMessage)
                            .foregroundColor(.white)
                            .padding()
                            .background(exportMessage.contains("Failed") ? Color.red : Color.green)
                            .cornerRadius(8)
                            .padding()
                            .transition(.move(edge: .bottom))
                        Spacer()
                    }
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
            .navigationDestination(isPresented: $showingRouteDetails) {
                if let routeDetailsViewModel = selectedRouteDetailsViewModel {
                    RouteDetailsView(viewModel: routeDetailsViewModel)
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
                
                // Create RouteDetailsViewModel
                let routeDetailsViewModel = RouteDetailsViewModel(
                    weatherService: serviceProvider.openMeteoService,
                    routeCalculationService: serviceProvider.routeCalculationService
                )
                
                await MainActor.run {
                    // Apply route data with estimated speed
                    routeDetailsViewModel.applyRouteData(gpxFile.route, averageSpeed: "10")
                    
                    // Set up navigation
                    selectedRouteDetailsViewModel = routeDetailsViewModel
                    showingRouteDetails = true
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load route: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func exportRoute(_ favorite: RouteFavorite) {
        Task {
            do {
                // Parse GPX data
                let gpxFile = try await serviceProvider.gpxService.loadGpxFile(from: favorite.gpxData)
                
                // Present document picker for export
                let exportURL = try await presentDocumentPickerForExport(routeName: favorite.name)
                
                // Write GPX file
                try await serviceProvider.gpxService.writeGpxFile(gpxFile, to: exportURL)
                
                await MainActor.run {
                    exportMessage = "Route exported successfully!"
                    showingExportSuccess = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showingExportSuccess = false
                    }
                }
                
            } catch {
                await MainActor.run {
                    exportMessage = "Failed to export route: \(error.localizedDescription)"
                    showingExportSuccess = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showingExportSuccess = false
                    }
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
    
    private func presentDocumentPickerForExport(routeName: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let fileName = routeName.replacingOccurrences(of: " ", with: "_") + ".gpx"
                
                // Create temporary file for export
                let tempDirectory = FileManager.default.temporaryDirectory
                let tempFileURL = tempDirectory.appendingPathComponent(fileName)
                
                let documentPicker = UIDocumentPickerViewController(forExporting: [tempFileURL])
                
                // Create delegate
                let delegate = DocumentPickerExportDelegate { result in
                    switch result {
                    case .success(let url):
                        continuation.resume(returning: url)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                documentPicker.delegate = delegate
                
                // Present picker
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    rootViewController.present(documentPicker, animated: true)
                } else {
                    continuation.resume(throwing: NSError(domain: "RouteFavoritesView", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unable to present document picker"]))
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
    let onExport: () -> Void
    
    var body: some View {
        HStack {
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
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 8) {
                Button(action: onTap) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
