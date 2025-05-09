//
//  WeatherFavoritesView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/9/25.
//


import SwiftUI
import CoreLocation

struct WeatherFavoritesView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @StateObject private var viewModel = WeatherFavoritesViewModel()
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else if viewModel.favorites.isEmpty {
                emptyView
            } else {
                favoritesList
            }
        }
        .navigationTitle("Weather Favorites")
        .onAppear {
            loadFavorites()
        }
    }
    
    // MARK: - Loading Favorites
    private func loadFavorites() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let favorites = try await serviceProvider.weatherService.getFavoriteWeatherLocationsAsync()
                
                await MainActor.run {
                    viewModel.favorites = favorites
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load favorites: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - View Components
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Loading your favorite locations...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title)
                .foregroundColor(.primary)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Try Again") {
                loadFavorites()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
            
            Text("No Favorite Locations")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("Add locations to your favorites by tapping the heart icon on the weather screen.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            NavigationLink(destination: CurrentLocalWeatherView()) {
                Text("View Current Location Weather")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var favoritesList: some View {
        List {
            ForEach(viewModel.favorites) { favorite in
                NavigationLink(
                    destination: WeatherMapLocationView(
                        latitude: favorite.latitude,
                        longitude: favorite.longitude,
                        locationName: favorite.locationName
                    )
                ) {
                    FavoriteLocationRow(favorite: favorite)
                }
            }
            .onDelete { indexSet in
                removeFavorites(at: indexSet)
            }
        }
        .refreshable {
            loadFavorites()
        }
    }
    
    // MARK: - Actions
    private func removeFavorites(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let favorite = viewModel.favorites[index]
                
                // Toggle the favorite status to false (unfavorite)
                _ = await serviceProvider.weatherService.toggleWeatherLocationFavoriteAsync(
                    latitude: favorite.latitude,
                    longitude: favorite.longitude,
                    locationName: favorite.locationName
                )
            }
            
            // Reload favorites
            loadFavorites()
        }
    }
}

// MARK: - Supporting Views
struct FavoriteLocationRow: View {
    let favorite: WeatherLocationFavorite
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.locationName)
                    .font(.headline)
                
                Text("Lat: \(String(format: "%.4f", favorite.latitude)), Long: \(String(format: "%.4f", favorite.longitude))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Added: \(formatDate(favorite.createdAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - ViewModel
class WeatherFavoritesViewModel: ObservableObject {
    @Published var favorites: [WeatherLocationFavorite] = []
}

// MARK: - Preview
struct WeatherFavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WeatherFavoritesView()
                .environmentObject(ServiceProvider())
        }
    }
}