//
//  AllRoutesView.swift
//  Mariner Studio
//
//  Created for displaying all routes from various sources (public, imported, created).
//

import SwiftUI

struct AllRoutesView: View {
    @StateObject private var viewModel: AllRoutesViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var showingGpxView = false
    @State private var selectedGpxFile: GpxFile?
    @State private var selectedRouteName: String = ""
    @State private var showingRouteDetails = false
    @State private var selectedRouteForDetails: AllRoute?
    
    init(allRoutesService: AllRoutesDatabaseService? = nil) {
        _viewModel = StateObject(wrappedValue: AllRoutesViewModel(allRoutesService: allRoutesService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with filters
                headerView
                
                // Search Bar
                searchBarView
                
                // Content
                if viewModel.isLoading && viewModel.routes.isEmpty {
                    loadingView
                } else if viewModel.filteredRoutes.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    routesListView
                }
                
                // Error message
                if !viewModel.errorMessage.isEmpty {
                    errorView
                }
            }
            .navigationTitle("All Routes")
            .navigationBarTitleDisplayMode(.large)
            .withHomeButton()
            .onAppear {
                viewModel.loadRoutes()
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
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Filter buttons
            filterButtonsView
            
            if viewModel.isLoading && !viewModel.routes.isEmpty {
                ProgressView("Refreshing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var filterButtonsView: some View {
        HStack(spacing: 8) {
            ForEach(["all", "public", "imported", "created"], id: \.self) { filter in
                Button(action: {
                    viewModel.selectedFilter = filter
                    viewModel.applyFilter()
                }) {
                    Text(filterDisplayName(filter))
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewModel.selectedFilter == filter ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(viewModel.selectedFilter == filter ? .white : .primary)
                        .cornerRadius(8)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private func filterDisplayName(_ filter: String) -> String {
        switch filter {
        case "all": return "All"
        case "public": return "Public"
        case "imported": return "Imported"
        case "created": return "Created"
        default: return filter.capitalized
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBarView: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search routes...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Routes List
    
    private var routesListView: some View {
        List(viewModel.filteredRoutes) { route in
            AllRouteRowView(
                route: route,
                isOperationInProgress: viewModel.operationsInProgress.contains(route.id)
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .swipeActions(edge: .leading) {
                // Voyage Plan button (green) - rightmost on left side
                Button {
                    loadRoute(route)
                } label: {
                    Label("Voyage Plan", systemImage: "map")
                }
                .tint(.green)
                .disabled(viewModel.operationsInProgress.contains(route.id))
                
                // Details button (blue) - leftmost on left side
                Button {
                    showRouteDetails(route)
                } label: {
                    Label("Details", systemImage: "info.circle")
                }
                .tint(.blue)
                .disabled(viewModel.operationsInProgress.contains(route.id))
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                // Delete button
                Button(role: .destructive) {
                    viewModel.deleteRoute(route)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(viewModel.operationsInProgress.contains(route.id))
                
                // Favorite button
                Button {
                    viewModel.toggleFavorite(route)
                } label: {
                    Label(
                        route.isFavorite ? "Unfavorite" : "Favorite",
                        systemImage: route.isFavorite ? "star.fill" : "star"
                    )
                }
                .tint(.yellow)
                .disabled(viewModel.operationsInProgress.contains(route.id))
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            viewModel.refresh()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading routes...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: viewModel.routes.isEmpty ? "list.bullet.circle" : "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(viewModel.routes.isEmpty ? "No Routes Available" : "No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(viewModel.routes.isEmpty ? 
                 "Download public routes, import your own files, or create new routes to get started." :
                 "No routes match your current filter and search criteria. Try adjusting your search terms or changing the filter.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if viewModel.routes.isEmpty {
                Button("Refresh") {
                    viewModel.refresh()
                }
                .buttonStyle(.borderedProminent)
            } else {
                HStack(spacing: 12) {
                    if !viewModel.searchText.isEmpty {
                        Button("Clear Search") {
                            viewModel.searchText = ""
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if viewModel.selectedFilter != "all" {
                        Button("Show All") {
                            viewModel.selectedFilter = "all"
                            viewModel.applyFilter()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                
                Text(viewModel.errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                
                Spacer()
                
                Button("Dismiss") {
                    viewModel.errorMessage = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadRoute(_ route: AllRoute) {
        Task {
            do {
                // Parse GPX data from database
                let gpxFile = try await serviceProvider.gpxService.loadGpxFile(from: route.gpxData)
                
                await MainActor.run {
                    // Set up navigation to GpxView with pre-loaded data
                    selectedGpxFile = gpxFile
                    selectedRouteName = route.name
                    showingGpxView = true
                }
                
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = "Failed to load route: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func showRouteDetails(_ route: AllRoute) {
        selectedRouteForDetails = route
        showingRouteDetails = true
    }
    
}

// MARK: - All Route Row View

struct AllRouteRowView: View {
    let route: AllRoute
    let isOperationInProgress: Bool
    
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
                
                // Show favorite indicator if favorited
                if route.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                }
            }
            
            
            // Route Stats
            routeStatsView
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
    // Create mock data for preview
    let mockRoutes = [
        AllRoute(
            id: 1,
            name: "Boston to NYC",
            gpxData: "",
            waypointCount: 12,
            totalDistance: 185.5,
            sourceType: "public",
            isFavorite: true,
            tags: "Harbor, Commercial",
            notes: "Popular commercial route"
        ),
        AllRoute(
            id: 2,
            name: "Cape Cod Loop",
            gpxData: "",
            waypointCount: 8,
            totalDistance: 45.2,
            sourceType: "imported",
            isFavorite: false,
            tags: "Scenic",
            notes: "Beautiful coastal route"
        ),
        AllRoute(
            id: 3,
            name: "Custom Harbor Route",
            gpxData: "",
            waypointCount: 5,
            totalDistance: 12.8,
            sourceType: "created",
            isFavorite: true,
            notes: "Local harbor navigation"
        )
    ]
    
    // Create preview with mock data
    VStack(spacing: 16) {
        ForEach(mockRoutes) { route in
            AllRouteRowView(
                route: route,
                isOperationInProgress: false
            )
            .padding(.horizontal)
        }
    }
    .background(Color(.systemGroupedBackground))
}