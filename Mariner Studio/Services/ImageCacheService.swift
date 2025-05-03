import Foundation

// Protocol defining the image cache service interface
protocol ImageCacheService {
    func getCacheKey(_ navUnitId: String, _ fileName: String) -> String
    func getImageAsync(_ key: String) async -> Data?
    func saveImageAsync(_ key: String, _ data: Data) async
}

// Thread-safe implementation of the ImageCacheService
class ImageCacheServiceImpl: ImageCacheService {
    // In-memory cache with a serial queue for thread safety
    private var cache: [String: Data] = [:]
    private let queue = DispatchQueue(label: "com.mariner.imagecache")
    
    // Generate a cache key from nav unit ID and file name
    func getCacheKey(_ navUnitId: String, _ fileName: String) -> String {
        return "\(navUnitId)_\(fileName)"
    }
    
    // Get an image from the cache
    func getImageAsync(_ key: String) async -> Data? {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.cache[key])
            }
        }
    }
    
    // Save an image to the cache
    func saveImageAsync(_ key: String, _ data: Data) async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.cache[key] = data
                continuation.resume()
            }
        }
    }
}
