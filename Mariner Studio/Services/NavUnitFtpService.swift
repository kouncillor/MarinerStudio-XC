import Foundation
import SwiftUI

// Protocol defining the FTP service interface
protocol NavUnitFtpService {
    func getNavUnitImagesAsync(navUnitId: String) async throws -> [String]
    func downloadNavUnitImageAsync(navUnitId: String, fileName: String) async throws -> Data
}

// Placeholder implementation of the NavUnitFtpService
class NavUnitFtpServiceImpl: NavUnitFtpService {
    // Sample data to use for testing
    private let sampleFileNames = ["image1.jpg", "image2.jpg", "image3.jpg"]
    
    // Returns a list of image file names for a given nav unit
    func getNavUnitImagesAsync(navUnitId: String) async throws -> [String] {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))
        
        // Return sample file names
        return sampleFileNames
    }
    
    // Downloads an image for a given nav unit and file name
    func downloadNavUnitImageAsync(navUnitId: String, fileName: String) async throws -> Data {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))
        
        // Create a simple colored rectangle instead of using UIImage
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
        let image = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: 200, height: 200)
            ctx.cgContext.setFillColor(UIColor.blue.cgColor)
            ctx.cgContext.fill(rect)
        }
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            return imageData
        }
        
        // If no image created, return empty data
        return Data()
    }
}
