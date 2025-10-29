import SwiftUI
import CloudKit

#if DEBUG
struct TestingToolsView: View {
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Subscription Testing")) {
                    Button("Check Subscription Status") {
                        Task {
                            await subscriptionService.determineSubscriptionStatus()
                            await MainActor.run {
                                alertMessage = "Subscription status checked - see console logs"
                                showingAlert = true
                            }
                        }
                    }

                    Button("Restore Purchases") {
                        Task {
                            await subscriptionService.restorePurchases()
                            await MainActor.run {
                                alertMessage = "Restore purchases completed - see console logs"
                                showingAlert = true
                            }
                        }
                    }
                }

                Section(header: Text("Info")) {
                    Text("Use RevenueCat dashboard for advanced testing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Testing Tools")
            .alert("Debug Info", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

#Preview {
    TestingToolsView()
        .environmentObject(RevenueCatSubscription())
}
#endif