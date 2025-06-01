
import SwiftUI
import MapKit
import CoreLocation

struct NavUnitDetailsView: View {
    // Use ObservedObject instead of StateObject since we'll initialize it from outside
    @ObservedObject var viewModel: NavUnitDetailsViewModel
    @EnvironmentObject var serviceProvider: ServiceProvider
    
    // State for photo picker and gallery
    @State private var showingPhotoPicker = false
    @State private var showingSyncSettings = false
    
    // State for recommendations
    @State private var showingRecommendationForm = false
    @State private var showingUserRecommendations = false
    
    // Simple initializer that takes a view model
    init(viewModel: NavUnitDetailsViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Error Message
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Unit Header Card
                headerCard
                
                // Map Frame
                mapView
                
                // Action Buttons
                actionButtons
                
                // Photos Section
                localPhotosSection
                
                // FTP Photos Section - COMMENTED OUT FOR INITIAL RELEASE
                // TODO: Re-enable remote photos feature in future version
                // remotePhotosSection
                
                // Primary Location
                locationDetailsSection
                
                // Waterway Info
                if viewModel.hasWaterwayInfo {
                    waterwayInfoSection
                }
                
                // Facility Info
                facilityInfoSection
                
                // Transportation
                if viewModel.hasTransportationInfo {
                    transportationInfoSection
                }
                
                // Specifications
                specificationsSection
                
                // Additional Info
                if viewModel.hasAdditionalInfo {
                    additionalInfoSection
                }
                
                // Service Info
                serviceInfoSection
            }
            .padding()
        }
        .navigationBarTitle("Navigation Unit Details", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: MainView(shouldClearNavigation: true)) {
                    Image(systemName: "house.fill")
                        .foregroundColor(.blue)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    // Provide haptic feedback
                    let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
                    impactGenerator.prepare()
                    impactGenerator.impactOccurred()
                })
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoPickerView(isPresented: $showingPhotoPicker) { image in
                Task {
                    await viewModel.saveNewPhoto(image)
                }
            }
        }
        .sheet(isPresented: $showingSyncSettings) {
            NavigationView {
                PhotoSyncSettingsView(iCloudService: viewModel.iCloudSyncService as! iCloudSyncServiceImpl)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSyncSettings = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingRecommendationForm) {
            if let navUnit = viewModel.unit {
                RecommendationFormView(
                    viewModel: RecommendationFormViewModel(
                        navUnit: navUnit,
                        recommendationService: serviceProvider.recommendationService
                    ),
                    isPresented: $showingRecommendationForm
                )
            }
        }
        .fullScreenCover(isPresented: $viewModel.showingPhotoGallery) {
            PhotoGalleryView(
                viewModel: viewModel.createPhotoGalleryViewModel(),
                isPresented: $viewModel.showingPhotoGallery
            )
            .onDisappear {
                viewModel.refreshPhotosAfterGalleryDismiss()
            }
        }
        
    }
    
    // MARK: - View Components
    
    private var headerCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            
            VStack(spacing: 10) {
                Text(viewModel.unit?.navUnitName ?? "")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Divider()
                
                Text(viewModel.unit?.navUnitId ?? "")
                    .font(.body)
                    .foregroundColor(.gray)
                
                Text(viewModel.unit?.facilityType ?? "")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }

    private var mapView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            
            if viewModel.hasCoordinates, let mapRegion = viewModel.mapRegion, let _ = viewModel.mapAnnotation {
                // Modern iOS 17 Map implementation
                Map {
                    if let annotation = viewModel.mapAnnotation {
                        Marker(annotation.title, coordinate: annotation.coordinate)
                            .tint(.blue)
                    }
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()
            } else {
                ZStack {
                    Color(UIColor.systemGray6)
                        .cornerRadius(10)
                    
                    Text("No location coordinates available")
                        .foregroundColor(.gray)
                }
                .frame(height: 300)
                .padding()
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 15) {
            actionButton(
                icon: "carsixseven",
                action: { viewModel.openInMaps() },
                isEnabled: viewModel.hasCoordinates
            )
            
            actionButton(
                icon: "greenphonesixseven",
                action: { viewModel.makePhoneCall() },
                isEnabled: viewModel.hasPhoneNumbers
            )
            
            actionButton(
                icon: viewModel.favoriteIcon,
                action: {
                    Task {
                        await viewModel.toggleFavorite()
                    }
                },
                isEnabled: true
            )
            
            actionButton(
                icon: "commentsixseven",
                action: { showingUserRecommendations = true },
                isEnabled: true
            )
            
            // NEW: Suggest Update button
            actionButton(
                icon: "lightbulb.fill",
                action: { showingRecommendationForm = true },
                isEnabled: true
            )
            
            actionButton(
                icon: "sharesixseven",
                action: { viewModel.shareUnit() },
                isEnabled: true
            )
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingUserRecommendations) {
            NavigationView {
                UserRecommendationsView()
                    .environmentObject(serviceProvider)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingUserRecommendations = false
                            }
                        }
                    }
            }
        }
    }
    
    private func actionButton(icon: String, action: @escaping () -> Void, isEnabled: Bool) -> some View {
        Button(action: action) {
            if icon == "lightbulb.fill" {
                // Use system icon for the new suggestion button
                Image(systemName: icon)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundColor(isEnabled ? .orange : .gray.opacity(0.5))
            } else {
                // Use custom icons for existing buttons
                Image(icon)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .opacity(isEnabled ? 1.0 : 0.5)
            }
        }
        .disabled(!isEnabled)
    }
     
    // Add this section to the localPhotosSection in NavUnitDetailsView.swift
    // Replace the existing localPhotosSection with this updated version:

    private var localPhotosSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            
            VStack(spacing: 15) {
                // Header with sync settings button
                HStack {
                    Text("Private Photos")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Auto-sync indicator
                    if viewModel.isAutoSyncing {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Syncing...")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // iCloud sync status indicator
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.iCloudAccountStatusIcon)
                            .foregroundColor(viewModel.iCloudAccountStatusColor)
                            .font(.caption)
                        
                        Button(action: {
                            showingSyncSettings = true
                        }) {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        
                        // Manual sync button
                        if viewModel.iCloudSyncService.isEnabled && !viewModel.isAutoSyncing {
                            Button(action: {
                                Task {
                                    await viewModel.manualSyncNavUnit()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                if viewModel.localPhotos.isEmpty {
                    VStack {
                        Text("No photos yet")
                            .foregroundColor(.gray)
                    }
                    .frame(height: 200)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(viewModel.localPhotos) { photo in
                                photoItem(photo: photo)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 200)
                }
                
                HStack {
                    Button(action: {
                        showingPhotoPicker = true
                    }) {
                        Image("camerasixseven")
                            .resizable()
                            .frame(width: 44, height: 44)
                    }
                    
                    Text("New Photo")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
            .padding()
        }
    }
    
    
    
    
    
    private func photoItem(photo: NavUnitPhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .topLeading) {
                // Async image loading with thumbnail
                AsyncPhotoThumbnail(photo: photo, viewModel: viewModel)
                    .frame(width: 180, height: 180)
                    .cornerRadius(8)
                    .onTapGesture {
                        viewModel.viewPhoto(photo)
                    }
                
                // Sync status indicator in top-left
                VStack {
                    HStack {
                        syncStatusIndicator(for: photo)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }
            
            // Delete button in top-right
            Button(action: {
                Task {
                    await viewModel.deletePhoto(photo.id)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 30, height: 30)
                    
                    Text("×")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(5)
        }
        .frame(width: 180, height: 180)
    }
    
    private func syncStatusIndicator(for photo: NavUnitPhoto) -> some View {
        let status = viewModel.getSyncStatus(for: photo.id)
        
        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 24, height: 24)
            
            Group {
                if status == .syncing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: status.iconName)
                        .foregroundColor(syncStatusColor(for: status))
                        .font(.system(size: 12))
                }
            }
        }
    }
    
    private func syncStatusColor(for status: PhotoSyncStatus) -> Color {
        switch status {
        case .notSynced: return .gray
        case .syncing: return .blue
        case .synced: return .green
        case .failed: return .red
        }
    }
    
    private var remotePhotosSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            
            VStack(spacing: 15) {
                Text(viewModel.remotePhotosHeader)
                    .font(.headline)
                
                if viewModel.isLoadingFtpPhotos {
                    ProgressView()
                        .frame(height: 300)
                } else if viewModel.ftpPhotos.isEmpty {
                    Text("No remote photos available")
                        .foregroundColor(.gray)
                        .frame(height: 300)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(viewModel.ftpPhotos) { photo in
                                ftpPhotoItem(photo: photo)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 300)
                    
                    Text("Found \(viewModel.ftpPhotos.count) photos")
                        .font(.caption)
                }
            }
            .padding()
        }
    }
    
    private func ftpPhotoItem(photo: FtpPhotoItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 280, height: 280)
            
            // Simplify to always use a colored rectangle
            Rectangle()
                .fill(Color.green)
                .frame(width: 260, height: 260)
                .cornerRadius(8)
        }
        .cornerRadius(8)
        .onTapGesture {
            viewModel.viewFtpPhoto(photo)
        }
    }
    
    // MARK: - Detail Sections
    
    private var locationDetailsSection: some View {
        detailSection(title: "Location Details") {
            detailRow(label: "Address:", value: viewModel.unit?.streetAddress)
            detailRow(label: "City:", value: viewModel.unit?.cityOrTown)
            detailRow(label: "State:", value: viewModel.unit?.statePostalCode)
            detailRow(label: "ZIP:", value: viewModel.unit?.zipCode)
            detailRow(label: "Location:", value: viewModel.unit?.location)
            detailRow(label: "Description:", value: viewModel.unit?.locationDescription)
        }
    }
    
    private var waterwayInfoSection: some View {
        detailSection(title: "Waterway Information") {
            detailRow(label: "Waterway:", value: viewModel.unit?.waterwayName)
            detailRow(label: "Port:", value: viewModel.unit?.portName)
            
            if let mile = viewModel.unit?.mile {
                detailRow(label: "Mile Marker:", value: String(mile))
            }
            
            detailRow(label: "Bank:", value: viewModel.unit?.bank)
            detailRow(label: "Coordinates:", value: viewModel.formattedCoordinates)
        }
    }
    
    private var facilityInfoSection: some View {
        detailSection(title: "Facility Information") {
            detailRow(label: "Operators:", value: viewModel.unit?.operators)
            detailRow(label: "Owners:", value: viewModel.unit?.owners)
            detailRow(label: "Purpose:", value: viewModel.unit?.purpose)
        }
    }
    
    private var transportationInfoSection: some View {
        detailSection(title: "Transportation") {
            detailRow(label: "Highway:", value: viewModel.unit?.highwayNote)
            detailRow(label: "Railway:", value: viewModel.unit?.railwayNote)
        }
    }
    
    private var specificationsSection: some View {
        detailSection(title: "Specifications") {
            detailRow(label: "Depth Range:", value: viewModel.depthRange)
            detailRow(label: "Deck Height:", value: viewModel.deckHeightRange)
            
            let berthingText = "Largest: \(viewModel.unit?.berthingLargest?.description ?? "N/A"), Total: \(viewModel.unit?.berthingTotal?.description ?? "N/A")"
            detailRow(label: "Berthing:", value: berthingText)
            
            detailRow(label: "Vertical Datum:", value: viewModel.unit?.verticalDatum)
            detailRow(label: "Dock:", value: viewModel.unit?.dock)
        }
    }
    
    private var additionalInfoSection: some View {
        detailSection(title: "Additional Information") {
            detailRow(label: "Construction:", value: viewModel.unit?.construction)
            detailRow(label: "Mechanical:", value: viewModel.unit?.mechanicalHandling)
            detailRow(label: "Commodities:", value: viewModel.unit?.commodities)
            detailRow(label: "Remarks:", value: viewModel.unit?.remarks)
        }
    }
    
    private var serviceInfoSection: some View {
        detailSection(title: "Service Information") {
            detailRow(label: "Initiated:", value: viewModel.unit?.serviceInitiationDate)
            detailRow(label: "Terminated:", value: viewModel.unit?.serviceTerminationDate)
        }
    }
    
    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .padding(.bottom, 5)
            
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        )
    }
    
    private func detailRow(label: String, value: String?) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.body)
                .fontWeight(.bold)
                .frame(width: 120, alignment: .leading)
            
            Text(value ?? "Not specified")
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }
}
