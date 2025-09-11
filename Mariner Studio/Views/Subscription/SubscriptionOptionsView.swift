import SwiftUI
import StoreKit

struct SubscriptionOptionsView: View {
    let products: [Product]
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var selectedProduct: Product?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Your Plan")
                .font(.title2)
                .fontWeight(.semibold)
            
            ForEach(products, id: \.id) { product in
                SubscriptionOptionCard(product: product)
                    .onTapGesture {
                        selectedProduct = product
                        Task {
                            await purchaseProduct(product)
                        }
                    }
            }
        }
        .padding(.horizontal)
    }
    
    private func purchaseProduct(_ product: Product) async {
        do {
            try await subscriptionService.subscribe(to: product.id)
        } catch {
            DebugLogger.shared.log("❌ PAYWALL: Purchase failed - \(error)", category: "TRIAL_SUBSCRIPTION")
        }
    }
}

struct SubscriptionOptionCard: View {
    let product: Product?
    let title: String
    let price: String
    let period: String
    let subtitle: String?
    let productID: String?
    let isRecommended: Bool
    
    @EnvironmentObject var subscriptionService: SimpleSubscription
    
    // Multiple initializers for different use cases
    init(product: Product) {
        self.product = product
        self.title = product.displayName
        self.price = product.displayPrice
        self.period = product.subscription?.subscriptionPeriod.unit.localizedDescription ?? ""
        self.subtitle = nil
        self.productID = product.id
        self.isRecommended = false
    }
    
    init(title: String, price: String, period: String, subtitle: String? = nil, productID: String, isRecommended: Bool = false) {
        self.product = nil
        self.title = title
        self.price = price
        self.period = period
        self.subtitle = subtitle
        self.productID = productID
        self.isRecommended = isRecommended
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if isRecommended {
                HStack {
                    Spacer()
                    Text("BEST VALUE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                    Spacer()
                }
            }
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                
                HStack(alignment: .firstTextBaseline) {
                    Text(price)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("/ \(period)")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
                
                if case .firstLaunch = subscriptionService.subscriptionStatus {
                    Text("14-day free trial included")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.regular)
                }
            }
            
            if subscriptionService.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else {
                Button(action: {
                    guard let productID = productID else { return }
                    Task {
                        try await subscriptionService.subscribe(to: productID)
                    }
                }) {
                    Text(buttonText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRecommended ? Color.orange : Color.blue)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isRecommended ? Color.orange : Color.clear, lineWidth: 2)
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