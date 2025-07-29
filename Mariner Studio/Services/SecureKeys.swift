//
//  SecureKeys.swift
//  Mariner Studio
//
//  Auto-generated secure key storage with obfuscation
//  Generated on: 2025-07-29 17:46:34 +0000
//

import Foundation

/// Secure storage for API keys with runtime obfuscation
/// Keys are stored as encrypted segments and reconstructed at runtime
class SecureKeys {
    
    // MARK: - Supabase Key Storage
    // Generated obfuscated Supabase key data
private static let supabaseSegments: [(data: [UInt8], offset: Int)] = [
        ([0x27, 0x3b, 0x08, 0x2a, 0x20, 0x05, 0x21], 0),
        ([0x2b, 0x0d, 0x2b, 0x08, 0x0b, 0x17, 0x38], 7),
        ([0x0b, 0x73, 0x0c, 0x2b, 0x0b, 0x31, 0x0b], 14),
        ([0x2c, 0x10, 0x77, 0x21, 0x01, 0x0b, 0x74], 21),
        ([0x0b, 0x29, 0x32, 0x1a, 0x14, 0x01, 0x08], 28),
        ([0x7b, 0x6c, 0x27, 0x3b, 0x08, 0x32, 0x21], 35),
        ([0x71, 0x0f, 0x2b, 0x0d, 0x2b, 0x08, 0x38], 42),
        ([0x26, 0x1a, 0x00, 0x2a, 0x1b, 0x2f, 0x04], 49),
        ([0x38, 0x18, 0x11, 0x0b, 0x31, 0x0b, 0x2c], 56),
        ([0x08, 0x2e, 0x18, 0x2b, 0x0b, 0x74, 0x0b], 63),
        ([0x2f, 0x3a, 0x2c, 0x18, 0x0a, 0x0c, 0x70], 70),
        ([0x18, 0x15, 0x18, 0x3a, 0x21, 0x15, 0x7b], 77),
        ([0x3b, 0x26, 0x2f, 0x77, 0x70, 0x23, 0x70], 84),
        ([0x2e, 0x34, 0x1b, 0x2c, 0x10, 0x2d, 0x0b], 91),
        ([0x2b, 0x35, 0x2b, 0x21, 0x2f, 0x7b, 0x31], 98),
        ([0x18, 0x11, 0x0b, 0x74, 0x0b, 0x2f, 0x04], 105),
        ([0x37, 0x20, 0x70, 0x76, 0x2b, 0x0e, 0x01], 112),
        ([0x08, 0x32, 0x1b, 0x1a, 0x13, 0x2b, 0x0d], 119),
        ([0x28, 0x07, 0x71, 0x0c, 0x16, 0x03, 0x35], 126),
        ([0x0d, 0x16, 0x13, 0x73, 0x0f, 0x28, 0x13], 133),
        ([0x31, 0x0b, 0x2f, 0x14, 0x76, 0x21, 0x01], 140),
        ([0x0b, 0x74, 0x0f, 0x28, 0x03, 0x70, 0x0c], 147),
        ([0x16, 0x1b, 0x71, 0x0f, 0x06, 0x17, 0x3b], 154),
        ([0x0c, 0x0a, 0x72, 0x6c, 0x30, 0x0c, 0x21], 161),
        ([0x77, 0x13, 0x16, 0x36, 0x14, 0x76, 0x0b], 168),
        ([0x13, 0x09, 0x77, 0x2c, 0x6f, 0x0a, 0x34], 175),
        ([0x01, 0x07, 0x32, 0x0d, 0x18, 0x06, 0x32], 182),
        ([0x14, 0x01, 0x35, 0x12, 0x32, 0x2f, 0x09], 189),
        ([0x29, 0x28, 0x1b, 0x14, 0x00, 0x07, 0x0a], 196),
        ([0x0d, 0x33, 0x2c, 0x14, 0x0b], 203),
    ]
    private static let supabaseXorKey: UInt8 = 0x42
    
    /// Reconstructs the Supabase anonymous key from obfuscated segments
    static func getSupabaseKey() -> String {
        var result = [UInt8](repeating: 0, count: 208)
        
        for segment in supabaseSegments {
            for (index, byte) in segment.data.enumerated() {
                let targetIndex = segment.offset + index
                if targetIndex < result.count {
                    result[targetIndex] = byte ^ supabaseXorKey
                }
            }
        }
        
        return String(bytes: result, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? ""
    }
    
    // MARK: - RevenueCat Key Storage
    // Generated obfuscated RevenueCat key data
private static let revenueCatEncoded: String = "1203031f2c1c042431112920011d0701312134152b1a25121b07321c09350118"
private static let revenueCatXorKey: UInt8 = 0x73
    
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
    
    // MARK: - Verification (Debug only)
    #if DEBUG
    static func verifyKeys() {
        let supabase = getSupabaseKey()
        let revenueCat = getRevenueCatKey()
        
        print("🔐 SecureKeys Verification:")
        print("   Supabase key length: \(supabase.count)")
        print("   Supabase starts with: \(String(supabase.prefix(20)))...")
        print("   RevenueCat key length: \(revenueCat.count)")
        print("   RevenueCat starts with: \(String(revenueCat.prefix(10)))...")
    }
    #endif
}
