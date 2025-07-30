import SwiftUI

// Photo item for gallery view
struct GalleryPhotoItem: Identifiable {
    let id = UUID()
    let imageSource: ImageSource
    let caption: String?

    // Create from FtpPhotoItem
    static func fromFtpPhotoItem(_ photo: FtpPhotoItem) -> GalleryPhotoItem {
        return GalleryPhotoItem(
            imageSource: photo.imageSource,
            caption: photo.fileName
        )
    }
}
