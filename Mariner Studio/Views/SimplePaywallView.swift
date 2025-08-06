import SwiftUI

/**
 * SimplePaywallView - Dead Simple $2.99/month Paywall
 * 
 * Just a button. That's it. No complexity.
 */
struct SimplePaywallView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Icon/Logo
            Image(systemName: "anchor.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            // Title
            Text("Mariner Studio Pro")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Unlock full maritime navigation features")
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Price
            VStack(spacing: 10) {
                Text("$2.99")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.blue)
                
                Text("per month")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Subscribe Button
            Button(action: {
                Task {
                    await subscribe()
                }
            }) {
                HStack {
                    if subscriptionService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(subscriptionService.isLoading ? "Processing..." : "Subscribe Now")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(subscriptionService.isLoading)
            .padding(.horizontal, 40)
            
            // Restore Button
            Button(action: {
                Task {
                    await restore()
                }
            }) {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 30)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func subscribe() async {
        DebugLogger.shared.log("💰 PAYWALL: User tapped subscribe", category: "SIMPLE_SUBSCRIPTION")
        
        do {
            try await subscriptionService.subscribe()
        } catch {
            DebugLogger.shared.log("❌ PAYWALL: Subscribe failed: \(error)", category: "SIMPLE_SUBSCRIPTION")
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func restore() async {
        DebugLogger.shared.log("🔄 PAYWALL: User tapped restore", category: "SIMPLE_SUBSCRIPTION")
        await subscriptionService.restorePurchases()
    }
}

#Preview {
    SimplePaywallView()
        .environmentObject(SimpleSubscription())
}