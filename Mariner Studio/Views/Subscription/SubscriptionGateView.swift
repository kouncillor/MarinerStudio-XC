
import SwiftUI

struct SubscriptionGateView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var isCheckingStatus = true
    @State private var showTrialExplanation = false
    
    var body: some View {
        Group {
            if isCheckingStatus {
                // Loading screen while checking subscription status
                ProgressView("Checking subscription status...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else {
                // Determine what to show based on subscription status
                switch subscriptionService.subscriptionStatus {
                case .subscribed:
                    // User has active subscription - allow access
                    MainView()
                
                case .firstLaunch:
                    // First time user - show simple welcome
                    FirstTimeWelcomeView()
                        .fullScreenCover(isPresented: $showTrialExplanation) {
                            EnhancedPaywallView()
                        }
                
                case .expired, .unknown:
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
                    WelcomeFeatureCard(icon: "map.fill", title: "Navigation", description: "Professional maritime tools")
                    WelcomeFeatureCard(icon: "map.fill", title: "Navigation", description: "Professional maritime tools")
                    WelcomeFeatureCard(icon: "icloud.fill", title: "iCloud Sync", description: "Seamless sync across devices")
                    WelcomeFeatureCard(icon: "location.fill", title: "GPS Tracking", description: "Precise position tracking")
                    WelcomeFeatureCard(icon: "chart.line.uptrend.xyaxis", title: "Route Planning", description: "Plan and optimize voyages")
                }
                .padding(.horizontal)
                
                // Call to action buttons
                VStack(spacing: 16) {
                    // Premium text
                    Text("$2.99/month • Cancel anytime")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Premium button
                    Button(action: {
                        showTrialExplanation = true
                    }) {
                        Text("Subscribe Now")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Free button
                    Button(action: {
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
            InitialSubscriptionView()
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
