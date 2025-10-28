import SwiftUI

#if DEBUG
struct DebugSubscriptionView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Paywall Testing")
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
                    
                    // Primary action - Reset to test paywall
                    Button(action: {
                        subscriptionService.resetSubscriptionState()
                    }) {
                        Label("Reset & Show Paywall", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .cornerRadius(12)
                    }
                    
                    // Restore normal operation
                    Button(action: {
                        subscriptionService.restoreNormalOperation()
                    }) {
                        Label("Restore Normal Operation", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.purple.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Secondary actions
                    HStack(spacing: 12) {
                        Button(action: {
                            subscriptionService.enableDebugSubscription()
                        }) {
                            Label("Enable Sub", systemImage: "checkmark.circle")
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            subscriptionService.disableDebugSubscription()
                        }) {
                            Label("Disable Sub", systemImage: "xmark.circle")
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Additional Info
                VStack(spacing: 8) {
                    Text("Testing Tips")
                        .font(.headline)
                    
                    Text("• Use 'Reset & Show Paywall' to test subscription flow\n• Enable/Disable Sub for quick status changes\n• This menu is automatically disabled in release builds")
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