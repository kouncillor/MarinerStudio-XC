
import SwiftUI

struct RouteDetailsView: View {
    @ObservedObject var viewModel: RouteDetailsViewModel
    @State private var scrollToWaypointIndex: Int?
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
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 1)
                            .padding(.horizontal)
                            
                            // Route Conditions Summary Frame
                            VStack(alignment: .center, spacing: 5) {
                                Text("Route Conditions Summary")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                    .multilineTextAlignment(.center)
                                    .padding(.bottom, 5)
                                
                                // Conditions list
                                VStack(spacing: 12) {
                                    ConditionSummaryRow(text: viewModel.maxWindSpeed) {
                                        scrollToWaypoint(viewModel.maxWindWaypoint)
                                    }
                                    
                                    Divider()
                                    
                                    ConditionSummaryRow(text: viewModel.maxWaveHeight) {
                                        scrollToWaypoint(viewModel.maxWaveWaypoint)
                                    }
                                    
                                    Divider()
                                    
                                    ConditionSummaryRow(text: viewModel.maxHumidity) {
                                        scrollToWaypoint(viewModel.maxHumidityWaypoint)
                                    }
                                    
                                    Divider()
                                    
                                    ConditionSummaryRow(text: viewModel.lowestVisibility) {
                                        scrollToWaypoint(viewModel.minVisibilityWaypoint)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 1)
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 10)
                    }
                    
                    // Waypoints Collection
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(Array(viewModel.waypoints.enumerated()), id: \.element.id) { index, waypoint in
                                WaypointView(waypoint: waypoint)
                                    .id(index) // Use index as the identifier for scrolling
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                    .onChange(of: scrollToWaypointIndex) { _, index in
                        if let index = index {
                            withAnimation {
                                scrollToIndex(index)
                            }
                            // Reset after scrolling
                            scrollToWaypointIndex = nil
                        }
                    }
                }
                
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
        // Convert to 0-based index
        scrollToWaypointIndex = waypoint.index - 1
        
        // If summary is visible, hide it to make more room for the waypoint details
        if viewModel.isSummaryVisible {
            viewModel.toggleSummary()
        }
    }
    
    // Helper function to scroll to a specific index
    private func scrollToIndex(_ index: Int) {
        // This relies on having set the id of each item in the list
        // The actual scrolling is triggered by the onChange handler
    }
}

// Helper Views

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
                VStack(spacing: 10) {
                    HStack {
                        // Swell - Now placed side by side with Wind Wave
                        MarineDataBox(
                            title: "Swell",
                            value1: waypoint.swellHeightDisplay,
                            value2: "From: \(waypoint.swellDirectionCardinal)",
                            value3: "\(Int(waypoint.swellPeriod))s period"
                        
                        )
                        
                        // Wind Wave - Now placed side by side with Swell
                        MarineDataBox(
                            title: "Wind Wave",
                            value1: waypoint.windWaveHeightDisplay,
                            value2: "From: \(waypoint.windWaveDirectionCardinal)",
                            value3: "."
                        )
                    }
                    
                    // Total Wave - Now placed below Swell and Wind Wave
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Total Wave")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Height")
                                    .font(.caption)
                                Text(waypoint.waveHeightDisplay)
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("Direction")
                                    .font(.caption)
                                Text(waypoint.waveDirectionCardinal)
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("Period")
                                    .font(.caption)
                                Text("\(Int(waypoint.wavePeriod))s")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Modified HStack to use all available space
                    HStack(spacing: 10) {
                        // Course and wave directions with compass background
                        ZStack {
                            // Compass background
                            Image("compasscard")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            
                            // Text overlay
                            VStack(alignment: .center, spacing: 5) {
                                Text("Course True: \(waypoint.courseDisplay)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("Wave True: \(waypoint.waveDisplay)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("Wave Relative: \(waypoint.relativeWaveDisplay)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(6)
                        }
                        .background(Color.white)
                        .cornerRadius(8)
                        .frame(minWidth: 0, maxWidth: .infinity)  // Take up available width
                        .aspectRatio(1, contentMode: .fit)  // Make height proportional to width
                        
                        // Wave direction arrow
                        RelativeWaveDirectionView(waypoint: waypoint)
                            .background(Color.white)
                            .cornerRadius(8)
                            .frame(minWidth: 0, maxWidth: .infinity)  // Take up available width
                            .aspectRatio(1, contentMode: .fit)  // Make height proportional to width
                    }
                    .frame(maxWidth: .infinity)  // Make the HStack use all available width
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
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

struct MarineDataBox: View {
    let title: String
    let value1: String
    let value2: String
    let value3: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
            
            Text(value1)
                .font(.subheadline)
            
            Text(value2)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !value3.isEmpty {
                Text(value3)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct RelativeWaveDirectionView: View {
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
