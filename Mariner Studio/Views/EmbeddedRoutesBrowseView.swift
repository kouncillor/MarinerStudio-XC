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
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                if viewModel.isLoading && viewModel.routes.isEmpty {
                    loadingView
                } else if viewModel.routes.isEmpty && !viewModel.isLoading {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        refreshButton
                        HomeButton()
                    }
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
                    .foregroundColor(.blue)
                
                Text("Available Routes")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !viewModel.routes.isEmpty {
                    Text("\(viewModel.routes.count) routes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            if viewModel.isLoading && !viewModel.routes.isEmpty {
                ProgressView("Refreshing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Routes List
    
    private var routesListView: some View {
        List(viewModel.routes) { route in
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
            Image(systemName: "map.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Routes Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No embedded routes have been uploaded yet. Use the dev tools to upload some GPX files to get started.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Refresh") {
                viewModel.refresh()
            }
            .buttonStyle(.borderedProminent)
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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let description = route.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                downloadButton
            }
            
            // Route Details
            routeDetailsView
            
            // Route Stats
            routeStatsView
        }
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
    EmbeddedRoutesBrowseView()
}