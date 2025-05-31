
import Foundation
import SwiftUI
import CoreLocation
import Combine
import MapKit

// Map-related models
struct MapRegion: Equatable {
    var center: CLLocationCoordinate2D
    var span: MKCoordinateSpan
    
    static func == (lhs: MapRegion, rhs: MapRegion) -> Bool {
        return lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
               lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}

struct NavUnitMapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String
}

class NavUnitDetailsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var unit: NavUnit?
    @Published var localPhotos: [NavUnitPhoto] = []
    @Published var ftpPhotos: [FtpPhotoItem] = []
    @Published var errorMessage: String = ""
    @Published var isLoadingFtpPhotos: Bool = false
    @Published var remotePhotosHeader: String = "Remote Photos"
    @Published var favoriteIcon: String = "favoriteoutlinesixseven"
    @Published var formattedCoordinates: String = ""
    @Published var depthRange: String = ""
    @Published var deckHeightRange: String = ""
    @Published var hasMultiplePhoneNumbers: Bool = false
    
    // Photo gallery state
    @Published var showingPhotoGallery: Bool = false
    @Published var selectedPhotoIndex: Int = 0
    
    // iCloud sync status tracking
    @Published var photoSyncStatuses: [Int: PhotoSyncStatus] = [:]
    @Published var iCloudAccountStatus: String = "Unknown"
    @Published var iCloudAccountStatusIcon: String = "questionmark.circle.fill"
    @Published var iCloudAccountStatusColor: Color = .gray
    
    // Auto-sync state
    @Published var isAutoSyncing: Bool = false
    
    // MARK: - Sync Throttling
    private var lastSyncTime: [String: Date] = [:] // Track last sync time per navUnitId
    private let syncThrottleInterval: TimeInterval = 10 // Minimum 10 seconds between syncs
    private var activeSyncTasks: Set<String> = Set() // Track active sync operations
    
    // MARK: - Map-related Properties
    @Published var mapRegion: MapRegion?
    @Published var mapAnnotation: NavUnitMapAnnotation?
    
    // MARK: - Services
    private let databaseService: NavUnitDatabaseService
    private let photoService: PhotoDatabaseService
    private let navUnitFtpService: NavUnitFtpService
    private let imageCacheService: ImageCacheService
    private let favoritesService: FavoritesService
    private let photoCaptureService: PhotoCaptureService
    private let fileStorageService: FileStorageService
    let iCloudSyncService: iCloudSyncService // Made public for PhotoSyncSettingsView access
    
    // Used to manage and cancel any ongoing tasks
    private var cancellables = Set<AnyCancellable>()
    
    // Add an actor to safely manage concurrent access to currentPhoto
    private actor PhotoLoadingState {
        var currentCount = 0
        
        func increment() -> Int {
            currentCount += 1
            return currentCount
        }
    }
    
    private let photoLoadingState = PhotoLoadingState()
    
    // MARK: - Computed Properties
    var hasCoordinates: Bool {
        return unit?.latitude != nil && unit?.longitude != nil
    }
    
    var hasPhoneNumbers: Bool {
        return unit?.hasPhoneNumbers ?? false
    }
    
    var hasAdditionalInfo: Bool {
        return !(unit?.construction?.isEmpty ?? true) ||
               !(unit?.mechanicalHandling?.isEmpty ?? true) ||
               !(unit?.remarks?.isEmpty ?? true) ||
               !(unit?.commodities?.isEmpty ?? true)
    }
    
    var hasWaterwayInfo: Bool {
        return !(unit?.waterwayName?.isEmpty ?? true) ||
               !(unit?.portName?.isEmpty ?? true) ||
               unit?.mile != nil ||
               !(unit?.bank?.isEmpty ?? true)
    }
    
    var hasTransportationInfo: Bool {
        return !(unit?.highwayNote?.isEmpty ?? true) ||
               !(unit?.railwayNote?.isEmpty ?? true)
    }
    
    // MARK: - Initialization
    init(
        databaseService: NavUnitDatabaseService,
        photoService: PhotoDatabaseService,
        navUnitFtpService: NavUnitFtpService,
        imageCacheService: ImageCacheService,
        favoritesService: FavoritesService,
        photoCaptureService: PhotoCaptureService,
        fileStorageService: FileStorageService,
        iCloudSyncService: iCloudSyncService
    ) {
        self.databaseService = databaseService
        self.photoService = photoService
        self.navUnitFtpService = navUnitFtpService
        self.imageCacheService = imageCacheService
        self.favoritesService = favoritesService
        self.photoCaptureService = photoCaptureService
        self.fileStorageService = fileStorageService
        self.iCloudSyncService = iCloudSyncService
        
        setupiCloudStatusMonitoring()
    }
    
    // New initializer that takes a NavUnit
    init(
        navUnit: NavUnit,
        databaseService: NavUnitDatabaseService,
        photoService: PhotoDatabaseService,
        navUnitFtpService: NavUnitFtpService,
        imageCacheService: ImageCacheService,
        favoritesService: FavoritesService,
        photoCaptureService: PhotoCaptureService,
        fileStorageService: FileStorageService,
        iCloudSyncService: iCloudSyncService
    ) {
        self.databaseService = databaseService
        self.photoService = photoService
        self.navUnitFtpService = navUnitFtpService
        self.imageCacheService = imageCacheService
        self.favoritesService = favoritesService
        self.photoCaptureService = photoCaptureService
        self.fileStorageService = fileStorageService
        self.iCloudSyncService = iCloudSyncService
        
        setupiCloudStatusMonitoring()
        
        // Set the nav unit and update display properties
        self.unit = navUnit
        updateDisplayProperties()
        updateFavoriteIcon()
        initializeMap()
        
        // Start loading photos asynchronously using a Task that we can manage
        Task { @MainActor in
            do {
                try await loadAllPhotos()
                // Auto-sync photos for this nav unit if enabled
                await performAutoSyncIfEnabled()
            } catch {
                errorMessage = "Failed to load photos: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Auto Sync with Throttling
    private func performAutoSyncIfEnabled() async {
        guard let unit = unit,
              iCloudSyncService.isEnabled,
              !isAutoSyncing else { return }
        
        // Check if we've synced this nav unit recently
        let now = Date()
        if let lastSync = lastSyncTime[unit.navUnitId],
           now.timeIntervalSince(lastSync) < syncThrottleInterval {
            print("🛑 NavUnitDetailsViewModel: Throttling auto-sync for \(unit.navUnitId) - last sync was \(Int(now.timeIntervalSince(lastSync)))s ago")
            return
        }
        
        // Check if there's already an active sync for this nav unit
        if activeSyncTasks.contains(unit.navUnitId) {
            print("🛑 NavUnitDetailsViewModel: Auto-sync already in progress for \(unit.navUnitId)")
            return
        }
        
        await MainActor.run {
            isAutoSyncing = true
            activeSyncTasks.insert(unit.navUnitId)
            lastSyncTime[unit.navUnitId] = now
        }
        
        print("🔄 NavUnitDetailsViewModel: Starting throttled auto-sync for nav unit: \(unit.navUnitId)")
        
        await iCloudSyncService.syncPhotosForNavUnit(unit.navUnitId)
        
        // Reload photos after sync to show any newly downloaded photos
        await loadLocalPhotos()
        
        await MainActor.run {
            isAutoSyncing = false
            activeSyncTasks.remove(unit.navUnitId)
        }
        
        print("✅ NavUnitDetailsViewModel: Throttled auto-sync completed for nav unit: \(unit.navUnitId)")
    }
    
    // MARK: - iCloud Status Monitoring
    
    private func setupiCloudStatusMonitoring() {
        // Check initial status once on initialization
        Task {
            await updateiCloudAccountStatus()
        }
        
        // Removed reactive monitoring to prevent infinite loop
        // Status will be updated when user opens sync settings or manually refreshes
    }
    
    @MainActor
    private func updateiCloudAccountStatus() async {
        let status = await iCloudSyncService.checkAccountStatus()
        
        switch status {
        case .available:
            iCloudAccountStatus = "Available"
            iCloudAccountStatusIcon = "icloud.fill"
            iCloudAccountStatusColor = .green
        case .noAccount:
            iCloudAccountStatus = "No Account"
            iCloudAccountStatusIcon = "person.crop.circle.badge.xmark"
            iCloudAccountStatusColor = .red
        case .restricted:
            iCloudAccountStatus = "Restricted"
            iCloudAccountStatusIcon = "lock.circle.fill"
            iCloudAccountStatusColor = .orange
        case .couldNotDetermine:
            iCloudAccountStatus = "Unknown"
            iCloudAccountStatusIcon = "questionmark.circle.fill"
            iCloudAccountStatusColor = .gray
        case .temporarilyUnavailable:
            iCloudAccountStatus = "Unavailable"
            iCloudAccountStatusIcon = "exclamationmark.circle.fill"
            iCloudAccountStatusColor = .yellow
        @unknown default:
            iCloudAccountStatus = "Unknown"
            iCloudAccountStatusIcon = "questionmark.circle.fill"
            iCloudAccountStatusColor = .gray
        }
    }
    
    // MARK: - Sync Status Management
    
    func getSyncStatus(for photoId: Int) -> PhotoSyncStatus {
        return photoSyncStatuses[photoId] ?? .notSynced
    }
    
    func setSyncStatus(for photoId: Int, status: PhotoSyncStatus) {
        photoSyncStatuses[photoId] = status
    }
    
    func retrySyncForPhoto(_ photoId: Int) async {
        guard let photo = localPhotos.first(where: { $0.id == photoId }),
              iCloudSyncService.isEnabled else { return }
        
        await MainActor.run {
            setSyncStatus(for: photoId, status: .syncing)
        }
        
        do {
            // Load image data for sync
            if let image = await fileStorageService.loadImage(from: photo.filePath),
               let imageData = image.jpegData(compressionQuality: 0.8) {
                
                let recordID = try await iCloudSyncService.uploadPhoto(photo, imageData: imageData)
                
                await MainActor.run {
                    setSyncStatus(for: photoId, status: .synced)
                }
                
                print("✅ NavUnitDetailsViewModel: Retry sync successful for photo \(photoId) with record ID: \(recordID)")
            } else {
                throw NSError(domain: "PhotoSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image data"])
            }
        } catch {
            await MainActor.run {
                setSyncStatus(for: photoId, status: .failed)
            }
            print("❌ NavUnitDetailsViewModel: Retry sync failed for photo \(photoId): \(error.localizedDescription)")
        }
    }
    
    func manualSyncPhoto(_ photoId: Int) async {
        guard let photo = localPhotos.first(where: { $0.id == photoId }),
              iCloudSyncService.isEnabled else { return }
        
        await MainActor.run {
            setSyncStatus(for: photoId, status: .syncing)
        }
        
        do {
            // Load image data for sync
            if let image = await fileStorageService.loadImage(from: photo.filePath),
               let imageData = image.jpegData(compressionQuality: 0.8) {
                
                let recordID = try await iCloudSyncService.uploadPhoto(photo, imageData: imageData)
                
                await MainActor.run {
                    setSyncStatus(for: photoId, status: .synced)
                }
                
                print("✅ NavUnitDetailsViewModel: Manual sync successful for photo \(photoId) with record ID: \(recordID)")
            } else {
                throw NSError(domain: "PhotoSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image data"])
            }
        } catch {
            await MainActor.run {
                setSyncStatus(for: photoId, status: .failed)
            }
            print("❌ NavUnitDetailsViewModel: Manual sync failed for photo \(photoId): \(error.localizedDescription)")
        }
    }
    
    // Manual sync for this nav unit with throttling
    func manualSyncNavUnit() async {
        guard let unit = unit else { return }
        
        // Allow manual sync to bypass throttling but still check for active syncs
        if activeSyncTasks.contains(unit.navUnitId) {
            print("🛑 NavUnitDetailsViewModel: Manual sync blocked - auto-sync in progress for \(unit.navUnitId)")
            return
        }
        
        await MainActor.run {
            isAutoSyncing = true
            activeSyncTasks.insert(unit.navUnitId)
        }
        
        await iCloudSyncService.syncPhotosForNavUnit(unit.navUnitId)
        await loadLocalPhotos()
        
        await MainActor.run {
            isAutoSyncing = false
            activeSyncTasks.remove(unit.navUnitId)
            lastSyncTime[unit.navUnitId] = Date() // Update throttle time
        }
    }
    
    private func initializeSyncStatusForPhotos() {
        // Initialize sync status for all loaded photos
        for photo in localPhotos {
            if photoSyncStatuses[photo.id] == nil {
                // Default to not synced - in a real implementation, you might check if it's already synced
                photoSyncStatuses[photo.id] = .notSynced
            }
        }
    }
    
    // MARK: - Public Methods
    func loadUnit(_ navUnit: NavUnit) {
        self.unit = navUnit
        updateDisplayProperties()
        updateFavoriteIcon()
        initializeMap()
        
        // Start loading photos asynchronously
        Task { @MainActor in
            do {
                try await loadAllPhotos()
                await performAutoSyncIfEnabled()
            } catch {
                errorMessage = "Failed to load photos: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadAllPhotos() async throws {
        guard let unit = unit else { return }
        
        // Load local photos first - using photoService
        do {
            let photos = try await photoService.getNavUnitPhotosAsync(navUnitId: unit.navUnitId)
            await MainActor.run {
                self.localPhotos = photos
                self.initializeSyncStatusForPhotos()
            }
        } catch {
            print("Error loading local photos: \(error.localizedDescription)")
            // Continue loading remote photos even if local photos fail
        }
        
        // Then attempt to load remote photos
        await MainActor.run {
            self.isLoadingFtpPhotos = true
            self.remotePhotosHeader = "Remote Photos (Getting file list...)"
        }
        
        do {
            let fileNames = try await navUnitFtpService.getNavUnitImagesAsync(navUnitId: unit.navUnitId)
            
            await MainActor.run {
                self.ftpPhotos.removeAll()
            }
            
            let totalPhotos = fileNames.count
            
            // Process in batches for better performance
            let batchSize = 3 // Reduced batch size for better stability
            for i in stride(from: 0, to: fileNames.count, by: batchSize) {
                let upperBound = min(i + batchSize, fileNames.count)
                let batch = Array(fileNames[i..<upperBound])
                
                try await withThrowingTaskGroup(of: FtpPhotoItem.self) { group in
                    for fileName in batch {
                        group.addTask {
                            let item = FtpPhotoItem(fileName: fileName, imageSource: .placeholder)
                            
                            // Add to view model collection immediately with placeholder
                            await self.addPhotoToCollection(item)
                            
                            // Load the actual image
                            do {
                                try await self.loadFullImage(for: item, navUnitId: unit.navUnitId)
                            } catch {
                                print("Error loading image \(fileName): \(error.localizedDescription)")
                                // Continue with placeholder
                            }
                            
                            // Fixed: Use the actor to safely increment the counter
                            let currentCount = await self.photoLoadingState.increment()
                            await MainActor.run {
                                self.remotePhotosHeader = "Remote Photos (Loading \(currentCount) of \(totalPhotos))"
                            }
                            
                            return item
                        }
                    }
                    
                    // Wait for all tasks in the group to complete
                    for try await _ in group {
                        // Process each result if needed
                    }
                }
            }
            
            await MainActor.run {
                self.remotePhotosHeader = "Remote Photos (\(totalPhotos) photos)"
                self.isLoadingFtpPhotos = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error loading remote photos: \(error.localizedDescription)"
                self.remotePhotosHeader = "Remote Photos (Error loading)"
                self.isLoadingFtpPhotos = false
            }
        }
    }
    
    // Helper function to safely add a photo to the collection
    @MainActor
    private func addPhotoToCollection(_ photo: FtpPhotoItem) {
        self.ftpPhotos.append(photo)
    }
    
    // Updated to handle errors better
    private func loadFullImage(for item: FtpPhotoItem, navUnitId: String) async throws {
        let cacheKey = imageCacheService.getCacheKey(navUnitId, item.fileName)
        
        // Try to get from cache first
        if let imageData = await imageCacheService.getImageAsync(cacheKey) {
            await MainActor.run {
                if let index = self.ftpPhotos.firstIndex(where: { $0.fileName == item.fileName }) {
                    self.ftpPhotos[index].imageSource = .data(imageData)
                }
            }
            return
        }
        
        // If not in cache, download and cache it
        let imageData = try await navUnitFtpService.downloadNavUnitImageAsync(navUnitId: navUnitId, fileName: item.fileName)
        
        if !imageData.isEmpty {
            await imageCacheService.saveImageAsync(cacheKey, imageData)
            
            await MainActor.run {
                if let index = self.ftpPhotos.firstIndex(where: { $0.fileName == item.fileName }) {
                    self.ftpPhotos[index].imageSource = .data(imageData)
                }
            }
        }
    }
    
    func viewPhoto(_ photo: NavUnitPhoto) {
        guard let index = localPhotos.firstIndex(where: { $0.id == photo.id }) else { return }
        
        // This will trigger the gallery presentation in the view
        // The view will observe changes to selectedPhotoIndex
        selectedPhotoIndex = index
        showingPhotoGallery = true
        
        print("📸 NavUnitDetailsViewModel: Opening gallery at index: \(index), photos: \(localPhotos.count)")
    }
    
    func viewFtpPhoto(_ photo: FtpPhotoItem) {
        guard let index = ftpPhotos.firstIndex(where: { $0.fileName == photo.fileName }) else { return }
        
        // In a real implementation, this would navigate to the photo gallery view
        print("Opening FTP gallery at index: \(index), photos: \(ftpPhotos.count)")
    }
    
    func toggleFavorite() async {
        guard let unit = unit else { return }
        
        do {
            let isFavorite = try await databaseService.toggleFavoriteNavUnitAsync(navUnitId: unit.navUnitId)
            
            await MainActor.run {
                self.unit?.isFavorite = isFavorite
                updateFavoriteIcon()
            }
            
            await favoritesService.syncFavoriteNavUnitAsync(unit.navUnitId, isFavorite)
        } catch {
            await MainActor.run {
                self.errorMessage = "Unable to update favorite status: \(error.localizedDescription)"
            }
        }
    }
    
    func openInMaps() {
        guard let unit = unit,
              let latitude = unit.latitude,
              let longitude = unit.longitude else { return }
        
        let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinates))
        mapItem.name = unit.navUnitName
        
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    func makePhoneCall() {
        guard let unit = unit, unit.hasPhoneNumbers else {
            errorMessage = "No phone number available."
            return
        }
        
        let phoneNumbers = unit.phoneNumbers
        
        if phoneNumbers.count > 1 {
            // In real implementation, display action sheet for number selection
            // For now, just use the first one
            dialPhoneNumber(phoneNumbers[0])
        } else if let firstNumber = phoneNumbers.first {
            dialPhoneNumber(firstNumber)
        }
    }
    
    private func dialPhoneNumber(_ number: String) {
        let formattedNumber = number.replacingOccurrences(of: "-", with: "")
                                    .replacingOccurrences(of: " ", with: "")
        
        guard let url = URL(string: "tel://\(formattedNumber)") else { return }
        
        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
    
    func shareUnit() {
        guard let unit = unit else { return }
        
        var shareText = "Navigation Unit Information\n\n"
        shareText += "Name: \(unit.navUnitName)\n"
        shareText += "ID: \(unit.navUnitId)\n"
        
        if let facilityType = unit.facilityType {
            shareText += "Type: \(facilityType)\n"
        }
        
        if let unloCode = unit.unloCode, !unloCode.isEmpty {
            shareText += "UNLOCODE: \(unloCode)\n"
        }
        
        // Location Information
        shareText += "\nLocation Information:\n"
        if hasCoordinates {
            shareText += "Coordinates: \(formattedCoordinates)\n"
        }
        
        if let streetAddress = unit.streetAddress, !streetAddress.isEmpty {
            shareText += "Street Address: \(streetAddress)\n"
        }
        
        // Additional information could be added here
        
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        // Get the root view controller to present the share sheet from
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
        #endif
    }
    
    func takePhoto() {
        // This will be handled by the view presenting the PhotoPickerView
        print("📸 NavUnitDetailsViewModel: takePhoto() called - should be handled by view")
    }
    
    func saveNewPhoto(_ image: UIImage) async {
        print("🚀 NavUnitDetailsViewModel: saveNewPhoto() started")
        
        guard let unit = unit else {
            print("❌ NavUnitDetailsViewModel: No navigation unit selected")
            await MainActor.run {
                errorMessage = "No navigation unit selected"
            }
            return
        }
        
        print("✅ NavUnitDetailsViewModel: Unit found: \(unit.navUnitId)")
        
        do {
            print("💾 NavUnitDetailsViewModel: Starting file save...")
            // Save image to file system
            let (filePath, fileName) = try await fileStorageService.savePhoto(image, for: unit.navUnitId)
            print("✅ NavUnitDetailsViewModel: File saved - Path: \(filePath), Name: \(fileName)")
            
            // Create NavUnitPhoto object
            let navUnitPhoto = NavUnitPhoto(
                navUnitId: unit.navUnitId,
                filePath: filePath,
                fileName: fileName,
                description: "Photo taken on \(Date().formatted())"
            )
            print("✅ NavUnitDetailsViewModel: NavUnitPhoto object created")
            
            print("💾 NavUnitDetailsViewModel: Starting database save...")
            // Save to database
            let photoId = try await photoService.addNavUnitPhotoAsync(photo: navUnitPhoto)
            print("✅ NavUnitDetailsViewModel: Saved to database with ID: \(photoId)")
            
            // Initialize sync status as not synced
            await MainActor.run {
                setSyncStatus(for: photoId, status: .notSynced)
            }
            print("✅ NavUnitDetailsViewModel: Sync status initialized as .notSynced")
            
            // Check if iCloud sync is enabled
            print("☁️ NavUnitDetailsViewModel: Checking iCloud sync status...")
            print("☁️ NavUnitDetailsViewModel: iCloudSyncService.isEnabled = \(iCloudSyncService.isEnabled)")
            
            if iCloudSyncService.isEnabled {
                print("🚀 NavUnitDetailsViewModel: iCloud sync is ENABLED - starting upload process")
                
                await MainActor.run {
                    setSyncStatus(for: photoId, status: .syncing)
                }
                print("✅ NavUnitDetailsViewModel: Set sync status to .syncing")
                
                do {
                    print("🔄 NavUnitDetailsViewModel: Creating updated photo object for iCloud...")
                    let updatedPhoto = NavUnitPhoto(
                        id: photoId,
                        navUnitId: navUnitPhoto.navUnitId,
                        filePath: navUnitPhoto.filePath,
                        fileName: navUnitPhoto.fileName,
                        thumbPath: navUnitPhoto.thumbPath,
                        description: navUnitPhoto.description,
                        createdAt: navUnitPhoto.createdAt
                    )
                    print("✅ NavUnitDetailsViewModel: Updated photo object created")
                    
                    print("🖼️ NavUnitDetailsViewModel: Converting image to data...")
                    // Convert image to data for iCloud upload
                    let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
                    print("✅ NavUnitDetailsViewModel: Image converted to data - Size: \(imageData.count) bytes")
                    
                    if imageData.isEmpty {
                        print("❌ NavUnitDetailsViewModel: Image data is empty!")
                        throw NSError(domain: "PhotoSync", code: 2, userInfo: [NSLocalizedDescriptionKey: "Image data is empty"])
                    }
                    
                    print("☁️ NavUnitDetailsViewModel: Calling iCloudSyncService.uploadPhoto()...")
                    let recordID = try await iCloudSyncService.uploadPhoto(updatedPhoto, imageData: imageData)
                    print("🎉 NavUnitDetailsViewModel: iCloud upload SUCCESS! Record ID: \(recordID)")
                    
                    await MainActor.run {
                        setSyncStatus(for: photoId, status: .synced)
                    }
                    print("✅ NavUnitDetailsViewModel: Set sync status to .synced")
                    
                } catch {
                    print("💥 NavUnitDetailsViewModel: iCloud upload FAILED with error: \(error)")
                    print("💥 NavUnitDetailsViewModel: Error description: \(error.localizedDescription)")
                    
                    if let nsError = error as? NSError {
                        print("💥 NavUnitDetailsViewModel: NSError domain: \(nsError.domain)")
                        print("💥 NavUnitDetailsViewModel: NSError code: \(nsError.code)")
                    }
                    
                    await MainActor.run {
                        setSyncStatus(for: photoId, status: .failed)
                    }
                    print("✅ NavUnitDetailsViewModel: Set sync status to .failed")
                    // Continue anyway - photo is saved locally
                }
            } else {
                print("⚠️ NavUnitDetailsViewModel: iCloud sync is DISABLED - skipping upload")
            }
            
            print("🔄 NavUnitDetailsViewModel: Reloading local photos...")
            // Reload photos to show the new one
            await loadLocalPhotos()
            print("✅ NavUnitDetailsViewModel: Local photos reloaded")
            
        } catch {
            print("💥 NavUnitDetailsViewModel: saveNewPhoto() FAILED with error: \(error)")
            print("💥 NavUnitDetailsViewModel: Error description: \(error.localizedDescription)")
            
            if let nsError = error as? NSError {
                print("💥 NavUnitDetailsViewModel: NSError domain: \(nsError.domain)")
                print("💥 NavUnitDetailsViewModel: NSError code: \(nsError.code)")
            }
            
            await MainActor.run {
                errorMessage = "Failed to save photo: \(error.localizedDescription)"
            }
        }
        
        print("🏁 NavUnitDetailsViewModel: saveNewPhoto() completed")
    }
    
    func deletePhoto(_ photoId: Int) async {
        do {
            // Get the photo first to get the file path
            if let photoToDelete = localPhotos.first(where: { $0.id == photoId }) {
                // Delete from file system
                try await fileStorageService.deletePhoto(at: photoToDelete.filePath)
            }
            
            // Delete from database
            let deleteResult = try await photoService.deleteNavUnitPhotoAsync(photoId: photoId)
            print("🗑️ NavUnitDetailsViewModel: Delete result: \(deleteResult)")
            
            // Remove sync status
            await MainActor.run {
                photoSyncStatuses.removeValue(forKey: photoId)
            }
            
            // Reload local photos
            await loadLocalPhotos()
        } catch {
            await MainActor.run {
                self.errorMessage = "Error deleting photo: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Photo Gallery Helper
    
    func createPhotoGalleryViewModel() -> PhotoGalleryViewModel {
        return PhotoGalleryViewModel(
            photos: localPhotos,
            startingIndex: selectedPhotoIndex,
            fileStorageService: fileStorageService,
            photoService: photoService
        )
    }
    
    func refreshPhotosAfterGalleryDismiss() {
        // Reload photos when gallery is dismissed to reflect any deletions
        Task {
            await loadLocalPhotos()
        }
    }
    
    // MARK: - Photo Loading Helper
    
    func loadThumbnail(for photo: NavUnitPhoto) async -> UIImage? {
        return await fileStorageService.generateThumbnail(from: photo.filePath, maxSize: CGSize(width: 200, height: 200))
    }
    
    func loadFullImage(for photo: NavUnitPhoto) async -> UIImage? {
        return await fileStorageService.loadImage(from: photo.filePath)
    }
    
    private func loadLocalPhotos() async {
        guard let unit = unit else { return }
        
        do {
            // Use photoService instead of databaseService for photo operations
            let photos = try await photoService.getNavUnitPhotosAsync(navUnitId: unit.navUnitId)
            await MainActor.run {
                self.localPhotos = photos
                self.initializeSyncStatusForPhotos()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error loading photos: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Map Methods
    
    // Add this method to initialize the map when a unit is loaded
    private func initializeMap() {
        guard let unit = unit,
              let latitude = unit.latitude,
              let longitude = unit.longitude else {
            mapRegion = nil
            mapAnnotation = nil
            return
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        mapRegion = MapRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        mapAnnotation = NavUnitMapAnnotation(
            coordinate: coordinate,
            title: unit.navUnitName,
            subtitle: unit.facilityType ?? "Navigation Unit"
        )
    }
    
    // MARK: - Private Methods
    private func updateDisplayProperties() {
        guard let unit = unit else { return }
        
        // Format depth range
        if unit.depthMin != nil || unit.depthMax != nil {
            if unit.depthMin == unit.depthMax, let depth = unit.depthMin {
                depthRange = "\(depth) ft"
            } else if unit.depthMin == nil, let maxDepth = unit.depthMax {
                depthRange = "Up to \(maxDepth) ft"
            } else if unit.depthMax == nil, let minDepth = unit.depthMin {
                depthRange = "Minimum \(minDepth) ft"
            } else if let minDepth = unit.depthMin, let maxDepth = unit.depthMax {
                depthRange = "\(minDepth) - \(maxDepth) ft"
            }
        } else {
            depthRange = "Not specified"
        }
        
        // Format deck height range
        if unit.deckHeightMin != nil || unit.deckHeightMax != nil {
            if unit.deckHeightMin == unit.deckHeightMax, let height = unit.deckHeightMin {
                deckHeightRange = "\(height) ft"
            } else if unit.deckHeightMin == nil, let maxHeight = unit.deckHeightMax {
                deckHeightRange = "Up to \(maxHeight) ft"
            } else if unit.deckHeightMax == nil, let minHeight = unit.deckHeightMin {
                deckHeightRange = "Minimum \(minHeight) ft"
            } else if let minHeight = unit.deckHeightMin, let maxHeight = unit.deckHeightMax {
                deckHeightRange = "\(minHeight) - \(maxHeight) ft"
            }
        } else {
            deckHeightRange = "Not specified"
        }
        
        // Format coordinates - safely unwrapping optionals
        if let latitude = unit.latitude, let longitude = unit.longitude {
            formattedCoordinates = formatCoordinates(latitude: latitude, longitude: longitude)
        } else {
            formattedCoordinates = "Not available"
        }
        
        hasMultiplePhoneNumbers = unit.phoneNumbers.count > 1
    }
    
    private func formatCoordinates(latitude: Double, longitude: Double) -> String {
        let latDirection = latitude >= 0 ? "N" : "S"
        let lonDirection = longitude >= 0 ? "E" : "W"
        
        let absLat = abs(latitude)
        let absLon = abs(longitude)
        
        let latDegrees = floor(absLat)
        let latMinutes = (absLat - latDegrees) * 60
        
        let lonDegrees = floor(absLon)
        let lonMinutes = (absLon - lonDegrees) * 60
        
        return String(format: "%.0f°%.3f'%@, %.0f°%.3f'%@",
                      latDegrees, latMinutes, latDirection,
                      lonDegrees, lonMinutes, lonDirection)
    }
    
    private func updateFavoriteIcon() {
        favoriteIcon = unit?.isFavorite == true ? "favoritesixseven" : "favoriteoutlinesixseven"
    }
}
