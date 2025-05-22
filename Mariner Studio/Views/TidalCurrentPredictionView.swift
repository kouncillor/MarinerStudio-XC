import SwiftUI

struct TidalCurrentPredictionView: View {
    // MARK: - Properties
    @StateObject private var viewModel: TidalCurrentPredictionViewModel
    
    // MARK: - Initialization
    init(
        stationId: String,
        bin: Int,
        stationName: String,
        predictionService: TidalCurrentPredictionService = TidalCurrentPredictionServiceImpl(),
        currentStationService: CurrentStationDatabaseService
    ) {
        _viewModel = StateObject(wrappedValue: TidalCurrentPredictionViewModel(
            stationId: stationId,
            bin: bin,
            stationName: stationName,
            predictionService: predictionService,
            currentStationService: currentStationService
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
                
                // Date Selection
                dateSelectionView
                
                // Graph
                TidalCurrentGraphView(
                    predictions: viewModel.allPredictions,
                    selectedTime: viewModel.currentPrediction?.timestamp,
                    stationName: viewModel.stationName
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(.lightGray), lineWidth: 1)
                )
                
                // Current Data
                currentDataView
                
                // Extremes Table
                extremesTableView
                
                // Web View Button
                webViewButton
            }
            .padding()
        }
        .navigationTitle("Current Predictions")
        .withHomeButton()
        
        
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 3)
                            .frame(width: 100, height: 100)
                    )
            }
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
    
    private var currentDataView: some View {
        VStack(spacing: 10) {
            // Station name and favorite button
            HStack {
                Text(viewModel.stationName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
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
            
            // Navigation buttons
            HStack {
                Button(action: {
                    viewModel.previousPrediction()
                }) {
                    Image(systemName: "arrow.left.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(viewModel.canGoBackward ? .red : .gray.opacity(0.5))
                }
                .disabled(!viewModel.canGoBackward)
                
                Spacer()
                
                Button(action: {
                    viewModel.nextPrediction()
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(viewModel.canGoForward ? .green : .gray.opacity(0.5))
                }
                .disabled(!viewModel.canGoForward)
            }
            
            if let prediction = viewModel.currentPrediction {
                // Time
                Text(prediction.formattedTime)
                    .font(.system(size: 36))
                
                // Speed and Flow Direction
                Text("\(prediction.formattedVelocity) kts \(prediction.flowDirection)")
                    .font(.title2)
                
                // Direction
                Text("Direction \(prediction.directionDisplay)")
                    .font(.title3)
            } else {
                Text("No prediction data available")
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
        )
    }
    
    private var extremesTableView: some View {
        VStack(spacing: 10) {
            Text("Today's Currents")
                .font(.headline)
                .padding(.top, 5)
            
            // Header row
            HStack {
                Text("Time")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .frame(width: 80, alignment: .leading)
                
                Text("Event")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text("Speed")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal)
            
            // Divider
            Divider()
            
            // Data rows
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(viewModel.currentExtremes, id: \.id) { extreme in
                        HStack {
                            Text(extreme.time, format: .dateTime.hour().minute())
                                .font(.subheadline)
                                .foregroundColor(extreme.isNextEvent ? .green : (extreme.isMostRecentPast ? .orange : .primary))
                                .frame(width: 80, alignment: .leading)
                            
                            Text(extreme.event)
                                .font(.subheadline)
                                .foregroundColor(extreme.isNextEvent ? .green : (extreme.isMostRecentPast ? .orange : .primary))
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            Text(String(format: "%.1f kts", extreme.speed))
                                .font(.subheadline)
                                .foregroundColor(extreme.isNextEvent ? .green : (extreme.isMostRecentPast ? .orange : .primary))
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        
                        Divider()
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
        )
    }
    
    private var webViewButton: some View {
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
