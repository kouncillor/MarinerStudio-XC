import SwiftUI
import WebKit

struct TidalStationWebView: View {
    // MARK: - Properties
    let stationId: String
    let stationName: String
    @StateObject private var viewModel: TidalStationWebViewModel
    
    // MARK: - Initialization
    init(
        stationId: String,
        stationName: String,
        databaseService: DatabaseService
    ) {
        self.stationId = stationId
        self.stationName = stationName
        _viewModel = StateObject(wrappedValue: TidalStationWebViewModel(
            stationId: stationId,
            stationName: stationName,
            databaseService: databaseService
        ))
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Action bar
            HStack {
                Spacer()
                
                Button(action: {
                    viewModel.shareStation()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding()
                }
                
                Button(action: {
                    Task {
                        await viewModel.toggleFavorite()
                    }
                }) {
                    Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(viewModel.isFavorite ? .yellow : .gray)
                        .padding()
                }
            }
            .frame(height: 50)
            .background(Color("AliceBlue"))
            
            // Web view
            WebView(url: viewModel.stationUrl)
        }
        .navigationTitle("Station Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Web View
struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(URLRequest(url: url))
    }
}

// MARK: - Preview Provider
#Preview {
    NavigationStack {
        TidalStationWebView(
            stationId: "9447130",
            stationName: "Seattle",
            databaseService: MockDatabaseService()
        )
    }
}
