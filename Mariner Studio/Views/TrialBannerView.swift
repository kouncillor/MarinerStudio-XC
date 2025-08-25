import SwiftUI

struct TrialBannerView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main banner
            HStack(spacing: 12) {
                Image(systemName: "gift.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Free Trial: \(subscriptionService.trialDaysRemaining) days left")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Subscribe button (subtle)
                Button(action: {
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }) {
                    Text("Subscribe")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                // Expand/collapse button
                Button(action: {
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            // Expanded content
            if isExpanded {
                TrialDetailsView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct TrialDetailsView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    
    var body: some View {
        VStack(spacing: 16) {
            Divider()
            
            VStack(spacing: 12) {
                Text("Continue with Premium")
                    .font(.headline)
                
                Text("After your trial ends, continue enjoying all features with a subscription.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Subscription option
                SubscriptionOptionCard(
                    title: "Monthly",
                    price: "$2.99",
                    period: "month",
                    productID: "pro_monthly"
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(.regularMaterial)
    }
}