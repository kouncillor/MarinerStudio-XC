import SwiftUI
import CloudKit

#if DEBUG
struct TestingToolsView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var ignoreSandboxSubscriptions = UserDefaults.standard.bool(forKey: "ignoreSandboxSubscriptions")
    
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
                    
                    Toggle("Ignore Sandbox Subscriptions", isOn: $ignoreSandboxSubscriptions)
                        .onChange(of: ignoreSandboxSubscriptions) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "ignoreSandboxSubscriptions")
                            Task {
                                await subscriptionService.determineSubscriptionStatus()
                                await MainActor.run {
                                    alertMessage = newValue ? "Sandbox subscriptions will be ignored" : "Sandbox subscriptions will be respected"
                                    showingAlert = true
                                }
                            }
                        }
                    
                    Button("Reset Everything") {
                        subscriptionService.resetSubscriptionState()
                        ignoreSandboxSubscriptions = true
                        UserDefaults.standard.set(true, forKey: "ignoreSandboxSubscriptions")
                        alertMessage = "Everything reset + sandbox subscriptions ignored"
                        showingAlert = true
                    }
                    .foregroundColor(.red)
                }

                // TODO: Add UI testing section when feedback view is complete
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
#endif