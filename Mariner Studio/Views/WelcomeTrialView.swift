import SwiftUI

struct WelcomeTrialView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var showMainApp = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Welcome header
            VStack(spacing: 16) {
                Image(systemName: "anchor.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Welcome to Mariner Studio")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Your 14-day free trial starts now!")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Feature highlights
            VStack(alignment: .leading, spacing: 16) {
                WelcomeFeatureRow(icon: "cloud.sun.fill", title: "Real-time Weather", description: "Live maritime weather data")
                WelcomeFeatureRow(icon: "waveform.path", title: "Tidal Information", description: "Precise tidal predictions")
                WelcomeFeatureRow(icon: "map.fill", title: "Navigation Tools", description: "Professional maritime navigation")
                WelcomeFeatureRow(icon: "icloud.fill", title: "iCloud Sync", description: "Seamless sync across devices")
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showMainApp = true
                }
                
                // Trigger automatic trial start
                Task {
                    await subscriptionService.startTrial()
                }
            }) {
                HStack {
                    Text("Start Free Trial")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .fullScreenCover(isPresented: $showMainApp) {
            MainView()
                .environmentObject(subscriptionService)
        }
    }
}

struct WelcomeFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}