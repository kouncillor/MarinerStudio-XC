import SwiftUI
import CloudKit

/// Simple view to show CloudKit authentication status
/// Replaces complex Supabase authentication screens
struct CloudKitStatusView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Header
            VStack(spacing: 8) {
                Image(systemName: "icloud")
                    .font(.system(size: 50))
                    .foregroundColor(cloudKitManager.accountStatus == .available ? .blue : .orange)
                
                Text("iCloud Sync")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Status Information
            VStack(alignment: .leading, spacing: 15) {
                
                // Account Status
                HStack {
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading) {
                        Text("Account Status")
                            .font(.headline)
                        Text(cloudKitManager.getAccountStatusMessage())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Sync Status
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading) {
                        Text("Data Sync")
                            .font(.headline)
                        
                        if let lastSync = cloudKitManager.lastSyncDate {
                            Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No sync activity yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                if cloudKitManager.accountStatus == .available {
                    Divider()
                    
                    // Features
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Features Available")
                            .font(.headline)
                        
                        FeatureRow(icon: "heart.fill", title: "Favorites sync across devices")
                        FeatureRow(icon: "arrow.clockwise", title: "Automatic background sync")
                        FeatureRow(icon: "lock.shield", title: "Private iCloud storage")
                        FeatureRow(icon: "checkmark.circle", title: "No sign-in required")
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            if cloudKitManager.accountStatus != .available {
                // Help Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to Enable iCloud Sync")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HelpStep(number: "1", text: "Open Settings app")
                        HelpStep(number: "2", text: "Tap your name at the top")
                        HelpStep(number: "3", text: "Tap 'iCloud'")
                        HelpStep(number: "4", text: "Make sure iCloud Drive is enabled")
                        HelpStep(number: "5", text: "Restart Mariner Studio")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Manual Actions
            VStack(spacing: 12) {
                Button("Check Status") {
                    Task {
                        await cloudKitManager.checkAccountStatus()
                    }
                }
                .buttonStyle(.bordered)
                
                if cloudKitManager.accountStatus == .available {
                    Button("Trigger Sync") {
                        Task {
                            await cloudKitManager.triggerSync()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("iCloud Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            DebugLogger.shared.log("☁️ AUTH: CloudKit status view appeared", category: "CLOUDKIT_AUTH")
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        switch cloudKitManager.accountStatus {
        case .available:
            return "checkmark.circle.fill"
        case .noAccount:
            return "exclamationmark.triangle.fill"
        case .restricted:
            return "lock.circle.fill"
        case .couldNotDetermine:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch cloudKitManager.accountStatus {
        case .available:
            return .green
        case .noAccount, .restricted, .couldNotDetermine:
            return .orange
        @unknown default:
            return .orange
        }
    }
}

// MARK: - Helper Views

struct FeatureRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 16)
            
            Text(title)
                .font(.caption)
            
            Spacer()
        }
    }
}

struct HelpStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
            
            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        CloudKitStatusView()
            .environmentObject(CloudKitManager.shared)
    }
}