////
////  TrialExplanationView.swift
////  Mariner Studio
////
////  Created by Timothy Russell on 9/10/25.
////
//
//
//import SwiftUI
//
//struct TrialExplanationView: View {
//    @EnvironmentObject var subscriptionService: SimpleSubscription
//    @Environment(\.dismiss) private var dismiss
//    
//    var body: some View {
//        ZStack {
//            // Dark background
//            Color.black
//                .ignoresSafeArea()
//            
//            VStack(spacing: 0) {
//                // Header
//                VStack(spacing: 16) {
//                    HStack {
//                        Button(action: {
//                            dismiss()
//                        }) {
//                            Image(systemName: "xmark")
//                                .foregroundColor(.white)
//                                .font(.title2)
//                                .frame(width: 44, height: 44)
//                                .background(Color.gray.opacity(0.3))
//                                .clipShape(Circle())
//                        }
//                        
//                        Spacer()
//                    }
//                    .padding(.horizontal)
//                    .padding(.top, 20)
//                    
//                    Text("Start Free Trial")
//                        .font(.largeTitle)
//                        .fontWeight(.bold)
//                        .foregroundColor(.white)
//                    
//                    Text("How does your free trial work?")
//                        .font(.title3)
//                        .foregroundColor(.white.opacity(0.8))
//                }
//                .padding(.bottom, 40)
//                
//                // Timeline
//                VStack(spacing: 0) {
//                    // Today
//                    TimelineItem(
//                        icon: "calendar",
//                        iconColor: .green,
//                        title: "Today",
//                        description: "Enjoy unlimited access to all features. Find out if Mariner Studio is right for you.",
//                        isLast: false
//                    )
//                    
//                    // Day 10: Trial Reminder
//                    TimelineItem(
//                        icon: "bell",
//                        iconColor: .green,
//                        title: "Day 10: Trial Reminder",
//                        description: "We will show you a banner. You will have 4 more days to decide on your subscription.",
//                        isLast: false
//                    )
//                    
//                    // Day 14: Trial Ends
//                    TimelineItem(
//                        icon: "star",
//                        iconColor: .green,
//                        title: "Day 14: Trial Ends",
//                        description: "Your subscription will begin and you'll be charged. Or you can cancel and lose access to premium features.",
//                        isLast: true
//                    )
//                }
//                .padding(.horizontal, 40)
//                
//                Spacer()
//                
//                // Character illustration placeholder
//                VStack(spacing: 20) {
//                    // Anchor icon as character placeholder
//                    Image(systemName: "anchor.fill")
//                        .font(.system(size: 80))
//                        .foregroundColor(.green)
//                    
//                    // Pricing
//                    VStack(spacing: 4) {
//                        Text("Unlimited free access for 14 days,")
//                            .font(.title3)
//                            .foregroundColor(.white)
//                        
//                        Text("then $2.99 per month")
//                            .font(.title2)
//                            .fontWeight(.bold)
//                            .foregroundColor(.white)
//                    }
//                }
//                .padding(.bottom, 30)
//                
//                // Buttons
//                VStack(spacing: 16) {
//                    Button(action: {
//                        Task {
//                            await subscriptionService.startTrial()
//                            dismiss()
//                        }
//                    }) {
//                        Text("Try for $0.00")
//                            .font(.title2)
//                            .fontWeight(.bold)
//                            .foregroundColor(.black)
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color.green)
//                            .cornerRadius(25)
//                    }
//                    .padding(.horizontal)
//                    
//                    Button(action: {
//                        dismiss()
//                    }) {
//                        Text("SKIP")
//                            .font(.headline)
//                            .fontWeight(.semibold)
//                            .foregroundColor(.green)
//                    }
//                }
//                .padding(.bottom, 40)
//            }
//        }
//    }
//}
//
//struct TimelineItem: View {
//    let icon: String
//    let iconColor: Color
//    let title: String
//    let description: String
//    let isLast: Bool
//    
//    var body: some View {
//        HStack(alignment: .top, spacing: 16) {
//            // Timeline line and icon
//            VStack(spacing: 0) {
//                // Icon
//                ZStack {
//                    Circle()
//                        .fill(iconColor)
//                        .frame(width: 40, height: 40)
//                    
//                    Image(systemName: icon)
//                        .foregroundColor(.black)
//                        .font(.system(size: 18, weight: .bold))
//                }
//                
//                // Line (if not last)
//                if !isLast {
//                    Rectangle()
//                        .fill(iconColor)
//                        .frame(width: 3, height: 60)
//                        .padding(.top, 8)
//                }
//            }
//            
//            // Content
//            VStack(alignment: .leading, spacing: 8) {
//                Text(title)
//                    .font(.title3)
//                    .fontWeight(.bold)
//                    .foregroundColor(.white)
//                
//                Text(description)
//                    .font(.body)
//                    .foregroundColor(.white.opacity(0.8))
//                    .fixedSize(horizontal: false, vertical: true)
//                
//                if !isLast {
//                    Spacer()
//                        .frame(height: 40)
//                }
//            }
//            
//            Spacer()
//        }
//    }
//}
//
//#Preview {
//    TrialExplanationView()
//        .environmentObject(SimpleSubscription())
//}







import SwiftUI

struct TrialExplanationView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Light background to match app theme
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Start Free Trial")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.top, 40)
                .padding(.bottom, 40)
                
                // Timeline
                VStack(spacing: 0) {
                    // Today
                    TimelineItem(
                        icon: "calendar",
                        iconColor: .blue,
                        title: "Today",
                        description: "Get immediate access to all features. Find out if Mariner Studio is right for you.",
                        isLast: false
                    )
                    
                    // Day 10: Trial Reminder
                    TimelineItem(
                        icon: "bell",
                        iconColor: .blue,
                        title: "Day 10: Reminder",
                        description: "We'll remind you that billing begins in 4 days. Cancel anytime in Settings if you change your mind.",
                        isLast: false
                    )
                    
                    // Day 14: Trial Ends
                    TimelineItem(
                        icon: "star",
                        iconColor: .blue,
                        title: "Day 14: Billing Begins",
                        description: "Your subscription starts billing at $2.99/month. Cancel anytime before then to avoid charges.",
                        isLast: true
                    )
                }
                .padding(.horizontal, 40)
                
                Spacer()
                    .frame(maxHeight: 30)
                
                // Character illustration placeholder
                VStack(spacing: 16) {
                    // Anchor icon as character placeholder
                    Image(systemName: "anchor.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    // Pricing
                    VStack(spacing: 4) {
                        Text("Start your subscription with")
                            .font(.title3)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 0) {
                            Text("3 days free, then ")
                                .font(.title3)
                                .foregroundColor(.primary)
                            
                            Text("$2.99/month")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.bottom, 20)
                
                // Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            do {
                                try await subscriptionService.subscribe(to: "mariner_pro_monthly14")
                                dismiss()
                            } catch {
                                DebugLogger.shared.log("❌ TRIAL_SUB: Subscription failed: \(error)", category: "TRIAL_SUBSCRIPTION")
                            }
                        }
                    }) {
                        Text("Start Subscription")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(subscriptionService.isLoading)
                    
                    if subscriptionService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    }
                    
                    Button(action: {
                        subscriptionService.skipTrial()
                        dismiss()
                    }) {
                        Text("SKIP")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 16)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct TimelineItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline line and icon
            VStack(spacing: 0) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                }
                
                // Line (if not last)
                if !isLast {
                    Rectangle()
                        .fill(iconColor)
                        .frame(width: 3, height: 60)
                        .padding(.top, 8)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !isLast {
                    Spacer()
                        .frame(height: 40)
                }
            }
            
            Spacer()
        }
    }
}

#Preview {
    TrialExplanationView()
        .environmentObject(SimpleSubscription())
}
