import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @StateObject private var subscriptionService = SimpleSubscription()
    @State private var showingAbout = false
    @State private var showingSubscription = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
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
                        icon: "crown.fill",
                        title: "Subscription",
                        iconColor: .yellow
                    ) {
                        showingSubscription = true
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
                    
                    Divider()
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Version")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(getAppVersion())
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Build")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(getBuildNumber())
                                .foregroundColor(.primary)
                        }
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
    @EnvironmentObject var subscriptionService: SimpleSubscription
    
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
    @EnvironmentObject var subscriptionService: SimpleSubscription
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
                
                if case .inTrial(let daysRemaining) = subscriptionService.subscriptionStatus {
                    TrialInformationCard(daysRemaining: daysRemaining)
                }
                
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
    @EnvironmentObject var subscriptionService: SimpleSubscription
    
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
            case .inTrial:
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
            case .firstLaunch:
                Image(systemName: "gift.fill")
                    .foregroundColor(.green)
            case .trialExpired, .expired:
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
        case .inTrial(let days):
            return "Free Trial Active"
        case .firstLaunch:
            return "Welcome to Mariner Studio"
        case .trialExpired:
            return "Trial Expired"
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
        case .inTrial(let days):
            return "\(days) days remaining"
        case .firstLaunch:
            return "Start your 14-day free trial"
        case .trialExpired:
            return "Subscribe to continue using the app"
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
            case .inTrial:
                Text("TRIAL")
                    .font(.caption.bold())
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
        case .inTrial, .firstLaunch:
            return Color.blue.opacity(0.1)
        case .trialExpired, .expired:
            return Color.red.opacity(0.1)
        default:
            return Color.gray.opacity(0.1)
        }
    }
}

struct SubscriptionActionsGrid: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            
            if subscriptionService.needsPaywall {
                UpgradeToProButton()
                    .environmentObject(subscriptionService)
            }
            
            
            if case .subscribed = subscriptionService.subscriptionStatus {
                CancelSubscriptionButton()
            }
        }
    }
}

struct UpgradeToProButton: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    
    var body: some View {
        Button(action: {
            Task {
                do {
                    try await subscriptionService.subscribe(to: "mariner_pro_monthly14")
                } catch {
                    DebugLogger.shared.log("❌ SUBSCRIPTION: Upgrade failed: \(error)", category: "SUBSCRIPTION_SETTINGS")
                }
            }
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

struct TrialInformationCard: View {
    let daysRemaining: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                
                Text("Trial Information")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Full access to all maritime features")
                Text("• Weather data, tides, currents, and navigation")
                Text("• Cloud sync across all your devices")
                
                if daysRemaining <= 3 {
                    Text("• Subscribe before trial ends to continue")
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.05))
        )
    }
}

struct SubscriptionDetailsCard: View {
    @EnvironmentObject var subscriptionService: SimpleSubscription
    
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
                SubscriptionDetailRow(label: "Status", value: subscriptionService.getSubscriptionStatusMessage())
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


