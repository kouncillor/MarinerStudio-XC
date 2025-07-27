
import SwiftUI

struct TidalHeightPredictionView: View {
    // MARK: - Properties
    @StateObject private var viewModel: TidalHeightPredictionViewModel
    
    // MARK: - Initialization
    init(
        stationId: String,
        stationName: String,
        latitude: Double?,
        longitude: Double?,
        predictionService: TidalHeightPredictionService = TidalHeightPredictionServiceImpl(),
        tideFavoritesCloudService: TideFavoritesCloudService
    ) {
        _viewModel = StateObject(wrappedValue: TidalHeightPredictionViewModel(
            stationId: stationId,
            stationName: stationName,
            latitude: latitude,
            longitude: longitude,
            predictionService: predictionService,
            tideFavoritesCloudService: tideFavoritesCloudService
        ))
    }
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Error message
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Date selection
                dateSelectionView
                
                // Predictions data
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                } else {
                    stationDataView
                    
                    predictionsListView
                    
                    viewStationWebsiteButton
                }
            }
            .padding()
        }
        .navigationTitle("Tide Predictions")
        .withHomeButton()
        
        
        
        .task {
            await viewModel.loadPredictions()
        }
    }
    
    // MARK: - View Components
    private var dateSelectionView: some View {
        HStack {
            Button(action: {
                Task {
                    await viewModel.previousDay()
                }
            }) {
                Image(systemName: "arrow.left.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            Text(viewModel.formattedSelectedDate)
                .font(.title2)
            
            Spacer()
            
            Button(action: {
                Task {
                    await viewModel.nextDay()
                }
            }) {
                Image(systemName: "arrow.right.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal)
    }
    
    private var stationDataView: some View {
        VStack {
            HStack {
                Text(viewModel.stationName)
                    .font(.title)
                    .bold()
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await viewModel.toggleFavorite()
                    }
                }) {
                    Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(viewModel.isFavorite ? .yellow : .gray)
                }
            }
            
            if !viewModel.predictions.isEmpty {
                Text("Station ID: \(viewModel.stationId)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var predictionsListView: some View {
        VStack(spacing: 0) {
            if viewModel.predictions.isEmpty {
                Text("No predictions available for this date")
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(viewModel.predictions) { prediction in
                    HStack {
                        Text(prediction.formattedTime)
                            .font(.headline)
                            .frame(width: 80, alignment: .leading)
                        
                        Text(prediction.tideType)
                            .font(.subheadline)
                            .foregroundColor(prediction.type == "H" ? .blue : .red)
                            .frame(width: 60, alignment: .center)
                        
                        Spacer()
                        
                        Text("\(prediction.formattedHeight) ft")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    
                    if prediction.id != viewModel.predictions.last?.id {
                        Divider()
                    }
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var viewStationWebsiteButton: some View {
        Button(action: {
            viewModel.viewStationWebsite()
        }) {
            HStack {
                Image(systemName: "globe")
                Text("View Station on NOAA Website")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
        }
    }
}
