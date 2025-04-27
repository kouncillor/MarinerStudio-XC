// TidalCurrentGraphView.swift

import SwiftUI
import Charts

struct TidalCurrentGraphView: View {
    let predictions: [TidalCurrentPrediction]
    let selectedTime: Date?
    let stationName: String
    
    // Computed properties for chart data
    private var maxVelocity: Double {
        let maxSpeed = predictions.map { abs($0.speed) }.max() ?? 3.0
        return ceil(maxSpeed)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Station name at the top
            if !stationName.isEmpty {
                Text(stationName)
                    .font(.headline)
                    .padding(.top, 8)
            }
            
            if predictions.isEmpty {
                // No data message
                Text("No Data Available")
                    .foregroundColor(.gray)
                    .frame(height: 250)
            } else {
                // Chart
                Chart {
                    // Base line at zero
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(.black.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    // Current velocity line
                    LineMark(
                        x: .value("Time", predictions.map { $0.timestamp }),
                        y: .value("Speed", predictions.map { $0.speed })
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    // Selected time marker
                    if let selectedTime = selectedTime {
                        RuleMark(x: .value("Selected Time", selectedTime))
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartYScale(domain: -maxVelocity...maxVelocity)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let speedValue = value.as(Double.self) {
                                Text("\(speedValue, specifier: "%.1f")")
                            }
                        }
                    }
                }
                .frame(height: 250)
                
                // Legend
                HStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            Text("Flood")
                                .font(.caption)
                        }
                        
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text("Ebb")
                                .font(.caption)
                        }
                    }
                    .padding(.trailing, 20)
                }
            }
        }
        .padding(10)
        .background(Color.white)
    }
}
