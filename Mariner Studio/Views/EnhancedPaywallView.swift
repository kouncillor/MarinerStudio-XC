import SwiftUI
import StoreKit

struct EnhancedPaywallView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var availableProducts: [Product] = []
    @State private var isLoading = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                
                // Header section
                VStack(spacing: 20) {
                    Image(systemName: "anchor.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 12) {
                        Text(headerTitle)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(headerSubtitle)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)
                
                // Feature grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    FeatureCard(icon: "cloud.sun.fill", title: "Live Weather", description: "Real-time maritime conditions")
                    FeatureCard(icon: "waveform.path", title: "Tidal Data", description: "Accurate predictions")
                    FeatureCard(icon: "map.fill", title: "Navigation", description: "Professional tools")
                    FeatureCard(icon: "icloud.fill", title: "iCloud Sync", description: "Cross-device sync")
                }
                .padding(.horizontal)
                
                // Subscription options
                if isLoading {
                    ProgressView("Loading subscription options...")
                        .padding()
                } else {
                    SubscriptionOptionsView(products: availableProducts)
                }
                
                // Restore purchases button
                Button(action: {
                    Task {
                        await subscriptionService.restorePurchases()
                    }
                }) {
                    Text("Restore Purchases")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 30)
                
                // Legal text
                VStack(spacing: 8) {
                    Text("• Cancel anytime in Settings")
                    Text("• Payment charged to iTunes Account")
                    Text("• Subscription automatically renews")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .task {
            await loadProducts()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var headerTitle: String {
        switch subscriptionService.subscriptionStatus {
        case .trialExpired:
            return "Continue Your Journey"
        case .expired:
            return "Reactivate Premium"
        default:
            return "Unlock Premium Features"
        }
    }
    
    private var headerSubtitle: String {
        switch subscriptionService.subscriptionStatus {
        case .trialExpired:
            return "Your trial has ended. Subscribe to continue using all features."
        case .expired:
            return "Reactivate your subscription to restore full access."
        default:
            return "Get full access to professional maritime tools."
        }
    }
    
    private func loadProducts() async {
        do {
            availableProducts = try await subscriptionService.getAvailableProducts()
            isLoading = false
        } catch {
            errorMessage = "Failed to load subscription options: \(error.localizedDescription)"
            showingError = true
            isLoading = false
        }
    }
}

struct FeatureCard: View {
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