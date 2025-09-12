import SwiftUI
import StoreKit

struct InitialSubscriptionView: View {
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
                
                
                // Subscription options with prominent pricing
                if isLoading {
                    ProgressView("Loading subscription options...")
                        .padding()
                } else {
                    InitialAppleCompliantSubscriptionView(products: availableProducts)
                }
                
                // Apple-Style Legal Footer
                VStack(spacing: 16) {
                    Text("Cancel anytime. Subscription auto-renews.")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 0) {
                            Text("By joining you agree to our ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Link("privacy policy", destination: URL(string: "https://your-app-website.com/privacy")!)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .underline()
                            
                            Text(" and ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Link("terms of use", destination: URL(string: "https://your-app-website.com/terms")!)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .underline()
                            
                            Text(".")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 0) {
                            Text("Upon payment, you agree to Apple's ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Link("terms and conditions", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .underline()
                            
                            Text(".")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    
                    // Restore purchases button
                    Button(action: {
                        Task {
                            await subscriptionService.restorePurchases()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 20)
                }
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
        return "Mariner Studio Pro"
    }
    
    private var headerSubtitle: String {
        return "All features.\nNo restrictions."
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

// MARK: - Apple-Compliant Subscription View

struct InitialAppleCompliantSubscriptionView: View {
    let products: [Product]
    @EnvironmentObject var subscriptionService: SimpleSubscription
    
    var body: some View {
        VStack(spacing: 24) {
            ForEach(products, id: \.id) { product in
                InitialAppleCompliantSubscriptionCard(product: product)
            }
        }
        .padding(.horizontal)
    }
}

struct InitialAppleCompliantSubscriptionCard: View {
    let product: Product
    @EnvironmentObject var subscriptionService: SimpleSubscription
    
    var body: some View {
        VStack(spacing: 20) {
            // Product title
            Text(product.displayName)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            // PRICING DISPLAY
            VStack(spacing: 4) {
                Text(product.displayPrice)
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .foregroundColor(.primary)
                
                Text("per month")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Billed monthly • Cancel anytime")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        case .expired:
            return "Reactivate Subscription"
        case .firstLaunch, .unknown:
            return "Subscribe Now"
        default:
            return "Subscribe Now"
        }
    }
}