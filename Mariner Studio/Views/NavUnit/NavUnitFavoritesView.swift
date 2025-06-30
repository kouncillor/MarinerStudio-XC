//
//  NavUnitFavoritesView.swift
//  Mariner Studio
//
//  NavUnit Favorites View - Displays a list of favorite navigation units
//  Allows navigation to details and swipe-to-toggle favorite status
//

import SwiftUI

struct NavUnitFavoritesView: View {
    @StateObject private var viewModel = NavUnitFavoritesViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Main content
            mainContentView
        }
        .navigationTitle("Favorite Nav Units")
        .withHomeButton()
        .onAppear {
            print("🚢 VIEW: NavUnitFavoritesView appeared")
            print("🚢 VIEW: Current thread = \(Thread.current)")
            print("🚢 VIEW: Is main thread = \(Thread.isMainThread)")
            
            // Initialize services if needed
            if viewModel.navUnitService == nil {
                print("🔧 VIEW: Initializing ViewModel with services")
                print("🔧 VIEW: ServiceProvider available = \(serviceProvider)")
                
                viewModel.initialize(
                    navUnitService: serviceProvider.navUnitService,
                    locationService: serviceProvider.locationService
                )
            }
            
            print("📱 VIEW: Starting loadFavorites()")
            viewModel.loadFavorites()
        }
        .onDisappear {
            print("🚢 VIEW: NavUnitFavoritesView disappeared")
            viewModel.cleanup()
        }
    }
    
    // MARK: - Main Content View
    
    @ViewBuilder
    private var mainContentView: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if !viewModel.errorMessage.isEmpty {
                errorView
            } else if viewModel.favorites.isEmpty {
                emptyStateView
            } else {
                favoritesListView
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading favorite nav units...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error Loading Favorites")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(viewModel.errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                viewModel.loadFavorites()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No Favorite Nav Units")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add navigation units to your favorites from the nav units list or map view.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Browse Nav Units") {
                // This could navigate back or to the main nav units list
                // For now, we'll just refresh in case there are favorites
                viewModel.refreshFavorites()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Favorites List View
    
    private var favoritesListView: some View {
        VStack(spacing: 0) {
            // Quick stats header
            HStack {
                Text("\(viewModel.favorites.count) favorite nav units")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Swipe to remove")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            
            // List of favorites
            List {
                ForEach(viewModel.favorites) { navUnitWithDistance in
                    NavigationLink {
                        // Create NavUnitDetailsView with proper dependency injection
                        let detailsViewModel = NavUnitDetailsViewModel(
                            navUnit: navUnitWithDistance.station,
                            databaseService: serviceProvider.navUnitService,
                            photoService: serviceProvider.photoService,
                            navUnitFtpService: serviceProvider.navUnitFtpService,
                            imageCacheService: serviceProvider.imageCacheService,
                            favoritesService: serviceProvider.favoritesService,
                            photoCaptureService: serviceProvider.photoCaptureService,
                            fileStorageService: serviceProvider.fileStorageService,
                            iCloudSyncService: serviceProvider.iCloudSyncService,
                            noaaChartService: serviceProvider.noaaChartService
                        )
                        
                        NavUnitDetailsView(viewModel: detailsViewModel)
                    } label: {
                        FavoriteNavUnitRow(navUnitWithDistance: navUnitWithDistance)
                    }
                    .onAppear {
                        print("🎨 VIEW: Nav unit row appeared for \(navUnitWithDistance.station.navUnitId)")
                    }
                }
                .onDelete(perform: { offsets in
                    print("🗑️ VIEW: Delete gesture triggered for offsets \(Array(offsets))")
                    viewModel.removeFavorite(at: offsets)
                })
            }
            .listStyle(.insetGrouped)
            .refreshable {
                print("🔄 VIEW: Pull-to-refresh triggered")
                viewModel.refreshFavorites()
            }
        }
    }
}

// MARK: - Favorite Nav Unit Row

struct FavoriteNavUnitRow: View {
    let navUnitWithDistance: StationWithDistance<NavUnit>
    
    private var navUnit: NavUnit {
        navUnitWithDistance.station
    }
    
    private var distanceText: String {
        let distance = navUnitWithDistance.distanceFromUser
        
        if distance == Double.greatestFiniteMagnitude {
            return "Location unknown"
        } else if distance < 1.0 {
            return String(format: "%.1f mi", distance)
        } else {
            return String(format: "%.0f mi", distance)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Favorite star icon
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 16))
                .frame(width: 20)
            
            // Nav unit info
            VStack(alignment: .leading, spacing: 4) {
                Text(navUnit.navUnitName)
                    .font(.headline)
                    .lineLimit(2)
                
                if let location = navUnit.location, !location.isEmpty {
                    Text(location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Nav unit details
                HStack(spacing: 8) {
                    Text("ID: \(navUnit.navUnitId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let facilityType = navUnit.facilityType, !facilityType.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(facilityType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Distance and navigation indicator
            VStack(alignment: .trailing, spacing: 4) {
                Text(distanceText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

