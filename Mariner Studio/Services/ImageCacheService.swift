import Foundation

// Protocol defining the image cache service interface
protocol ImageCacheService {
    func getCacheKey(_ navUnitId: String, _ fileName: String) -> String
    func getImageAsync(_ key: String) async -> Data?
    func saveImageAsync(_ key: String, _ data: Data) async
}

// Placeholder implementation of the ImageCacheService
class ImageCacheServiceImpl: ImageCacheService {
    // In-memory cache
    private var cache: [String: Data] = [:]
    
    // Generate a cache key from nav unit ID and file name
    func getCacheKey(_ navUnitId: String, _ fileName: String) -> String {
        return "\(navUnitId)_\(fileName)"
    }
    
    // Get an image from the cache
    func getImageAsync(_ key: String) async -> Data? {
        return cache[key]
    }
    
    // Save an image to the cache
    func saveImageAsync(_ key: String, _ data: Data) async {
        cache[key] = data
    }
}
