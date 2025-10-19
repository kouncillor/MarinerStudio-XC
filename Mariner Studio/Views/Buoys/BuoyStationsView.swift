import SwiftUI

struct BuoyStationsView: View {
    // MARK: - Properties
    @StateObject private var viewModel: BuoyStationsViewModel

    // MARK: - Initialization
    init(
        buoyService: BuoyApiService = BuoyServiceImpl(),
        locationService: LocationService = LocationServiceImpl(),
        coreDataManager: CoreDataManager
    ) {
        _viewModel = StateObject(wrappedValue: BuoyStationsViewModel(
            buoyService: buoyService,
            locationService: locationService,
            coreDataManager: coreDataManager
        ))
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar and Filters
            searchAndFilterBar

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
                    stationsList
                }
            }
        }
        .navigationTitle("Buoy Stations")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.purple, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withNotificationAndHome(sourceView: "Buoy Stations")

        .task {
            await viewModel.loadStations()
        }
    }

    // MARK: - View Components
    private var searchAndFilterBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search stations...", text: $viewModel.searchText)
                    .onChange(of: viewModel.searchText) {
                        viewModel.filterStations()
                    }

                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .padding(.trailing, 8)

            Button(action: {
                viewModel.toggleFavorites()
            }) {
                Image(systemName: viewModel.showOnlyFavorites ? "star.fill" : "star")
                    .foregroundColor(viewModel.showOnlyFavorites ? .yellow : .gray)
                    .frame(width: 44, height: 44)
            }
        }
        .padding([.horizontal, .top])
        .background(Color(.systemGroupedBackground))
    }

    private var stationsList: some View {
        List {
            ForEach(viewModel.stations) { stationWithDistance in
                NavigationLink(destination: BuoyStationWebView(
                    station: stationWithDistance.station,
                    coreDataManager: viewModel.coreDataManager
                )) {
                    BuoyStationRow(
                        stationWithDistance: stationWithDistance,
                        onToggleFavorite: {
                            Task {
                                await viewModel.toggleStationFavorite(stationId: stationWithDistance.station.id)
                            }
                        }
                    )
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            await viewModel.refreshStations()
        }
    }
}

struct BuoyStationRow: View {
    let stationWithDistance: StationWithDistance<BuoyStation>
    let onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // First Row: Station Name
            HStack {
                // Process the name to remove any ID prefix if present
                // This handles cases where the name might be formatted as "ID-Name" or empty
                let displayName = stationWithDistance.station.name.isEmpty
                    ? "Unnamed Station"
                    : (stationWithDistance.station.name.contains("-")
                        ? stationWithDistance.station.name.components(separatedBy: "-").dropFirst().joined(separator: "-").trimmingCharacters(in: .whitespaces)
                        : stationWithDistance.station.name)

                Text(displayName)
                    .font(.headline)
                Spacer()
                Button(action: onToggleFavorite) {
                    Image(systemName: stationWithDistance.station.isFavorite ? "star.fill" : "star")
                        .foregroundColor(stationWithDistance.station.isFavorite ? .yellow : .gray)
                }
            }

            // Second Row: Distance
            if !stationWithDistance.distanceDisplay.isEmpty {
                Text(stationWithDistance.distanceDisplay)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }

            // Third Row: Meteorological
            if let met = stationWithDistance.station.meteorological, met == "y" {
                Text("Meteorological: Yes")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            // Fourth Row: Coordinates
            if let latitude = stationWithDistance.station.latitude,
               let longitude = stationWithDistance.station.longitude {
                Text("Coordinates: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 5)
    }
}
