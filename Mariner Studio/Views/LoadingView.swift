import SwiftUI

struct TrialLoadingView: View {
    let message: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 30) {
            // App icon/logo
            Image(systemName: "anchor.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
            
            // Loading message
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Progress indicator
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
        }
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}