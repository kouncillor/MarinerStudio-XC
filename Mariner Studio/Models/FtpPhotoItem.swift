import SwiftUI

// Image source type for FtpPhotoItem
enum ImageSource {
    case placeholder
    case data(Data)
}

// Model for FTP photos
struct FtpPhotoItem: Identifiable {
    let id = UUID()
    let fileName: String
    var imageSource: ImageSource
    
    // Convenience initializer with UIImage
    init(fileName: String, image: UIImage?) {
        self.fileName = fileName
        if let image = image, let data = image.jpegData(compressionQuality: 0.8) {
            self.imageSource = .data(data)
        } else {
            self.imageSource = .placeholder
        }
    }
    
    // Default initializer with ImageSource
    init(fileName: String, imageSource: ImageSource) {
        self.fileName = fileName
        self.imageSource = imageSource
    }
}
