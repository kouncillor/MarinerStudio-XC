import SwiftUI

// A more performant version of TidalCurrentGraphView
struct TidalCurrentGraphView: View {
    // MARK: - Properties
    let predictions: [TidalCurrentPrediction]
    let selectedTime: Date?
    let stationName: String

    // MARK: - Computed Properties
    private var maxVelocity: Double {
        // Cache the max velocity calculation
        let maxValue = predictions.map { abs($0.speed) }.max() ?? 3.0
        return ceil(maxValue)
    }

    private var sortedPredictions: [TidalCurrentPrediction] {
        // Sort predictions once, not in every subview
        return predictions.sorted { $0.timestamp < $1.timestamp }
    }

    private var startOfDay: Date? {
        guard let firstPrediction = sortedPredictions.first else { return nil }
        return Calendar.current.startOfDay(for: firstPrediction.timestamp)
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 10) {
            // Title
            if !stationName.isEmpty {
                Text(stationName)
                    .font(.headline)
                    .padding(.top, 5)
            }

            if predictions.isEmpty {
                Text("No data available")
                    .foregroundColor(.gray)
                    .frame(height: 250)
            } else {
                // Graph drawing - use efficient drawing with pre-cached values
                GraphContent(
                    predictions: sortedPredictions,
                    maxVelocity: maxVelocity,
                    selectedTime: selectedTime,
                    startOfDay: startOfDay ?? Date()
                )
                .frame(height: 250)

                // Legend
                HStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: 12, height: 4)
                            Text("Flood")
                                .font(.caption)
                        }

                        HStack {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 12, height: 4)
                            Text("Ebb")
                                .font(.caption)
                        }
                    }
                    .padding(.trailing, 20)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// Extract core graph content to a separate struct to improve performance
struct GraphContent: View {
    let predictions: [TidalCurrentPrediction]
    let maxVelocity: Double
    let selectedTime: Date?
    let startOfDay: Date

    // TimeInterval constants to avoid recalculation
    private let hoursInDay: Int = 24
    private let minutesInDay: Double = 24 * 60

    // Coordinate transformations
    private func xPosition(for date: Date, in width: CGFloat) -> CGFloat {
        // Calculate minutes since midnight
        let minutes = date.timeIntervalSince(startOfDay) / 60

        // Scale to view width (avoid division in the render loop)
        return CGFloat(minutes / minutesInDay) * width
    }

    private func yPosition(for velocity: Double, in height: CGFloat) -> CGFloat {
        // Center line is at height/2
        // Positive velocity (flood) goes upward from center
        // Negative velocity (ebb) goes downward from center
        let centerY = height / 2
        let scale = (height / 2) / CGFloat(maxVelocity)

        return centerY - (CGFloat(velocity) * scale)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background, grid and core elements
                GraphBackground(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    maxVelocity: maxVelocity,
                    startOfDay: startOfDay,
                    hoursInDay: hoursInDay,
                    xPositionCalculator: { date in
                        self.xPosition(for: date, in: geometry.size.width)
                    },
                    yPositionCalculator: { velocity in
                        self.yPosition(for: velocity, in: geometry.size.height)
                    }
                )

                // Current Curve - most performance-intensive part
                CurrentCurve(
                    predictions: predictions,
                    width: geometry.size.width,
                    height: geometry.size.height,
                    maxVelocity: maxVelocity,
                    startOfDay: startOfDay,
                    minutesInDay: minutesInDay
                )

                // Selected Time Marker - only draw when needed
                if let selectedTime = selectedTime {
                    let x = xPosition(for: selectedTime, in: geometry.size.width)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
            }
        }
    }
}

// Separate the background grid to avoid redrawing it unnecessarily
struct GraphBackground: View {
    let width: CGFloat
    let height: CGFloat
    let maxVelocity: Double
    let startOfDay: Date
    let hoursInDay: Int
    let xPositionCalculator: (Date) -> CGFloat
    let yPositionCalculator: (Double) -> CGFloat

    var body: some View {
        ZStack {
            // White background
            Rectangle()
                .fill(Color.white)

            // Horizontal grid lines for velocity
            HorizontalGridLines(
                maxVelocity: maxVelocity,
                width: width,
                yPositionCalculator: yPositionCalculator
            )

            // Vertical grid lines for time
            VerticalGridLines(
                hoursInDay: hoursInDay,
                startOfDay: startOfDay,
                height: height,
                xPositionCalculator: xPositionCalculator
            )

            // Add time labels
            TimeLabels(
                hoursInDay: hoursInDay,
                startOfDay: startOfDay,
                height: height,
                xPositionCalculator: xPositionCalculator
            )

            // Add velocity scale
            VelocityScale(
                maxVelocity: maxVelocity,
                yPositionCalculator: yPositionCalculator
            )
        }
    }
}

// Split the horizontal grid lines into their own component
struct HorizontalGridLines: View {
    let maxVelocity: Double
    let width: CGFloat
    let yPositionCalculator: (Double) -> CGFloat

    var body: some View {
        ZStack {
            ForEach(-Int(maxVelocity)...Int(maxVelocity), id: \.self) { value in
                if value == 0 {
                    // Center line (zero velocity)
                    Path { path in
                        let y = yPositionCalculator(Double(value))
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.black, lineWidth: 1.5)
                } else if value % 1 == 0 { // Only draw lines at whole numbers
                    Path { path in
                        let y = yPositionCalculator(Double(value))
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                }
            }
        }
    }
}

// Split the vertical grid lines into their own component
struct VerticalGridLines: View {
    let hoursInDay: Int
    let startOfDay: Date
    let height: CGFloat
    let xPositionCalculator: (Date) -> CGFloat

    var body: some View {
        ZStack {
            ForEach(0...hoursInDay, id: \.self) { hour in
                Path { path in
                    let calendar = Calendar.current
                    let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) ?? Date()
                    let x = xPositionCalculator(hourDate)

                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            }
        }
    }
}

// Time labels component
struct TimeLabels: View {
    let hoursInDay: Int
    let startOfDay: Date
    let height: CGFloat
    let xPositionCalculator: (Date) -> CGFloat
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        ZStack {
            ForEach(0...hoursInDay/3, id: \.self) { index in
                let hour = index * 3 // Every 3 hours
                let calendar = Calendar.current
                let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) ?? Date()

                Text(timeFormatter.string(from: hourDate))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .position(
                        x: xPositionCalculator(hourDate),
                        y: height + 12
                    )
            }
        }
    }
}

// Velocity scale component
struct VelocityScale: View {
    let maxVelocity: Double
    let yPositionCalculator: (Double) -> CGFloat

    var body: some View {
        ZStack {
            // Add velocity labels
            ForEach(-Int(maxVelocity)...Int(maxVelocity), id: \.self) { value in
                if value % 1 == 0 { // Only add labels at whole numbers
                    Text("\(value)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .position(
                            x: -12,
                            y: yPositionCalculator(Double(value))
                        )
                }
            }
        }
    }
}

// Optimize the curve drawing
struct CurrentCurve: View {
    let predictions: [TidalCurrentPrediction]
    let width: CGFloat
    let height: CGFloat
    let maxVelocity: Double
    let startOfDay: Date
    let minutesInDay: Double

    // Pre-compute values for better performance
    private var centerY: CGFloat {
        return height / 2
    }

    private var velocityScale: CGFloat {
        return (height / 2) / CGFloat(maxVelocity)
    }

    // Optimized position calculation
    private func position(for prediction: TidalCurrentPrediction) -> CGPoint {
        // X position - calculate minutes since midnight
        let minutes = prediction.timestamp.timeIntervalSince(startOfDay) / 60
        let x = CGFloat(minutes / minutesInDay) * width

        // Y position - scale velocity to view height
        let y = centerY - (CGFloat(prediction.speed) * velocityScale)

        return CGPoint(x: x, y: y)
    }

    var body: some View {
        // Use a single Path for better performance
        Path { path in
            guard !predictions.isEmpty else { return }

            let points = predictions.map { position(for: $0) }

            // Move to first point
            path.move(to: points[0])

            // Connect the rest of the points
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
        }
        .stroke(
            LinearGradient(
                gradient: Gradient(colors: [.red, .red, .green, .green]),
                startPoint: .bottom,
                endPoint: .top
            ),
            lineWidth: 2
        )
    }
}

#Preview {
    // Create some mock data for the preview
    let now = Date()
    let calendar = Calendar.current
    let mockPredictions: [TidalCurrentPrediction] = (0..<24).map { hour in
        let time = calendar.date(byAdding: .hour, value: hour, to: now)!
        // Create a sine wave pattern
        let speed = 3 * sin(Double(hour) * .pi / 6) // Period of 12 hours

        return TidalCurrentPrediction(
            regularSpeed: speed,
            velocityMajor: speed,
            bin: 1,
            timeString: time.formatted(),
            direction: 45,
            meanFloodDirection: 45,
            meanEbbDirection: 225,
            depth: 10,
            type: speed > 0 ? "flood" : "ebb"
        )
    }

    return TidalCurrentGraphView(
        predictions: mockPredictions,
        selectedTime: now,
        stationName: "Sample Station"
    )
}
