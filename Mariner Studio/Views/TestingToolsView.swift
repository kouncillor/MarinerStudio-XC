import SwiftUI
import CloudKit

struct TestingToolsView: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Subscription Testing
                Section("Subscription Testing") {
                    Button("Check Subscription Status") {
                        Task {
                            await subscriptionService.determineSubscriptionStatus()
                            await MainActor.run {
                                alertMessage = "Subscription status checked - see console logs"
                                showingAlert = true
                            }
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button("Restore Purchases") {
                        Task {
                            await subscriptionService.restorePurchases()
                            await MainActor.run {
                                alertMessage = "Restore purchases completed - see console logs"
                                showingAlert = true
                            }
                        }
                    }
                    .foregroundColor(.green)
                    
                    Button("Load Available Products") {
                        Task {
                            do {
                                let products = try await subscriptionService.getAvailableProducts()
                                await MainActor.run {
                                    alertMessage = "Found \(products.count) products - see console logs for details"
                                    showingAlert = true
                                }
                            } catch {
                                await MainActor.run {
                                    alertMessage = "Error loading products: \(error.localizedDescription)"
                                    showingAlert = true
                                }
                            }
                        }
                    }
                    .foregroundColor(.purple)
                    
                    Button("Reset to First Launch (No Subscription)") {
                        // Clear ALL subscription and trial data
                        UserDefaults.standard.removeObject(forKey: "hasUsedTrial")
                        UserDefaults.standard.removeObject(forKey: "trialStartDate")
                        UserDefaults.standard.removeObject(forKey: "subscriptionStatus")
                        UserDefaults.standard.removeObject(forKey: "subscriptionProductId")
                        UserDefaults.standard.removeObject(forKey: "subscriptionPurchaseDate")
                        UserDefaults.standard.removeObject(forKey: "debugOverrideSubscription")
                        UserDefaults.standard.removeObject(forKey: "localWeatherUsageDate")
                        UserDefaults.standard.removeObject(forKey: "localTideUsageDate")
                        UserDefaults.standard.removeObject(forKey: "localCurrentUsageDate")
                        UserDefaults.standard.removeObject(forKey: "localNavUnitUsageDate")
                        UserDefaults.standard.removeObject(forKey: "localBuoyUsageDate")
                        UserDefaults.standard.synchronize()
                        
                        // Enable debug override to bypass StoreKit subscription check
                        #if DEBUG
                        subscriptionService.enableDebugOverride(true)
                        #endif
                        
                        Task {
                            await subscriptionService.determineSubscriptionStatus()
                            await MainActor.run {
                                alertMessage = "Reset complete - user appears as first-time installer with no subscription"
                                showingAlert = true
                            }
                        }
                    }
                    .foregroundColor(.red)
                    
                    Button("Reset Local Weather Usage") {
                        UserDefaults.standard.removeObject(forKey: "localWeatherUsageDate")
                        UserDefaults.standard.synchronize()
                        subscriptionService.objectWillChange.send()
                        alertMessage = "Local weather usage reset - can be used again today"
                        showingAlert = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("Reset Local Tide Usage") {
                        UserDefaults.standard.removeObject(forKey: "localTideUsageDate")
                        UserDefaults.standard.synchronize()
                        subscriptionService.objectWillChange.send()
                        alertMessage = "Local tide usage reset - can be used again today"
                        showingAlert = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("Reset Local Current Usage") {
                        UserDefaults.standard.removeObject(forKey: "localCurrentUsageDate")
                        UserDefaults.standard.synchronize()
                        subscriptionService.objectWillChange.send()
                        alertMessage = "Local current usage reset - can be used again today"
                        showingAlert = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("Reset Local Nav Unit Usage") {
                        UserDefaults.standard.removeObject(forKey: "localNavUnitUsageDate")
                        UserDefaults.standard.synchronize()
                        subscriptionService.objectWillChange.send()
                        alertMessage = "Local nav unit usage reset - can be used again today"
                        showingAlert = true
                    }
                    .foregroundColor(.blue)
                    
                    #if DEBUG
                    Button("Disable Debug Override") {
                        subscriptionService.enableDebugOverride(false)
                        alertMessage = "Debug override disabled - StoreKit subscriptions will be honored"
                        showingAlert = true
                    }
                    .foregroundColor(.orange)
                    #endif
                }
                
                // MARK: - Trial Testing
                Section("Trial Testing") {
                    Button("Reset to First Launch") {
                        UserDefaults.standard.removeObject(forKey: "hasUsedTrial")
                        UserDefaults.standard.removeObject(forKey: "trialStartDate")
                        UserDefaults.standard.synchronize()
                        
                        alertMessage = "Trial reset to first launch state. App will restart in 3 seconds..."
                        showingAlert = true
                        
                        // Force app to restart
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            exit(0)
                        }
                    }
                    .foregroundColor(.red)
                    
                    Button("Simulate Day 2 (Banner Appears)") {
                        let day2Date = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
                        UserDefaults.standard.set(day2Date, forKey: "trialStartDate")
                        UserDefaults.standard.set(true, forKey: "hasUsedTrial")
                        Task {
                            await subscriptionService.determineSubscriptionStatus()
                            await MainActor.run {
                                alertMessage = "Trial set to day 2 - banner should appear"
                                showingAlert = true
                            }
                        }
                    }
                    .foregroundColor(.orange)
                    
                    Button("Simulate Day 3 (Last Day)") {
                        let day3Date = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
                        UserDefaults.standard.set(day3Date, forKey: "trialStartDate")
                        UserDefaults.standard.set(true, forKey: "hasUsedTrial")
                        Task {
                            await subscriptionService.determineSubscriptionStatus()
                            await MainActor.run {
                                alertMessage = "Trial set to last day - 1 day remaining"
                                showingAlert = true
                            }
                        }
                    }
                    .foregroundColor(.orange)
                    
                    Button("Simulate Trial Expired") {
                        let expiredDate = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
                        UserDefaults.standard.set(expiredDate, forKey: "trialStartDate")
                        UserDefaults.standard.set(true, forKey: "hasUsedTrial")
                        Task {
                            await subscriptionService.determineSubscriptionStatus()
                            await MainActor.run {
                                alertMessage = "Trial expired - paywall should appear"
                                showingAlert = true
                            }
                        }
                    }
                    .foregroundColor(.red)
                }
                
                // MARK: - CloudKit Testing
                Section("CloudKit Testing") {
                    Button("Check CloudKit Status") {
                        Task {
                            await CloudKitManager.shared.checkAccountStatus()
                            await MainActor.run {
                                CloudKitManager.shared.printCloudKitStatus()
                                alertMessage = "CloudKit status checked - see console logs"
                                showingAlert = true
                            }
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button("Force CloudKit Sync") {
                        // Trigger a manual sync by updating the last sync date
                        CloudKitManager.shared.lastSyncDate = Date()
                        alertMessage = "CloudKit sync triggered"
                        showingAlert = true
                    }
                    .foregroundColor(.cyan)
                }
                
                // MARK: - System Info
                Section("System Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Status:")
                            .font(.headline)
                        
                        HStack {
                            Text("Subscription:")
                            Spacer()
                            Text(subscriptionService.getSubscriptionStatusMessage())
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Trial Days:")
                            Spacer()
                            Text("\(subscriptionService.trialDaysRemaining)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Has Access:")
                            Spacer()
                            Text(subscriptionService.hasAppAccess ? "Yes" : "No")
                                .foregroundColor(subscriptionService.hasAppAccess ? .green : .red)
                        }
                        
                        HStack {
                            Text("Needs Paywall:")
                            Spacer()
                            Text(subscriptionService.needsPaywall ? "Yes" : "No")
                                .foregroundColor(subscriptionService.needsPaywall ? .red : .green)
                        }
                        
                        HStack {
                            Text("CloudKit Status:")
                            Spacer()
                            Text(CloudKitManager.shared.accountStatus.description)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Navigation Links
                Section("Navigation Testing") {
                    NavigationLink("Core Data + CloudKit Test") {
                        CoreDataTestView()
                    }
                }
            }
            .navigationTitle("Testing Tools")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Testing Result", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - CloudKit Account Status Extension

extension CKAccountStatus {
    var description: String {
        switch self {
        case .available:
            return "Available"
        case .noAccount:
            return "No Account"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Could Not Determine"
        case .temporarilyUnavailable:
            return "Temporarily Unavailable"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Preview

struct TestingToolsView_Previews: PreviewProvider {
    static var previews: some View {
        TestingToolsView()
            .environmentObject(SimpleSubscription())
            .environmentObject(ServiceProvider())
    }
}
