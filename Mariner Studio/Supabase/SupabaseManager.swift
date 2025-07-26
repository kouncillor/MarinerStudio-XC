import Foundation
import Supabase
import Combine

/// Centralized Supabase manager with comprehensive logging and race condition monitoring
final class SupabaseManager {
    
    // MARK: - Shared Instance
    static let shared = SupabaseManager()
    
    // MARK: - Private Properties
    public let client: SupabaseClient
    private let operationQueue = DispatchQueue(label: "supabase.operations", qos: .utility)
    internal let logQueue = DispatchQueue(label: "supabase.logging", qos: .background)
    private var activeOperations: [String: Date] = [:]
    private let operationsLock = NSLock()
    private var operationCounter: Int = 0
    
    // MARK: - Performance Tracking
    private var operationStats: [String: OperationStats] = [:]
    private let statsLock = NSLock()
    
    // MARK: - Session Caching
    private var cachedSession: Session?
    private var sessionCacheTime: Date?
    private let sessionCacheLock = NSLock()
    private let sessionCacheValidDuration: TimeInterval = 60 // 1 minute cache
    
    // MARK: - Initialization
    private init() {
        logQueue.async {
            DebugLogger.shared.log("\n🚀 SUPABASE MANAGER: Initializing comprehensive logging system", category: "SUPABASE_INIT")
            DebugLogger.shared.log("🚀 SUPABASE MANAGER: Thread = \(Thread.current)", category: "SUPABASE_INIT")
            DebugLogger.shared.log("🚀 SUPABASE MANAGER: Timestamp = \(Date())", category: "SUPABASE_INIT")
        }
        
        guard let url = URL(string: "https://lgdsvefqqorvnvkiobth.supabase.co") else {
            fatalError("❌ SUPABASE MANAGER: Invalid URL")
        }
        
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxnZHN2ZWZxcW9ydm52a2lvYnRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwOTQ1MjQsImV4cCI6MjA2NTY3MDUyNH0.rNc5QTtV4IQK5n-HvCEpOZDpVCwPpmKkjYVBEHOqnVI"
        
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        
        logQueue.async {
            DebugLogger.shared.log("✅ SUPABASE MANAGER: Client initialized successfully", category: "SUPABASE_INIT")
            DebugLogger.shared.log("✅ SUPABASE MANAGER: Ready for operations\n", category: "SUPABASE_INIT")
        }
    }
    
    // MARK: - Operation Tracking
    
    internal func startOperation(_ name: String, details: String = "") -> String {
        operationsLock.lock()
        defer { operationsLock.unlock() }
        
        operationCounter += 1
        let operationId = "\(name)_\(operationCounter)"
        let startTime = Date()
        activeOperations[operationId] = startTime
        
        logQueue.async {
            DebugLogger.shared.log("\n🟢 OPERATION START: \(operationId)", category: "SUPABASE_OPS")
            DebugLogger.shared.log("🟢 OPERATION: \(name)", category: "SUPABASE_OPS")
            DebugLogger.shared.log("🟢 DETAILS: \(details)", category: "SUPABASE_OPS")
            DebugLogger.shared.log("🟢 START TIME: \(startTime)", category: "SUPABASE_OPS")
            DebugLogger.shared.log("🟢 THREAD: \(Thread.current)", category: "SUPABASE_OPS")
            DebugLogger.shared.log("🟢 ACTIVE OPERATIONS: \(self.activeOperations.count)", category: "SUPABASE_OPS")
            DebugLogger.shared.log("🟢 CONCURRENT OPS: \(Array(self.activeOperations.keys))", category: "SUPABASE_OPS")
        }
        
        return operationId
    }
    
    internal func endOperation(_ operationId: String, success: Bool, error: Error? = nil) {
        operationsLock.lock()
        let startTime = activeOperations.removeValue(forKey: operationId)
        operationsLock.unlock()
        
        guard let start = startTime else { return }
        
        let duration = Date().timeIntervalSince(start)
        let operationName = String(operationId.split(separator: "_").first ?? "unknown")
        
        // Update stats
        updateStats(operationName: operationName, duration: duration, success: success)
        
        logQueue.async {
            if success {
                DebugLogger.shared.log("\n✅ OPERATION SUCCESS: \(operationId)", category: "SUPABASE_OPS")
                DebugLogger.shared.log("✅ DURATION: \(String(format: "%.3f", duration))s", category: "SUPABASE_OPS")
            } else {
                DebugLogger.shared.log("\n❌ OPERATION FAILED: \(operationId)", category: "SUPABASE_OPS")
                DebugLogger.shared.log("❌ DURATION: \(String(format: "%.3f", duration))s", category: "SUPABASE_OPS")
                if let error = error {
                    DebugLogger.shared.log("❌ ERROR: \(error)", category: "SUPABASE_OPS")
                    DebugLogger.shared.log("❌ ERROR TYPE: \(type(of: error))", category: "SUPABASE_OPS")
                    let nsError = error as NSError
                    DebugLogger.shared.log("❌ ERROR DOMAIN: \(nsError.domain)", category: "SUPABASE_OPS")
                    DebugLogger.shared.log("❌ ERROR CODE: \(nsError.code)", category: "SUPABASE_OPS")
                    DebugLogger.shared.log("❌ ERROR INFO: \(nsError.userInfo)", category: "SUPABASE_OPS")
                }
            }
            DebugLogger.shared.log("✅ REMAINING ACTIVE: \(self.activeOperations.count)", category: "SUPABASE_OPS")
            if !self.activeOperations.isEmpty {
                DebugLogger.shared.log("⚠️ STILL RUNNING: \(Array(self.activeOperations.keys))", category: "SUPABASE_OPS")
                
                // Check for long-running operations
                let now = Date()
                for (opId, startTime) in self.activeOperations {
                    let runTime = now.timeIntervalSince(startTime)
                    if runTime > 10.0 { // More than 10 seconds
                        DebugLogger.shared.log("🚨 LONG RUNNING: \(opId) has been running for \(String(format: "%.1f", runTime))s", category: "SUPABASE_OPS")
                    }
                }
            }
        }
    }
    
    private func updateStats(operationName: String, duration: TimeInterval, success: Bool) {
        statsLock.lock()
        defer { statsLock.unlock() }
        
        if var stats = operationStats[operationName] {
            stats.totalCalls += 1
            stats.totalDuration += duration
            stats.minDuration = min(stats.minDuration, duration)
            stats.maxDuration = max(stats.maxDuration, duration)
            if success {
                stats.successCount += 1
            } else {
                stats.failureCount += 1
            }
            operationStats[operationName] = stats
        } else {
            operationStats[operationName] = OperationStats(
                totalCalls: 1,
                successCount: success ? 1 : 0,
                failureCount: success ? 0 : 1,
                totalDuration: duration,
                minDuration: duration,
                maxDuration: duration
            )
        }
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) async throws -> Session {
        let operationId = startOperation("signIn", details: "email: \(email)")
        
        do {
            let result = try await client.auth.signIn(email: email, password: password)
            
            logQueue.async {
                DebugLogger.shared.log("📊 SIGN IN RESULT:", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   User ID: \(result.user.id)", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   Email: \(result.user.email ?? "none")", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   Session expires: \(Date(timeIntervalSince1970: TimeInterval(result.expiresAt)))", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   Access token length: \(result.accessToken.count)", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   Refresh token length: \(result.refreshToken.count)", category: "SUPABASE_AUTH")
            }
            
            endOperation(operationId, success: true)
            return result
        } catch {
            endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    
    
    
    func signUp(email: String, password: String) async throws -> AuthResponse {
        let operationId = startOperation("signUp", details: "email: \(email)")
        
        do {
            let result = try await client.auth.signUp(email: email, password: password)
            
            logQueue.async {
                DebugLogger.shared.log("📊 SIGN UP RESULT:", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   User ID: \(result.user.id)", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   Email: \(result.user.email ?? "none")", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   Email confirmed: \(result.user.emailConfirmedAt != nil)", category: "SUPABASE_AUTH")
            }
            
            endOperation(operationId, success: true)
            return result
        } catch {
            endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    func signOut() async throws {
        let operationId = startOperation("signOut")
        
        do {
            try await client.auth.signOut()
            endOperation(operationId, success: true)
        } catch {
            endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    func getSession() async throws -> Session {
        // Check cache first
        sessionCacheLock.lock()
        if let cached = cachedSession,
           let cacheTime = sessionCacheTime,
           Date().timeIntervalSince(cacheTime) < sessionCacheValidDuration {
            sessionCacheLock.unlock()
            
            logQueue.async {
                DebugLogger.shared.log("🎯 SESSION CACHE HIT: Using cached session", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   Cache age: \(String(format: "%.1f", Date().timeIntervalSince(cacheTime)))s", category: "SUPABASE_AUTH")
            }
            
            return cached
        }
        sessionCacheLock.unlock()
        
        let operationId = startOperation("getSession")
        
        do {
            let session = try await client.auth.session
            
            // Cache the session
            sessionCacheLock.lock()
            cachedSession = session
            sessionCacheTime = Date()
            sessionCacheLock.unlock()
            
            logQueue.async {
                DebugLogger.shared.log("📊 SESSION RESULT (FRESH):", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   User ID: \(session.user.id)", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   Email: \(session.user.email ?? "none")", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   Expires at: \(Date(timeIntervalSince1970: TimeInterval(session.expiresAt)))", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   Time until expiry: \(String(format: "%.1f", Date(timeIntervalSince1970: TimeInterval(session.expiresAt)).timeIntervalSinceNow / 60)) minutes", category: "SUPABASE_AUTH")
                DebugLogger.shared.log("   Cached for future use", category: "SUPABASE_AUTH")
            }
            
            endOperation(operationId, success: true)
            return session
        } catch {
            endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    // MARK: - Database Operations
    
    func from(_ table: String) -> PostgrestQueryBuilder {
        logQueue.async {
            DebugLogger.shared.log("🗄️ DATABASE: Creating query builder for table '\(table)'", category: "SUPABASE_DB")
        }
        
        return client.from(table)
    }
    
    
    // MARK: - Connection Health
    
    func checkConnectionHealth() async -> Bool {
        let operationId = startOperation("healthCheck")
        
        do {
            // Try a simple query
            let _ = try await client
                .from("user_tide_favorites")
                .select("*")
                .limit(1)
                .execute()
            
            endOperation(operationId, success: true)
            return true
        } catch {
            endOperation(operationId, success: false, error: error)
            return false
        }
    }
    
    // MARK: - Statistics and Monitoring
    
    func printStats() {
        statsLock.lock()
        let stats = operationStats
        statsLock.unlock()
        
        logQueue.async {
            DebugLogger.shared.log("\n📊 SUPABASE MANAGER STATISTICS:", category: "SUPABASE_STATS")
            DebugLogger.shared.log("📊 ================================", category: "SUPABASE_STATS")
            
            for (operation, stat) in stats.sorted(by: { $0.key < $1.key }) {
                let avgDuration = stat.totalDuration / Double(stat.totalCalls)
                let successRate = Double(stat.successCount) / Double(stat.totalCalls) * 100
                
                DebugLogger.shared.log("📊 \(operation.uppercased()):", category: "SUPABASE_STATS")
                DebugLogger.shared.log("   Total calls: \(stat.totalCalls)", category: "SUPABASE_STATS")
                DebugLogger.shared.log("   Success rate: \(String(format: "%.1f", successRate))%", category: "SUPABASE_STATS")
                DebugLogger.shared.log("   Avg duration: \(String(format: "%.3f", avgDuration))s", category: "SUPABASE_STATS")
                DebugLogger.shared.log("   Min duration: \(String(format: "%.3f", stat.minDuration))s", category: "SUPABASE_STATS")
                DebugLogger.shared.log("   Max duration: \(String(format: "%.3f", stat.maxDuration))s", category: "SUPABASE_STATS")
                DebugLogger.shared.log("   Failures: \(stat.failureCount)", category: "SUPABASE_STATS")
                DebugLogger.shared.log("", category: "SUPABASE_STATS")
            }
            
            DebugLogger.shared.log("📊 Current active operations: \(self.activeOperations.count)", category: "SUPABASE_STATS")
            if !self.activeOperations.isEmpty {
                for (opId, startTime) in self.activeOperations {
                    let duration = Date().timeIntervalSince(startTime)
                    DebugLogger.shared.log("   \(opId): \(String(format: "%.1f", duration))s", category: "SUPABASE_STATS")
                }
            }
            DebugLogger.shared.log("📊 ================================\n", category: "SUPABASE_STATS")
        }
    }
    
    func getCurrentOperations() -> [String] {
        operationsLock.lock()
        defer { operationsLock.unlock() }
        return Array(activeOperations.keys)
    }
    
    // MARK: - Debug Methods
    
    func enableVerboseLogging() {
        logQueue.async {
            DebugLogger.shared.log("🔍 SUPABASE MANAGER: Verbose logging ENABLED", category: "SUPABASE_DEBUG")
        }
    }
    
    func logCurrentState() {
        let operations = getCurrentOperations()
        
        logQueue.async {
            DebugLogger.shared.log("\n🔍 SUPABASE MANAGER STATE:", category: "SUPABASE_STATE")
            DebugLogger.shared.log("🔍 Active operations: \(operations.count)", category: "SUPABASE_STATE")
            DebugLogger.shared.log("🔍 Operations: \(operations)", category: "SUPABASE_STATE")
            DebugLogger.shared.log("🔍 Thread: \(Thread.current)", category: "SUPABASE_STATE")
            DebugLogger.shared.log("🔍 Timestamp: \(Date())", category: "SUPABASE_STATE")
        }
    }
    
    
    
    // MARK: - Navigation Unit Favorites Methods
        
        /// Retrieve all navigation unit favorites for a specific user from Supabase
        /// Used by NavUnitSyncService for sync operations
        /// - Parameter userId: The authenticated user's unique identifier
        /// - Returns: Array of RemoteNavUnitFavorite records for the user
        /// - Throws: Database errors or network issues
        func getNavUnitFavorites(userId: UUID) async throws -> [RemoteNavUnitFavorite] {
            let operationId = startOperation("getNavUnitFavorites", details: "userId: \(userId)")
            
            do {
                logQueue.async {
                    DebugLogger.shared.log("☁️🧭 NAV_UNIT_FAVORITES_QUERY: Starting remote favorites retrieval", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("☁️🧭 NAV_UNIT_FAVORITES_QUERY: Table = user_nav_unit_favorites", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("☁️🧭 NAV_UNIT_FAVORITES_QUERY: User ID filter = \(userId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("☁️🧭 NAV_UNIT_FAVORITES_QUERY: Timestamp = \(Date())", category: "SUPABASE_NAVUNIT")
                }
                
                // Query the user_nav_unit_favorites table for this specific user
                let response: PostgrestResponse<[RemoteNavUnitFavorite]> = try await client
                    .from("user_nav_unit_favorites")
                    .select("*")
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                
                let favorites = response.value
                
                logQueue.async {
                    DebugLogger.shared.log("✅☁️🧭 NAV_UNIT_FAVORITES_SUCCESS: Retrieved \(favorites.count) nav unit favorites", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("☁️🧭 NAV_UNIT_FAVORITES_BREAKDOWN:", category: "SUPABASE_NAVUNIT")
                    
                    // Log breakdown of favorite vs unfavorite records
                    let favoriteRecords = favorites.filter { $0.isFavorite }
                    let unfavoriteRecords = favorites.filter { !$0.isFavorite }
                    DebugLogger.shared.log("   - Favorites (true): \(favoriteRecords.count)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("   - Unfavorites (false): \(unfavoriteRecords.count)", category: "SUPABASE_NAVUNIT")
                    
                    // Log first few records for debugging
                    if !favorites.isEmpty {
                        DebugLogger.shared.log("☁️🧭 NAV_UNIT_FAVORITES_SAMPLE:", category: "SUPABASE_NAVUNIT")
                        for (index, favorite) in favorites.prefix(5).enumerated() {
                            DebugLogger.shared.log("   [\(index)] NavUnit: \(favorite.navUnitId)", category: "SUPABASE_NAVUNIT")
                            DebugLogger.shared.log("       Name: \(favorite.navUnitName ?? "unknown")", category: "SUPABASE_NAVUNIT")
                            DebugLogger.shared.log("       Favorite: \(favorite.isFavorite)", category: "SUPABASE_NAVUNIT")
                            DebugLogger.shared.log("       Modified: \(favorite.lastModified)", category: "SUPABASE_NAVUNIT")
                            DebugLogger.shared.log("       Device: \(favorite.deviceId)", category: "SUPABASE_NAVUNIT")
                            DebugLogger.shared.log("       Coords: \(favorite.latitude?.description ?? "nil"), \(favorite.longitude?.description ?? "nil")", category: "SUPABASE_NAVUNIT")
                        }
                        
                        if favorites.count > 5 {
                            DebugLogger.shared.log("   ... and \(favorites.count - 5) more records", category: "SUPABASE_NAVUNIT")
                        }
                    } else {
                        DebugLogger.shared.log("⚠️☁️🧭 NAV_UNIT_FAVORITES_WARNING: No remote favorites found for user", category: "SUPABASE_NAVUNIT")
                    }
                }
                
                endOperation(operationId, success: true)
                return favorites
                
            } catch {
                logQueue.async {
                    DebugLogger.shared.log("❌☁️🧭 NAV_UNIT_FAVORITES_ERROR: Failed to retrieve remote favorites", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("❌☁️🧭 NAV_UNIT_FAVORITES_ERROR_DETAILS: \(error.localizedDescription)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("❌☁️🧭 NAV_UNIT_FAVORITES_ERROR_TYPE: \(type(of: error))", category: "SUPABASE_NAVUNIT")
                    
                    // Log additional error context for debugging
                    if let postgrestError = error as? PostgrestError {
                        DebugLogger.shared.log("❌☁️🧭 NAV_UNIT_FAVORITES_POSTGREST_ERROR: \(postgrestError)", category: "SUPABASE_NAVUNIT")
                    }
                }
                
                endOperation(operationId, success: false, error: error)
                throw error
            }
        }
        
        /// Insert or update a single navigation unit favorite in Supabase
        /// Uses upsert strategy to handle both new inserts and updates
        /// - Parameter favorite: RemoteNavUnitFavorite record to insert/update
        /// - Throws: Database errors or network issues
        func upsertNavUnitFavorite(_ favorite: RemoteNavUnitFavorite) async throws {
            let operationId = startOperation("upsertNavUnitFavorite",
                                           details: "navUnitId: \(favorite.navUnitId), isFavorite: \(favorite.isFavorite)")
            
            do {
                logQueue.async {
                    DebugLogger.shared.log("📤🧭 NAV_UNIT_UPSERT: Starting nav unit favorite upsert", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("📤🧭 NAV_UNIT_UPSERT: Table = user_nav_unit_favorites", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("📤🧭 NAV_UNIT_UPSERT: NavUnit ID = \(favorite.navUnitId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("📤🧭 NAV_UNIT_UPSERT: Name = \(favorite.navUnitName ?? "unknown")", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("📤🧭 NAV_UNIT_UPSERT: User ID = \(favorite.userId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("📤🧭 NAV_UNIT_UPSERT: Is Favorite = \(favorite.isFavorite)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("📤🧭 NAV_UNIT_UPSERT: Last Modified = \(favorite.lastModified)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("📤🧭 NAV_UNIT_UPSERT: Device ID = \(favorite.deviceId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("📤🧭 NAV_UNIT_UPSERT: Timestamp = \(Date())", category: "SUPABASE_NAVUNIT")
                }
                
                // Use upsert to handle both insert and update cases
                // Supabase will insert if no matching record exists, update if it does
                try await client
                    .from("user_nav_unit_favorites")
                   // .upsert(favorite)
                    .upsert(favorite, onConflict: "user_id,nav_unit_id")
                    .execute()
                
                logQueue.async {
                    DebugLogger.shared.log("✅📤🧭 NAV_UNIT_UPSERT_SUCCESS: Nav unit favorite upserted successfully", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("✅📤🧭 NAV_UNIT_UPSERT_SUCCESS: NavUnit \(favorite.navUnitId) - \(favorite.navUnitName ?? "unknown")", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("✅📤🧭 NAV_UNIT_UPSERT_SUCCESS: Final state: isFavorite = \(favorite.isFavorite)", category: "SUPABASE_NAVUNIT")
                }
                
                endOperation(operationId, success: true)
                
            } catch {
                logQueue.async {
                    DebugLogger.shared.log("❌📤🧭 NAV_UNIT_UPSERT_ERROR: Failed to upsert nav unit favorite", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("❌📤🧭 NAV_UNIT_UPSERT_ERROR: NavUnit = \(favorite.navUnitId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("❌📤🧭 NAV_UNIT_UPSERT_ERROR_DETAILS: \(error.localizedDescription)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("❌📤🧭 NAV_UNIT_UPSERT_ERROR_TYPE: \(type(of: error))", category: "SUPABASE_NAVUNIT")
                    
                    // Log the favorite data that failed to upsert for debugging
                    DebugLogger.shared.log("❌📤🧭 NAV_UNIT_UPSERT_FAILED_DATA:", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("   NavUnit ID: \(favorite.navUnitId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("   User ID: \(favorite.userId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("   Is Favorite: \(favorite.isFavorite)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("   Last Modified: \(favorite.lastModified)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("   Device ID: \(favorite.deviceId)", category: "SUPABASE_NAVUNIT")
                    
                    // Log additional error context for debugging
                    if let postgrestError = error as? PostgrestError {
                        DebugLogger.shared.log("❌📤🧭 NAV_UNIT_UPSERT_POSTGREST_ERROR: \(postgrestError)", category: "SUPABASE_NAVUNIT")
                    }
                }
                
                endOperation(operationId, success: false, error: error)
                throw error
            }
        }
        
        /// Delete a navigation unit favorite from Supabase
        /// Used when a user completely removes a favorite (rare, but included for completeness)
        /// - Parameters:
        ///   - userId: The authenticated user's unique identifier
        ///   - navUnitId: The navigation unit identifier to remove
        /// - Throws: Database errors or network issues
        func deleteNavUnitFavorite(userId: UUID, navUnitId: String) async throws {
            let operationId = startOperation("deleteNavUnitFavorite",
                                           details: "userId: \(userId), navUnitId: \(navUnitId)")
            
            do {
                logQueue.async {
                    DebugLogger.shared.log("🗑️🧭 NAV_UNIT_DELETE: Starting nav unit favorite deletion", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("🗑️🧭 NAV_UNIT_DELETE: Table = user_nav_unit_favorites", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("🗑️🧭 NAV_UNIT_DELETE: User ID = \(userId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("🗑️🧭 NAV_UNIT_DELETE: NavUnit ID = \(navUnitId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("🗑️🧭 NAV_UNIT_DELETE: Timestamp = \(Date())", category: "SUPABASE_NAVUNIT")
                }
                
                // Delete the specific record for this user and nav unit
                try await client
                    .from("user_nav_unit_favorites")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .eq("nav_unit_id", value: navUnitId)
                    .execute()
                
                logQueue.async {
                    DebugLogger.shared.log("✅🗑️🧭 NAV_UNIT_DELETE_SUCCESS: Nav unit favorite deleted successfully", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("✅🗑️🧭 NAV_UNIT_DELETE_SUCCESS: User \(userId) - NavUnit \(navUnitId)", category: "SUPABASE_NAVUNIT")
                }
                
                endOperation(operationId, success: true)
                
            } catch {
                logQueue.async {
                    DebugLogger.shared.log("❌🗑️🧭 NAV_UNIT_DELETE_ERROR: Failed to delete nav unit favorite", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("❌🗑️🧭 NAV_UNIT_DELETE_ERROR: User = \(userId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("❌🗑️🧭 NAV_UNIT_DELETE_ERROR: NavUnit = \(navUnitId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("❌🗑️🧭 NAV_UNIT_DELETE_ERROR_DETAILS: \(error.localizedDescription)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("❌🗑️🧭 NAV_UNIT_DELETE_ERROR_TYPE: \(type(of: error))", category: "SUPABASE_NAVUNIT")
                    
                    // Log additional error context for debugging
                    if let postgrestError = error as? PostgrestError {
                        DebugLogger.shared.log("❌🗑️🧭 NAV_UNIT_DELETE_POSTGREST_ERROR: \(postgrestError)", category: "SUPABASE_NAVUNIT")
                    }
                }
                
                endOperation(operationId, success: false, error: error)
                throw error
            }
        }
        
        /// Bulk delete all navigation unit favorites for a user
        /// Used for complete sync resets or user data cleanup
        /// - Parameter userId: The authenticated user's unique identifier
        /// - Returns: Number of records deleted
        /// - Throws: Database errors or network issues
        func deleteAllNavUnitFavorites(userId: UUID) async throws -> Int {
            let operationId = startOperation("deleteAllNavUnitFavorites", details: "userId: \(userId)")
            
            do {
                logQueue.async {
                    DebugLogger.shared.log("🗑️🧭 NAV_UNIT_BULK_DELETE: Starting bulk nav unit favorites deletion", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("🗑️🧭 NAV_UNIT_BULK_DELETE: Table = user_nav_unit_favorites", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("🗑️🧭 NAV_UNIT_BULK_DELETE: User ID = \(userId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("🗑️🧭 NAV_UNIT_BULK_DELETE: Timestamp = \(Date())", category: "SUPABASE_NAVUNIT")
                }
                
                // First, get count of records that will be deleted for reporting
                let countResponse: PostgrestResponse<[RemoteNavUnitFavorite]> = try await client
                    .from("user_nav_unit_favorites")
                    .select("id")
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                
                let recordCount = countResponse.value.count
                
                // Delete all records for this user
                try await client
                    .from("user_nav_unit_favorites")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                
                logQueue.async {
                    DebugLogger.shared.log("✅🗑️🧭 NAV_UNIT_BULK_DELETE_SUCCESS: Bulk deletion completed", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("✅🗑️🧭 NAV_UNIT_BULK_DELETE_SUCCESS: User \(userId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("✅🗑️🧭 NAV_UNIT_BULK_DELETE_SUCCESS: Records deleted: \(recordCount)", category: "SUPABASE_NAVUNIT")
                }
                
                endOperation(operationId, success: true)
                return recordCount
                
            } catch {
                logQueue.async {
                    DebugLogger.shared.log("❌🗑️🧭 NAV_UNIT_BULK_DELETE_ERROR: Failed to bulk delete nav unit favorites", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("❌🗑️🧭 NAV_UNIT_BULK_DELETE_ERROR: User = \(userId)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("❌🗑️🧭 NAV_UNIT_BULK_DELETE_ERROR_DETAILS: \(error.localizedDescription)", category: "SUPABASE_NAVUNIT")
                    DebugLogger.shared.log("❌🗑️🧭 NAV_UNIT_BULK_DELETE_ERROR_TYPE: \(type(of: error))", category: "SUPABASE_NAVUNIT")
                    
                    // Log additional error context for debugging
                    if let postgrestError = error as? PostgrestError {
                        DebugLogger.shared.log("❌🗑️🧭 NAV_UNIT_BULK_DELETE_POSTGREST_ERROR: \(postgrestError)", category: "SUPABASE_NAVUNIT")
                    }
                }
                
                endOperation(operationId, success: false, error: error)
                throw error
            }
        }
    
    // MARK: - Weather Favorites Methods
    
    /// Retrieve all weather location favorites for the specified user from Supabase
    /// Used for syncing weather favorites between devices and users
    /// - Parameter userId: The authenticated user's unique identifier
    /// - Returns: Array of remote weather favorites
    /// - Throws: Database errors or network issues
    func getWeatherFavorites(userId: UUID) async throws -> [RemoteWeatherFavorite] {
        let operationId = startOperation("getWeatherFavorites", details: "userId: \(userId)")
        
        do {
            logQueue.async {
                DebugLogger.shared.log("📥🌤️ WEATHER_FAVORITES_FETCH: Starting weather favorites query for user", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📥🌤️ WEATHER_FAVORITES_FETCH: Table = user_weather_favorites", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📥🌤️ WEATHER_FAVORITES_FETCH: User ID = \(userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📥🌤️ WEATHER_FAVORITES_FETCH: Filter = user_id eq \(userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📥🌤️ WEATHER_FAVORITES_FETCH: Timestamp = \(Date())", category: "SUPABASE_WEATHER")
            }
            
            let response: PostgrestResponse<[RemoteWeatherFavorite]> = try await client
                .from("user_weather_favorites")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
            
            logQueue.async {
                DebugLogger.shared.log("✅📥🌤️ WEATHER_FAVORITES_FETCH_SUCCESS: Weather favorites retrieved successfully", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("✅📥🌤️ WEATHER_FAVORITES_FETCH_SUCCESS: User = \(userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("✅📥🌤️ WEATHER_FAVORITES_FETCH_SUCCESS: Count = \(response.value.count)", category: "SUPABASE_WEATHER")
                
                if !response.value.isEmpty {
                    DebugLogger.shared.log("✅📥🌤️ WEATHER_FAVORITES_FETCH_SUCCESS: Sample locations:", category: "SUPABASE_WEATHER")
                    for (index, favorite) in response.value.prefix(5).enumerated() {
                        DebugLogger.shared.log("   [\(index + 1)] \(favorite.latitude),\(favorite.longitude) - \(favorite.locationName) (favorite: \(favorite.isFavorite))", category: "SUPABASE_WEATHER")
                    }
                    if response.value.count > 5 {
                        DebugLogger.shared.log("   ... and \(response.value.count - 5) more", category: "SUPABASE_WEATHER")
                    }
                } else {
                    DebugLogger.shared.log("✅📥🌤️ WEATHER_FAVORITES_FETCH_SUCCESS: No weather favorites found for user", category: "SUPABASE_WEATHER")
                }
            }
            
            endOperation(operationId, success: true)
            return response.value
            
        } catch {
            logQueue.async {
                DebugLogger.shared.log("❌📥🌤️ WEATHER_FAVORITES_FETCH_ERROR: Failed to retrieve weather favorites", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌📥🌤️ WEATHER_FAVORITES_FETCH_ERROR: User = \(userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌📥🌤️ WEATHER_FAVORITES_FETCH_ERROR_DETAILS: \(error.localizedDescription)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌📥🌤️ WEATHER_FAVORITES_FETCH_ERROR_TYPE: \(type(of: error))", category: "SUPABASE_WEATHER")
                
                // Log additional error context for debugging
                if let postgrestError = error as? PostgrestError {
                    DebugLogger.shared.log("❌📥🌤️ WEATHER_FAVORITES_FETCH_POSTGREST_ERROR: \(postgrestError)", category: "SUPABASE_WEATHER")
                    if let code = postgrestError.code {
                        DebugLogger.shared.log("❌📥🌤️ WEATHER_FAVORITES_FETCH_ERROR_CODE: \(code)", category: "SUPABASE_WEATHER")
                    }
                    DebugLogger.shared.log("❌📥🌤️ WEATHER_FAVORITES_FETCH_ERROR_MESSAGE: \(postgrestError.message)", category: "SUPABASE_WEATHER")
                }
            }
            
            endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Insert or update a weather location favorite in Supabase
    /// Uses upsert to handle both new inserts and updates automatically
    /// - Parameter favorite: The weather favorite data to insert/update
    /// - Throws: Database errors or network issues
    func upsertWeatherFavorite(_ favorite: RemoteWeatherFavorite) async throws {
        let operationId = startOperation("upsertWeatherFavorite", 
                                       details: "location: \(favorite.latitude),\(favorite.longitude), name: \(favorite.locationName)")
        
        do {
            logQueue.async {
                DebugLogger.shared.log("📤🌤️ WEATHER_FAVORITE_UPSERT: Starting weather favorite upsert", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📤🌤️ WEATHER_FAVORITE_UPSERT: Table = user_weather_favorites", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📤🌤️ WEATHER_FAVORITE_UPSERT: User ID = \(favorite.userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📤🌤️ WEATHER_FAVORITE_UPSERT: Location = \(favorite.latitude),\(favorite.longitude)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📤🌤️ WEATHER_FAVORITE_UPSERT: Location Name = \(favorite.locationName)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📤🌤️ WEATHER_FAVORITE_UPSERT: Is Favorite = \(favorite.isFavorite)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📤🌤️ WEATHER_FAVORITE_UPSERT: Last Modified = \(favorite.lastModified)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📤🌤️ WEATHER_FAVORITE_UPSERT: Device ID = \(favorite.deviceId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📤🌤️ WEATHER_FAVORITE_UPSERT: Conflict Resolution = user_id,latitude,longitude", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("📤🌤️ WEATHER_FAVORITE_UPSERT: Timestamp = \(Date())", category: "SUPABASE_WEATHER")
            }
            
            try await client
                .from("user_weather_favorites")
                .upsert(favorite, onConflict: "user_id,latitude,longitude")
                .execute()
            
            logQueue.async {
                DebugLogger.shared.log("✅📤🌤️ WEATHER_FAVORITE_UPSERT_SUCCESS: Weather favorite upserted successfully", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("✅📤🌤️ WEATHER_FAVORITE_UPSERT_SUCCESS: User = \(favorite.userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("✅📤🌤️ WEATHER_FAVORITE_UPSERT_SUCCESS: Location = \(favorite.latitude),\(favorite.longitude)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("✅📤🌤️ WEATHER_FAVORITE_UPSERT_SUCCESS: Name = \(favorite.locationName)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("✅📤🌤️ WEATHER_FAVORITE_UPSERT_SUCCESS: Favorite Status = \(favorite.isFavorite)", category: "SUPABASE_WEATHER")
            }
            
            endOperation(operationId, success: true)
            
        } catch {
            logQueue.async {
                DebugLogger.shared.log("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR: Failed to upsert weather favorite", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR: User = \(favorite.userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR: Location = \(favorite.latitude),\(favorite.longitude)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR: Name = \(favorite.locationName)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR_DETAILS: \(error.localizedDescription)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR_TYPE: \(type(of: error))", category: "SUPABASE_WEATHER")
                
                // Log the weather favorite data that failed for debugging
                DebugLogger.shared.log("❌📤🌤️ WEATHER_FAVORITE_UPSERT_FAILED_DATA:", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("   User ID: \(favorite.userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("   Latitude: \(favorite.latitude)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("   Longitude: \(favorite.longitude)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("   Location Name: \(favorite.locationName)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("   Is Favorite: \(favorite.isFavorite)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("   Last Modified: \(favorite.lastModified)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("   Device ID: \(favorite.deviceId)", category: "SUPABASE_WEATHER")
                
                // Log additional error context for debugging
                if let postgrestError = error as? PostgrestError {
                    DebugLogger.shared.log("❌📤🌤️ WEATHER_FAVORITE_UPSERT_POSTGREST_ERROR: \(postgrestError)", category: "SUPABASE_WEATHER")
                    if let code = postgrestError.code {
                        DebugLogger.shared.log("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR_CODE: \(code)", category: "SUPABASE_WEATHER")
                    }
                    DebugLogger.shared.log("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR_MESSAGE: \(postgrestError.message)", category: "SUPABASE_WEATHER")
                }
            }
            
            endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Delete a specific weather location favorite from Supabase
    /// Used for removing individual favorites during sync operations
    /// - Parameters:
    ///   - userId: The user who owns the favorite
    ///   - latitude: The latitude of the weather location
    ///   - longitude: The longitude of the weather location
    /// - Throws: Database errors or network issues
    func deleteWeatherFavorite(userId: UUID, latitude: Double, longitude: Double) async throws {
        let operationId = startOperation("deleteWeatherFavorite", 
                                       details: "userId: \(userId), location: \(latitude),\(longitude)")
        
        do {
            logQueue.async {
                DebugLogger.shared.log("🗑️🌤️ WEATHER_FAVORITE_DELETE: Starting weather favorite deletion", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("🗑️🌤️ WEATHER_FAVORITE_DELETE: Table = user_weather_favorites", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("🗑️🌤️ WEATHER_FAVORITE_DELETE: User ID = \(userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("🗑️🌤️ WEATHER_FAVORITE_DELETE: Location = \(latitude),\(longitude)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("🗑️🌤️ WEATHER_FAVORITE_DELETE: Delete Filter = user_id AND latitude AND longitude", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("🗑️🌤️ WEATHER_FAVORITE_DELETE: Timestamp = \(Date())", category: "SUPABASE_WEATHER")
            }
            
            try await client
                .from("user_weather_favorites")
                .delete()
                .eq("user_id", value: userId)
                .eq("latitude", value: latitude)
                .eq("longitude", value: longitude)
                .execute()
            
            logQueue.async {
                DebugLogger.shared.log("✅🗑️🌤️ WEATHER_FAVORITE_DELETE_SUCCESS: Weather favorite deleted successfully", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("✅🗑️🌤️ WEATHER_FAVORITE_DELETE_SUCCESS: User = \(userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("✅🗑️🌤️ WEATHER_FAVORITE_DELETE_SUCCESS: Location = \(latitude),\(longitude)", category: "SUPABASE_WEATHER")
            }
            
            endOperation(operationId, success: true)
            
        } catch {
            logQueue.async {
                DebugLogger.shared.log("❌🗑️🌤️ WEATHER_FAVORITE_DELETE_ERROR: Failed to delete weather favorite", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌🗑️🌤️ WEATHER_FAVORITE_DELETE_ERROR: User = \(userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌🗑️🌤️ WEATHER_FAVORITE_DELETE_ERROR: Location = \(latitude),\(longitude)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌🗑️🌤️ WEATHER_FAVORITE_DELETE_ERROR_DETAILS: \(error.localizedDescription)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌🗑️🌤️ WEATHER_FAVORITE_DELETE_ERROR_TYPE: \(type(of: error))", category: "SUPABASE_WEATHER")
                
                // Log additional error context for debugging
                if let postgrestError = error as? PostgrestError {
                    DebugLogger.shared.log("❌🗑️🌤️ WEATHER_FAVORITE_DELETE_POSTGREST_ERROR: \(postgrestError)", category: "SUPABASE_WEATHER")
                }
            }
            
            endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Delete ALL weather location favorites for a specific user from Supabase
    /// Used for bulk cleanup operations or complete sync resets
    /// - Parameter userId: The user whose favorites should be deleted
    /// - Returns: Number of favorites deleted
    /// - Throws: Database errors or network issues
    func deleteAllWeatherFavorites(userId: UUID) async throws -> Int {
        let operationId = startOperation("deleteAllWeatherFavorites", details: "userId: \(userId)")
        
        do {
            logQueue.async {
                DebugLogger.shared.log("🗑️🌤️ WEATHER_BULK_DELETE: Starting bulk weather favorites deletion", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("🗑️🌤️ WEATHER_BULK_DELETE: Table = user_weather_favorites", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("🗑️🌤️ WEATHER_BULK_DELETE: User ID = \(userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("🗑️🌤️ WEATHER_BULK_DELETE: Delete Filter = user_id eq \(userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("🗑️🌤️ WEATHER_BULK_DELETE: Operation = DELETE ALL for user", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("🗑️🌤️ WEATHER_BULK_DELETE: Timestamp = \(Date())", category: "SUPABASE_WEATHER")
            }
            
            // First, get the count before deletion for reporting
            let countResponse: PostgrestResponse<[RemoteWeatherFavorite]> = try await client
                .from("user_weather_favorites")
                .select("id")
                .eq("user_id", value: userId)
                .execute()
            
            let countBefore = countResponse.value.count
            
            logQueue.async {
                DebugLogger.shared.log("🗑️🌤️ WEATHER_BULK_DELETE: Found \(countBefore) weather favorites to delete", category: "SUPABASE_WEATHER")
            }
            
            // Perform the bulk deletion
            try await client
                .from("user_weather_favorites")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            
            logQueue.async {
                DebugLogger.shared.log("✅🗑️🌤️ WEATHER_BULK_DELETE_SUCCESS: All weather favorites deleted successfully", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("✅🗑️🌤️ WEATHER_BULK_DELETE_SUCCESS: User = \(userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("✅🗑️🌤️ WEATHER_BULK_DELETE_SUCCESS: Deleted Count = \(countBefore)", category: "SUPABASE_WEATHER")
            }
            
            endOperation(operationId, success: true)
            return countBefore
            
        } catch {
            logQueue.async {
                DebugLogger.shared.log("❌🗑️🌤️ WEATHER_BULK_DELETE_ERROR: Failed to delete all weather favorites", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌🗑️🌤️ WEATHER_BULK_DELETE_ERROR: User = \(userId)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌🗑️🌤️ WEATHER_BULK_DELETE_ERROR_DETAILS: \(error.localizedDescription)", category: "SUPABASE_WEATHER")
                DebugLogger.shared.log("❌🗑️🌤️ WEATHER_BULK_DELETE_ERROR_TYPE: \(type(of: error))", category: "SUPABASE_WEATHER")
                
                // Log additional error context for debugging
                if let postgrestError = error as? PostgrestError {
                    DebugLogger.shared.log("❌🗑️🌤️ WEATHER_BULK_DELETE_POSTGREST_ERROR: \(postgrestError)", category: "SUPABASE_WEATHER")
                }
            }
            
            endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    // MARK: - Schema Discovery Methods
    
    /// Test if embedded_routes table exists and discover its structure
    /// Used for debugging schema issues
    func testEmbeddedRoutesTable() async throws -> String {
        let operationId = startOperation("testEmbeddedRoutesTable")
        
        do {
            logQueue.async {
                DebugLogger.shared.log("🔍📊 TABLE_TEST: Testing embedded_routes table existence", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("🔍📊 TABLE_TEST: Attempting simple SELECT query", category: "SUPABASE_ROUTES")
            }
            
            // Try a simple query to see if the table exists at all
            let response: PostgrestResponse<[String]> = try await client
                .from("embedded_routes")
                .select("*")
                .limit(0)  // Don't actually return data, just test schema
                .execute()
            
            logQueue.async {
                DebugLogger.shared.log("✅🔍📊 TABLE_TEST_SUCCESS: embedded_routes table EXISTS", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("✅🔍📊 TABLE_TEST_SUCCESS: Table is accessible", category: "SUPABASE_ROUTES")
            }
            
            endOperation(operationId, success: true)
            return "Table exists and is accessible"
            
        } catch {
            logQueue.async {
                DebugLogger.shared.log("❌🔍📊 TABLE_TEST_ERROR: embedded_routes table issue", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("❌🔍📊 TABLE_TEST_ERROR_DETAILS: \(error.localizedDescription)", category: "SUPABASE_ROUTES")
                
                if let postgrestError = error as? PostgrestError {
                    DebugLogger.shared.log("❌🔍📊 TABLE_TEST_POSTGREST_ERROR: \(postgrestError)", category: "SUPABASE_ROUTES")
                    if let code = postgrestError.code {
                        DebugLogger.shared.log("❌🔍📊 TABLE_TEST_ERROR_CODE: \(code)", category: "SUPABASE_ROUTES")
                    }
                    DebugLogger.shared.log("❌🔍📊 TABLE_TEST_ERROR_MESSAGE: \(postgrestError.message)", category: "SUPABASE_ROUTES")
                }
            }
            
            endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    // MARK: - Embedded Route Methods
    
    /// Upload or update an embedded route to Supabase
    /// Used for syncing locally parsed GPX routes to the cloud database
    /// - Parameter route: The embedded route data to insert
    /// - Throws: Database errors or network issues  
    func upsertEmbeddedRoute(_ route: RemoteEmbeddedRoute) async throws {
        // Ensure we have an authenticated session for RLS
        let session = try await getSession()
        let operationId = startOperation("upsertEmbeddedRoute",
                                       details: "routeName: \(route.name)")
        
        do {
            logQueue.async {
                DebugLogger.shared.log("📤🛣️ ROUTE_INSERT: Starting embedded route insert", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("📤🛣️ ROUTE_INSERT: Table = embedded_routes (RLS-protected table)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("📤🛣️ ROUTE_INSERT: Authenticated User = \(session.user.id)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("📤🛣️ ROUTE_INSERT: Route Name = \(route.name)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("📤🛣️ ROUTE_INSERT: Category = \(route.category ?? "nil")", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("📤🛣️ ROUTE_INSERT: Waypoint Count = \(route.waypointCount)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("📤🛣️ ROUTE_INSERT: Total Distance = \(route.totalDistance)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("📤🛣️ ROUTE_INSERT: Is Active = \(route.isActive ?? false)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("📤🛣️ ROUTE_INSERT: Timestamp = \(Date())", category: "SUPABASE_ROUTES")
            }
            
            // Use insert since there's no unique constraint on name
            // Each upload creates a new route entry
            try await client
                .from("embedded_routes")
                .insert(route)
                .execute()
            
            logQueue.async {
                DebugLogger.shared.log("✅📤🛣️ ROUTE_INSERT_SUCCESS: Embedded route inserted successfully", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("✅📤🛣️ ROUTE_INSERT_SUCCESS: Route '\(route.name)' added by user \(session.user.id)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("✅📤🛣️ ROUTE_INSERT_SUCCESS: Waypoints: \(route.waypointCount), Distance: \(route.totalDistance)", category: "SUPABASE_ROUTES")
            }
            
            endOperation(operationId, success: true)
            
        } catch {
            logQueue.async {
                DebugLogger.shared.log("❌📤🛣️ ROUTE_INSERT_ERROR: Failed to insert embedded route", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("❌📤🛣️ ROUTE_INSERT_ERROR: Route = \(route.name)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("❌📤🛣️ ROUTE_INSERT_ERROR_DETAILS: \(error.localizedDescription)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("❌📤🛣️ ROUTE_INSERT_ERROR_TYPE: \(type(of: error))", category: "SUPABASE_ROUTES")
                
                // Log the route data that failed to insert for debugging
                DebugLogger.shared.log("❌📤🛣️ ROUTE_INSERT_FAILED_DATA:", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("   Route Name: \(route.name)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("   Category: \(route.category ?? "nil")", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("   Waypoint Count: \(route.waypointCount)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("   Total Distance: \(route.totalDistance)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("   Is Active: \(route.isActive ?? false)", category: "SUPABASE_ROUTES")
                
                // Log additional error context for debugging
                if let postgrestError = error as? PostgrestError {
                    DebugLogger.shared.log("❌📤🛣️ ROUTE_INSERT_POSTGREST_ERROR: \(postgrestError)", category: "SUPABASE_ROUTES")
                }
            }
            
            endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Retrieve all embedded routes from the public Supabase table
    /// Used for browsing available routes from the cloud database
    /// - Parameter limit: Optional limit on number of routes to fetch (default: no limit)
    /// - Returns: Array of all embedded routes
    /// - Throws: Database errors or network issues
    func getEmbeddedRoutes(limit: Int? = nil) async throws -> [RemoteEmbeddedRoute] {
        let operationId = startOperation("getEmbeddedRoutes", details: "limit: \(limit?.description ?? "none")")
        
        do {
            logQueue.async {
                DebugLogger.shared.log("📥🛣️ ROUTE_FETCH: Starting embedded routes fetch", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("📥🛣️ ROUTE_FETCH: Table = embedded_routes (public table)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("📥🛣️ ROUTE_FETCH: Limit = \(limit?.description ?? "none")", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("📥🛣️ ROUTE_FETCH: Timestamp = \(Date())", category: "SUPABASE_ROUTES")
            }
            
            var query = client
                .from("embedded_routes")
                .select("*")
                .eq("is_active", value: true) // Only fetch active routes
                .order("created_at", ascending: false)
            
            if let limit = limit {
                query = query.limit(limit)
            }
            
            let response: PostgrestResponse<[RemoteEmbeddedRoute]> = try await query.execute()
            
            logQueue.async {
                DebugLogger.shared.log("✅📥🛣️ ROUTE_FETCH_SUCCESS: Embedded routes fetched successfully", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("✅📥🛣️ ROUTE_FETCH_SUCCESS: Routes found: \(response.value.count)", category: "SUPABASE_ROUTES")
                if !response.value.isEmpty {
                    DebugLogger.shared.log("✅📥🛣️ ROUTE_FETCH_SUCCESS: Route names: \(response.value.map { $0.name })", category: "SUPABASE_ROUTES")
                }
            }
            
            endOperation(operationId, success: true)
            return response.value
            
        } catch {
            logQueue.async {
                DebugLogger.shared.log("❌📥🛣️ ROUTE_FETCH_ERROR: Failed to fetch embedded routes", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("❌📥🛣️ ROUTE_FETCH_ERROR_DETAILS: \(error.localizedDescription)", category: "SUPABASE_ROUTES")
                DebugLogger.shared.log("❌📥🛣️ ROUTE_FETCH_ERROR_TYPE: \(type(of: error))", category: "SUPABASE_ROUTES")
                
                // Log additional error context for debugging
                if let postgrestError = error as? PostgrestError {
                    DebugLogger.shared.log("❌📥🛣️ ROUTE_FETCH_POSTGREST_ERROR: \(postgrestError)", category: "SUPABASE_ROUTES")
                }
            }
            
            endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    
}

// MARK: - Supporting Types
private struct OperationStats {
    var totalCalls: Int
    var successCount: Int
    var failureCount: Int
    var totalDuration: TimeInterval
    var minDuration: TimeInterval
    var maxDuration: TimeInterval
}

// MARK: - Database Query Builder with Logging
class DatabaseQueryBuilder {
    private let client: SupabaseClient
    private let table: String
    private let manager: SupabaseManager
    private var query: String = "*"
    private var filters: [String] = []
    private var limitValue: Int?
    
    init(client: SupabaseClient, table: String, manager: SupabaseManager) {
        self.client = client
        self.table = table
        self.manager = manager
    }
    
    func select(_ columns: String) -> DatabaseQueryBuilder {
        query = columns
        manager.logQueue.async {
            DebugLogger.shared.log("🗄️ QUERY: SELECT \(columns) FROM \(self.table)", category: "SUPABASE_QUERY")
        }
        return self
    }
    
    func eq(_ column: String, value: Any) -> DatabaseQueryBuilder {
        let filter = "\(column)=eq.\(value)"
        filters.append(filter)
        manager.logQueue.async {
            DebugLogger.shared.log("🗄️ FILTER: \(column) = \(value)", category: "SUPABASE_QUERY")
        }
        return self
    }
    
    func limit(_ count: Int) -> DatabaseQueryBuilder {
        limitValue = count
        manager.logQueue.async {
            DebugLogger.shared.log("🗄️ LIMIT: \(count)", category: "SUPABASE_QUERY")
        }
        return self
    }
    
    func execute<T: Codable>() async throws -> PostgrestResponse<[T]> {
        let operationId = manager.startOperation("dbQuery", details: "table: \(table), filters: \(filters.count)")
        
        do {
            let builder = client.from(table).select(query)
            
            for filter in filters {
                // This is simplified - you'd need to properly parse and apply filters
                // For now, this shows the logging structure
            }
            
            let result: PostgrestResponse<[T]> = if let limit = limitValue {
                try await builder.limit(limit).execute()
            } else {
                try await builder.execute()
            }
            
            manager.logQueue.async {
                DebugLogger.shared.log("📊 QUERY RESULT:", category: "SUPABASE_QUERY")
                DebugLogger.shared.log("   Table: \(self.table)", category: "SUPABASE_QUERY")
                DebugLogger.shared.log("   Query: \(self.query)", category: "SUPABASE_QUERY")
                DebugLogger.shared.log("   Filters: \(self.filters)", category: "SUPABASE_QUERY")
                DebugLogger.shared.log("   Limit: \(self.limitValue?.description ?? "none")", category: "SUPABASE_QUERY")
                DebugLogger.shared.log("   Status: Success", category: "SUPABASE_QUERY")
            }
            
            manager.endOperation(operationId, success: true)
            return result
        } catch {
            manager.endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    
}
