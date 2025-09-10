






//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//import SwiftUI
//
//struct SubscriptionGateView: View {
//    @EnvironmentObject var subscriptionService: SimpleSubscription
//    @State private var isCheckingStatus = true
//    
//    var body: some View {
//        Group {
//            if isCheckingStatus {
//                // Loading screen while checking subscription status
//                TrialLoadingView(message: "Checking subscription status...")
//            } else {
//                // Determine what to show based on subscription status
//                switch subscriptionService.subscriptionStatus {
//                case .subscribed:
//                    // User has active subscription - allow access
//                    MainView()
//                
//                case .inTrial(let daysRemaining):
//                    // User has active trial - allow access with banner
//                    MainView()
//                        .overlay(alignment: .top) {
//                            if subscriptionService.showTrialBanner {
//                                TrialBannerView()
//                                    .transition(.move(edge: .top))
//                            }
//                        }
//                
//                case .firstLaunch:
//                    // First time user - show welcome with trial offer
//                    FirstTimeWelcomeView()
//                
//                case .trialExpired, .expired, .unknown:
//                    // No valid access - show paywall
//                    EnhancedPaywallView()
//                }
//            }
//        }
//        .onAppear {
//            Task {
//                await subscriptionService.determineSubscriptionStatus()
//                isCheckingStatus = false
//            }
//        }
//    }
//}
//
//// MARK: - First Time Welcome View
//
//struct FirstTimeWelcomeView: View {
//    @EnvironmentObject var subscriptionService: SimpleSubscription
//    
//    var body: some View {
//        VStack(spacing: 30) {
//            Spacer()
//            
//            // App branding
//            VStack(spacing: 16) {
//                Image(systemName: "anchor.fill")
//                    .font(.system(size: 100))
//                    .foregroundColor(.blue)
//                
//                Text("Welcome to Mariner Studio")
//                    .font(.largeTitle)
//                    .fontWeight(.bold)
//                    .multilineTextAlignment(.center)
//                
//                // IMPROVED TRIAL MESSAGING (Apple Compliance)
//                VStack(spacing: 8) {
//                    Text("Get 14 days free, then $2.99/month")
//                        .font(.title2)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.blue)
//                        .multilineTextAlignment(.center)
//                    
//                    Text("Full access to all professional maritime tools")
//                        .font(.title3)
//                        .foregroundColor(.secondary)
//                        .multilineTextAlignment(.center)
//                }
//                .padding(.vertical, 12)
//                .padding(.horizontal, 20)
//                .background(Color.blue.opacity(0.1))
//                .cornerRadius(12)
//            }
//            
//            Spacer()
//            
//            // Feature highlights
//            VStack(alignment: .leading, spacing: 16) {
//                WelcomeFeatureRow(icon: "cloud.sun.fill", title: "Real-time Weather", description: "Live maritime weather data")
//                WelcomeFeatureRow(icon: "waveform.path", title: "Tidal Information", description: "Precise tidal predictions")
//                WelcomeFeatureRow(icon: "map.fill", title: "Navigation Tools", description: "Professional maritime navigation")
//                WelcomeFeatureRow(icon: "icloud.fill", title: "iCloud Sync", description: "Seamless sync across devices")
//            }
//            .padding(.horizontal)
//            
//            Spacer()
//            
//            // Trial start button
//            Button(action: {
//                Task {
//                    await subscriptionService.startTrial()
//                }
//            }) {
//                HStack {
//                    Text("Start 14-Day Free Trial")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                    
//                    Image(systemName: "arrow.right")
//                        .foregroundColor(.white)
//                }
//                .frame(maxWidth: .infinity)
//                .padding()
//                .background(Color.blue)
//                .cornerRadius(12)
//            }
//            .padding(.horizontal)
//            
//            // Apple Compliance Footer
//            VStack(spacing: 4) {
//                Text("Free for 14 days, then $2.99/month")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                
//                Text("Cancel anytime • No commitment")
//                    .font(.caption2)
//                    .foregroundColor(.secondary)
//            }
//            .padding(.bottom, 30)
//        }
//    }
//}
//






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
                
                // Auto-show trial explanation for first-time users
                if case .firstLaunch = subscriptionService.subscriptionStatus {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showTrialExplanation = true
                    }
                }
            }
        }
    }
}

// MARK: - Simplified First Time Welcome View

struct FirstTimeWelcomeView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var showTrialExplanation = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App branding
            VStack(spacing: 20) {
                Image(systemName: "anchor.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.blue)
                
                Text("Mariner Studio")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Professional Maritime Navigation")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Call to action
            VStack(spacing: 20) {
                Button(action: {
                    showTrialExplanation = true
                }) {
                    Text("Get Started")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Text("Free trial available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 50)
        }
        .fullScreenCover(isPresented: $showTrialExplanation) {
            TrialExplanationView()
        }
    }
}

//struct WelcomeFeatureRow: View {
//    let icon: String
//    let title: String
//    let description: String
//    
//    var body: some View {
//        HStack(spacing: 16) {
//            Image(systemName: icon)
//                .font(.title2)
//                .foregroundColor(.blue)
//                .frame(width: 30)
//            
//            VStack(alignment: .leading, spacing: 2) {
//                Text(title)
//                    .font(.headline)
//                
//                Text(description)
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//            }
//            
//            Spacer()
//        }
//    }
//}
