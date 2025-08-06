import Foundation
import StoreKit

/**
 * SimpleSubscription - Dead Simple $2.99/month Subscription
 * 
 * No servers. No cross-device complexity. No bullshit.
 * Just: "Did this person buy it? Yes/No"
 */
@MainActor
class SimpleSubscription: ObservableObject {
    
    @Published var isPro: Bool = false
    @Published var isLoading: Bool = false
    
    private let productID = "pro_monthly" // Your App Store Connect product ID
    
    init() {
        DebugLogger.shared.log("💰 SIMPLE SUB: Initializing dead-simple subscription service", category: "SIMPLE_SUBSCRIPTION")
        Task {
            await checkSubscription()
        }
    }
    
    /**
     * Check if user has active subscription - that's it
     */
    func checkSubscription() async {
        DebugLogger.shared.log("💰 SIMPLE SUB: Checking subscription status", category: "SIMPLE_SUBSCRIPTION")
        
        // Check all transactions for our product
        for await result in Transaction.all {
            if case .verified(let transaction) = result,
               transaction.productID == productID {
                DebugLogger.shared.log("✅ SIMPLE SUB: Active subscription found", category: "SIMPLE_SUBSCRIPTION")
                isPro = true
                return
            }
        }
        
        DebugLogger.shared.log("❌ SIMPLE SUB: No active subscription", category: "SIMPLE_SUBSCRIPTION")
        isPro = false
    }
    
    /**
     * Buy the $2.99/month subscription
     */
    func subscribe() async throws {
        DebugLogger.shared.log("💰 SIMPLE SUB: Starting purchase", category: "SIMPLE_SUBSCRIPTION")
        isLoading = true
        
        do {
            // Load the product
            let products = try await Product.products(for: [productID])
            guard let product = products.first else {
                DebugLogger.shared.log("❌ SIMPLE SUB: Product not found", category: "SIMPLE_SUBSCRIPTION")
                throw SubscriptionError.productNotFound
            }
            
            DebugLogger.shared.log("💰 SIMPLE SUB: Product loaded: \(product.displayName) - \(product.displayPrice)", category: "SIMPLE_SUBSCRIPTION")
            
            // Purchase it
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                DebugLogger.shared.log("🎉 SIMPLE SUB: Purchase successful", category: "SIMPLE_SUBSCRIPTION")
                await checkSubscription()
            case .userCancelled:
                DebugLogger.shared.log("❌ SIMPLE SUB: User cancelled", category: "SIMPLE_SUBSCRIPTION")
            case .pending:
                DebugLogger.shared.log("⏳ SIMPLE SUB: Purchase pending", category: "SIMPLE_SUBSCRIPTION")
            @unknown default:
                DebugLogger.shared.log("❓ SIMPLE SUB: Unknown purchase result", category: "SIMPLE_SUBSCRIPTION")
            }
            
        } catch {
            DebugLogger.shared.log("❌ SIMPLE SUB: Purchase failed: \(error)", category: "SIMPLE_SUBSCRIPTION")
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Restore purchases (Apple handles this automatically)
     */
    func restorePurchases() async {
        DebugLogger.shared.log("🔄 SIMPLE SUB: Restoring purchases", category: "SIMPLE_SUBSCRIPTION")
        
        do {
            try await AppStore.sync()
            await checkSubscription()
            DebugLogger.shared.log("✅ SIMPLE SUB: Restore complete", category: "SIMPLE_SUBSCRIPTION")
        } catch {
            DebugLogger.shared.log("❌ SIMPLE SUB: Restore failed: \(error)", category: "SIMPLE_SUBSCRIPTION")
        }
    }
}

// MARK: - Simple Errors

enum SubscriptionError: Error, LocalizedError {
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription product not found"
        }
    }
}