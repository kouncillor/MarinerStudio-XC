import Foundation
import Supabase

/// Simplified Supabase manager for public route downloads only
/// No authentication functionality - only public data access
final class SupabaseManager {
    
    // MARK: - Shared Instance
    static let shared = SupabaseManager()
    
    // MARK: - Private Properties  
    private let client: SupabaseClient
    
    // MARK: - Initialization
    private init() {
        // Get secure configuration
        let config = AppConfiguration.shared
        
        // Validate Supabase configuration
        guard !config.supabaseURL.isEmpty else {
            fatalError("❌ SUPABASE: Missing SUPABASE_URL configuration")
        }
        
        guard !config.supabaseAnonKey.isEmpty else {
            fatalError("❌ SUPABASE: Missing SUPABASE_ANON_KEY configuration")
        }
        
        guard let url = URL(string: config.supabaseURL) else {
            fatalError("❌ SUPABASE: Invalid SUPABASE_URL: \(config.supabaseURL)")
        }
        
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: config.supabaseAnonKey)
        DebugLogger.shared.log("✅ SUPABASE: Initialized for public routes access only", category: "SUPABASE_INIT")
    }
    
    // MARK: - Public Routes Access
    
    /// Retrieve all embedded routes from the public Supabase table
    /// Used for browsing available routes from the cloud database
    /// - Parameter limit: Optional limit on number of routes to fetch (default: no limit)
    /// - Returns: Array of all embedded routes
    /// - Throws: Database errors or network issues
    func getEmbeddedRoutes(limit: Int? = nil) async throws -> [RemoteEmbeddedRoute] {
        DebugLogger.shared.log("📥🛣️ ROUTES: Fetching public embedded routes", category: "SUPABASE_ROUTES")
        
        do {
            var query = client
                .from("embedded_routes")
                .select("*")
                .eq("is_active", value: true) // Only fetch active routes
                .order("created_at", ascending: false)
            
            if let limit = limit {
                query = query.limit(limit)
            }
            
            let response: PostgrestResponse<[RemoteEmbeddedRoute]> = try await query.execute()
            
            DebugLogger.shared.log("✅ ROUTES: Fetched \(response.value.count) embedded routes", category: "SUPABASE_ROUTES")
            return response.value
            
        } catch {
            DebugLogger.shared.log("❌ ROUTES: Failed to fetch embedded routes: \(error)", category: "SUPABASE_ROUTES")
            throw error
        }
    }
}