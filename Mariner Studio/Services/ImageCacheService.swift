import Foundation

// Protocol defining the image cache service interface
protocol ImageCacheService {
    func getCacheKey(_ navUnitId: String, _ fileName: String) -> String
    func getImageAsync(_ key: String) async -> Data?
    func saveImageAsync(_ key: String, _ data: Data) async
}

