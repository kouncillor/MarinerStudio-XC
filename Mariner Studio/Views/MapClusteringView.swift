import SwiftUI
import MapKit

struct MapClusteringView: View {
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.8050315413548, longitude: -122.413632917219),
        span: MKCoordinateSpan(latitudeDelta: 0.00978871051851371, longitudeDelta: 0.008167393319212121)
    )
    
    @StateObject private var viewModel = MapClusteringViewModel()
    
    var body: some View {
        ZStack {
            // Use the renamed view representable
            TandmMapViewRepresentable(region: $mapRegion, annotations: viewModel.cycles)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MapLegendView()
                        .padding()
                }
            }
        }
        .navigationTitle("Bicycle Rentals")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load the cycle data when view appears
            viewModel.loadData()
        }
    }
}

struct MapLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LegendItem(color: Color(red: 0.668, green: 0.475, blue: 0.259), text: "Unicycle")
            LegendItem(color: Color(red: 1.0, green: 0.474, blue: 0.0), text: "Bicycle")
            LegendItem(color: Color(red: 0.597, green: 0.706, blue: 0.0), text: "Tricycle")
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(10)
        .shadow(radius: 3)
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(text)
                .font(.caption)
            Spacer()
        }
    }
}

// ViewModel to handle data loading and processing
class MapClusteringViewModel: ObservableObject {
    @Published var cycles: [Cycle] = []
    
    func loadData() {
        guard let plistURL = Bundle.main.url(forResource: "Data", withExtension: "plist") else {
            print("Failed to resolve URL for Data.plist in bundle.")
            return
        }

        do {
            let plistData = try Data(contentsOf: plistURL)
            let decoder = PropertyListDecoder()
            let decodedData = try decoder.decode(MapData.self, from: plistData)
            
            // Set the cycles data
            self.cycles = decodedData.cycles
        } catch {
            print("Failed to load provided data, error: \(error.localizedDescription)")
        }
    }
}
