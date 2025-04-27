import SwiftUI

struct TidalHeightPredictionView: View {
    // MARK: - Properties
    let stationId: String
    let stationName: String
    
    // MARK: - Body
    var body: some View {
        VStack {
            Text("Tide Predictions")
                .font(.largeTitle)
                .padding()
            
            Text("Station: \(stationName)")
                .font(.headline)
            
            Text("ID: \(stationId)")
                .font(.subheadline)
            
            Text("This is a placeholder for the TidalHeightPredictionView")
                .padding()
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .navigationTitle("Tide Predictions")
    }
}

#Preview {
    NavigationStack {
        TidalHeightPredictionView(
            stationId: "9447130",
            stationName: "Seattle"
        )
    }
}
