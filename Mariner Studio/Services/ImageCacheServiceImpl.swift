import Foundation




// Thread-safe implementation of the ImageCacheService that conforms to Sendable
@available(iOS 13.0, *)
final class ImageCacheServiceImpl: ImageCacheService, @unchecked Sendable {
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
                let cachedData = self.cache[key]
                continuation.resume(returning: cachedData)
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

