
import SwiftUI

struct SubscriptionGateView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var isCheckingStatus = true
    @State private var showTrialExplanation = false
    
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
                    // First time user - show simple welcome that leads to explanation
                    FirstTimeWelcomeView()
                        .fullScreenCover(isPresented: $showTrialExplanation) {
                            TrialExplanationView()
                        }
                
                case .skippedTrial:
                    // User skipped trial - limited access to MainView (only MAP accessible)
                    MainView()
                
                case .trialExpired, .expired, .unknown:
                    // No valid access - show paywall
                    EnhancedPaywallView()
                }
            }
        }
        .onAppear {
            Task {
                await subscriptionService.determineSubscriptionStatus()
                isCheckingStatus = false
            }
        }
    }
}

// MARK: - Simplified First Time Welcome View

struct FirstTimeWelcomeView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var showTrialExplanation = false
    @State private var showMainApp = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // App branding
                VStack(spacing: 15) {
                    Image(systemName: "anchor.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Mariner Studio")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Professional Maritime Navigation")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Feature cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    WelcomeFeatureCard(icon: "cloud.sun.fill", title: "Live Weather", description: "Real-time maritime conditions and forecasts")
                    WelcomeFeatureCard(icon: "waveform.path", title: "Tidal Data", description: "Accurate tidal predictions and heights")
                    WelcomeFeatureCard(icon: "map.fill", title: "Navigation", description: "Professional maritime tools")
                    WelcomeFeatureCard(icon: "icloud.fill", title: "iCloud Sync", description: "Seamless sync across devices")
                    WelcomeFeatureCard(icon: "location.fill", title: "GPS Tracking", description: "Precise position tracking")
                    WelcomeFeatureCard(icon: "chart.line.uptrend.xyaxis", title: "Route Planning", description: "Plan and optimize voyages")
                }
                .padding(.horizontal)
                
                // Call to action buttons
                VStack(spacing: 16) {
                    // Premium button
                    Button(action: {
                        showTrialExplanation = true
                    }) {
                        VStack(spacing: 4) {
                            Text("Try Premium")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("3-day free trial, then $2.99/month")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Free button
                    Button(action: {
                        subscriptionService.skipTrial()
                        showMainApp = true
                    }) {
                        Text("Continue with Free Version")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Text("Limited features • Upgrade anytime")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 30)
            }
        }
        .fullScreenCover(isPresented: $showTrialExplanation) {
            TrialExplanationView()
        }
        .fullScreenCover(isPresented: $showMainApp) {
            MainView()
                .environmentObject(subscriptionService)
        }
    }
}

struct WelcomeFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}
