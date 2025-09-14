
import SwiftUI

struct SubscriptionGateView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var isCheckingStatus = true
    
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
                        .onAppear {
                            DebugLogger.shared.log("🔍 TEST_CORE_STATUS: UI showing MainView (subscribed)", category: "TEST_CORE_STATUS")
                        }
                
                case .firstLaunch:
                    // First time user - show simple welcome
                    FirstTimeWelcomeView()
                        .onAppear {
                            DebugLogger.shared.log("🔍 TEST_CORE_STATUS: UI showing FirstTimeWelcomeView (firstLaunch)", category: "TEST_CORE_STATUS")
                        }
                
                case .expired, .unknown:
                    // No valid access - show paywall
                    EnhancedPaywallView()
                        .onAppear {
                            DebugLogger.shared.log("🔍 TEST_CORE_STATUS: UI showing EnhancedPaywallView (expired/unknown)", category: "TEST_CORE_STATUS")
                        }
                }
            }
        }
        .onAppear {
            DebugLogger.shared.log("🔍 TEST_CORE_STATUS: SubscriptionGateView appeared", category: "TEST_CORE_STATUS")
            Task {
                DebugLogger.shared.log("🔍 TEST_CORE_STATUS: Starting status check from UI", category: "TEST_CORE_STATUS")
                await subscriptionService.determineSubscriptionStatus()
                isCheckingStatus = false
                DebugLogger.shared.log("🔍 TEST_CORE_STATUS: Status check complete, isCheckingStatus = false", category: "TEST_CORE_STATUS")
            }
        }
    }
}

// MARK: - Simplified First Time Welcome View

struct FirstTimeWelcomeView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
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
                }
                .padding(.top, 20)
                
                // Feature list
                VStack(spacing: 16) {
                    WelcomeFeatureRow(icon: "cloud.sun.fill", title: "Live Weather", description: "Real-time maritime conditions and forecasts")
                    WelcomeFeatureRow(icon: "map.fill", title: "Interactive Map", description: "Professional maritime tools")
                    WelcomeFeatureRow(icon: "arrow.up.arrow.down", title: "Tides", description: "Accurate tidal predictions")
                    WelcomeFeatureRow(icon: "arrow.left.arrow.right", title: "Currents", description: "Accurate currents and data")
                    WelcomeFeatureRow(icon: "portfoureight", title: "Docks and Facilities", description: "")
                    WelcomeFeatureRow(icon: "point.bottomleft.forward.to.arrow.triangle.uturn.scurvepath", title: "Route Planning", description: "Plan and optimize voyages")
                }
                .padding(.horizontal)
                
                // Call to action buttons
                VStack(spacing: 16) {
                    // Premium text
                    VStack(spacing: 4) {
                        Text("Get unlimited access for $2.99/month")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                        
                        Text("Subscription auto-renews • Cancel anytime")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Premium button
                    Button(action: {
                        Task {
                            do {
                                try await subscriptionService.subscribeToMonthly()
                            } catch {
                                DebugLogger.shared.log("❌ SUBSCRIPTION: Purchase failed: \(error)", category: "SUBSCRIPTION")
                            }
                        }
                    }) {
                        Text("Subscribe Now $2.99/month")
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
            // Icon circle with color based on title
            let iconColor: Color = {
                switch title {
                case "Live Weather":
                    return .yellow
                case "Tides":
                    return .green
                case "Currents":
                    return .red
                case "Route Planning":
                    return .orange
                default:
                    return .blue
                }
            }()
            
            if icon == "portfoureight" {
                Image(icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())
            } else {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}
