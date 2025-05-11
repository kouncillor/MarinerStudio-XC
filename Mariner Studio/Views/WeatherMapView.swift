import SwiftUI
import MapKit

struct WeatherMapView: View {
    @StateObject private var viewModel = WeatherMapViewModel()
    
    var body: some View {
        Map()
            .edgesIgnoringSafeArea(.all)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.initialize()
            }
    }
}

#Preview {
    NavigationView {
        WeatherMapView()
    }
}

