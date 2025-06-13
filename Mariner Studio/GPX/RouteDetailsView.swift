
import SwiftUI

struct RouteDetailsView: View {
    @ObservedObject var viewModel: RouteDetailsViewModel
    @State private var scrollToWaypointIndex: Int?
    @State private var emphasizedWaypointIndex: Int?
    @EnvironmentObject var serviceProvider: ServiceProvider
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Top Section (Summary)
                    if viewModel.isSummaryVisible {
                        VStack(spacing: 10) {
                            // Route Summary Frame
                            VStack(alignment: .center, spacing: 5) {
                                Text(viewModel.routeName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                    .multilineTextAlignment(.center)
                                    .padding(.bottom, 5)
                                
                                // Route details grid
                                VStack(spacing: 10) {
                                    RouteDetailRow(label: "Departure:", value: viewModel.departureTime)
                                    RouteDetailRow(label: "Arrival:", value: viewModel.arrivalTime)
                                    RouteDetailRow(label: "Total Distance:", value: viewModel.totalDistance)
                                    RouteDetailRow(label: "Average Speed:", value: viewModel.averageSpeed)
                                    RouteDetailRow(label: "Duration:", value: viewModel.duration)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            
                            // Condition Summary
                            VStack(spacing: 8) {
                                ConditionSummaryRow(
                                    text: "Max Wind Speed: \(viewModel.maxWindSpeed) at \(viewModel.maxWindWaypoint?.name ?? "Unknown")",
                                    action: { scrollToWaypoint(viewModel.maxWindWaypoint) }
                                )
                                
                                ConditionSummaryRow(
                                    text: "Max Wave Height: \(viewModel.maxWaveHeight) at \(viewModel.maxWaveWaypoint?.name ?? "Unknown")",
                                    action: { scrollToWaypoint(viewModel.maxWaveWaypoint) }
                                )
                                
                                ConditionSummaryRow(
                                    text: "Max Humidity: \(viewModel.maxHumidity) at \(viewModel.maxHumidityWaypoint?.name ?? "Unknown")",
                                    action: { scrollToWaypoint(viewModel.maxHumidityWaypoint) }
                                )
                                
                                ConditionSummaryRow(
                                    text: "Lowest Visibility: \(viewModel.lowestVisibility) at \(viewModel.minVisibilityWaypoint?.name ?? "Unknown")",
                                    action: { scrollToWaypoint(viewModel.minVisibilityWaypoint) }
                                )
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    
                    // Waypoints List with ScrollViewReader
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.waypoints, id: \.index) { waypoint in
                                    WaypointView(waypoint: waypoint)
                                        .id(waypoint.index) // Set ID for scrolling
                                        .modifier(WaypointEmphasisModifier(
                                            isEmphasized: emphasizedWaypointIndex == waypoint.index
                                        ))
                                }
                            }
                            .padding(.horizontal)
                        }
                        .onChange(of: scrollToWaypointIndex) { _, newIndex in
                            if let index = newIndex {
                                // Animate scroll to center the waypoint
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    proxy.scrollTo(index, anchor: .center)
                                }
                                
                                // Add emphasis after scroll completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        emphasizedWaypointIndex = index
                                    }
                                    
                                    // Remove emphasis after 2.5 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            emphasizedWaypointIndex = nil
                                        }
                                    }
                                }
                                
                                // Reset scroll index
                                scrollToWaypointIndex = nil
                            }
                        }
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                // Loading and Error overlays
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(width: 100, height: 100)
                        .background(Color(UIColor.systemBackground).opacity(0.8))
                        .cornerRadius(10)
                }
                
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }
        }
        .navigationTitle("Route Details")
        .withHomeButton()
        .navigationBarItems(trailing:
            Button(action: {
                viewModel.toggleSummary()
            }) {
                Image(systemName: viewModel.isSummaryVisible ? "chevron.up" : "chevron.down")
            }
        )
    }
    
    private func scrollToWaypoint(_ waypoint: WaypointItem?) {
        guard let waypoint = waypoint else { return }
        
        // Set the target waypoint index for scrolling
        scrollToWaypointIndex = waypoint.index
        
        // If summary is visible, hide it to make more room for the waypoint details
        if viewModel.isSummaryVisible {
            viewModel.toggleSummary()
        }
    }
}

// MARK: - Waypoint Emphasis Modifier
struct WaypointEmphasisModifier: ViewModifier {
    let isEmphasized: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isEmphasized ? 1.02 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEmphasized ? Color.orange.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isEmphasized ? Color.orange : Color.clear, lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.3), value: isEmphasized)
    }
}

// MARK: - Helper Views
struct RouteDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct ConditionSummaryRow: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .contentShape(Rectangle())
        }
    }
}

struct WaypointView: View {
    @ObservedObject var waypoint: WaypointItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("#\(waypoint.index)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(waypoint.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(formatDate(waypoint.eta))
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            // Weather condition
            if waypoint.weatherDataAvailable {
                HStack {
                    Image(waypoint.weatherIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                    
                    Text(waypoint.weatherCondition)
                        .font(.body)
                    
                    Spacer()
                    
                    Text(waypoint.visibilityDisplay)
                        .font(.caption)
                }
                .padding(.vertical, 5)
                
                // Weather data
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(waypoint.temperatureDisplay)
                            .font(.headline)
                        Text(waypoint.dewPointDisplay + " DP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(waypoint.humidityDisplay + " RH")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("Wind: " + waypoint.windSpeedDisplay)
                            .font(.subheadline)
                        Text("from " + waypoint.windDirection)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Gusts: " + waypoint.windGustsDisplay)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("Weather data not available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 5)
            }
            
            // Marine data
            if waypoint.marineDataAvailable {
                VStack(spacing: 12) {
                    // Total Wave Card - Most prominent at top
                    TotalWaveCard(
                        height: waypoint.waveHeightDisplay,
                        direction: waypoint.waveDirectionCardinal,
                        period: "\(Int(waypoint.wavePeriod))s period"
                    )
                    
                    // Swell Card
                    MarineDataCard(
                        title: "Swell",
                        icon: "water.waves",
                        height: waypoint.swellHeightDisplay,
                        direction: waypoint.swellDirectionCardinal,
                        period: "\(Int(waypoint.swellPeriod))s period",
                        cardColor: Color.cyan.opacity(0.1),
                        accentColor: Color.cyan
                    )
                    
                    // Wind Wave Card
                    MarineDataCard(
                        title: "Wind Wave",
                        icon: "wind",
                        height: waypoint.windWaveHeightDisplay,
                        direction: waypoint.windWaveDirectionCardinal,
                        period: nil,
                        cardColor: Color.blue.opacity(0.1),
                        accentColor: Color.blue
                    )
                    
                    // Wave Direction Compass - Integrated better
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "location.north.circle")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Wave Direction")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        WaveDirectionCompass(waypoint: waypoint)
                            .frame(width: 100, height: 100)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(12)
                }
            } else {
                Text("Marine data not available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 5)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Marine Data Cards
struct TotalWaveCard: View {
    let height: String
    let direction: String
    let period: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with title and icon
            HStack {
                Image(systemName: "waveform.path")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Total Wave Height")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Main content
            HStack(spacing: 16) {
                // Height - Primary value
                VStack(alignment: .leading, spacing: 4) {
                    Text("Height")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(height)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Direction and Period
                VStack(alignment: .trailing, spacing: 8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.north")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Text("From \(direction)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Text(period)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
        )
        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct MarineDataCard: View {
    let title: String
    let icon: String
    let height: String
    let direction: String
    let period: String?
    let cardColor: Color
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon section
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(accentColor)
                    .frame(width: 30, height: 30)
            }
            
            // Content section
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Height (main value)
                Text(height)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(accentColor)
                
                // Direction
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("From \(direction)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Period (if available)
                if let period = period {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(period)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(cardColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct WaveDirectionCompass: View {
    @ObservedObject var waypoint: WaypointItem
    
    var body: some View {
        ZStack {
            // Compass background
            Image("compasscard")
                .resizable()
                .aspectRatio(contentMode: .fit)
            
            // Wave direction arrow
            Image(getWaveDirectionImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(0.6)
        }
    }
    
    private func getWaveDirectionImage() -> String {
        if waypoint.displayImageOne { return "wavefromzero" }
        else if waypoint.displayImageTwo { return "wavefromtwentytwofive" }
        else if waypoint.displayImageThree { return "wavefromfortyfive" }
        else if waypoint.displayImageFour { return "wavefromsixtysevenfive" }
        else if waypoint.displayImageFive { return "wavefromninety" }
        else if waypoint.displayImageSix { return "wavefromonetwelvepointfive" }
        else if waypoint.displayImageSeven { return "wavefromonethirtyfive" }
        else if waypoint.displayImageEight { return "wavefromonefiftysevenfive" }
        else if waypoint.displayImageNine { return "wavefromoneeighty" }
        else if waypoint.displayImageTen { return "wavefromtwohundredtwofive" }
        else if waypoint.displayImageEleven { return "wavefromtwotwentyfive" }
        else if waypoint.displayImageTwelve { return "wavefromtwofortysevenfive" }
        else if waypoint.displayImageThirteen { return "wavefromtwoseventy" }
        else if waypoint.displayImageFourteen { return "wavefromtwoninetytwofive" }
        else if waypoint.displayImageFifteen { return "wavefromthreefifteen" }
        else if waypoint.displayImageSixteen { return "wavefromthreethirtysevenfive" }
        else { return "wavefromzero" } // Default
    }
}
