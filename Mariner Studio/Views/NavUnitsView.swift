// Views/NavUnitsView.swift
import SwiftUI

struct NavUnitsView: View {
    // MARK: - Properties
    @StateObject private var viewModel: NavUnitsViewModel
    // Removed @State properties for searchText and showOnlyFavorites

    // MARK: - Initialization
    init(
        databaseService: DatabaseService,
        locationService: LocationService = LocationServiceImpl() // Can use default if always provided by ServiceProvider
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
            statusBar // Corrected statusBar usage

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
            // Use the renamed load method if applicable, otherwise keep as is
            await viewModel.loadNavUnits()
        }
    }

    // MARK: - View Components
    private var searchAndFilterBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                // Bind TextField directly to the ViewModel's property
                TextField("Search nav units...", text: $viewModel.searchText)
                    .onChange(of: viewModel.searchText) { _ in
                        // Call the ViewModel's method that now reads the properties internally
                        viewModel.searchTextChanged() // Corrected method call
                    }

                // Use viewModel.searchText here too
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        // Call the ViewModel's clear method
                        viewModel.clearSearch() // Corrected method call
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemBackground)) // Use system background for adaptability
            .cornerRadius(10)
            .padding(.trailing, 8)

            Button(action: {
                // Toggle the ViewModel's property directly
                viewModel.showOnlyFavorites.toggle()
                // Call the ViewModel's method that reacts to the toggle
                viewModel.favoritesToggleChanged() // Corrected method call
            }) {
                // Read the favorite state from the ViewModel
                Image(systemName: viewModel.showOnlyFavorites ? "star.fill" : "star") // Use viewModel state
                    .foregroundColor(viewModel.showOnlyFavorites ? .yellow : .gray) // Use viewModel state
                    .frame(width: 44, height: 44) // Ensure consistent button size
            }
        }
        .padding([.horizontal, .top])
    }

    // CORRECTED statusBar implementation
    private var statusBar: some View {
        // Wrap the content in a VStack
        VStack(alignment: .leading, spacing: 4) { // Added VStack and spacing
            HStack {
                Text("Total Units: \(viewModel.totalNavUnits)")
                    .font(.footnote)
                Spacer()
                // Read computed property from ViewModel
                Text("Location: \(viewModel.isLocationEnabled ? "Enabled" : "Disabled")")
                    .font(.footnote)
            }
            .padding(.horizontal) // Keep horizontal padding for this HStack

            // Add user coordinates display for consistency, inside the VStack
            if viewModel.isLocationEnabled {
                HStack {
                    Text("Your Position: \(viewModel.userLatitude), \(viewModel.userLongitude)")
                        .font(.footnote)
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding(.horizontal) // Keep horizontal padding for this HStack too
            }
        }
        .padding(.bottom, 5) // Apply bottom padding to the whole VStack
    }

    private var navUnitsList: some View {
        List {
            // Use the filtered list from the ViewModel
            ForEach(viewModel.filteredNavUnits) { navUnitWithDistance in
                // Using a Button instead of NavigationLink for now, assuming details view is TBD
                Button(action: {
                    // Action for selecting a row (e.g., navigate to detail view)
                    print("Selected NavUnit: \(navUnitWithDistance.station.navUnitName)")
                    // TODO: Implement navigation to a NavUnit detail view if needed
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
                .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle for standard row appearance
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
             // Use the renamed refresh method
             await viewModel.refreshNavUnits()
        }
    }
}

// NavUnitRow remains unchanged from your provided code
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
                // Ensure the button tap area is reasonable even if the icon is small
                .contentShape(Rectangle())
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
                 // Assuming phoneNumbers is non-empty due to hasPhoneNumbers check
                 Text("Phone: \(navUnitWithDistance.station.phoneNumbers.first ?? "N/A")")
                     .font(.caption)
                     .foregroundColor(.blue) // Keep phone number noticeable
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
        .padding(.vertical, 5) // Add some vertical padding to rows
    }

    // Helper functions (assuming these are still needed and correct)
    private func formatCityState(city: String?, state: String?) -> String? {
        let cityText = city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stateText = state?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

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
             // Check for valid coordinate range if necessary, e.g. lat != 0 || lon != 0
             if abs(lat) > 0.0001 || abs(lon) > 0.0001 { // Avoid showing 0.0000, 0.0000
                 return String(format: "Lat: %.4f, Long: %.4f", lat, lon)
             }
        }
        return nil
    }
}


// MARK: - Preview
#Preview {
    // Ensure the preview also works with the updated structure
    // You might need a mock DatabaseService and LocationService for robust previews
    NavUnitsView(
        databaseService: DatabaseServiceImpl.getInstance(), // Or a mock service
        locationService: LocationServiceImpl() // Or a mock service
    )
    // Add environment object if MainView provides it higher up
    // .environmentObject(ServiceProvider())
}
