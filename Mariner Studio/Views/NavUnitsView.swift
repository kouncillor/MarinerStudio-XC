// Views/NavUnitsView.swift
import SwiftUI

struct NavUnitsView: View {
    // MARK: - Properties
    @StateObject private var viewModel: NavUnitsViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider

    // MARK: - Initialization
    init(
        navUnitService: NavUnitDatabaseService,
        locationService: LocationService = LocationServiceImpl() // Can use default if always provided by ServiceProvider
    ) {
        _viewModel = StateObject(wrappedValue: NavUnitsViewModel(
            navUnitService: navUnitService,
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

                // Bind TextField directly to the ViewModel's property
                TextField("Search nav units...", text: $viewModel.searchText)
                    .onChange(of: viewModel.searchText) { _ in
                        viewModel.searchTextChanged()
                    }

                // Use viewModel.searchText here too
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
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
                viewModel.showOnlyFavorites.toggle()
                viewModel.favoritesToggleChanged()
            }) {
                Image(systemName: viewModel.showOnlyFavorites ? "star.fill" : "star")
                    .foregroundColor(viewModel.showOnlyFavorites ? .yellow : .gray)
                    .frame(width: 44, height: 44)
            }
        }
        .padding([.horizontal, .top])
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Total Units: \(viewModel.totalNavUnits)")
                    .font(.footnote)
                Spacer()
                Text("Location: \(viewModel.isLocationEnabled ? "Enabled" : "Disabled")")
                    .font(.footnote)
            }
            .padding(.horizontal)

            if viewModel.isLocationEnabled {
                HStack {
                    Text("Your Position: \(viewModel.userLatitude), \(viewModel.userLongitude)")
                        .font(.footnote)
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 5)
    }

    private var navUnitsList: some View {
        List {
            ForEach(viewModel.filteredNavUnits) { navUnitWithDistance in
                NavigationLink {
                    // Create the destination view directly to avoid closures
                    let detailsViewModel = NavUnitDetailsViewModel(
                        navUnit: navUnitWithDistance.station,
                        databaseService: viewModel.navUnitService,
                        photoService: serviceProvider.photoService,
                        navUnitFtpService: serviceProvider.navUnitFtpService,
                        imageCacheService: serviceProvider.imageCacheService,
                        favoritesService: serviceProvider.favoritesService
                    )
                    NavUnitDetailsView(viewModel: detailsViewModel)
                } label: {
                    NavUnitRow(
                        navUnitWithDistance: navUnitWithDistance,
                        onToggleFavorite: {
                            Task {
                                await viewModel.toggleNavUnitFavorite(navUnitId: navUnitWithDistance.station.navUnitId)
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
             await viewModel.refreshNavUnits()
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
                 Text("Phone: \(navUnitWithDistance.station.phoneNumbers.first ?? "N/A")")
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

            if !navUnitWithDistance.distanceDisplay.isEmpty {
                Text("Distance: \(navUnitWithDistance.distanceDisplay)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 5)
    }

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
             if abs(lat) > 0.0001 || abs(lon) > 0.0001 {
                 return String(format: "Lat: %.4f, Long: %.4f", lat, lon)
             }
        }
        return nil
    }
}

#Preview {
    NavUnitsView(
        navUnitService: NavUnitDatabaseService(databaseCore: DatabaseCore())
    )
    .environmentObject(ServiceProvider())
}
