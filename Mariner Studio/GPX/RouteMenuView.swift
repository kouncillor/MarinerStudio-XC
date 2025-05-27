
//
//  RouteMenuView.swift
//  Mariner Studio
//
//  Created by Timothy Russell on 5/23/25.
//

import SwiftUI

struct RouteMenuView: View {
    @EnvironmentObject var serviceProvider: ServiceProvider
    @State private var showingServiceSelector = false
    @State private var selectedServiceType: GpxServiceType = .automatic
    @State private var showingGpxView = false
    @State private var loadedGpxFile: GpxFile?
    @State private var isLoadingFile = false
    @State private var errorMessage = ""
    
    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                // Route Favorites - Now fully functional
                NavigationLink(destination: RouteFavoritesView()) {
                    RouteMenuButtonContent(
                        icon: "star.fill",
                        title: "FAVORITES",
                        subtitle: "Your Saved Routes",
                        isSystemIcon: true,
                        iconColor: .yellow
                    )
                }
                
                // Create New Route - Uses CoreGPX for writing
                NavigationLink(destination: CreateRouteView()) {
                    RouteMenuButtonContent(
                        icon: "plus.circle.fill",
                        title: "CREATE NEW ROUTE",
                        subtitle: "Full GPX 1.1 Creation",
                        isSystemIcon: true,
                        iconColor: .orange
                    )
                }
                
                // Open GPX File - Now directly opens file picker
                Button(action: {
                    Task {
                        await openGpxFile()
                    }
                }) {
                    RouteMenuButtonContent(
                        icon: "doc.fill",
                        title: "OPEN GPX FILE",
                        subtitle: "Legacy & Modern GPX Support",
                        isSystemIcon: true,
                        iconColor: .blue
                    )
                }
                .disabled(isLoadingFile)
                
                // Import from Cloud Services
                NavigationLink(destination: CloudImportView()) {
                    RouteMenuButtonContent(
                        icon: "icloud.and.arrow.down.fill",
                        title: "CLOUD IMPORT",
                        subtitle: "iCloud, Dropbox, Google Drive",
                        isSystemIcon: true,
                        iconColor: .purple
                    )
                }
                
                // Route Converter - Convert between formats
                NavigationLink(destination: RouteConverterView()) {
                    RouteMenuButtonContent(
                        icon: "arrow.triangle.2.circlepath",
                        title: "CONVERT ROUTES",
                        subtitle: "GPX, KML, TCX, FIT",
                        isSystemIcon: true,
                        iconColor: .indigo
                    )
                }
                
                // Download Routes - COMMENTED OUT
                /*
                NavigationLink(destination: DownloadRoutesView()) {
                    RouteMenuButtonContent(
                        icon: "arrow.down.circle.fill",
                        title: "DOWNLOAD ROUTES",
                        subtitle: "Online Route Library",
                        isSystemIcon: true,
                        iconColor: .green
                    )
                }
                */
            }
            .padding()
            
            // Loading indicator
            if isLoadingFile {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading GPX file...")
                        .padding(.top)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            
            // Error message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
            }
        }
        .navigationTitle("Routes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Settings") {
                    showingServiceSelector = true
                }
            }
        }
        .sheet(isPresented: $showingServiceSelector) {
            ServiceSelectorView(
                selectedServiceType: $selectedServiceType,
                onServiceChanged: { newType in
                    GpxServiceFactory.shared.setDefaultServiceType(newType)
                }
            )
        }
        .navigationDestination(isPresented: $showingGpxView) {
            if let gpxFile = loadedGpxFile {
                GpxView(
                    serviceProvider: serviceProvider,
                    preLoadedRoute: gpxFile
                )
            }
        }
        .onAppear {
            // Print factory status for debugging
            GpxServiceFactory.shared.printServiceStatus()
        }
    }
    
    // MARK: - File Loading Functions
    
    private func openGpxFile() async {
        await MainActor.run {
            isLoadingFile = true
            errorMessage = ""
            loadedGpxFile = nil
        }
        
        do {
            // Present document picker directly
            let url = try await presentDocumentPicker(fileTypes: ["com.topografix.gpx", "public.xml"])
            
            // Load GPX file using the service
            let gpxFile = try await serviceProvider.gpxService.loadGpxFile(from: url)
            
            await MainActor.run {
                loadedGpxFile = gpxFile
                showingGpxView = true
                isLoadingFile = false
            }
            
        } catch let gpxError as GpxServiceError {
            await MainActor.run {
                errorMessage = gpxError.localizedDescription
                isLoadingFile = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error loading GPX file: \(error.localizedDescription)"
                isLoadingFile = false
            }
        }
    }
    
    private func presentDocumentPicker(fileTypes: [String]) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let documentPickerVC = UIDocumentPickerViewController(documentTypes: fileTypes, in: .import)
                
                // Create a delegate to handle the document picker
                let delegate = DocumentPickerDelegate { result in
                    switch result {
                    case .success(let url):
                        continuation.resume(returning: url)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                // Store the delegate to prevent it from being deallocated
                documentPickerVC.delegate = delegate
                
                // Store delegate in the view to prevent deallocation
                self.setDocumentPickerDelegate(delegate)
                
                // Present the document picker
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    rootViewController.present(documentPickerVC, animated: true)
                } else {
                    continuation.resume(throwing: NSError(domain: "RouteMenuView", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unable to present document picker"]))
                }
            }
        }
    }
    
    // Store delegate to prevent deallocation
    @State private var documentPickerDelegate: DocumentPickerDelegate?
    
    private func setDocumentPickerDelegate(_ delegate: DocumentPickerDelegate) {
        documentPickerDelegate = delegate
    }
}

// Document picker delegate to handle the file selection
class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    typealias CompletionHandler = (Result<URL, Error>) -> Void
    
    private let completion: CompletionHandler
    
    init(completion: @escaping CompletionHandler) {
        self.completion = completion
        super.init()
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            completion(.failure(NSError(domain: "com.marinerstudio", code: 404,
                               userInfo: [NSLocalizedDescriptionKey: "No document selected"])))
            return
        }
        
        // Ensure we have access to the URL
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        completion(.success(url))
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(.failure(NSError(domain: "com.marinerstudio", code: 401,
                           userInfo: [NSLocalizedDescriptionKey: "Document picker was cancelled"])))
    }
}

// MARK: - Enhanced Button Content

struct RouteMenuButtonContent: View {
    let icon: String
    let title: String
    let subtitle: String?
    let isSystemIcon: Bool
    let iconColor: Color?

    init(icon: String, title: String, subtitle: String? = nil, isSystemIcon: Bool = false, iconColor: Color? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isSystemIcon = isSystemIcon
        self.iconColor = iconColor
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Group {
                if isSystemIcon {
                    Image(systemName: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .foregroundColor(iconColor ?? .accentColor)
                } else {
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 55, height: 55)
                }
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(UIColor.lightGray), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        )
        .frame(minHeight: subtitle != nil ? 140 : 120)
    }
}

// MARK: - Service Selector View

struct ServiceSelectorView: View {
    @Binding var selectedServiceType: GpxServiceType
    let onServiceChanged: (GpxServiceType) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("GPX Service Engine")) {
                    ForEach(GpxServiceFactory.shared.getAvailableServices(), id: \.self) { serviceType in
                        ServiceTypeRow(
                            serviceType: serviceType,
                            isSelected: selectedServiceType == serviceType
                        ) {
                            selectedServiceType = serviceType
                            onServiceChanged(serviceType)
                        }
                    }
                }
                
                Section(header: Text("Service Information")) {
                    ServiceInfoView()
                }
            }
            .navigationTitle("Service Settings")
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

struct ServiceTypeRow: View {
    let serviceType: GpxServiceType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(serviceDisplayName(serviceType))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(serviceDescription(serviceType))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func serviceDisplayName(_ type: GpxServiceType) -> String {
        switch type {
        case .legacy:
            return "Legacy Service"
        case .coreGpx:
            return "CoreGPX Service"
        case .automatic:
            return "Automatic Selection"
        }
    }
    
    private func serviceDescription(_ type: GpxServiceType) -> String {
        switch type {
        case .legacy:
            return "Your original GPX parser - simple and reliable"
        case .coreGpx:
            return "Full-featured GPX 1.1 support with read/write capabilities"
        case .automatic:
            return "Automatically choose the best service for each task"
        }
    }
}

struct ServiceInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let info = GpxServiceFactory.shared.getServiceInfo()
            
            Text("Current Default: \(info["defaultType"] as? String ?? "Unknown")")
                .font(.caption)
            
            Text("Available Services: \((info["availableServices"] as? [String] ?? []).joined(separator: ", "))")
                .font(.caption)
            
            Text("Cached Instances: \((info["cachedServices"] as? [String] ?? []).joined(separator: ", "))")
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - Placeholder Views (for future implementation)

struct CloudImportView: View {
    var body: some View {
        Text("Cloud Import - Coming Soon")
            .navigationTitle("Cloud Import")
    }
}

struct RouteConverterView: View {
    var body: some View {
        Text("Route Converter - Coming Soon")
            .navigationTitle("Convert Routes")
    }
}
