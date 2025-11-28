import SwiftUI
import RevenueCat
import RevenueCatUI

struct AppSettingsView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    @State private var showingAbout = false
    @State private var showingSubscription = false
    @State private var showingVesselSettings = false
    @State private var showFeedback = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Spacer()

                    Button(action: {
                        showFeedback = true
                    }) {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Menu Options
                VStack(spacing: 1) {
                    SettingsMenuRow(
                        icon: "info.circle.fill",
                        title: "About",
                        iconColor: .blue
                    ) {
                        showingAbout = true
                    }
                    
                    SettingsMenuRow(
                        icon: "ferry.fill",
                        title: "Vessel",
                        iconColor: .orange
                    ) {
                        showingVesselSettings = true
                    }

                    SettingsMenuRow(
                        icon: "doc.text.fill",
                        title: "Legal",
                        iconColor: .gray
                    ) {
                        openTermsOfUse()
                    }
                    
                    SettingsMenuRow(
                        icon: "hand.raised.fill",
                        title: "Privacy",
                        iconColor: .green
                    ) {
                        openPrivacyPolicy()
                    }
                    
                }
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color.white
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAbout) {
            AboutSheet()
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionSheet()
                .environmentObject(subscriptionService)
        }
        .sheet(isPresented: $showingVesselSettings) {
            VesselSettingsSheet()
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(sourceView: "App Settings")
        }
    }
    
    private func openPrivacyPolicy() {
        DebugLogger.shared.log("Opening Privacy Policy link", category: "SETTINGS")
        if let url = URL(string: "https://marinerstudio.com/privacy/") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfUse() {
        DebugLogger.shared.log("Opening Terms of Use link", category: "SETTINGS")
        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Menu Components

struct SettingsMenuRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                    .font(.title2)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sheet Views

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About Mariner Studio")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Mariner Studio provides comprehensive maritime weather data, tidal information, and navigation tools for maritime professionals and enthusiasts.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("About")
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
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

struct SubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SubscriptionManagementSection()
                        .environmentObject(subscriptionService)
                }
                .padding()
            }
            .navigationTitle("Subscription")
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




// MARK: - Supporting Views

struct AppInformationSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About Mariner Studio")
                .font(.headline)
                .padding(.horizontal)
            
            Text("Mariner Studio provides comprehensive maritime weather data, tidal information, and navigation tools for maritime professionals and enthusiasts.")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                AppInfoRow(label: "Version", value: getAppVersion())
                AppInfoRow(label: "Build", value: getBuildNumber())
            }
            .padding(.horizontal)
        }
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

struct LegalSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legal")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                PrivacyPolicyButton()
                TermsOfUseButton()
            }
            .padding(.horizontal)
        }
    }
}

struct PrivacyPolicyButton: View {
    var body: some View {
        Button(action: {
            openPrivacyPolicy()
        }) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Privacy Policy")
                        .font(.body)
                        .foregroundColor(.primary)
                    Text("View our privacy policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func openPrivacyPolicy() {
        DebugLogger.shared.log("Opening Privacy Policy link", category: "SETTINGS")
        if let url = URL(string: "https://marinerstudio.com/privacy/") {
            UIApplication.shared.open(url)
        }
    }
}

struct TermsOfUseButton: View {
    var body: some View {
        Button(action: {
            openTermsOfUse()
        }) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Terms of Use")
                        .font(.body)
                        .foregroundColor(.primary)
                    Text("View terms and conditions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func openTermsOfUse() {
        DebugLogger.shared.log("Opening Terms of Use link", category: "SETTINGS")
        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
            UIApplication.shared.open(url)
        }
    }
}

struct CloudKitSection: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("iCloud Sync")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                // Status Display
                HStack {
                    Image(systemName: cloudKitManager.accountStatus == .available ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(cloudKitManager.accountStatus == .available ? .green : .orange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cloudKitManager.accountStatus == .available ? "iCloud Sync Active" : "iCloud Setup Needed")
                            .font(.body)
                            .foregroundColor(.primary)
                        Text(cloudKitManager.getAccountStatusMessage())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    NavigationLink(destination: CloudKitStatusView().environmentObject(cloudKitManager)) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(cloudKitManager.accountStatus == .available ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                )
            }
            .padding(.horizontal)
        }
    }
}


struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About Mariner Studio")
                .font(.headline)
                .padding(.horizontal)
            
            Text("Mariner Studio provides comprehensive maritime weather data, tidal information, and navigation tools for maritime professionals and enthusiasts.")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
}

struct DividerView: View {
    var body: some View {
        Divider()
            .padding(.horizontal)
    }
}

struct AppInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Subscription Management Section

struct SubscriptionManagementSection: View {
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    @State private var showingSubscriptionDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                SubscriptionStatusCard()
                    .environmentObject(subscriptionService)
                
                SubscriptionActionsGrid()
                    .environmentObject(subscriptionService)
                
                
                if case .subscribed = subscriptionService.subscriptionStatus {
                    SubscriptionDetailsCard()
                        .environmentObject(subscriptionService)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct SubscriptionStatusCard: View {
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    
    var body: some View {
        HStack {
            statusIcon
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.body)
                    .foregroundColor(.primary)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if subscriptionService.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                statusBadge
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(statusBackgroundColor)
        )
    }
    
    private var statusIcon: some View {
        Group {
            switch subscriptionService.subscriptionStatus {
            case .subscribed:
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
            case .firstLaunch:
                Image(systemName: "gift.fill")
                    .foregroundColor(.green)
            case .expired:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            default:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var statusTitle: String {
        switch subscriptionService.subscriptionStatus {
        case .subscribed:
            return "Mariner Studio Pro"
        case .firstLaunch:
            return "Welcome to Mariner Studio"
        case .expired:
            return "Subscription Expired"
        default:
            return "Checking Status..."
        }
    }
    
    private var statusSubtitle: String {
        switch subscriptionService.subscriptionStatus {
        case .subscribed:
            return "Full access to all features"
        case .firstLaunch:
            return "Subscribe for full access"
        case .expired:
            return "Renew to restore access"
        default:
            return "Loading subscription information..."
        }
    }
    
    private var statusBadge: some View {
        Group {
            switch subscriptionService.subscriptionStatus {
            case .subscribed:
                Text("PRO")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow)
                    .clipShape(Capsule())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
            default:
                EmptyView()
            }
        }
    }
    
    private var statusBackgroundColor: Color {
        switch subscriptionService.subscriptionStatus {
        case .subscribed:
            return Color.yellow.opacity(0.1)
        case .firstLaunch:
            return Color.blue.opacity(0.1)
        case .expired:
            return Color.red.opacity(0.1)
        default:
            return Color.gray.opacity(0.1)
        }
    }
}

struct SubscriptionActionsGrid: View {
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            
            if subscriptionService.needsPaywall {
                UpgradeToProButton()
                    .environmentObject(subscriptionService)
                
                RestorePurchasesButton()
                    .environmentObject(subscriptionService)
            }
            
            if case .subscribed = subscriptionService.subscriptionStatus {
                CancelSubscriptionButton()
                
                RestorePurchasesButton()
                    .environmentObject(subscriptionService)
            }
        }
    }
}

struct UpgradeToProButton: View {
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    @State private var showPaywall = false
    @State private var testOffering: Offering?

    var body: some View {
        Button(action: {
            showPaywall = true
        }) {
            VStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)

                Text("Upgrade")
                    .font(.caption.bold())
                    .foregroundColor(.primary)

                Text("$2.99/month")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showPaywall) {
            Group {
                if let offering = testOffering {
                    PaywallView(offering: offering)
                        .onPurchaseCompleted { customerInfo in
                            showPaywall = false
                        }
                } else {
                    PaywallView()
                        .onPurchaseCompleted { customerInfo in
                            showPaywall = false
                        }
                }
            }
        }
        .task {
            // Load the new paywall offering
            do {
                let offerings = try await Purchases.shared.offerings()
                testOffering = offerings.offering(identifier: "rev_cat_template")
            } catch {
                // Silently fail, will fall back to default offering
            }
        }
    }
}



struct RestorePurchasesButton: View {
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    
    var body: some View {
        Button(action: {
            Task {
                await subscriptionService.restorePurchases()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: "arrow.clockwise.circle")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Restore")
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                
                Text("Purchases")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(subscriptionService.isLoading)
    }
}

struct CancelSubscriptionButton: View {
    var body: some View {
        Button(action: {
            openAppStoreSubscriptions()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red)
                    .font(.title3)
                
                Text("Cancel")
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                
                Text("Subscription")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func openAppStoreSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}


struct SubscriptionDetailsCard: View {
    @EnvironmentObject var subscriptionService: RevenueCatSubscription
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                
                Text("Subscription Details")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                SubscriptionDetailRow(label: "Plan", value: "Mariner Studio Pro")
                SubscriptionDetailRow(label: "Price", value: "$2.99 per month")
                SubscriptionDetailRow(label: "Billing", value: "Auto-renewing")
                SubscriptionDetailRow(label: "Status", value: subscriptionService.subscriptionStatusMessage)
            }
            
            Text("Manage billing and cancellation through the App Store")
                .font(.caption2)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.05))
        )
    }
}

struct SubscriptionDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Vessel Settings Sheet

struct VesselSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var vesselSettings = VesselSettings.shared

    @State private var vesselName: String = ""
    @State private var lengthText: String = ""
    @State private var widthText: String = ""
    @State private var draftText: String = ""
    @State private var speedText: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vessel Information")) {
                    HStack {
                        Text("Name")
                            .foregroundColor(.secondary)
                        TextField("My Vessel", text: $vesselName)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Dimensions (feet)")) {
                    HStack {
                        Text("Length")
                            .foregroundColor(.secondary)
                        TextField("0", text: $lengthText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Width (Beam)")
                            .foregroundColor(.secondary)
                        TextField("0", text: $widthText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Draft")
                            .foregroundColor(.secondary)
                        TextField("0", text: $draftText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Performance"), footer: Text("Default speed used for route ETA calculations")) {
                    HStack {
                        Text("Average Speed (knots)")
                            .foregroundColor(.secondary)
                        TextField("10", text: $speedText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Button(action: {
                        resetToDefaults()
                    }) {
                        HStack {
                            Spacer()
                            Text("Reset to Defaults")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Vessel Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }

    private func loadCurrentSettings() {
        vesselName = vesselSettings.vesselName
        lengthText = vesselSettings.vesselLength > 0 ? String(format: "%.1f", vesselSettings.vesselLength) : ""
        widthText = vesselSettings.vesselWidth > 0 ? String(format: "%.1f", vesselSettings.vesselWidth) : ""
        draftText = vesselSettings.vesselDraft > 0 ? String(format: "%.1f", vesselSettings.vesselDraft) : ""
        speedText = vesselSettings.averageSpeed > 0 ? String(format: "%.1f", vesselSettings.averageSpeed) : ""
    }

    private func saveSettings() {
        vesselSettings.vesselName = vesselName
        vesselSettings.vesselLength = Double(lengthText) ?? 0
        vesselSettings.vesselWidth = Double(widthText) ?? 0
        vesselSettings.vesselDraft = Double(draftText) ?? 0
        vesselSettings.averageSpeed = Double(speedText) ?? 0
        print("🚢 VesselSettings: Saved - Name: '\(vesselName)', Length: \(lengthText), Width: \(widthText), Draft: \(draftText), Speed: \(speedText)")
    }

    private func resetToDefaults() {
        vesselName = ""
        lengthText = ""
        widthText = ""
        draftText = ""
        speedText = ""
    }
}

