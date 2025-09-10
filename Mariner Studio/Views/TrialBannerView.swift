//import SwiftUI
//
//struct TrialBannerView: View {
//    @EnvironmentObject var subscriptionService: SimpleSubscription
//    @State private var isExpanded = false
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Main banner
//            HStack(spacing: 12) {
//                Image(systemName: "gift.fill")
//                    .foregroundColor(.blue)
//                    .font(.system(size: 16, weight: .semibold))
//                
//                Text("Free Trial: \(subscriptionService.trialDaysRemaining) days left")
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//                    .foregroundColor(.primary)
//                
//                Spacer()
//                
//                // Subscribe button (subtle)
//                Button(action: {
//                    withAnimation(.spring()) {
//                        isExpanded.toggle()
//                    }
//                }) {
//                    Text("Subscribe")
//                        .font(.caption)
//                        .fontWeight(.medium)
//                        .padding(.horizontal, 12)
//                        .padding(.vertical, 6)
//                        .background(Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(12)
//                }
//                
//                // Expand/collapse button
//                Button(action: {
//                    withAnimation(.spring()) {
//                        isExpanded.toggle()
//                    }
//                }) {
//                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//            }
//            .padding(.horizontal, 16)
//            .padding(.vertical, 12)
//            .background(.regularMaterial)
//            
//            // Expanded content
//            if isExpanded {
//                TrialDetailsView()
//                    .transition(.asymmetric(
//                        insertion: .opacity.combined(with: .move(edge: .top)),
//                        removal: .opacity.combined(with: .move(edge: .top))
//                    ))
//            }
//        }
//        .cornerRadius(12)
//        .padding(.horizontal, 16)
//        .padding(.top, 8)
//        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
//    }
//}
//
//struct TrialDetailsView: View {
//    @EnvironmentObject var subscriptionService: SimpleSubscription
//    
//    var body: some View {
//        VStack(spacing: 16) {
//            Divider()
//            
//            VStack(spacing: 12) {
//                Text("Continue with Premium")
//                    .font(.headline)
//                
//                Text("After your trial ends, continue enjoying all features with a subscription.")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.center)
//                
//                // Subscription option
//                SubscriptionOptionCard(
//                    title: "Monthly",
//                    price: "$2.99",
//                    period: "month",
//                    productID: "mariner_pro_monthly14"
//                )
//            }
//            .padding(.horizontal, 16)
//            .padding(.bottom, 16)
//        }
//        .background(.regularMaterial)
//    }
//}



















































import SwiftUI

struct TrialBannerView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main banner
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trial Ending Soon")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // IMPROVED TRIAL MESSAGING (Apple Compliance)
                    Text("\(subscriptionService.trialDaysRemaining) days left • Then $2.99/month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Expanded subscription options
            if isExpanded {
                VStack(spacing: 16) {
                    Divider()
                    
                    VStack(spacing: 12) {
                        Text("Continue with Pro Subscription")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        // APPLE COMPLIANT PRICING DISPLAY
                        VStack(spacing: 8) {
                            Text("$2.99")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.blue)
                            
                            Text("per month")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Billed monthly • Cancel anytime")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: {
                            Task {
                                do {
                                    try await subscriptionService.subscribe(to: "pro_monthly")
                                } catch {
                                    DebugLogger.shared.log("❌ SUBSCRIPTION: Purchase failed: \(error)", category: "SUBSCRIPTION")
                                }
                            }
                        }) {
                            Text("Subscribe Now")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .disabled(subscriptionService.isLoading)
                        
                        if subscriptionService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        }
                    }
                    .padding()
                }
                .background(.regularMaterial)
                .cornerRadius(12)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
