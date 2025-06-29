//
//import SwiftUI
//
//struct NavUnitFavoritesView: View {
//    @StateObject private var viewModel = NavUnitFavoritesViewModel()
//    @EnvironmentObject var serviceProvider: ServiceProvider
//    @Environment(\.colorScheme) var colorScheme
//    
//    var body: some View {
//        Group {
//            if viewModel.isLoading {
//                ProgressView("Loading favorites...")
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//            } else if !viewModel.errorMessage.isEmpty {
//                VStack {
//                    Image(systemName: "exclamationmark.triangle")
//                        .font(.largeTitle)
//                        .foregroundColor(.orange)
//                        .padding()
//                    
//                    Text(viewModel.errorMessage)
//                        .multilineTextAlignment(.center)
//                        .padding()
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//            } else if viewModel.favorites.isEmpty {
//                VStack(spacing: 16) {
//                    Image(systemName: "star.slash")
//                        .font(.system(size: 60))
//                        .foregroundColor(.gray)
//                        .padding()
//                    
//                    Text("No Favorite Nav Units")
//                        .font(.title2)
//                        .fontWeight(.semibold)
//                    
//                    Text("Navigation units you mark as favorites will appear here.")
//                        .multilineTextAlignment(.center)
//                        .foregroundColor(.secondary)
//                    
//                    Spacer().frame(height: 20)
//                    
//                    NavigationLink(destination: NavUnitsView(
//                        navUnitService: serviceProvider.navUnitService,
//                        locationService: serviceProvider.locationService
//                    )) {
//                        HStack {
//                            Image(systemName: "list.bullet")
//                            Text("Browse All Nav Units")
//                        }
//                        .padding()
//                        .background(Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                    }
//                }
//                .padding()
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//            } else {
//                List {
//                    ForEach(viewModel.favorites, id: \.navUnitId) { navUnit in
//                        NavigationLink {
//                            // Create the destination view with proper NavUnitDetailsViewModel
//                            let detailsViewModel = NavUnitDetailsViewModel(
//                                navUnit: navUnit,
//                                databaseService: serviceProvider.navUnitService,
//                                photoService: serviceProvider.photoService,
//                                navUnitFtpService: serviceProvider.navUnitFtpService,
//                                imageCacheService: serviceProvider.imageCacheService,
//                                favoritesService: serviceProvider.favoritesService,
//                                photoCaptureService: serviceProvider.photoCaptureService,
//                                fileStorageService: serviceProvider.fileStorageService,
//                                iCloudSyncService: serviceProvider.iCloudSyncService,
//                                noaaChartService: serviceProvider.noaaChartService // ADDED: Chart service parameter
//                            )
//                            NavUnitDetailsView(viewModel: detailsViewModel)
//                        } label: {
//                            FavoriteNavUnitRow(navUnit: navUnit)
//                        }
//                    }
//                    .onDelete(perform: viewModel.removeFavorite)
//                }
//                .listStyle(InsetGroupedListStyle())
//                .refreshable {
//                    viewModel.loadFavorites()
//                }
//            }
//        }
//        .navigationTitle("Favorite Nav Units")
//        .toolbar {
//            ToolbarItem(placement: .topBarTrailing) {
//                NavigationLink(destination: MainView(shouldClearNavigation: true)) {
//                    Image(systemName: "house.fill")
//                        .foregroundColor(.blue)
//                }
//                .simultaneousGesture(TapGesture().onEnded {
//                    // Provide haptic feedback
//                    let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
//                    impactGenerator.prepare()
//                    impactGenerator.impactOccurred()
//                })
//            }
//        }
//        .onAppear {
//            viewModel.initialize(
//                navUnitService: serviceProvider.navUnitService,
//                locationService: serviceProvider.locationService
//            )
//            viewModel.loadFavorites()
//        }
//        .onDisappear {
//            viewModel.cleanup()
//        }
//    }
//}
//
//struct FavoriteNavUnitRow: View {
//    let navUnit: NavUnit
//    
//    var body: some View {
//        HStack(spacing: 16) {
//            // Nav Unit icon
//            Image(systemName: "n.circle.fill")
//                .resizable()
//                .frame(width: 36, height: 36)
//                .foregroundColor(.blue)
//                .padding(8)
//                .background(Color.white.opacity(0.1))
//                .clipShape(Circle())
//            
//            // Nav Unit info
//            VStack(alignment: .leading, spacing: 4) {
//                Text(navUnit.navUnitName)
//                    .font(.headline)
//                
//                if let facilityType = navUnit.facilityType, !facilityType.isEmpty {
//                    Text(facilityType)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
//                
//            }
//            
//            Spacer()
//        
//        }
//        .padding(.vertical, 8)
//    }
//}




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
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Sync button
                Button(action: {
                    print("☁️ NAV_UNIT_UI: Manual sync button tapped")
                    Task {
                        await viewModel.manualSync()
                    }
                }) {
                    Image(systemName: viewModel.syncStatusIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewModel.syncStatusColor)
                        .rotationEffect(.degrees(viewModel.isSyncing ? 360 : 0))
                        .animation(
                            viewModel.isSyncing ?
                            .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                            value: viewModel.isSyncing
                        )
                }
                .disabled(!viewModel.canSync)
            }
        }
        .onAppear {
            print("🌊⚖️ NAV_UNIT_VIEW: NavUnitFavoritesView appeared")
            print("🌊⚖️ NAV_UNIT_VIEW: Current thread = \(Thread.current)")
            print("🌊⚖️ NAV_UNIT_VIEW: Is main thread = \(Thread.isMainThread)")
            
            // Initialize services
            viewModel.initialize(
                navUnitService: serviceProvider.navUnitService,
                locationService: serviceProvider.locationService
            )
            
            print("📱 NAV_UNIT_VIEW: Starting loadFavorites()")
            viewModel.loadFavorites()
            
            // Perform app launch sync
            print("🚀 NAV_UNIT_VIEW: Starting app launch sync")
            Task {
                await viewModel.performAppLaunchSync()
            }
        }
        .onDisappear {
            print("🌊⚖️ NAV_UNIT_VIEW: NavUnitFavoritesView disappeared")
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
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(viewModel.errorMessage)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                print("🔄 NAV_UNIT_VIEW: Retry button tapped")
                viewModel.loadFavorites()
            }) {
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
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Favorite Nav Units")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Pull down to refresh or browse all nav units to add favorites.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Spacer().frame(height: 20)
            
            NavigationLink(destination: NavUnitsView(
                navUnitService: serviceProvider.navUnitService,
                locationService: serviceProvider.locationService
            )) {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("Browse All Nav Units")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Favorites List View
    
    private var favoritesListView: some View {
        VStack(spacing: 0) {
            // Sync Status Bar
            NavUnitSyncStatusBar(viewModel: viewModel)
            
            List {
                ForEach(viewModel.favorites, id: \.navUnitId) { navUnit in
                    NavigationLink {
                        // Create the destination view with proper NavUnitDetailsViewModel
                        let detailsViewModel = NavUnitDetailsViewModel(
                            navUnit: navUnit,
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
                        FavoriteNavUnitRow(navUnit: navUnit)
                    }
                }
                .onDelete(perform: { indexSet in
                    print("🗑️ NAV_UNIT_VIEW: Delete gesture triggered")
                    viewModel.removeFavorite(at: indexSet)
                    
                    // Haptic feedback
                    let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
                    impactGenerator.prepare()
                    impactGenerator.impactOccurred()
                })
            }
            .listStyle(InsetGroupedListStyle())
            .refreshable {
                print("🔄 NAV_UNIT_VIEW: Pull-to-refresh triggered")
                viewModel.loadFavorites()
                
                // Sync after refresh
                await viewModel.syncWithCloud()
            }
        }
        .onAppear {
            print("🎨 NAV_UNIT_VIEW: Favorites list view appeared with \(viewModel.favorites.count) nav units")
        }
    }
}

// MARK: - Nav Unit Sync Status Bar

struct NavUnitSyncStatusBar: View {
    @ObservedObject var viewModel: NavUnitFavoritesViewModel
    @State private var showingSuccessMessage = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Main status bar
            HStack(spacing: 12) {
                // Status icon and text
                HStack(spacing: 8) {
                    if viewModel.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: viewModel.syncStatusIcon)
                            .foregroundColor(viewModel.syncStatusColor)
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    Text(viewModel.syncStatusText)
                        .font(.caption)
                        .foregroundColor(viewModel.syncStatusColor)
                }
                
                Spacer()
                
                // Manual sync button
                if !viewModel.isSyncing {
                    Button(action: {
                        print("☁️ NAV_UNIT_SYNC_BAR: Manual sync button tapped")
                        Task {
                            await viewModel.manualSync()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "icloud.and.arrow.up")
                                .font(.system(size: 12, weight: .medium))
                            Text("Sync")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .disabled(!viewModel.canSync)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            
            // Success message (auto-dismissing)
            if let successMessage = viewModel.formattedSyncSuccessMessage, showingSuccessMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                    
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Error message (persistent)
            if let errorMessage = viewModel.syncErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    // Dismiss button for error
                    Button(action: {
                        viewModel.clearSyncMessages()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red.opacity(0.6))
                            .font(.system(size: 14))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
            }
        }
        .onChange(of: viewModel.syncSuccessMessage) { message in
            if message != nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingSuccessMessage = true
                }
                
                // Auto-dismiss success message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSuccessMessage = false
                    }
                    
                    // Clear the message after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.clearSyncMessages()
                    }
                }
            }
        }
    }
}

// MARK: - Favorite Nav Unit Row (Enhanced)

struct FavoriteNavUnitRow: View {
    let navUnit: NavUnit
    
    var body: some View {
        HStack(spacing: 16) {
            // Nav Unit icon
            Image(systemName: "n.circle.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundColor(.blue)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
            
            // Nav Unit info
            VStack(alignment: .leading, spacing: 4) {
                Text(navUnit.navUnitName)
                    .font(.headline)
                    .lineLimit(2)
                
                if let facilityType = navUnit.facilityType, !facilityType.isEmpty {
                    Text(facilityType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Location info if available
                if let latitude = navUnit.latitude, let longitude = navUnit.longitude,
                   latitude != 0.0 && longitude != 0.0 {
                    Text("\(String(format: "%.4f", latitude))°, \(String(format: "%.4f", longitude))°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Favorite indicator
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 16))
        }
        .padding(.vertical, 8)
    }
}
