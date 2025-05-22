
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
     //  .navigationTitle("Tidal Current Stations")
       .withHomeButton()
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
   
   private var stationsList: some View {
       List {
           ForEach(viewModel.stations, id: \.station.uniqueId) { stationWithDistance in
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
                               await viewModel.toggleStationFavorite(
                                   stationId: stationWithDistance.station.id,
                                   bin: stationWithDistance.station.currentBin
                               )
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
   
   // Define color palette
   private let stationNameColor = Color(.sRGB, red: 0.0, green: 0.2, blue: 0.4, opacity: 1.0) // Deep Navy Blue
   private let stateColor = Color(.sRGB, red: 0.4, green: 0.45, blue: 0.5, opacity: 1.0) // Slate Gray
   private let depthColor = Color(.sRGB, red: 0.0, green: 0.5, blue: 0.5, opacity: 1.0) // Teal
   private let distanceColor = Color(.sRGB, red: 0.9, green: 0.6, blue: 0.0, opacity: 1.0) // Amber
   
   var body: some View {
       VStack(alignment: .leading, spacing: 5) {
           HStack {
               Text(stationWithDistance.station.name)
                   .font(.title)
                   .fontWeight(.medium)
                   .foregroundColor(stationNameColor)
               Spacer()
               Button(action: onToggleFavorite) {
                   Image(systemName: stationWithDistance.station.isFavorite ? "star.fill" : "star")
                       .foregroundColor(stationWithDistance.station.isFavorite ? .yellow : .gray)
               }
           }
           
           if let state = stationWithDistance.station.state, !state.isEmpty {
               Text(state)
                   .font(.subheadline)
                   .foregroundColor(stateColor)
           }
           
           // Show depth information with the new teal color
           if let depth = stationWithDistance.station.depth {
               Text("Depth: \(String(format: "%.1f", depth)) ft")
                   .font(.headline)
                   .foregroundColor(depthColor)
           }
           
           if !stationWithDistance.distanceDisplay.isEmpty {
               Text("Distance: \(stationWithDistance.distanceDisplay)")
                   .font(.headline)
                   .foregroundColor(distanceColor)
           }
       }
       .padding(.vertical, 5)
   }
}
