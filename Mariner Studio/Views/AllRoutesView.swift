//
//  AllRoutesView.swift
//  Mariner Studio
//
//  Created for displaying all routes from various sources (public, imported, created).
//

import SwiftUI

struct AllRoutesView: View {
    @StateObject private var viewModel: AllRoutesViewModel
    
    init(allRoutesService: AllRoutesDatabaseService? = nil) {
        _viewModel = StateObject(wrappedValue: AllRoutesViewModel(allRoutesService: allRoutesService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with filters
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
            .navigationTitle("All Routes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .onAppear {
                viewModel.loadRoutes()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("All Available Routes")
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
    
    // MARK: - Routes List
    
    private var routesListView: some View {
        List(viewModel.filteredRoutes) { route in
            AllRouteRowView(
                route: route,
                isOperationInProgress: viewModel.operationsInProgress.contains(route.id),
                onFavoriteToggle: {
                    viewModel.toggleFavorite(route)
                },
                onDelete: {
                    viewModel.deleteRoute(route)
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
            Image(systemName: "list.bullet.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Routes Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Download public routes, import your own files, or create new routes to get started.")
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

// MARK: - All Route Row View

struct AllRouteRowView: View {
    let route: AllRoute
    let isOperationInProgress: Bool
    let onFavoriteToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Route Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
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
                    
                    if let notes = route.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 20) {
                    favoriteButton
                    deleteButton
                }
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
    
    private var favoriteButton: some View {
        Button(action: onFavoriteToggle) {
            Image(systemName: route.isFavorite ? "star.fill" : "star")
                .foregroundColor(isOperationInProgress ? .gray.opacity(0.5) : (route.isFavorite ? .yellow : .gray))
                .font(.title3)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .disabled(isOperationInProgress)
    }
    
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .foregroundColor(isOperationInProgress ? .gray.opacity(0.5) : .red)
                .font(.title3)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .disabled(isOperationInProgress)
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
    
    private var routeDetailsView: some View {
        HStack(spacing: 16) {
            if let tags = route.tags, !tags.isEmpty {
                Label {
                    Text(tags)
                        .font(.caption)
                } icon: {
                    Image(systemName: "tag")
                        .foregroundColor(.orange)
                }
            }
            
            Label {
                Text(route.formattedCreatedDate)
                    .font(.caption)
            } icon: {
                Image(systemName: "calendar")
                    .foregroundColor(.green)
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
                value: route.formattedDistance
            )
            
            if route.isFavorite {
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        
                        Text("Favorite")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("★")
                        .font(.caption)
                        .fontWeight(.medium)
                }
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
}

// MARK: - Preview

#Preview {
    AllRoutesView()
}