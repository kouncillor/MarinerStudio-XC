//
//  VoyagePlanFavoritesView.swift
//  Mariner Studio
//
//  Created for voyage planning with favorite routes.
//

import SwiftUI

struct VoyagePlanFavoritesView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var favoriteRoutes: [AllRoute] = []
    @State private var isLoading = true
    @State private var showingGpxView = false
    @State private var selectedGpxFile: GpxFile?
    @State private var selectedRouteName: String = ""

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading favorites...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if favoriteRoutes.isEmpty {
                Text("No favorite routes")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(favoriteRoutes) { route in
                    Button(action: { loadRoute(route) }) {
                        VStack(alignment: .leading, spacing: 8) {
                            // Route Name
                            Text(route.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

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
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(sourceTypeColor(for: route.sourceType).opacity(0.2))
                            .foregroundColor(sourceTypeColor(for: route.sourceType))
                            .cornerRadius(4)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Voyage Plan Favorites")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.orange, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withNotificationAndHome(sourceView: "Voyage Plan Favorites")
        .onAppear {
            Task {
                await loadFavoriteRoutes()
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

    private func sourceTypeColor(for sourceType: String) -> Color {
        switch sourceType {
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
                // Handle error - could show an alert or error message
                print("Failed to load route: \(error.localizedDescription)")
            }
        }
    }

    private func loadFavoriteRoutes() async {
        do {
            let favorites = try await serviceProvider.allRoutesService.getFavoriteRoutesAsync()
            await MainActor.run {
                favoriteRoutes = favorites
                isLoading = false
            }
        } catch {
            await MainActor.run {
                favoriteRoutes = []
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VoyagePlanFavoritesView()
            .environmentObject(ServiceProvider())
    }
}
