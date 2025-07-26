
import SwiftUI
import MapKit

struct WeatherMapView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @StateObject private var viewModel = WeatherMapViewModel()
    
    // State variables for managing selected location and navigation
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showWeatherDetail = false
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $viewModel.region,
                showsUserLocation: true,
                userTrackingMode: $viewModel.userTrackingMode)
                .edgesIgnoringSafeArea(.all)
                // Add a long press gesture to the map
                .gesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                        .onEnded { value in
                            switch value {
                            case .second(true, let drag):
                                if let drag = drag {
                                    // Get the location of the long press
                                    let location = MapHelpers.convertPointToCoordinate(
                                        point: drag.location,
                                        in: viewModel.region
                                    )
                                    
                                    // Store the location and trigger the sheet presentation
                                    selectedLocation = location
                                    showWeatherDetail = true
                                    
                                    // Provide haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                            default:
                                break
                            }
                        }
                )
            
            // Location button in the bottom-right corner
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.centerOnUserLocation()
                    }) {
                        Image(systemName: "location.fill")
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .padding()
                }
            }
            
            // Long press hint overlay (only shown initially)
            VStack {
                Text("Long press on map to check weather at that location")
                    .font(.caption)
                    .padding(8)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .shadow(radius: 1)
                    .padding(.top, 8)
                Spacer()
            }
            
            // Error message display
            if !viewModel.errorMessage.isEmpty {
                VStack {
                    Text(viewModel.errorMessage)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                    Spacer()
                }
            }
            
            // Loading indicator
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Weather Map")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(red: 0.53, green: 0.81, blue: 0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .withHomeButton()
        .onAppear {
            viewModel.initialize(with: serviceProvider.locationService)
        }
        // Add NavigationLink to show the weather detail view when a location is selected
        .background(
            NavigationLink(
                destination: Group {
                    if let location = selectedLocation {
                        CurrentLocalWeatherViewForMap(
                            latitude: location.latitude,
                            longitude: location.longitude
                        )
                    }
                },
                isActive: $showWeatherDetail,
                label: { EmptyView() }
            )
        )
    }
}

// Helper struct to convert screen coordinates to map coordinates
struct MapHelpers {
    static func convertPointToCoordinate(point: CGPoint, in region: MKCoordinateRegion) -> CLLocationCoordinate2D {
        // Calculate the map size in degrees
        let mapSizeInDegrees = region.span
        
        // Calculate relative position of tap point from center of screen (-0.5 to 0.5)
        let relativeTapPoint = CGPoint(
            x: (point.x / UIScreen.main.bounds.width) - 0.5,
            y: (point.y / UIScreen.main.bounds.height) - 0.5
        )
        
        // Convert relative position to degrees
        let latitudeDelta = relativeTapPoint.y * mapSizeInDegrees.latitudeDelta
        let longitudeDelta = relativeTapPoint.x * mapSizeInDegrees.longitudeDelta
        
        // Calculate actual lat/long by adding the delta to the center
        return CLLocationCoordinate2D(
            latitude: region.center.latitude - latitudeDelta,
            longitude: region.center.longitude + longitudeDelta
        )
    }
}

#Preview {
    NavigationView {
        WeatherMapView()
            .environmentObject(ServiceProvider())
    }
}
