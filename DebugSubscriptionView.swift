import SwiftUI

#if DEBUG
struct DebugSubscriptionView: View {
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)

                    Text("RevenueCat Testing")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Debug Build Only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // Current Status
                VStack(spacing: 12) {
                    Text("Current Status")
                        .font(.headline)

                    Text(subscriptionService.subscriptionStatusMessage)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(subscriptionService.hasAppAccess ? .green : .red)
                        .padding()
                        .background(subscriptionService.hasAppAccess ? .green.opacity(0.1) : .red.opacity(0.1))
                        .cornerRadius(12)
                }

                // Quick Actions
                VStack(spacing: 16) {
                    Text("Quick Actions")
                        .font(.headline)

                    // Check status
                    Button(action: {
                        Task {
                            await subscriptionService.determineSubscriptionStatus()
                        }
                    }) {
                        Label("Refresh Status", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .cornerRadius(12)
                    }

                    // Restore purchases
                    Button(action: {
                        Task {
                            await subscriptionService.restorePurchases()
                        }
                    }) {
                        Label("Restore Purchases", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.purple.opacity(0.1))
                            .cornerRadius(12)
                    }
                }

                // Additional Info
                VStack(spacing: 8) {
                    Text("Testing Tips")
                        .font(.headline)

                    Text("• Use RevenueCat dashboard to manage test users\n• Sandbox purchases work in development\n• Use Xcode StoreKit Configuration for local testing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding()
                        .background(.gray.opacity(0.1))
                        .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Debug Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Debug Menu Trigger
struct DebugMenuTrigger: View {
    @State private var showDebugMenu = false
    @State private var tapCount = 0
    @State private var lastTapTime = Date()
    
    var body: some View {
        // Invisible trigger area
        Rectangle()
            .fill(Color.clear)
            .frame(width: 50, height: 50)
            .contentShape(Rectangle())
            .onTapGesture {
                handleDebugTap()
            }
            .sheet(isPresented: $showDebugMenu) {
                DebugSubscriptionView()
            }
    }
    
    private func handleDebugTap() {
        let now = Date()
        
        // Reset tap count if more than 2 seconds have passed
        if now.timeIntervalSince(lastTapTime) > 2.0 {
            tapCount = 1
        } else {
            tapCount += 1
        }
        
        lastTapTime = now
        
        // Show debug menu after 5 quick taps
        if tapCount >= 5 {
            showDebugMenu = true
            tapCount = 0
        }
    }
}
#endif