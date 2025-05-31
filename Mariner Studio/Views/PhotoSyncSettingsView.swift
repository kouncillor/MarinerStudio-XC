
import SwiftUI
import CloudKit

struct PhotoSyncSettingsView: View {
    @ObservedObject var iCloudService: iCloudSyncServiceImpl
    @State private var showingAccountAlert = false
    @State private var accountAlertMessage = ""
    
    var body: some View {
        Form {
            Section(header: Text("iCloud Photo Sync")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.blue)
                        Text("Sync Photos to iCloud")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $iCloudService.isEnabled)
                            .disabled(iCloudService.accountStatus != .available)
                    }
                    
                    Text("Automatically backup your navigation unit photos to iCloud for access across all your devices.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                
                // Account Status
                HStack {
                    Text("iCloud Status")
                        .font(.subheadline)
                    Spacer()
                    HStack {
                        Image(systemName: accountStatusIcon)
                            .foregroundColor(accountStatusColor)
                        Text(accountStatusText)
                            .font(.caption)
                            .foregroundColor(accountStatusColor)
                    }
                }
                
                if iCloudService.accountStatus != .available {
                    Button("Check Account Status") {
                        Task {
                            await checkAccountAndShowAlert()
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
            
            if iCloudService.isEnabled && iCloudService.accountStatus == .available {
                Section(header: Text("Sync Options")) {
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundColor(.green)
                        Text("Wi-Fi Only")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .disabled(true) // TODO: Implement Wi-Fi only option
                    }
                    
                    Button("Sync All Photos Now") {
                        Task {
                            await iCloudService.syncAllLocalPhotos()
                        }
                    }
                    .foregroundColor(.blue)
                    .disabled(iCloudService.syncProgress.isInProgress)
                }
                
                // Sync Progress Section
                if iCloudService.syncProgress.isInProgress || iCloudService.syncProgress.errorMessage != nil {
                    Section(header: Text("Sync Status")) {
                        if iCloudService.syncProgress.isInProgress {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Syncing photos...")
                                        .font(.subheadline)
                                    Spacer()
                                }
                                
                                if iCloudService.syncProgress.totalPhotos > 0 {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(iCloudService.syncProgress.processedPhotos) of \(iCloudService.syncProgress.totalPhotos) photos")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        ProgressView(value: iCloudService.syncProgress.progressPercentage)
                                            .progressViewStyle(LinearProgressViewStyle())
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if let errorMessage = iCloudService.syncProgress.errorMessage {
                            HStack {
                                Image(systemName: iCloudService.syncProgress.isInProgress ? "info.circle" :
                                      errorMessage.contains("failed") ? "exclamationmark.triangle" : "checkmark.circle")
                                    .foregroundColor(iCloudService.syncProgress.isInProgress ? .blue :
                                                   errorMessage.contains("failed") ? .orange : .green)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                Section(footer: Text("Photos are automatically synced when you take them and when you view navigation units. Use 'Sync All Photos Now' to upload any photos that haven't been synced yet.")) {
                    EmptyView()
                }
            }
        }
        .navigationTitle("Photo Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await iCloudService.checkAccountStatus()
            }
        }
        .alert("iCloud Account", isPresented: $showingAccountAlert) {
            Button("OK") { }
        } message: {
            Text(accountAlertMessage)
        }
    }
    
    // MARK: - Account Status Helpers
    
    private var accountStatusText: String {
        switch iCloudService.accountStatus {
        case .available:
            return "Available"
        case .noAccount:
            return "No Account"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Unknown"
        case .temporarilyUnavailable:
            return "Unavailable"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var accountStatusIcon: String {
        switch iCloudService.accountStatus {
        case .available:
            return "checkmark.circle.fill"
        case .noAccount:
            return "person.crop.circle.badge.xmark"
        case .restricted:
            return "lock.circle.fill"
        case .couldNotDetermine:
            return "questionmark.circle.fill"
        case .temporarilyUnavailable:
            return "exclamationmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }
    
    private var accountStatusColor: Color {
        switch iCloudService.accountStatus {
        case .available:
            return .green
        case .noAccount:
            return .red
        case .restricted:
            return .orange
        case .couldNotDetermine:
            return .gray
        case .temporarilyUnavailable:
            return .yellow
        @unknown default:
            return .gray
        }
    }
    
    private func checkAccountAndShowAlert() async {
        let status = await iCloudService.checkAccountStatus()
        
        await MainActor.run {
            switch status {
            case .available:
                accountAlertMessage = "Your iCloud account is available and ready for photo sync."
            case .noAccount:
                accountAlertMessage = "Please sign in to iCloud in Settings to enable photo sync."
            case .restricted:
                accountAlertMessage = "iCloud access is restricted. Please check your device restrictions in Settings."
            case .couldNotDetermine:
                accountAlertMessage = "Unable to determine iCloud account status. Please try again later."
            case .temporarilyUnavailable:
                accountAlertMessage = "iCloud is temporarily unavailable. Please try again later."
            @unknown default:
                accountAlertMessage = "Unknown iCloud account status."
            }
            showingAccountAlert = true
        }
    }
}

// MARK: - Preview
#if DEBUG
struct PhotoSyncSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PhotoSyncSettingsView(
                iCloudService: iCloudSyncServiceImpl(
                    fileStorageService: try! FileStorageServiceImpl()
                )
            )
        }
    }
}
#endif
