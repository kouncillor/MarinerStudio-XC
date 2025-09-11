//import SwiftUI
//import StoreKit
//
//struct EnhancedPaywallView: View {
//    @EnvironmentObject var subscriptionService: SimpleSubscription
//    @State private var availableProducts: [Product] = []
//    @State private var isLoading = true
//    @State private var showingError = false
//    @State private var errorMessage = ""
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 30) {
//                
//                // Header section
//                VStack(spacing: 20) {
//                    Image(systemName: "anchor.fill")
//                        .font(.system(size: 80))
//                        .foregroundColor(.blue)
//                    
//                    VStack(spacing: 12) {
//                        Text(headerTitle)
//                            .font(.largeTitle)
//                            .fontWeight(.bold)
//                            .multilineTextAlignment(.center)
//                        
//                        Text(headerSubtitle)
//                            .font(.title3)
//                            .foregroundColor(.secondary)
//                            .multilineTextAlignment(.center)
//                    }
//                }
//                .padding(.top, 20)
//                
//                // Feature grid
//                LazyVGrid(columns: [
//                    GridItem(.flexible()),
//                    GridItem(.flexible())
//                ], spacing: 20) {
//                    FeatureCard(icon: "cloud.sun.fill", title: "Live Weather", description: "Real-time maritime conditions")
//                    FeatureCard(icon: "waveform.path", title: "Tidal Data", description: "Accurate predictions")
//                    FeatureCard(icon: "map.fill", title: "Navigation", description: "Professional tools")
//                    FeatureCard(icon: "icloud.fill", title: "iCloud Sync", description: "Cross-device sync")
//                }
//                .padding(.horizontal)
//                
//                // Subscription options with prominent pricing
//                if isLoading {
//                    ProgressView("Loading subscription options...")
//                        .padding()
//                } else {
//                    AppleCompliantSubscriptionView(products: availableProducts)
//                }
//                
//                // Restore purchases button
//                Button(action: {
//                    Task {
//                        await subscriptionService.restorePurchases()
//                    }
//                }) {
//                    Text("Restore Purchases")
//                        .font(.subheadline)
//                        .foregroundColor(.blue)
//                }
//                .padding(.bottom, 30)
//                
//                // Legal text
//                VStack(spacing: 8) {
//                    Text("• Cancel anytime in Settings")
//                    Text("• Payment charged to iTunes Account")
//                    Text("• Subscription automatically renews")
//                }
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//                .padding(.bottom, 20)
//            }
//        }
//        .task {
//            await loadProducts()
//        }
//        .alert("Error", isPresented: $showingError) {
//            Button("OK") { }
//        } message: {
//            Text(errorMessage)
//        }
//    }
//    
//    private var headerTitle: String {
//        switch subscriptionService.subscriptionStatus {
//        case .trialExpired:
//            return "Continue Your Journey"
//        case .expired:
//            return "Reactivate Premium"
//        default:
//            return "Unlock Premium Features"
//        }
//    }
//    
//    private var headerSubtitle: String {
//        switch subscriptionService.subscriptionStatus {
//        case .trialExpired:
//            return "Your trial has ended. Subscribe to continue using all features."
//        case .expired:
//            return "Reactivate your subscription to restore full access."
//        default:
//            return "Get full access to professional maritime tools."
//        }
//    }
//    
//    private func loadProducts() async {
//        do {
//            availableProducts = try await subscriptionService.getAvailableProducts()
//            isLoading = false
//        } catch {
//            errorMessage = "Failed to load subscription options: \(error.localizedDescription)"
//            showingError = true
//            isLoading = false
//        }
//    }
//}
//
//struct FeatureCard: View {
//    let icon: String
//    let title: String
//    let description: String
//    
//    var body: some View {
//        VStack(spacing: 12) {
//            Image(systemName: icon)
//                .font(.system(size: 30))
//                .foregroundColor(.blue)
//            
//            Text(title)
//                .font(.headline)
//            
//            Text(description)
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.center)
//        }
//        .padding()
//        .background(.regularMaterial)
//        .cornerRadius(12)
//    }
//}
//
//// MARK: - Apple-Compliant Subscription View
//
//struct AppleCompliantSubscriptionView: View {
//    let products: [Product]
//    @EnvironmentObject var subscriptionService: SimpleSubscription
//    
//    var body: some View {
//        VStack(spacing: 24) {
//            ForEach(products, id: \.id) { product in
//                AppleCompliantSubscriptionCard(product: product)
//            }
//        }
//        .padding(.horizontal)
//    }
//}
//
//struct AppleCompliantSubscriptionCard: View {
//    let product: Product
//    @EnvironmentObject var subscriptionService: SimpleSubscription
//    
//    var body: some View {
//        VStack(spacing: 16) {
//            // Product title
//            Text(product.displayName)
//                .font(.title2)
//                .fontWeight(.semibold)
//                .multilineTextAlignment(.center)
//            
//            // MOST PROMINENT: Billed amount
//            VStack(spacing: 4) {
//                Text(product.displayPrice)
//                    .font(.system(size: 48, weight: .bold, design: .default))
//                    .foregroundColor(.primary)
//                
//                Text("per month")
//                    .font(.title2)
//                    .fontWeight(.semibold)
//                    .foregroundColor(.primary)
//            }
//            
//            // SUBORDINATE: Free trial information (smaller, less prominent)
//            if case .firstLaunch = subscriptionService.subscriptionStatus {
//                VStack(spacing: 2) {
//                    Text("14-day free trial")
//                        .font(.footnote)
//                        .foregroundColor(.secondary)
//                    
//                    Text("Then \(product.displayPrice)/month")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//                .padding(.top, 8)
//            }
//            
//            // Subscribe button
//            Button(action: {
//                Task {
//                    do {
//                        try await subscriptionService.subscribe(to: product.id)
//                    } catch {
//                        DebugLogger.shared.log("❌ SUBSCRIPTION: Purchase failed: \(error)", category: "SUBSCRIPTION")
//                    }
//                }
//            }) {
//                Text(buttonText)
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color.blue)
//                    .cornerRadius(12)
//            }
//            .disabled(subscriptionService.isLoading)
//            
//            if subscriptionService.isLoading {
//                ProgressView()
//                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
//            }
//        }
//        .padding(24)
//        .background(.regularMaterial)
//        .cornerRadius(16)
//        .overlay(
//            RoundedRectangle(cornerRadius: 16)
//                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
//        )
//    }
//    
//    private var buttonText: String {
//        switch subscriptionService.subscriptionStatus {
//        case .firstLaunch, .unknown:
//            return "Start Free Trial"
//        case .trialExpired:
//            return "Subscribe Now"
//        case .expired:
//            return "Reactivate"
//        default:
//            return "Subscribe"
//        }
//    }
//}







//
//
//
//import SwiftUI
//import StoreKit
//
//struct EnhancedPaywallView: View {
//    @EnvironmentObject var subscriptionService: SimpleSubscription
//    @State private var availableProducts: [Product] = []
//    @State private var isLoading = true
//    @State private var showingError = false
//    @State private var errorMessage = ""
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 30) {
//                
//                // Header section
//                VStack(spacing: 20) {
//                    Image(systemName: "anchor.fill")
//                        .font(.system(size: 80))
//                        .foregroundColor(.blue)
//                    
//                    VStack(spacing: 12) {
//                        Text(headerTitle)
//                            .font(.largeTitle)
//                            .fontWeight(.bold)
//                            .multilineTextAlignment(.center)
//                        
//                        Text(headerSubtitle)
//                            .font(.title3)
//                            .foregroundColor(.secondary)
//                            .multilineTextAlignment(.center)
//                    }
//                }
//                .padding(.top, 20)
//                
//                // Feature grid
//                LazyVGrid(columns: [
//                    GridItem(.flexible()),
//                    GridItem(.flexible())
//                ], spacing: 20) {
//                    FeatureCard(icon: "cloud.sun.fill", title: "Live Weather", description: "Real-time maritime conditions")
//                    FeatureCard(icon: "waveform.path", title: "Tidal Data", description: "Accurate predictions")
//                    FeatureCard(icon: "map.fill", title: "Navigation", description: "Professional tools")
//                    FeatureCard(icon: "icloud.fill", title: "iCloud Sync", description: "Cross-device sync")
//                }
//                .padding(.horizontal)
//                
//                // Subscription options with prominent pricing
//                if isLoading {
//                    ProgressView("Loading subscription options...")
//                        .padding()
//                } else {
//                    AppleCompliantSubscriptionView(products: availableProducts)
//                }
//                
//                // Legal Links Section
//                VStack(spacing: 16) {
//                    HStack(spacing: 20) {
//                        Link("Terms of Service", destination: URL(string: "https://your-app-website.com/terms")!)
//                            .font(.caption)
//                            .foregroundColor(.blue)
//                        
//                        Link("Privacy Policy", destination: URL(string: "https://your-app-website.com/privacy")!)
//                            .font(.caption)
//                            .foregroundColor(.blue)
//                        
//                        Link("Manage Subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
//                            .font(.caption)
//                            .foregroundColor(.blue)
//                    }
//                    
//                    // Restore purchases button
//                    Button(action: {
//                        Task {
//                            await subscriptionService.restorePurchases()
//                        }
//                    }) {
//                        Text("Restore Purchases")
//                            .font(.subheadline)
//                            .foregroundColor(.blue)
//                    }
//                    .padding(.bottom, 20)
//                }
//                
//                // Apple Required Auto-Renewal Disclosure
//                VStack(spacing: 12) {
//                    Text("Subscription Terms")
//                        .font(.footnote)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.primary)
//                    
//                    Text("Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period. Account will be charged for renewal within 24-hours prior to the end of the current period. Subscriptions may be managed by the user and auto-renewal may be turned off by going to the user's Account Settings after purchase.")
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                        .multilineTextAlignment(.center)
//                        .padding(.horizontal)
//                    
//                    // Additional standard terms
//                    VStack(spacing: 8) {
//                        Text("• Payment will be charged to iTunes Account at confirmation of purchase")
//                        Text("• Subscription automatically renews unless cancelled")
//                        Text("• Cancel anytime in App Store account settings")
//                    }
//                    .font(.caption2)
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal)
//                    .padding(.bottom, 20)
//                }
//            }
//        }
//        .task {
//            await loadProducts()
//        }
//        .alert("Error", isPresented: $showingError) {
//            Button("OK") { }
//        } message: {
//            Text(errorMessage)
//        }
//    }
//    
//   private var headerTitle: String {
//        switch subscriptionService.subscriptionStatus {
//        case .trialExpired:
//            return "Continue Your Journey"
//        case .expired:
//            return "Reactivate Premium"
//        default:
//            return "Unlock Premium Features"
//        }
//    }
//    
//    private var headerSubtitle: String {
//        switch subscriptionService.subscriptionStatus {
//        case .trialExpired:
//            return "Your trial has ended. Subscribe to continue using all features."
//        case .expired:
//            return "Reactivate your subscription to restore full access."
//        default:
//            return "Get full access to professional maritime tools."
//        }
//    }
//    
//    private func loadProducts() async {
//        do {
//            availableProducts = try await subscriptionService.getAvailableProducts()
//            isLoading = false
//        } catch {
//            errorMessage = "Failed to load subscription options: \(error.localizedDescription)"
//            showingError = true
//            isLoading = false
//        }
//    }
//}
//
//struct FeatureCard: View {
//    let icon: String
//    let title: String
//    let description: String
//    
//    var body: some View {
//        VStack(spacing: 12) {
//            Image(systemName: icon)
//                .font(.system(size: 30))
//                .foregroundColor(.blue)
//            
//            Text(title)
//                .font(.headline)
//            
//            Text(description)
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.center)
//        }
//        .padding()
//        .background(.regularMaterial)
//        .cornerRadius(12)
//    }
//}
//
//// MARK: - Apple-Compliant Subscription View
//
//struct AppleCompliantSubscriptionView: View {
//    let products: [Product]
//    @EnvironmentObject var subscriptionService: SimpleSubscription
//    
//    var body: some View {
//        VStack(spacing: 24) {
//            ForEach(products, id: \.id) { product in
//                AppleCompliantSubscriptionCard(product: product)
//            }
//        }
//        .padding(.horizontal)
//    }
//}
//
//struct AppleCompliantSubscriptionCard: View {
//    let product: Product
//    @EnvironmentObject var subscriptionService: SimpleSubscription
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            // Product title
//            Text(product.displayName)
//                .font(.title2)
//                .fontWeight(.semibold)
//                .multilineTextAlignment(.center)
//            
//            // PROMINENT TRIAL MESSAGING (Apple Compliance)
//            if case .firstLaunch = subscriptionService.subscriptionStatus {
//                VStack(spacing: 8) {
//                    Text("Get 14 days free")
//                        .font(.title2)
//                        .fontWeight(.bold)
//                        .foregroundColor(.blue)
//                    
//                    Text("then \(product.displayPrice)/month")
//                        .font(.title3)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.primary)
//                }
//                .padding(.vertical, 12)
//                .padding(.horizontal, 20)
//                .background(Color.blue.opacity(0.1))
//                .cornerRadius(12)
//            } else {
//                // For expired users, show monthly price prominently
//                VStack(spacing: 4) {
//                    Text(product.displayPrice)
//                        .font(.system(size: 48, weight: .bold, design: .default))
//                        .foregroundColor(.primary)
//                    
//                    Text("per month")
//                        .font(.title2)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.primary)
//                }
//            }
//            
//            // Subscribe button
//            Button(action: {
//                Task {
//                    do {
//                        try await subscriptionService.subscribe(to: product.id)
//                    } catch {
//                        DebugLogger.shared.log("❌ SUBSCRIPTION: Purchase failed: \(error)", category: "SUBSCRIPTION")
//                    }
//                }
//            }) {
//                Text(buttonText)
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color.blue)
//                    .cornerRadius(12)
//            }
//            .disabled(subscriptionService.isLoading)
//            
//            if subscriptionService.isLoading {
//                ProgressView()
//                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
//            }
//        }
//        .padding(24)
//        .background(.regularMaterial)
//        .cornerRadius(16)
//        .overlay(
//            RoundedRectangle(cornerRadius: 16)
//                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
//        )
//    }
//    
//    private var buttonText: String {
//        switch subscriptionService.subscriptionStatus {
//        case .firstLaunch, .unknown:
//            return "Start Free Trial"
//        case .trialExpired:
//            return "Subscribe Now"
//        case .expired:
//            return "Reactivate"
//        default:
//            return "Subscribe"
//        }
//    }
//}






























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
        switch subscriptionService.subscriptionStatus {
        case .trialExpired:
            return "Continue Your Journey"
        case .expired:
            return "Welcome Back"
        default:
            return "Premium Access Required"
        }
    }
    
    private var headerSubtitle: String {
        switch subscriptionService.subscriptionStatus {
        case .trialExpired:
            return "Your free trial has ended. Continue with premium to keep using all features."
        case .expired:
            return "Reactivate your subscription to restore full access to premium features."
        default:
            return "Subscribe to access all professional maritime navigation tools."
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
        VStack(spacing: 20) {
            // Product title
            Text(product.displayName)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            // PRICING DISPLAY - Focused on continuation since first-time users don't see this screen
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
        case .trialExpired:
            return "Continue with Premium"
        case .expired:
            return "Reactivate Subscription"
        case .firstLaunch, .unknown:
            return "Subscribe Now" // Fallback, though first launch users shouldn't see this
        default:
            return "Subscribe Now"
        }
    }
}
