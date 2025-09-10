#!/usr/bin/env swift

import Foundation

class KeyEncoder {
    
    // MARK: - Supabase Key Encoding
    static func encodeSupabaseKey(_ key: String) -> String {
        let keyBytes = Array(key.utf8)
        let xorKey: UInt8 = 0x42
        
        // XOR encrypt the key
        let encrypted = keyBytes.map { $0 ^ xorKey }
        
        // Split into chunks of 7 bytes for obfuscation
        let chunkSize = 7
        let chunks = encrypted.chunked(into: chunkSize)
        
        var result = """
        // Generated obfuscated Supabase key data
        private static let supabaseSegments: [(data: [UInt8], offset: Int)] = [
        """
        
        for (index, chunk) in chunks.enumerated() {
            let offset = index * chunkSize
            let hexData = chunk.map { "0x\(String($0, radix: 16, uppercase: false).padded(toLength: 2, withPad: "0"))" }.joined(separator: ", ")
            result += "\n        ([\(hexData)], \(offset)),"
        }
        
        result += "\n    ]"
        result += "\n    private static let supabaseXorKey: UInt8 = 0x42"
        
        return result
    }
    
    // MARK: - RevenueCat Key Encoding
    static func encodeRevenueCatKey(_ key: String) -> String {
        // Simple XOR approach - more reliable
        let keyBytes = Array(key.utf8)
        let xorKey: UInt8 = 0x73 // Different from Supabase key
        
        let encrypted = keyBytes.map { $0 ^ xorKey }
        let hexString = encrypted.map { String(format: "%02x", $0) }.joined()
        
        let result = """
        // Generated obfuscated RevenueCat key data
        private static let revenueCatEncoded: String = "\(hexString)"
        private static let revenueCatXorKey: UInt8 = 0x73
        """
        
        return result
    }
    
    // MARK: - Full SecureKeys Generation
    static func generateSecureKeysFile(supabaseKey: String, revenueCatKey: String) -> String {
        let supabaseCode = encodeSupabaseKey(supabaseKey)
        let revenueCatCode = encodeRevenueCatKey(revenueCatKey)
        
        return """
//
//  SecureKeys.swift
//  Mariner Studio
//
//  Auto-generated secure key storage with obfuscation
//  Generated on: \(Date())
//

import Foundation

/// Secure storage for API keys with runtime obfuscation
/// Keys are stored as encrypted segments and reconstructed at runtime
class SecureKeys {
    
    // MARK: - Supabase Key Storage
    \(supabaseCode)
    
    /// Reconstructs the Supabase anonymous key from obfuscated segments
    static func getSupabaseKey() -> String {
        var result = [UInt8](repeating: 0, count: \(supabaseKey.count))
        
        for segment in supabaseSegments {
            for (index, byte) in segment.data.enumerated() {
                let targetIndex = segment.offset + index
                if targetIndex < result.count {
                    result[targetIndex] = byte ^ supabaseXorKey
                }
            }
        }
        
        return String(bytes: result, encoding: .utf8)?.trimmingCharacters(in: .nullCharacters) ?? ""
    }
    
    // MARK: - RevenueCat Key Storage
    \(revenueCatCode)
    
    /// Reconstructs the RevenueCat API key from obfuscated hex string
    static func getRevenueCatKey() -> String {
        // Convert hex string back to bytes
        var bytes: [UInt8] = []
        let hexString = revenueCatEncoded
        
        for i in stride(from: 0, to: hexString.count, by: 2) {
            let start = hexString.index(hexString.startIndex, offsetBy: i)
            let end = hexString.index(start, offsetBy: 2)
            let hexByte = String(hexString[start..<end])
            if let byte = UInt8(hexByte, radix: 16) {
                bytes.append(byte)
            }
        }
        
        // XOR decrypt
        let decrypted = bytes.map { $0 ^ revenueCatXorKey }
        
        return String(bytes: decrypted, encoding: .utf8) ?? ""
    }
    
    // MARK: - Verification
    static func verifyKeys() {
        let supabase = getSupabaseKey()
        let revenueCat = getRevenueCatKey()
        
        print("🔐 SecureKeys Verification:")
        print("   Supabase key length: \\(supabase.count)")
        print("   Supabase starts with: \\(String(supabase.prefix(20)))...")
        print("   RevenueCat key length: \\(revenueCat.count)")
        print("   RevenueCat starts with: \\(String(revenueCat.prefix(10)))...")
    }
}
"""
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        return stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: Swift.min(size, count - $0))
            return String(self[start..<end])
        }
    }
    
    func padded(toLength length: Int, withPad pad: String) -> String {
        if count >= length { return self }
        return pad + self
    }
}

// MARK: - Main Execution
if CommandLine.arguments.count == 3 {
    let supabaseKey = CommandLine.arguments[1]
    let revenueCatKey = CommandLine.arguments[2]
    
    let secureKeysContent = KeyEncoder.generateSecureKeysFile(
        supabaseKey: supabaseKey,
        revenueCatKey: revenueCatKey
    )
    
    print(secureKeysContent)
} else {
    print("Usage: swift KeyEncoder.swift <supabase_key> <revenuecat_key>")
    print("")
    print("Example:")
    print("swift KeyEncoder.swift 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...' 'appl_owWBbZSrntrBRGfXiVahtAozFrk'")
}