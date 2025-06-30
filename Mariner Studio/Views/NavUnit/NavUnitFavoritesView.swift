////
////  NavUnitFavoritesView.swift
////  Mariner Studio
////
////  NavUnit Favorites View - Displays a list of favorite navigation units
////  Allows navigation to details and swipe-to-toggle favorite status
////
//
//import SwiftUI
//
//struct NavUnitFavoritesView: View {
//    @StateObject private var viewModel = NavUnitFavoritesViewModel()
//    @EnvironmentObject var serviceProvider: ServiceProvider
//    @Environment(\.colorScheme) var colorScheme
//    
//    var body: some View {
//        ZStack {
//            // Main content
//            mainContentView
//        }
//        .navigationTitle("Favorite Nav Units")
//        .withHomeButton()
//        .onAppear {
//            print("🚢 VIEW: NavUnitFavoritesView appeared")
//            print("🚢 VIEW: Current thread = \(Thread.current)")
//            print("🚢 VIEW: Is main thread = \(Thread.isMainThread)")
//            
//            // Initialize services if needed
//            if viewModel.navUnitService == nil {
//                print("🔧 VIEW: Initializing ViewModel with services")
//                print("🔧 VIEW: ServiceProvider available = \(serviceProvider)")
//                
//                viewModel.initialize(
//                    navUnitService: serviceProvider.navUnitService,
//                    locationService: serviceProvider.locationService
//                )
//            }
//            
//            print("📱 VIEW: Starting loadFavorites()")
//            viewModel.loadFavorites()
//        }
//        .onDisappear {
//            print("🚢 VIEW: NavUnitFavoritesView disappeared")
//            viewModel.cleanup()
//        }
//    }
//    
//    // MARK: - Main Content View
//    
//    @ViewBuilder
//    private var mainContentView: some View {
//        Group {
//            if viewModel.isLoading {
//                loadingView
//            } else if !viewModel.errorMessage.isEmpty {
//                errorView
//            } else if viewModel.favorites.isEmpty {
//                emptyStateView
//            } else {
//                favoritesListView
//            }
//        }
//    }
//    
//    // MARK: - Loading View
//    
//    private var loadingView: some View {
//        VStack(spacing: 16) {
//            ProgressView()
//                .scaleEffect(1.2)
//            
//            Text("Loading favorite nav units...")
//                .font(.headline)
//                .foregroundColor(.secondary)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(Color(.systemBackground))
//    }
//    
//    // MARK: - Error View
//    
//    private var errorView: some View {
//        VStack(spacing: 20) {
//            Image(systemName: "exclamationmark.triangle")
//                .font(.system(size: 50))
//                .foregroundColor(.orange)
//            
//            Text("Error Loading Favorites")
//                .font(.title2)
//                .fontWeight(.semibold)
//            
//            Text(viewModel.errorMessage)
//                .font(.body)
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//            
//            Button("Try Again") {
//                viewModel.loadFavorites()
//            }
//            .buttonStyle(.borderedProminent)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(Color(.systemBackground))
//    }
//    
//    // MARK: - Empty State View
//    
//    private var emptyStateView: some View {
//        VStack(spacing: 24) {
//            Image(systemName: "star.slash")
//                .font(.system(size: 60))
//                .foregroundColor(.secondary)
//            
//            VStack(spacing: 12) {
//                Text("No Favorite Nav Units")
//                    .font(.title2)
//                    .fontWeight(.semibold)
//                
//                Text("Add navigation units to your favorites from the nav units list or map view.")
//                    .font(.body)
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal, 40)
//            }
//            
//            Button("Browse Nav Units") {
//                // This could navigate back or to the main nav units list
//                // For now, we'll just refresh in case there are favorites
//                viewModel.refreshFavorites()
//            }
//            .buttonStyle(.borderedProminent)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(Color(.systemBackground))
//    }
//    
//    // MARK: - Favorites List View
//    
//    private var favoritesListView: some View {
//        VStack(spacing: 0) {
//            // Quick stats header
//            HStack {
//                Text("\(viewModel.favorites.count) favorite nav units")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                
//                Spacer()
//                
//                Text("Swipe to remove")
//                    .font(.caption2)
//                    .foregroundColor(.secondary)
//            }
//            .padding(.horizontal)
//            .padding(.vertical, 4)
//            .background(Color(.systemGray6))
//            
//            // List of favorites
//            List {
//                ForEach(viewModel.favorites) { navUnitWithDistance in
//                    NavigationLink {
//                        // Create NavUnitDetailsView with proper dependency injection
//                        let detailsViewModel = NavUnitDetailsViewModel(
//                            navUnit: navUnitWithDistance.station,
//                            databaseService: serviceProvider.navUnitService,
//                            favoritesService: serviceProvider.favoritesService,
//                            noaaChartService: serviceProvider.noaaChartService
//                        )
//                        
//                        NavUnitDetailsView(viewModel: detailsViewModel)
//                    } label: {
//                        FavoriteNavUnitRow(navUnitWithDistance: navUnitWithDistance)
//                    }
//                    .onAppear {
//                        print("🎨 VIEW: Nav unit row appeared for \(navUnitWithDistance.station.navUnitId)")
//                    }
//                }
//                .onDelete(perform: { offsets in
//                    print("🗑️ VIEW: Delete gesture triggered for offsets \(Array(offsets))")
//                    viewModel.removeFavorite(at: offsets)
//                })
//            }
//            .listStyle(.insetGrouped)
//            .refreshable {
//                print("🔄 VIEW: Pull-to-refresh triggered")
//                viewModel.refreshFavorites()
//            }
//        }
//    }
//}
//
//// MARK: - Favorite Nav Unit Row
//
//struct FavoriteNavUnitRow: View {
//    let navUnitWithDistance: StationWithDistance<NavUnit>
//    
//    private var navUnit: NavUnit {
//        navUnitWithDistance.station
//    }
//    
//    private var distanceText: String {
//        let distance = navUnitWithDistance.distanceFromUser
//        
//        if distance == Double.greatestFiniteMagnitude {
//            return "Location unknown"
//        } else if distance < 1.0 {
//            return String(format: "%.1f mi", distance)
//        } else {
//            return String(format: "%.0f mi", distance)
//        }
//    }
//    
//    var body: some View {
//        HStack(spacing: 12) {
//            // Favorite star icon
//            Image(systemName: "star.fill")
//                .foregroundColor(.yellow)
//                .font(.system(size: 16))
//                .frame(width: 20)
//            
//            // Nav unit info
//            VStack(alignment: .leading, spacing: 4) {
//                Text(navUnit.navUnitName)
//                    .font(.headline)
//                    .lineLimit(2)
//                
//                if let location = navUnit.location, !location.isEmpty {
//                    Text(location)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                        .lineLimit(1)
//                }
//                
//                // Nav unit details
//                HStack(spacing: 8) {
//                    Text("ID: \(navUnit.navUnitId)")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    
//                    if let facilityType = navUnit.facilityType, !facilityType.isEmpty {
//                        Text("•")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                        
//                        Text(facilityType)
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                }
//            }
//            
//            Spacer()
//            
//            // Distance and navigation indicator
//            VStack(alignment: .trailing, spacing: 4) {
//                Text(distanceText)
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//                    .foregroundColor(.blue)
//                
//                Image(systemName: "chevron.right")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//        }
//        .padding(.vertical, 4)
//    }
//}
//





//
//  NavUnitFavoritesView.swift
//  Mariner Studio
//
//  NavUnit Favorites View with comprehensive sync integration
//  Displays user's favorite navigation units with manual sync capability
//  Features sync status indication and error handling
//

import SwiftUI

struct NavUnitFavoritesView: View {
    @StateObject private var viewModel = NavUnitFavoritesViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.favorites.isEmpty {
                LoadingView()
            } else if !viewModel.errorMessage.isEmpty {
                ErrorView(errorMessage: viewModel.errorMessage) {
                    viewModel.loadFavorites()
                }
            } else if viewModel.favorites.isEmpty {
                EmptyFavoritesView()
            } else {
                FavoritesListView()
            }
        }
        .navigationTitle("Favorite Nav Units")
        .navigationBarTitleDisplayMode(.inline)
        .withHomeButton()
        .onAppear {
            print("🎨 NavUnitFavoritesView: View appeared")
            viewModel.initialize(
                navUnitService: serviceProvider.navUnitService,
                locationService: serviceProvider.locationService,
                syncService: serviceProvider.navUnitSyncService
            )
            viewModel.loadFavorites()
        }
        .onDisappear {
            print("🎨 NavUnitFavoritesView: View disappeared")
            viewModel.cleanup()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Sync button in the same position as CurrentFavoritesView
                SyncButton()
            }
        }
    }
    
    // MARK: - Sync Button
    
    @ViewBuilder
    private func SyncButton() -> some View {
        if viewModel.isSyncing {
            // Show progress indicator when syncing
            ProgressView()
                .scaleEffect(0.8)
                .foregroundColor(.blue)
        } else {
            // Show sync button when not syncing
            Button(action: {
                print("🔄 NavUnitFavoritesView: Manual sync button tapped")
                Task {
                    await viewModel.performManualSync()
                }
            }) {
                Image(systemName: syncIconName)
                    .foregroundColor(syncIconColor)
            }
            .disabled(viewModel.isLoading) // Disable while initial load is happening
        }
    }
    
    // MARK: - Sync Icon State
    
    private var syncIconName: String {
        if viewModel.syncErrorMessage != nil {
            return "exclamationmark.icloud"
        } else if viewModel.lastSyncTime != nil {
            return "checkmark.icloud.fill"
        } else {
            return "icloud.slash"
        }
    }
    
    private var syncIconColor: Color {
        if viewModel.syncErrorMessage != nil {
            return .orange
        } else if viewModel.lastSyncTime != nil {
            return .green
        } else {
            return .gray
        }
    }
    
    // MARK: - Loading View
    
    @ViewBuilder
    private func LoadingView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Loading favorites...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Error View
    
    @ViewBuilder
    private func ErrorView(errorMessage: String, onRetry: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Error Loading Favorites")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(errorMessage)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Empty State View
    
    @ViewBuilder
    private func EmptyFavoritesView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Favorite Nav Units")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add navigation units to your favorites from the nav units list or map view.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.caption)
                .padding(.horizontal, 40)
            
            NavigationLink(destination: NavUnitsView(
                navUnitService: serviceProvider.navUnitService,
                locationService: serviceProvider.locationService
            )) {
                HStack {
                    Image(systemName: "location.magnifyingglass")
                    Text("Browse All Nav Units")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Favorites List View
    
    @ViewBuilder
    private func FavoritesListView() -> some View {
        VStack(spacing: 0) {
            // NEW: Sync Status View (like CurrentFavoritesView)
            SyncStatusView()
            
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
                            favoritesService: serviceProvider.favoritesService,
                            noaaChartService: serviceProvider.noaaChartService
                        )
                        
                        NavUnitDetailsView(viewModel: detailsViewModel)
                    } label: {
                        FavoriteNavUnitRow(navUnitWithDistance: navUnitWithDistance)
                    }
                    .onAppear {
                        print("🎨 NavUnitFavoritesView: Nav unit row appeared for \(navUnitWithDistance.station.navUnitId)")
                    }
                }
                .onDelete(perform: { offsets in
                    print("🗑️ NavUnitFavoritesView: Delete gesture triggered for offsets \(Array(offsets))")
                    Task {
                        await viewModel.removeFavorite(at: offsets)
                    }
                })
            }
            .listStyle(.insetGrouped)
            .refreshable {
                print("🔄 NavUnitFavoritesView: Pull-to-refresh triggered")
                await viewModel.refreshFavorites()
            }
        }
    }
    
    // MARK: - Sync Status View
    
    @ViewBuilder
    private func SyncStatusView() -> some View {
        if viewModel.isSyncing {
            // Show syncing status
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Syncing nav unit favorites...")
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
        } else if let errorMessage = viewModel.syncErrorMessage {
            // Show sync error
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                Spacer()
                
                Button("Retry") {
                    Task {
                        await viewModel.performManualSync()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
        } else if let successMessage = viewModel.syncSuccessMessage {
            // Show sync success (auto-dismiss after 3 seconds)
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(successMessage)
                    .font(.caption)
                    .foregroundColor(.green)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1))
            .onAppear {
                // Auto-dismiss success message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    viewModel.clearSyncMessages()
                }
            }
        } else if let lastSyncTime = viewModel.lastSyncTime {
            // Show last sync time
            HStack {
                Image(systemName: "checkmark.icloud.fill")
                    .foregroundColor(.green)
                Text("Last sync: \(DateFormatter.syncStatus.string(from: lastSyncTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                
                Button("Sync") {
                    Task {
                        await viewModel.performManualSync()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
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
            
            // Nav unit info
            VStack(alignment: .leading, spacing: 4) {
                Text(navUnit.navUnitName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let facilityType = navUnit.facilityType, !facilityType.isEmpty {
                    Text(facilityType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    if let cityOrTown = navUnit.cityOrTown, !cityOrTown.isEmpty {
                        Text(cityOrTown)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let statePostalCode = navUnit.statePostalCode, !statePostalCode.isEmpty {
                        Text(statePostalCode)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(distanceText)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let syncStatus: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
