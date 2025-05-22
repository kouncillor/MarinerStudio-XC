
import SwiftUI
import MapKit
import CoreLocation

struct NavUnitDetailsView: View {
    // Use ObservedObject instead of StateObject since we'll initialize it from outside
    @ObservedObject var viewModel: NavUnitDetailsViewModel
    
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
                
                // FTP Photos Section
                remotePhotosSection
                
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
        .withHomeButton()
        
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
                action: { /* Show notes view */ },
                isEnabled: true
            )
            
            actionButton(
                icon: "sharesixseven",
                action: { viewModel.shareUnit() },
                isEnabled: true
            )
        }
        .padding(.horizontal)
    }
    
    private func actionButton(icon: String, action: @escaping () -> Void, isEnabled: Bool) -> some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .frame(width: 44, height: 44)
                .opacity(isEnabled ? 1.0 : 0.5)
        }
        .disabled(!isEnabled)
    }
    
    private var localPhotosSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            
            VStack(spacing: 15) {
                if viewModel.localPhotos.isEmpty {
                    VStack {
                        Text("Private Photos")
                            .font(.title3)
                        
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
                    Button(action: { viewModel.takePhoto() }) {
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
            // Use a color rectangle instead of loading from file
            Rectangle()
                .fill(Color.blue)
                .frame(width: 180, height: 180)
                .cornerRadius(8)
                .onTapGesture {
                    viewModel.viewPhoto(photo)
                }
            
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
