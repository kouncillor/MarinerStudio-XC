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
                
                // Subscription options with prominent pricing
                if isLoading {
                    ProgressView("Loading subscription options...")
                        .padding()
                } else {
                    AppleCompliantSubscriptionView(products: availableProducts)
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

// MARK: - Apple-Compliant Subscription View

struct AppleCompliantSubscriptionView: View {
    let products: [Product]
    @EnvironmentObject var subscriptionService: SimpleSubscription
    
    var body: some View {
        VStack(spacing: 24) {
            ForEach(products, id: \.id) { product in
                AppleCompliantSubscriptionCard(product: product)
            }
        }
        .padding(.horizontal)
    }
}

struct AppleCompliantSubscriptionCard: View {
    let product: Product
    @EnvironmentObject var subscriptionService: SimpleSubscription
    
    var body: some View {
        VStack(spacing: 16) {
            // Product title
            Text(product.displayName)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            // MOST PROMINENT: Billed amount
            VStack(spacing: 4) {
                Text(product.displayPrice)
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .foregroundColor(.primary)
                
                Text("per month")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // SUBORDINATE: Free trial information (smaller, less prominent)
            if case .firstLaunch = subscriptionService.subscriptionStatus {
                VStack(spacing: 2) {
                    Text("14-day free trial")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Text("Then \(product.displayPrice)/month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            
            // Subscribe button
            Button(action: {
                Task {
                    do {
                        try await subscriptionService.subscribe(to: product.id)
                    } catch {
                        DebugLogger.shared.log("❌ SUBSCRIPTION: Purchase failed: \(error)", category: "SUBSCRIPTION")
                    }
                }
            }) {
                Text(buttonText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .disabled(subscriptionService.isLoading)
            
            if subscriptionService.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            }
        }
        .padding(24)
        .background(.regularMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var buttonText: String {
        switch subscriptionService.subscriptionStatus {
        case .firstLaunch, .unknown:
            return "Start Free Trial"
        case .trialExpired:
            return "Subscribe Now"
        case .expired:
            return "Reactivate"
        default:
            return "Subscribe"
        }
    }
}