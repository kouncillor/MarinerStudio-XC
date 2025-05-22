
import SwiftUI

struct NavUnitFavoritesView: View {
    @StateObject private var viewModel = NavUnitFavoritesViewModel()
    @EnvironmentObject var serviceProvider: ServiceProvider
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading favorites...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.errorMessage.isEmpty {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text(viewModel.errorMessage)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.favorites.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                        .padding()
                    
                    Text("No Favorite Nav Units")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Navigation units you mark as favorites will appear here.")
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
            } else {
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
                                favoritesService: serviceProvider.favoritesService
                            )
                            NavUnitDetailsView(viewModel: detailsViewModel)
                        } label: {
                            FavoriteNavUnitRow(navUnit: navUnit)
                        }
                    }
                    .onDelete(perform: viewModel.removeFavorite)
                }
                .listStyle(InsetGroupedListStyle())
                .refreshable {
                    viewModel.loadFavorites()
                }
            }
        }
       .navigationTitle("Favorite Nav Units")
       .withHomeButton()
        
        .onAppear {
            viewModel.initialize(
                navUnitService: serviceProvider.navUnitService,
                locationService: serviceProvider.locationService
            )
            viewModel.loadFavorites()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

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
                
                if let facilityType = navUnit.facilityType, !facilityType.isEmpty {
                    Text(facilityType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
            }
            
            Spacer()
        
        }
        .padding(.vertical, 8)
    }
}
