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
    
    // MARK: - Map-related Properties
    @Published var mapRegion: MapRegion?
    @Published var mapAnnotation: NavUnitMapAnnotation?
    
    // MARK: - Services
    private let databaseService: NavUnitDatabaseService
    private let photoService: PhotoDatabaseService
    private let navUnitFtpService: NavUnitFtpService
    private let imageCacheService: ImageCacheService
    private let favoritesService: FavoritesService
    
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
        favoritesService: FavoritesService
    ) {
        self.databaseService = databaseService
        self.photoService = photoService
        self.navUnitFtpService = navUnitFtpService
        self.imageCacheService = imageCacheService
        self.favoritesService = favoritesService
    }
    
    // New initializer that takes a NavUnit
    init(
        navUnit: NavUnit,
        databaseService: NavUnitDatabaseService,
        photoService: PhotoDatabaseService,
        navUnitFtpService: NavUnitFtpService,
        imageCacheService: ImageCacheService,
        favoritesService: FavoritesService
    ) {
        self.databaseService = databaseService
        self.photoService = photoService
        self.navUnitFtpService = navUnitFtpService
        self.imageCacheService = imageCacheService
        self.favoritesService = favoritesService
        
        // Set the nav unit and update display properties
        self.unit = navUnit
        updateDisplayProperties()
        updateFavoriteIcon()
        initializeMap()
        
        // Start loading photos asynchronously using a Task that we can manage
        Task { @MainActor in
            do {
                try await loadAllPhotos()
            } catch {
                errorMessage = "Failed to load photos: \(error.localizedDescription)"
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
            } catch {
                errorMessage = "Failed to load photos: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadAllPhotos() async throws {
        guard let unit = unit else { return }
        
        // Load local photos first - using photoService
        do {
            self.localPhotos = try await photoService.getNavUnitPhotosAsync(navUnitId: unit.navUnitId)
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
        
        // In a real implementation, this would navigate to the photo gallery view
        print("Opening gallery at index: \(index), photos: \(localPhotos.count)")
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
        // This would use UIImagePickerController or PHPickerViewController in a real implementation
        print("Taking photo")
    }
    
    func deletePhoto(_ photoId: Int) async {
        do {
            // Fixed: Store the result in a variable, even if we don't use it
            let deleteResult = try await photoService.deleteNavUnitPhotoAsync(photoId: photoId)
            print("Delete result: \(deleteResult)")
            await loadLocalPhotos()
        } catch {
            await MainActor.run {
                self.errorMessage = "Error deleting photo: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadLocalPhotos() async {
        guard let unit = unit else { return }
        
        do {
            // Use photoService instead of databaseService for photo operations
            self.localPhotos = try await photoService.getNavUnitPhotosAsync(navUnitId: unit.navUnitId)
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
