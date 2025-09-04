import SwiftUI

struct SubscriptionGateView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var isCheckingStatus = true
    
    var body: some View {
        Group {
            if isCheckingStatus {
                // Loading screen while checking subscription status
                TrialLoadingView(message: "Checking subscription status...")
            } else {
                // Determine what to show based on subscription status
                switch subscriptionService.subscriptionStatus {
                case .subscribed:
                    // User has active subscription - allow access
                    MainView()
                
                case .inTrial(let daysRemaining):
                    // User has active trial - allow access with banner
                    MainView()
                        .overlay(alignment: .top) {
                            if subscriptionService.showTrialBanner {
                                TrialBannerView()
                                    .transition(.move(edge: .top))
                            }
                        }
                
                case .firstLaunch:
                    // First time user - show welcome with trial offer
                    FirstTimeWelcomeView()
                
                case .trialExpired, .expired, .unknown:
                    // No valid access - show paywall
                    EnhancedPaywallView()
                }
            }
        }
        .task {
            await checkSubscriptionStatus()
        }
        .animation(.easeInOut(duration: 0.3), value: subscriptionService.subscriptionStatus)
    }
    
    private func checkSubscriptionStatus() async {
        await subscriptionService.determineSubscriptionStatus()
        isCheckingStatus = false
    }
}

struct FirstTimeWelcomeView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    
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
                
                Text("Just $2.99/month")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("14 days free trial included")
                    .font(.subheadline)
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
            
            // Trial start button
            Button(action: {
                Task {
                    await subscriptionService.startTrial()
                }
            }) {
                HStack {
                    Text("Start 14-Day Trial")
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
            
            // Small print
            Text("$2.99/month after free trial • Cancel anytime")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 30)
        }
    }
}

