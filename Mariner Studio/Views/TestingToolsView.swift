import SwiftUI
import CloudKit

struct TestingToolsView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Button("Check Subscription Status") {
                    Task {
                        await subscriptionService.determineSubscriptionStatus()
                        await MainActor.run {
                            alertMessage = "Subscription status checked - see console logs"
                            showingAlert = true
                        }
                    }
                }
                
                Button("Reset Everything") {
                    subscriptionService.resetSubscriptionState()
                    alertMessage = "Everything reset"
                    showingAlert = true
                }
                .foregroundColor(.red)
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
        .environmentObject(SimpleSubscription())
}