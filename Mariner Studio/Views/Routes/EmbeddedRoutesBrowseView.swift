//
//  EmbeddedRoutesBrowseView.swift
//  Mariner Studio
//
//  Created for browsing and downloading embedded routes from Supabase.
//

import SwiftUI

struct EmbeddedRoutesBrowseView: View {
    @StateObject private var viewModel: EmbeddedRoutesBrowseViewModel

    init(allRoutesService: AllRoutesDatabaseService? = nil, routeCalculationService: RouteCalculationService? = nil) {
        _viewModel = StateObject(wrappedValue: EmbeddedRoutesBrowseViewModel(allRoutesService: allRoutesService, routeCalculationService: routeCalculationService))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

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
            .navigationTitle("Browse Routes")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.orange, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HomeButton()
                }
            }
            .onAppear {
                viewModel.loadRoutes()
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("Available Routes")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                if !viewModel.routes.isEmpty {
                    Text("\(viewModel.filteredRoutes.count) of \(viewModel.routes.count) routes")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal)
            .padding(.top)

            if viewModel.isLoading && !viewModel.routes.isEmpty {
                ProgressView("Refreshing...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .background(Color.orange)
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
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Routes List

    private var routesListView: some View {
        List(viewModel.filteredRoutes) { route in
            RouteRowView(
                route: route,
                isDownloading: viewModel.downloadingRouteId == route.id,
                isDownloaded: viewModel.isRouteDownloaded(route),
                onDownload: {
                    viewModel.downloadRoute(route)
                }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
            Image(systemName: viewModel.routes.isEmpty ? "map.circle" : "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(viewModel.routes.isEmpty ? "No Routes Available" : "No Results Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text(viewModel.routes.isEmpty ?
                 "No embedded routes have been uploaded yet. Use the dev tools to upload some GPX files to get started." :
                 "No routes match your search criteria. Try adjusting your search terms.")
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
                Button("Clear Search") {
                    viewModel.searchText = ""
                }
                .buttonStyle(.borderedProminent)
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

    // MARK: - Refresh Button

    private var refreshButton: some View {
        Button(action: {
            viewModel.refresh()
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
    }
}

// MARK: - Route Row View

struct RouteRowView: View {
    let route: RemoteEmbeddedRoute
    let isDownloading: Bool
    let isDownloaded: Bool
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Route Header
            Text(route.name)
                .font(.headline)
                .fontWeight(.semibold)

            // Route Stats
            routeStatsView

            // Download Button at bottom
            downloadButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private var downloadButton: some View {
        Button(action: onDownload) {
            HStack(spacing: 6) {
                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                } else {
                    Image(systemName: "icloud.and.arrow.down")
                }

                Text(buttonText)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(buttonBackgroundColor)
            .cornerRadius(8)
        }
        .disabled(isDownloading || isDownloaded)
    }

    private var buttonText: String {
        if isDownloading {
            return "Downloading..."
        } else if isDownloaded {
            return "Downloaded"
        } else {
            return "Download"
        }
    }

    private var buttonBackgroundColor: Color {
        if isDownloading {
            return Color.gray
        } else if isDownloaded {
            return Color.green
        } else {
            return Color.blue
        }
    }

    private var routeDetailsView: some View {
        HStack(spacing: 16) {
            Label {
                Text(route.category ?? "General")
                    .font(.caption)
            } icon: {
                Image(systemName: "tag")
                    .foregroundColor(.orange)
            }

            if let difficulty = route.difficulty {
                Label {
                    Text(difficulty)
                        .font(.caption)
                } icon: {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.red)
                }
            }

            if let region = route.region {
                Label {
                    Text(region)
                        .font(.caption)
                } icon: {
                    Image(systemName: "location")
                        .foregroundColor(.green)
                }
            }
        }
    }

    private var routeStatsView: some View {
        HStack(spacing: 20) {
            statItem(
                icon: "point.3.connected.trianglepath.dotted",
                label: "Points",
                value: "\(route.waypointCount)"
            )

            statItem(
                icon: "ruler",
                label: "Distance",
                value: formatDistance(route.totalDistance)
            )

            if let duration = route.estimatedDurationHours {
                statItem(
                    icon: "clock",
                    label: "Duration",
                    value: formatDuration(duration)
                )
            }
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

    private func formatDistance(_ distance: Float) -> String {
        if distance < 1.0 {
            return String(format: "%.0f m", distance * 1000)
        } else {
            return String(format: "%.1f km", distance)
        }
    }

    private func formatDuration(_ hours: Float) -> String {
        if hours < 1.0 {
            return String(format: "%.0f min", hours * 60)
        } else {
            return String(format: "%.1f hrs", hours)
        }
    }
}

// MARK: - Preview

#Preview {
    // Create mock routes for preview
    let mockRoutes = [
        RemoteEmbeddedRoute(
            id: UUID(),
            name: "Boston Harbor Loop",
            description: "Scenic harbor route with lighthouse views and historic landmarks",
            gpxData: "",
            waypointCount: 8,
            totalDistance: 12.5,
            startLatitude: 42.3601,
            startLongitude: -71.0589,
            startName: "Boston Harbor",
            endLatitude: 42.3601,
            endLongitude: -71.0589,
            endName: "Boston Harbor",
            category: "Harbor",
            difficulty: "Easy",
            region: "New England",
            estimatedDurationHours: 2.0,
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true,
            bboxNorth: 42.37,
            bboxSouth: 42.35,
            bboxEast: -71.05,
            bboxWest: -71.07
        ),
        RemoteEmbeddedRoute(
            id: UUID(),
            name: "Cape Cod Commercial Route",
            description: "Main shipping channel for commercial vessels entering Cape Cod Bay",
            gpxData: "",
            waypointCount: 15,
            totalDistance: 45.8,
            startLatitude: 42.0565,
            startLongitude: -70.1763,
            startName: "Provincetown",
            endLatitude: 41.7003,
            endLongitude: -70.2962,
            endName: "Chatham",
            category: "Commercial",
            difficulty: "Moderate",
            region: "Massachusetts",
            estimatedDurationHours: 6.5,
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true,
            bboxNorth: 42.06,
            bboxSouth: 41.70,
            bboxEast: -70.17,
            bboxWest: -70.30
        ),
        RemoteEmbeddedRoute(
            id: UUID(),
            name: "Nantucket Sound Crossing",
            description: "Direct route across Nantucket Sound with navigation aids",
            gpxData: "",
            waypointCount: 12,
            totalDistance: 28.2,
            startLatitude: 41.2033,
            startLongitude: -70.0995,
            startName: "Nantucket",
            endLatitude: 41.6782,
            endLongitude: -70.6692,
            endName: "Woods Hole",
            category: "Open Water",
            difficulty: "Advanced",
            region: "Cape Cod",
            estimatedDurationHours: 4.0,
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true,
            bboxNorth: 41.68,
            bboxSouth: 41.20,
            bboxEast: -70.09,
            bboxWest: -70.67
        )
    ]

    // Create preview with mock route cards
    NavigationStack {
        List(mockRoutes) { route in
            RouteRowView(
                route: route,
                isDownloading: route.id == mockRoutes[1].id, // Show downloading state for second route
                isDownloaded: route.id == mockRoutes[0].id,  // Show downloaded state for first route
                onDownload: { }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Browse Routes")
        .navigationBarTitleDisplayMode(.large)
    }
}
