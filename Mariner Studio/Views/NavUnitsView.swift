// Views/NavUnitsView.swift
import SwiftUI

struct NavUnitsView: View {
    // MARK: - Properties
    @StateObject private var viewModel: NavUnitsViewModel
    @State private var searchText = ""
    @State private var showOnlyFavorites = false
    
    // MARK: - Initialization
    init(
        databaseService: DatabaseService,
        locationService: LocationService = LocationServiceImpl()
    ) {
        _viewModel = StateObject(wrappedValue: NavUnitsViewModel(
            databaseService: databaseService,
            locationService: locationService
        ))
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            searchAndFilterBar
            
            // Status Information
            statusBar
            
            // Main Content
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    navUnitsList
                }
            }
        }
        .navigationTitle("Navigation Units")
        .task {
            await viewModel.loadNavUnits()
        }
    }
    
    // MARK: - View Components
    private var searchAndFilterBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search nav units...", text: $searchText)
                    .onChange(of: searchText) { _ in
                        viewModel.filterNavUnits(searchText: searchText, showOnlyFavorites: showOnlyFavorites)
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        viewModel.filterNavUnits(searchText: "", showOnlyFavorites: showOnlyFavorites)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.trailing, 8)
            
            Button(action: {
                showOnlyFavorites.toggle()
                viewModel.filterNavUnits(searchText: searchText, showOnlyFavorites: showOnlyFavorites)
            }) {
                Image(systemName: showOnlyFavorites ? "star.fill" : "star")
                    .foregroundColor(showOnlyFavorites ? .yellow : .gray)
                    .frame(width: 44, height: 44)
            }
        }
        .padding([.horizontal, .top])
    }
    
    private var statusBar: some View {
        HStack {
            Text("Total Units: \(viewModel.totalNavUnits)")
                .font(.footnote)
            Spacer()
            Text("Location: \(viewModel.isLocationEnabled ? "Enabled" : "Disabled")")
                .font(.footnote)
        }
        .padding(.horizontal)
        .padding(.bottom, 5)
    }
    
    private var navUnitsList: some View {
        List {
            ForEach(viewModel.filteredNavUnits) { navUnitWithDistance in
                // Using a Button instead of NavigationLink for now
                Button(action: {
                    // Just print info for now instead of navigating
                    print("Selected NavUnit: \(navUnitWithDistance.station.navUnitName)")
                }) {
                    NavUnitRow(
                        navUnitWithDistance: navUnitWithDistance,
                        onToggleFavorite: {
                            Task {
                                await viewModel.toggleNavUnitFavorite(navUnitId: navUnitWithDistance.station.navUnitId)
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle()) // Keeps the row's appearance clean
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await viewModel.loadNavUnits()
        }
    }
}

struct NavUnitRow: View {
    let navUnitWithDistance: StationWithDistance<NavUnit>
    let onToggleFavorite: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(navUnitWithDistance.station.navUnitName)
                    .font(.headline)
                Spacer()
                Button(action: onToggleFavorite) {
                    Image(systemName: navUnitWithDistance.station.isFavorite ? "star.fill" : "star")
                        .foregroundColor(navUnitWithDistance.station.isFavorite ? .yellow : .gray)
                }
            }
            
            if let facilityType = navUnitWithDistance.station.facilityType, !facilityType.isEmpty {
                Text(facilityType)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            if let location = navUnitWithDistance.station.location, !location.isEmpty {
                Text(location)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            if let cityState = formatCityState(
                city: navUnitWithDistance.station.cityOrTown,
                state: navUnitWithDistance.station.statePostalCode
            ), !cityState.isEmpty {
                Text(cityState)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if navUnitWithDistance.station.hasPhoneNumbers {
                Text("Phone: \(navUnitWithDistance.station.phoneNumbers.first ?? "")")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if let coordinates = formatCoordinates(
                latitude: navUnitWithDistance.station.latitude,
                longitude: navUnitWithDistance.station.longitude
            ), !coordinates.isEmpty {
                Text(coordinates)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Display distance if available
            if !navUnitWithDistance.distanceDisplay.isEmpty {
                Text("Distance: \(navUnitWithDistance.distanceDisplay)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 5)
    }
    
    // Helper functions
    private func formatCityState(city: String?, state: String?) -> String? {
        let cityText = city ?? ""
        let stateText = state ?? ""
        
        if !cityText.isEmpty && !stateText.isEmpty {
            return "\(cityText), \(stateText)"
        } else if !cityText.isEmpty {
            return cityText
        } else if !stateText.isEmpty {
            return stateText
        }
        
        return nil
    }
    
    private func formatCoordinates(latitude: Double?, longitude: Double?) -> String? {
        if let lat = latitude, let lon = longitude {
            return "Lat: \(String(format: "%.4f", lat)), Long: \(String(format: "%.4f", lon))"
        }
        return nil
    }
}

// MARK: - Preview
#Preview {
    NavUnitsView(databaseService: DatabaseServiceImpl.getInstance())
}
