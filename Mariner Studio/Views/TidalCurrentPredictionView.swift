// TidalCurrentPredictionView.swift

import SwiftUI

struct TidalCurrentPredictionView: View {
    // MARK: - Properties
    @StateObject private var viewModel: TidalCurrentPredictionViewModel
    let stationId: String
    let bin: Int
    let stationName: String
    
    // MARK: - Initialization
    init(
        stationId: String,
        bin: Int,
        stationName: String,
        predictionService: TidalCurrentPredictionService,
        databaseService: DatabaseService
    ) {
        self.stationId = stationId
        self.bin = bin
        self.stationName = stationName
        _viewModel = StateObject(wrappedValue: TidalCurrentPredictionViewModel(
            predictionService: predictionService,
            databaseService: databaseService
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
                dateSelector
                
                // Graph
                graphView
                
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
        .task {
            await viewModel.initialize(stationId: stationId, bin: bin, stationName: stationName)
        }
    }
    
    // MARK: - View Components
    private var dateSelector: some View {
        HStack {
            Button(action: {
                Task {
                    await viewModel.previousDay()
                }
            }) {
                Image(systemName: "arrow.left")
                    .frame(width: 44, height: 44)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            Text(viewModel.selectedDate, format: .dateTime.day().month())
                .font(.title2)
            
            Spacer()
            
            Button(action: {
                Task {
                    await viewModel.nextDay()
                }
            }) {
                Image(systemName: "arrow.right")
                    .frame(width: 44, height: 44)
                    .foregroundColor(.green)
            }
        }
    }
    
    private var graphView: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 300)
            } else {
                TidalCurrentGraphView(
                    predictions: viewModel.allPredictions,
                    selectedTime: viewModel.currentPrediction?.timestamp,
                    stationName: viewModel.stationName
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
    }
    
    private var currentDataView: some View {
        VStack(spacing: 10) {
            // Station name and favorite button
            HStack {
                Text(viewModel.stationName)
                    .font(.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await viewModel.toggleFavorite()
                    }
                }) {
                    Image(systemName: viewModel.favoriteIcon)
                        .font(.title2)
                        .foregroundColor(viewModel.favoriteIcon == "star.fill" ? .yellow : .gray)
                }
                .frame(width: 44, height: 44)
            }
            
            // Navigation buttons
            HStack {
                Button(action: {
                    viewModel.previousPrediction()
                }) {
                    Image(systemName: "arrow.left")
                        .frame(width: 44, height: 44)
                        .foregroundColor(viewModel.canGoBackward ? .red : .gray.opacity(0.5))
                }
                .disabled(!viewModel.canGoBackward)
                
                Spacer()
                
                Button(action: {
                    viewModel.nextPrediction()
                }) {
                    Image(systemName: "arrow.right")
                        .frame(width: 44, height: 44)
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
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
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
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
    }
    
    private var webViewButton: some View {
        NavigationLink(destination: TidalCurrentStationWebView(
            stationId: stationId,
            bin: bin,
            stationName: stationName
        )) {
            Text("View Station Website")
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue)
                )
                .foregroundColor(.white)
        }
    }
}
