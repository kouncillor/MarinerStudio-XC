import SwiftUI
import WebKit

struct BuoyStationWebView: View {
    // MARK: - Properties
    let station: BuoyStation
    let buoyDatabaseService: BuoyDatabaseService
    @State private var isFavorite: Bool
    @State private var isLoading = true
    @State private var loadingURL: URL?
    
    // MARK: - Initialization
    init(station: BuoyStation, buoyDatabaseService: BuoyDatabaseService) {
        self.station = station
        self.buoyDatabaseService = buoyDatabaseService
        // Initialize with the station's current favorite status
        _isFavorite = State(initialValue: station.isFavorite)
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // WebView to display NOAA buoy station page
            WebViewContainer(
                url: URL(string: "https://www.ndbc.noaa.gov/station_page.php?station=\(station.id)")!,
                isLoading: $isLoading
            )
            .edgesIgnoringSafeArea(.bottom)
            
            // Loading indicator
            if isLoading {
                Color.white.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                
                ProgressView("Loading...")
                    .scaleEffect(1.5)
                    .padding()
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(10)
            }
        }
        .navigationTitle(station.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Favorite button
                    Button(action: {
                        toggleFavorite()
                    }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .yellow : .gray)
                    }
                    
                    // Share button
                    Button(action: {
                        shareStation()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            loadFavoriteStatus()
        }
    }
    
    // MARK: - Methods
    private func loadFavoriteStatus() {
        Task {
            isFavorite = await buoyDatabaseService.isBuoyStationFavoriteAsync(stationId: station.id)
        }
    }
    
    private func toggleFavorite() {
        Task {
            let newStatus = await buoyDatabaseService.toggleBuoyStationFavoriteAsync(stationId: station.id)
            await MainActor.run {
                isFavorite = newStatus
            }
        }
    }
    
    private func shareStation() {
        let text = "NOAA Buoy Station: \(station.name)\nURL: https://www.ndbc.noaa.gov/station_page.php?station=\(station.id)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        // Find the current window scene for presenting the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true, completion: nil)
        }
    }
}

// MARK: - WebView Implementation
struct WebViewContainer: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load if URL is different from current URL to prevent reload loops
        if webView.url == nil || webView.url?.absoluteString != url.absoluteString {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewContainer
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}
