

import SwiftUI
import MapKit

struct WeatherMapView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @StateObject private var viewModel = WeatherMapViewModel()
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $viewModel.region,
                showsUserLocation: true,
                userTrackingMode: $viewModel.userTrackingMode)
                .edgesIgnoringSafeArea(.all)
            
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
        .onAppear {
            viewModel.initialize(with: serviceProvider.locationService)
        }
    }
}

#Preview {
    NavigationView {
        WeatherMapView()
            .environmentObject(ServiceProvider())
    }
}
