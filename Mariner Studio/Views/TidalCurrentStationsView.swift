import SwiftUI

struct TidalCurrentStationsView: View {
   // MARK: - Properties
   @StateObject private var viewModel: TidalCurrentStationsViewModel
   @State private var isRefreshing = false
   
   // MARK: - Initialization
   init(
       tidalCurrentService: TidalCurrentService = TidalCurrentServiceImpl(),
       locationService: LocationService = LocationServiceImpl(),
       currentStationService: CurrentStationDatabaseService
   ) {
       _viewModel = StateObject(wrappedValue: TidalCurrentStationsViewModel(
           tidalCurrentService: tidalCurrentService,
           locationService: locationService,
           currentStationService: currentStationService
       ))
   }
   
   // MARK: - Body
   var body: some View {
       VStack(spacing: 0) {
           // Search Bar and Filters
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
                   stationsList
               }
           }
       }
       .navigationTitle("Tidal Current Stations")
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
           .padding(8)
           .background(Color(.systemBackground))
           .cornerRadius(10)
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
   }
   
   private var statusBar: some View {
       HStack {
           Text("Total Stations: \(viewModel.totalStations)")
               .font(.footnote)
           Spacer()
           Text("Location: \(viewModel.isLocationEnabled ? "Enabled" : "Disabled")")
               .font(.footnote)
       }
       .padding(.horizontal)
       .padding(.bottom, 5)
   }
   
   private var stationsList: some View {
       List {
           ForEach(viewModel.stations) { stationWithDistance in
               NavigationLink(destination: TidalCurrentPredictionView(
                   stationId: stationWithDistance.station.id,
                   bin: stationWithDistance.station.currentBin ?? 0,
                   stationName: stationWithDistance.station.name,
                   currentStationService: viewModel.currentStationService
               )) {
                   TidalCurrentStationRow(
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
       .listStyle(PlainListStyle())
       .refreshable {
           await viewModel.refreshStations()
       }
   }
}

struct TidalCurrentStationRow: View {
   let stationWithDistance: StationWithDistance<TidalCurrentStation>
   let onToggleFavorite: () -> Void
   
   var body: some View {
       VStack(alignment: .leading, spacing: 5) {
           HStack {
               Text(stationWithDistance.station.name)
                   .font(.headline)
               Spacer()
               Button(action: onToggleFavorite) {
                   Image(systemName: stationWithDistance.station.isFavorite ? "star.fill" : "star")
                       .foregroundColor(stationWithDistance.station.isFavorite ? .yellow : .gray)
               }
           }
           
           if let state = stationWithDistance.station.state, !state.isEmpty {
               Text(state)
                   .font(.subheadline)
                   .foregroundColor(.gray)
           }
           
           Text("Station ID: \(stationWithDistance.station.id)")
               .font(.caption)
               .foregroundColor(.gray)
           
           // Fixed line handling optional latitude and longitude
           if let latitude = stationWithDistance.station.latitude,
              let longitude = stationWithDistance.station.longitude {
               Text("Lat: \(String(format: "%.4f", latitude)), Long: \(String(format: "%.4f", longitude))")
                   .font(.caption)
           }
           
           if !stationWithDistance.distanceDisplay.isEmpty {
               Text("Distance: \(stationWithDistance.distanceDisplay)")
                   .font(.caption)
                   .foregroundColor(.gray)
           }
       }
       .padding(.vertical, 5)
   }
}
