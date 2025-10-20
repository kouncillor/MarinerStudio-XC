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
                        Text(headerSubtitle)
                            .font(.title2)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.top, 20)


                // Subscription options with prominent pricing
                if isLoading {
                    ProgressView("Loading subscription options...")
                        .padding()
                } else {
                    AppleCompliantSubscriptionView(products: availableProducts)
                }

                // Apple-Style Legal Footer
                VStack(spacing: 16) {

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

    private var headerSubtitle: String {
        return "Daily limit reached. Subscribe for unlimited access to all features."
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

struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
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
        VStack(spacing: 20) {
            // Product title
            Text("Get Pro Now")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            // PRICING DISPLAY
            VStack(spacing: 4) {
                Text(product.displayPrice)
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .foregroundColor(.blue)

                Text("per month")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)

                Text("Subscription auto-renews • Cancel anytime")
                    .font(.caption)
                    .fontWeight(.bold)
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
        return "Subscribe Now"
    }
}