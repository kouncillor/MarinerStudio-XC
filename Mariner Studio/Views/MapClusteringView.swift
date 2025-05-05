import SwiftUI
import MapKit

struct MapClusteringView: View {
    @StateObject private var viewModel = MapViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            MapViewRepresentable(
                annotations: viewModel.annotations,
                region: viewModel.region,
                showsUserLocation: true
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding([.top, .leading])
                    
                    Spacer()
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    
                    MKCompassButton()
                        .mapControls()
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.8))
                        .clipShape(Circle())
                        .padding()
                    
                    MKUserTrackingButton()
                        .mapControls()
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.8))
                        .clipShape(Circle())
                        .padding([.bottom, .trailing])
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadData()
        }
    }
}

class MapViewModel: ObservableObject {
    @Published var annotations: [MapAnnotation] = []
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    func loadData() {
        // Load data from the bundle (similar to Tandm)
        guard let url = Bundle.main.url(forResource: "Data", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListDecoder().decode(MarinerMapData.self, from: data) else {
            print("Failed to load map data")
            return
        }
        
        self.annotations = plist.cycles.map { MapAnnotation(from: $0) }
        self.region = plist.region
    }
}

struct MKCompassButton: UIViewRepresentable {
    func makeUIView(context: Context) -> MKCompassButton {
        let button = MKCompassButton(mapView: MKMapView())
        button.compassVisibility = .visible
        return button
    }
    
    func updateUIView(_ uiView: MKCompassButton, context: Context) {}
}

struct MKUserTrackingButton: UIViewRepresentable {
    func makeUIView(context: Context) -> MKUserTrackingButton {
        return MKUserTrackingButton(mapView: MKMapView())
    }
    
    func updateUIView(_ uiView: MKUserTrackingButton, context: Context) {}
}
