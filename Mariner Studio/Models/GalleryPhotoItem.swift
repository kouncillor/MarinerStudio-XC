import SwiftUI

// Photo item for gallery view
struct GalleryPhotoItem: Identifiable {
    let id = UUID()
    let imageSource: ImageSource
    let caption: String?
    
    // Create from NavUnitPhoto
    static func fromNavUnitPhoto(_ photo: NavUnitPhoto) -> GalleryPhotoItem {
        // Load image from file path
        if let image = UIImage(contentsOfFile: photo.filePath) {
            if let data = image.jpegData(compressionQuality: 0.9) {
                return GalleryPhotoItem(
                    imageSource: .data(data),
                    caption: photo.description
                )
            }
        }
        
        return GalleryPhotoItem(
            imageSource: .placeholder,
            caption: photo.description
        )
    }
    
    // Create from FtpPhotoItem
    static func fromFtpPhotoItem(_ photo: FtpPhotoItem) -> GalleryPhotoItem {
        return GalleryPhotoItem(
            imageSource: photo.imageSource,
            caption: photo.fileName
        )
    }
}
