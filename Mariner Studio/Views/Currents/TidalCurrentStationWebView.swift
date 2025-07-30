// TidalCurrentStationWebView.swift

import SwiftUI
import WebKit

struct TidalCurrentStationWebView: View {
    // MARK: - Properties
    let stationId: String
    let bin: Int
    let stationName: String

    // MARK: - URL
    var stationUrl: URL? {
        URL(string: "https://tidesandcurrents.noaa.gov/noaacurrents/predictions.html?id=\(stationId)_\(bin)")
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Top Action Bar
            HStack {
                Spacer()

                Button(action: shareStation) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal)
            .frame(height: 60)
            .background(Color(UIColor.systemGray6))

            // WebView using the renamed helper
            if let url = stationUrl {
                CurrentStationWebViewHelper(url: url) // Use the renamed helper struct
            } else {
                Text("Invalid URL")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle("Station Details")
        .withHomeButton()

        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions
    private func shareStation() {
        guard let url = stationUrl else { return }

        let shareText = "NOAA Current Station: \(stationName)\nURL: \(url.absoluteString)"
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        // Present the share sheet
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(activityViewController, animated: true)
        }
    }
}

// MARK: - Renamed WebView Helper for Current Station
// Renamed from WebView to CurrentStationWebViewHelper
struct CurrentStationWebViewHelper: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Check if the URL has changed before reloading
        if uiView.url != url {
           uiView.load(URLRequest(url: url))
        }
    }
}
