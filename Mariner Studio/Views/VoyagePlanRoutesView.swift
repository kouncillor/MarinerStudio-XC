//
//  VoyagePlanRoutesView.swift
//  Mariner Studio
//
//  Created for simplified route selection in voyage planning.
//

import SwiftUI

struct VoyagePlanRoutesView: View {
    @StateObject private var viewModel: VoyagePlanRoutesViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var showingGpxView = false
    @State private var selectedGpxFile: GpxFile?
    @State private var selectedRouteName: String = ""

    init(allRoutesService: AllRoutesDatabaseService? = nil) {
        _viewModel = StateObject(wrappedValue: VoyagePlanRoutesViewModel(allRoutesService: allRoutesService))
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
            .navigationTitle("Select Route for Voyage Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.green, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .withNotificationAndHome(sourceView: "Voyage Plan Routes")
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
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
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
            VoyagePlanRouteRowView(
                route: route,
                onTap: { loadRoute(route) }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(PlainListStyle())
        .background(Color(.systemGroupedBackground))
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
            Image(systemName: viewModel.routes.isEmpty ? "map" : "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(viewModel.routes.isEmpty ? "No Routes Available" : "No Results Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text(viewModel.routes.isEmpty ?
                 "Download or import routes to get started with voyage planning." :
                 "No routes match your current search criteria. Try adjusting your search terms.")
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
}

// MARK: - Voyage Plan Route Row View

struct VoyagePlanRouteRowView: View {
    let route: AllRoute
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    // Route Name
                    Text(route.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    // Route Stats
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("\(route.waypointCount) waypoints")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "ruler")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(route.formattedDistance)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Source Type Badge
                    HStack(spacing: 4) {
                        Image(systemName: route.sourceTypeIcon)
                            .font(.caption2)
                        Text(route.sourceTypeDisplayName)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(sourceTypeColor.opacity(0.2))
                    .foregroundColor(sourceTypeColor)
                    .cornerRadius(6)
                }

                Spacer()

                // Tap indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
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

// MARK: - Preview

#Preview {
    NavigationStack {
        VoyagePlanRoutesView()
            .environmentObject(ServiceProvider())
    }
}
