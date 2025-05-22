import SwiftUI

struct TidalHeightPredictionView: View {
    // MARK: - Properties
    @StateObject private var viewModel: TidalHeightPredictionViewModel
    
    // MARK: - Initialization
    init(
        stationId: String,
        stationName: String,
        predictionService: TidalHeightPredictionService = TidalHeightPredictionServiceImpl(),
        tideStationService: TideStationDatabaseService
    ) {
        _viewModel = StateObject(wrappedValue: TidalHeightPredictionViewModel(
            stationId: stationId,
            stationName: stationName,
            predictionService: predictionService,
            tideStationService: tideStationService
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
            .padding(.bottom, 5)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.gray.opacity(0.3), radius: 5, x: 0, y: 2)
        )
    }
    
    private var predictionsListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.predictions.isEmpty && !viewModel.isLoading {
                Text("No predictions available for this date")
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.predictions) { prediction in
                    HStack {
                        Text(prediction.formattedTime)
                            .font(.body)
                            .frame(width: 80, alignment: .leading)
                        
                        Spacer()
                        
                        Text(prediction.tideType)
                            .font(.body)
                        
                        Spacer()
                        
                        Text(String(format: "%.2f ft", prediction.height))
                            .font(.body)
                            .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.gray.opacity(0.3), radius: 5, x: 0, y: 2)
        )
    }
    
    private var viewStationWebsiteButton: some View {
        Button(action: {
            viewModel.viewStationWebsite()
        }) {
            Text("View Station Website")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(10)
        }
    }
}
