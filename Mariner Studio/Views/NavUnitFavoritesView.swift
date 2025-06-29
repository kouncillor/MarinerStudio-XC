
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
            
            // Initialize services
            viewModel.initialize(
                navUnitService: serviceProvider.navUnitService,
                locationService: serviceProvider.locationService
            )
            
            print("📱 NAV_UNIT_VIEW: Starting simple loadFavorites()")
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
    
    @ViewBuilder
    private var mainContentView: some View {
        if viewModel.isLoading {
            // Loading state
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Loading favorites...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        } else if !viewModel.errorMessage.isEmpty {
            // Error state
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                
                Text("Error Loading Favorites")
                    .font(.headline)
                
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
            
        } else if viewModel.favorites.isEmpty {
            // Empty state
            VStack(spacing: 20) {
                Image(systemName: "star")
                    .font(.system(size: 50))
                    .foregroundColor(.yellow)
                
                Text("No Favorite Nav Units")
                    .font(.headline)
                
                Text("Add nav units to your favorites to see them here")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        } else {
            // Favorites list
            favoritesList
        }
    }
    
    private var favoritesList: some View {
        List {
            ForEach(viewModel.favorites, id: \.navUnitId) { favoriteRecord in
                NavigationLink {
                    // Fetch full NavUnit model when user taps
                    NavUnitDetailWrapper(
                        navUnitId: favoriteRecord.navUnitId,
                        serviceProvider: serviceProvider
                    )
                } label: {
                    SimpleFavoriteNavUnitRow(favoriteRecord: favoriteRecord)
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
        .onAppear {
            print("🎨 NAV_UNIT_VIEW: Favorites list view appeared with \(viewModel.favorites.count) nav units")
        }
    }
}

// MARK: - Simple Favorite Nav Unit Row

struct SimpleFavoriteNavUnitRow: View {
    let favoriteRecord: NavUnitFavoriteRecord
    
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
                Text(favoriteRecord.navUnitName ?? "Unknown Nav Unit")
                    .font(.headline)
                    .lineLimit(2)
                
                if let facilityType = favoriteRecord.facilityType, !facilityType.isEmpty {
                    Text(facilityType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Show nav unit ID as small text
                Text("ID: \(favoriteRecord.navUnitId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
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

// MARK: - NavUnit Detail Wrapper (Fetches Full Model)

struct NavUnitDetailWrapper: View {
    let navUnitId: String
    let serviceProvider: ServiceProvider
    
    @State private var navUnit: NavUnit?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Loading nav unit details...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Error Loading Details")
                        .font(.headline)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        loadNavUnit()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else if let navUnit = navUnit {
                // Create full NavUnitDetailsViewModel with the loaded model
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
                
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Nav Unit Not Found")
                        .font(.headline)
                    
                    Text("This nav unit may have been removed from the database.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Nav Unit Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadNavUnit()
        }
    }
    
    private func loadNavUnit() {
        print("🔍 NAV_UNIT_WRAPPER: Loading full NavUnit for ID: \(navUnitId)")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedNavUnit = try await serviceProvider.navUnitService.getNavUnitByIdAsync(navUnitId: navUnitId)
                
                await MainActor.run {
                    self.navUnit = fetchedNavUnit
                    self.isLoading = false
                    
                    if fetchedNavUnit != nil {
                        print("✅ NAV_UNIT_WRAPPER: Successfully loaded NavUnit \(navUnitId)")
                    } else {
                        print("❌ NAV_UNIT_WRAPPER: NavUnit \(navUnitId) not found")
                    }
                }
            } catch {
                print("❌ NAV_UNIT_WRAPPER: Error loading NavUnit \(navUnitId): \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = "Failed to load nav unit: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Simple Detail View (Placeholder) - REMOVED

// Helper view for info rows
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.regular)
        }
    }
}
