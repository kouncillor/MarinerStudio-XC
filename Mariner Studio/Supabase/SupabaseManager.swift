import Foundation
import Supabase
import Combine

/// Centralized Supabase manager with comprehensive logging and race condition monitoring
final class SupabaseManager {
    
    // MARK: - Shared Instance
    static let shared = SupabaseManager()
    
    // MARK: - Private Properties
    private let client: SupabaseClient
    private let operationQueue = DispatchQueue(label: "supabase.operations", qos: .utility)
    internal let logQueue = DispatchQueue(label: "supabase.logging", qos: .background)
    private var activeOperations: [String: Date] = [:]
    private let operationsLock = NSLock()
    private var operationCounter: Int = 0
    
    // MARK: - Performance Tracking
    private var operationStats: [String: OperationStats] = [:]
    private let statsLock = NSLock()
    
    // MARK: - Initialization
    private init() {
        logQueue.async {
            print("\n🚀 SUPABASE MANAGER: Initializing comprehensive logging system")
            print("🚀 SUPABASE MANAGER: Thread = \(Thread.current)")
            print("🚀 SUPABASE MANAGER: Timestamp = \(Date())")
        }
        
        guard let url = URL(string: "https://lgdsvefqqorvnvkiobth.supabase.co") else {
            fatalError("❌ SUPABASE MANAGER: Invalid URL")
        }
        
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxnZHN2ZWZxcW9ydm52a2lvYnRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwOTQ1MjQsImV4cCI6MjA2NTY3MDUyNH0.rNc5QTtV4IQK5n-HvCEpOZDpVCwPpmKkjYVBEHOqnVI"
        
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        
        logQueue.async {
            print("✅ SUPABASE MANAGER: Client initialized successfully")
            print("✅ SUPABASE MANAGER: Ready for operations\n")
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
            print("\n🟢 OPERATION START: \(operationId)")
            print("🟢 OPERATION: \(name)")
            print("🟢 DETAILS: \(details)")
            print("🟢 START TIME: \(startTime)")
            print("🟢 THREAD: \(Thread.current)")
            print("🟢 ACTIVE OPERATIONS: \(self.activeOperations.count)")
            print("🟢 CONCURRENT OPS: \(Array(self.activeOperations.keys))")
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
                print("\n✅ OPERATION SUCCESS: \(operationId)")
                print("✅ DURATION: \(String(format: "%.3f", duration))s")
            } else {
                print("\n❌ OPERATION FAILED: \(operationId)")
                print("❌ DURATION: \(String(format: "%.3f", duration))s")
                if let error = error {
                    print("❌ ERROR: \(error)")
                    print("❌ ERROR TYPE: \(type(of: error))")
                    let nsError = error as NSError
                    print("❌ ERROR DOMAIN: \(nsError.domain)")
                    print("❌ ERROR CODE: \(nsError.code)")
                    print("❌ ERROR INFO: \(nsError.userInfo)")
                }
            }
            print("✅ REMAINING ACTIVE: \(self.activeOperations.count)")
            if !self.activeOperations.isEmpty {
                print("⚠️ STILL RUNNING: \(Array(self.activeOperations.keys))")
                
                // Check for long-running operations
                let now = Date()
                for (opId, startTime) in self.activeOperations {
                    let runTime = now.timeIntervalSince(startTime)
                    if runTime > 10.0 { // More than 10 seconds
                        print("🚨 LONG RUNNING: \(opId) has been running for \(String(format: "%.1f", runTime))s")
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
                print("📊 SIGN IN RESULT:")
                print("   User ID: \(result.user.id)")
                print("   Email: \(result.user.email ?? "none")")
                print("   Session expires: \(Date(timeIntervalSince1970: TimeInterval(result.expiresAt)))")
                print("   Access token length: \(result.accessToken.count)")
                print("   Refresh token length: \(result.refreshToken.count)")
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
                print("📊 SIGN UP RESULT:")
                print("   User ID: \(result.user.id)")
                print("   Email: \(result.user.email ?? "none")")
                print("   Email confirmed: \(result.user.emailConfirmedAt != nil)")
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
        let operationId = startOperation("getSession")
        
        do {
            let session = try await client.auth.session
            
            logQueue.async {
                print("📊 SESSION RESULT:")
                print("   User ID: \(session.user.id)")
                print("   Email: \(session.user.email ?? "none")")
                print("   Expires at: \(Date(timeIntervalSince1970: TimeInterval(session.expiresAt)))")
                print("   Time until expiry: \(String(format: "%.1f", Date(timeIntervalSince1970: TimeInterval(session.expiresAt)).timeIntervalSinceNow / 60)) minutes")
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
            print("🗄️ DATABASE: Creating query builder for table '\(table)'")
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
            print("\n📊 SUPABASE MANAGER STATISTICS:")
            print("📊 ================================")
            
            for (operation, stat) in stats.sorted(by: { $0.key < $1.key }) {
                let avgDuration = stat.totalDuration / Double(stat.totalCalls)
                let successRate = Double(stat.successCount) / Double(stat.totalCalls) * 100
                
                print("📊 \(operation.uppercased()):")
                print("   Total calls: \(stat.totalCalls)")
                print("   Success rate: \(String(format: "%.1f", successRate))%")
                print("   Avg duration: \(String(format: "%.3f", avgDuration))s")
                print("   Min duration: \(String(format: "%.3f", stat.minDuration))s")
                print("   Max duration: \(String(format: "%.3f", stat.maxDuration))s")
                print("   Failures: \(stat.failureCount)")
                print("")
            }
            
            print("📊 Current active operations: \(self.activeOperations.count)")
            if !self.activeOperations.isEmpty {
                for (opId, startTime) in self.activeOperations {
                    let duration = Date().timeIntervalSince(startTime)
                    print("   \(opId): \(String(format: "%.1f", duration))s")
                }
            }
            print("📊 ================================\n")
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
            print("🔍 SUPABASE MANAGER: Verbose logging ENABLED")
        }
    }
    
    func logCurrentState() {
        let operations = getCurrentOperations()
        
        logQueue.async {
            print("\n🔍 SUPABASE MANAGER STATE:")
            print("🔍 Active operations: \(operations.count)")
            print("🔍 Operations: \(operations)")
            print("🔍 Thread: \(Thread.current)")
            print("🔍 Timestamp: \(Date())")
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
                    print("☁️🧭 NAV_UNIT_FAVORITES_QUERY: Starting remote favorites retrieval")
                    print("☁️🧭 NAV_UNIT_FAVORITES_QUERY: Table = user_nav_unit_favorites")
                    print("☁️🧭 NAV_UNIT_FAVORITES_QUERY: User ID filter = \(userId)")
                    print("☁️🧭 NAV_UNIT_FAVORITES_QUERY: Timestamp = \(Date())")
                }
                
                // Query the user_nav_unit_favorites table for this specific user
                let response: PostgrestResponse<[RemoteNavUnitFavorite]> = try await client
                    .from("user_nav_unit_favorites")
                    .select("*")
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                
                let favorites = response.value
                
                logQueue.async {
                    print("✅☁️🧭 NAV_UNIT_FAVORITES_SUCCESS: Retrieved \(favorites.count) nav unit favorites")
                    print("☁️🧭 NAV_UNIT_FAVORITES_BREAKDOWN:")
                    
                    // Log breakdown of favorite vs unfavorite records
                    let favoriteRecords = favorites.filter { $0.isFavorite }
                    let unfavoriteRecords = favorites.filter { !$0.isFavorite }
                    print("   - Favorites (true): \(favoriteRecords.count)")
                    print("   - Unfavorites (false): \(unfavoriteRecords.count)")
                    
                    // Log first few records for debugging
                    if !favorites.isEmpty {
                        print("☁️🧭 NAV_UNIT_FAVORITES_SAMPLE:")
                        for (index, favorite) in favorites.prefix(5).enumerated() {
                            print("   [\(index)] NavUnit: \(favorite.navUnitId)")
                            print("       Name: \(favorite.navUnitName ?? "unknown")")
                            print("       Favorite: \(favorite.isFavorite)")
                            print("       Modified: \(favorite.lastModified)")
                            print("       Device: \(favorite.deviceId)")
                            print("       Coords: \(favorite.latitude?.description ?? "nil"), \(favorite.longitude?.description ?? "nil")")
                        }
                        
                        if favorites.count > 5 {
                            print("   ... and \(favorites.count - 5) more records")
                        }
                    } else {
                        print("⚠️☁️🧭 NAV_UNIT_FAVORITES_WARNING: No remote favorites found for user")
                    }
                }
                
                endOperation(operationId, success: true)
                return favorites
                
            } catch {
                logQueue.async {
                    print("❌☁️🧭 NAV_UNIT_FAVORITES_ERROR: Failed to retrieve remote favorites")
                    print("❌☁️🧭 NAV_UNIT_FAVORITES_ERROR_DETAILS: \(error.localizedDescription)")
                    print("❌☁️🧭 NAV_UNIT_FAVORITES_ERROR_TYPE: \(type(of: error))")
                    
                    // Log additional error context for debugging
                    if let postgrestError = error as? PostgrestError {
                        print("❌☁️🧭 NAV_UNIT_FAVORITES_POSTGREST_ERROR: \(postgrestError)")
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
                    print("📤🧭 NAV_UNIT_UPSERT: Starting nav unit favorite upsert")
                    print("📤🧭 NAV_UNIT_UPSERT: Table = user_nav_unit_favorites")
                    print("📤🧭 NAV_UNIT_UPSERT: NavUnit ID = \(favorite.navUnitId)")
                    print("📤🧭 NAV_UNIT_UPSERT: Name = \(favorite.navUnitName ?? "unknown")")
                    print("📤🧭 NAV_UNIT_UPSERT: User ID = \(favorite.userId)")
                    print("📤🧭 NAV_UNIT_UPSERT: Is Favorite = \(favorite.isFavorite)")
                    print("📤🧭 NAV_UNIT_UPSERT: Last Modified = \(favorite.lastModified)")
                    print("📤🧭 NAV_UNIT_UPSERT: Device ID = \(favorite.deviceId)")
                    print("📤🧭 NAV_UNIT_UPSERT: Timestamp = \(Date())")
                }
                
                // Use upsert to handle both insert and update cases
                // Supabase will insert if no matching record exists, update if it does
                try await client
                    .from("user_nav_unit_favorites")
                   // .upsert(favorite)
                    .upsert(favorite, onConflict: "user_id,nav_unit_id")
                    .execute()
                
                logQueue.async {
                    print("✅📤🧭 NAV_UNIT_UPSERT_SUCCESS: Nav unit favorite upserted successfully")
                    print("✅📤🧭 NAV_UNIT_UPSERT_SUCCESS: NavUnit \(favorite.navUnitId) - \(favorite.navUnitName ?? "unknown")")
                    print("✅📤🧭 NAV_UNIT_UPSERT_SUCCESS: Final state: isFavorite = \(favorite.isFavorite)")
                }
                
                endOperation(operationId, success: true)
                
            } catch {
                logQueue.async {
                    print("❌📤🧭 NAV_UNIT_UPSERT_ERROR: Failed to upsert nav unit favorite")
                    print("❌📤🧭 NAV_UNIT_UPSERT_ERROR: NavUnit = \(favorite.navUnitId)")
                    print("❌📤🧭 NAV_UNIT_UPSERT_ERROR_DETAILS: \(error.localizedDescription)")
                    print("❌📤🧭 NAV_UNIT_UPSERT_ERROR_TYPE: \(type(of: error))")
                    
                    // Log the favorite data that failed to upsert for debugging
                    print("❌📤🧭 NAV_UNIT_UPSERT_FAILED_DATA:")
                    print("   NavUnit ID: \(favorite.navUnitId)")
                    print("   User ID: \(favorite.userId)")
                    print("   Is Favorite: \(favorite.isFavorite)")
                    print("   Last Modified: \(favorite.lastModified)")
                    print("   Device ID: \(favorite.deviceId)")
                    
                    // Log additional error context for debugging
                    if let postgrestError = error as? PostgrestError {
                        print("❌📤🧭 NAV_UNIT_UPSERT_POSTGREST_ERROR: \(postgrestError)")
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
                    print("🗑️🧭 NAV_UNIT_DELETE: Starting nav unit favorite deletion")
                    print("🗑️🧭 NAV_UNIT_DELETE: Table = user_nav_unit_favorites")
                    print("🗑️🧭 NAV_UNIT_DELETE: User ID = \(userId)")
                    print("🗑️🧭 NAV_UNIT_DELETE: NavUnit ID = \(navUnitId)")
                    print("🗑️🧭 NAV_UNIT_DELETE: Timestamp = \(Date())")
                }
                
                // Delete the specific record for this user and nav unit
                try await client
                    .from("user_nav_unit_favorites")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .eq("nav_unit_id", value: navUnitId)
                    .execute()
                
                logQueue.async {
                    print("✅🗑️🧭 NAV_UNIT_DELETE_SUCCESS: Nav unit favorite deleted successfully")
                    print("✅🗑️🧭 NAV_UNIT_DELETE_SUCCESS: User \(userId) - NavUnit \(navUnitId)")
                }
                
                endOperation(operationId, success: true)
                
            } catch {
                logQueue.async {
                    print("❌🗑️🧭 NAV_UNIT_DELETE_ERROR: Failed to delete nav unit favorite")
                    print("❌🗑️🧭 NAV_UNIT_DELETE_ERROR: User = \(userId)")
                    print("❌🗑️🧭 NAV_UNIT_DELETE_ERROR: NavUnit = \(navUnitId)")
                    print("❌🗑️🧭 NAV_UNIT_DELETE_ERROR_DETAILS: \(error.localizedDescription)")
                    print("❌🗑️🧭 NAV_UNIT_DELETE_ERROR_TYPE: \(type(of: error))")
                    
                    // Log additional error context for debugging
                    if let postgrestError = error as? PostgrestError {
                        print("❌🗑️🧭 NAV_UNIT_DELETE_POSTGREST_ERROR: \(postgrestError)")
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
                    print("🗑️🧭 NAV_UNIT_BULK_DELETE: Starting bulk nav unit favorites deletion")
                    print("🗑️🧭 NAV_UNIT_BULK_DELETE: Table = user_nav_unit_favorites")
                    print("🗑️🧭 NAV_UNIT_BULK_DELETE: User ID = \(userId)")
                    print("🗑️🧭 NAV_UNIT_BULK_DELETE: Timestamp = \(Date())")
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
                    print("✅🗑️🧭 NAV_UNIT_BULK_DELETE_SUCCESS: Bulk deletion completed")
                    print("✅🗑️🧭 NAV_UNIT_BULK_DELETE_SUCCESS: User \(userId)")
                    print("✅🗑️🧭 NAV_UNIT_BULK_DELETE_SUCCESS: Records deleted: \(recordCount)")
                }
                
                endOperation(operationId, success: true)
                return recordCount
                
            } catch {
                logQueue.async {
                    print("❌🗑️🧭 NAV_UNIT_BULK_DELETE_ERROR: Failed to bulk delete nav unit favorites")
                    print("❌🗑️🧭 NAV_UNIT_BULK_DELETE_ERROR: User = \(userId)")
                    print("❌🗑️🧭 NAV_UNIT_BULK_DELETE_ERROR_DETAILS: \(error.localizedDescription)")
                    print("❌🗑️🧭 NAV_UNIT_BULK_DELETE_ERROR_TYPE: \(type(of: error))")
                    
                    // Log additional error context for debugging
                    if let postgrestError = error as? PostgrestError {
                        print("❌🗑️🧭 NAV_UNIT_BULK_DELETE_POSTGREST_ERROR: \(postgrestError)")
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
                print("📥🌤️ WEATHER_FAVORITES_FETCH: Starting weather favorites query for user")
                print("📥🌤️ WEATHER_FAVORITES_FETCH: Table = user_weather_favorites")
                print("📥🌤️ WEATHER_FAVORITES_FETCH: User ID = \(userId)")
                print("📥🌤️ WEATHER_FAVORITES_FETCH: Filter = user_id eq \(userId)")
                print("📥🌤️ WEATHER_FAVORITES_FETCH: Timestamp = \(Date())")
            }
            
            let response: PostgrestResponse<[RemoteWeatherFavorite]> = try await client
                .from("user_weather_favorites")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
            
            logQueue.async {
                print("✅📥🌤️ WEATHER_FAVORITES_FETCH_SUCCESS: Weather favorites retrieved successfully")
                print("✅📥🌤️ WEATHER_FAVORITES_FETCH_SUCCESS: User = \(userId)")
                print("✅📥🌤️ WEATHER_FAVORITES_FETCH_SUCCESS: Count = \(response.value.count)")
                
                if !response.value.isEmpty {
                    print("✅📥🌤️ WEATHER_FAVORITES_FETCH_SUCCESS: Sample locations:")
                    for (index, favorite) in response.value.prefix(5).enumerated() {
                        print("   [\(index + 1)] \(favorite.latitude),\(favorite.longitude) - \(favorite.locationName) (favorite: \(favorite.isFavorite))")
                    }
                    if response.value.count > 5 {
                        print("   ... and \(response.value.count - 5) more")
                    }
                } else {
                    print("✅📥🌤️ WEATHER_FAVORITES_FETCH_SUCCESS: No weather favorites found for user")
                }
            }
            
            endOperation(operationId, success: true)
            return response.value
            
        } catch {
            logQueue.async {
                print("❌📥🌤️ WEATHER_FAVORITES_FETCH_ERROR: Failed to retrieve weather favorites")
                print("❌📥🌤️ WEATHER_FAVORITES_FETCH_ERROR: User = \(userId)")
                print("❌📥🌤️ WEATHER_FAVORITES_FETCH_ERROR_DETAILS: \(error.localizedDescription)")
                print("❌📥🌤️ WEATHER_FAVORITES_FETCH_ERROR_TYPE: \(type(of: error))")
                
                // Log additional error context for debugging
                if let postgrestError = error as? PostgrestError {
                    print("❌📥🌤️ WEATHER_FAVORITES_FETCH_POSTGREST_ERROR: \(postgrestError)")
                    if let code = postgrestError.code {
                        print("❌📥🌤️ WEATHER_FAVORITES_FETCH_ERROR_CODE: \(code)")
                    }
                    print("❌📥🌤️ WEATHER_FAVORITES_FETCH_ERROR_MESSAGE: \(postgrestError.message)")
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
                print("📤🌤️ WEATHER_FAVORITE_UPSERT: Starting weather favorite upsert")
                print("📤🌤️ WEATHER_FAVORITE_UPSERT: Table = user_weather_favorites")
                print("📤🌤️ WEATHER_FAVORITE_UPSERT: User ID = \(favorite.userId)")
                print("📤🌤️ WEATHER_FAVORITE_UPSERT: Location = \(favorite.latitude),\(favorite.longitude)")
                print("📤🌤️ WEATHER_FAVORITE_UPSERT: Location Name = \(favorite.locationName)")
                print("📤🌤️ WEATHER_FAVORITE_UPSERT: Is Favorite = \(favorite.isFavorite)")
                print("📤🌤️ WEATHER_FAVORITE_UPSERT: Last Modified = \(favorite.lastModified)")
                print("📤🌤️ WEATHER_FAVORITE_UPSERT: Device ID = \(favorite.deviceId)")
                print("📤🌤️ WEATHER_FAVORITE_UPSERT: Conflict Resolution = user_id,latitude,longitude")
                print("📤🌤️ WEATHER_FAVORITE_UPSERT: Timestamp = \(Date())")
            }
            
            try await client
                .from("user_weather_favorites")
                .upsert(favorite, onConflict: "user_id,latitude,longitude")
                .execute()
            
            logQueue.async {
                print("✅📤🌤️ WEATHER_FAVORITE_UPSERT_SUCCESS: Weather favorite upserted successfully")
                print("✅📤🌤️ WEATHER_FAVORITE_UPSERT_SUCCESS: User = \(favorite.userId)")
                print("✅📤🌤️ WEATHER_FAVORITE_UPSERT_SUCCESS: Location = \(favorite.latitude),\(favorite.longitude)")
                print("✅📤🌤️ WEATHER_FAVORITE_UPSERT_SUCCESS: Name = \(favorite.locationName)")
                print("✅📤🌤️ WEATHER_FAVORITE_UPSERT_SUCCESS: Favorite Status = \(favorite.isFavorite)")
            }
            
            endOperation(operationId, success: true)
            
        } catch {
            logQueue.async {
                print("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR: Failed to upsert weather favorite")
                print("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR: User = \(favorite.userId)")
                print("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR: Location = \(favorite.latitude),\(favorite.longitude)")
                print("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR: Name = \(favorite.locationName)")
                print("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR_DETAILS: \(error.localizedDescription)")
                print("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR_TYPE: \(type(of: error))")
                
                // Log the weather favorite data that failed for debugging
                print("❌📤🌤️ WEATHER_FAVORITE_UPSERT_FAILED_DATA:")
                print("   User ID: \(favorite.userId)")
                print("   Latitude: \(favorite.latitude)")
                print("   Longitude: \(favorite.longitude)")
                print("   Location Name: \(favorite.locationName)")
                print("   Is Favorite: \(favorite.isFavorite)")
                print("   Last Modified: \(favorite.lastModified)")
                print("   Device ID: \(favorite.deviceId)")
                
                // Log additional error context for debugging
                if let postgrestError = error as? PostgrestError {
                    print("❌📤🌤️ WEATHER_FAVORITE_UPSERT_POSTGREST_ERROR: \(postgrestError)")
                    if let code = postgrestError.code {
                        print("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR_CODE: \(code)")
                    }
                    print("❌📤🌤️ WEATHER_FAVORITE_UPSERT_ERROR_MESSAGE: \(postgrestError.message)")
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
                print("🗑️🌤️ WEATHER_FAVORITE_DELETE: Starting weather favorite deletion")
                print("🗑️🌤️ WEATHER_FAVORITE_DELETE: Table = user_weather_favorites")
                print("🗑️🌤️ WEATHER_FAVORITE_DELETE: User ID = \(userId)")
                print("🗑️🌤️ WEATHER_FAVORITE_DELETE: Location = \(latitude),\(longitude)")
                print("🗑️🌤️ WEATHER_FAVORITE_DELETE: Delete Filter = user_id AND latitude AND longitude")
                print("🗑️🌤️ WEATHER_FAVORITE_DELETE: Timestamp = \(Date())")
            }
            
            try await client
                .from("user_weather_favorites")
                .delete()
                .eq("user_id", value: userId)
                .eq("latitude", value: latitude)
                .eq("longitude", value: longitude)
                .execute()
            
            logQueue.async {
                print("✅🗑️🌤️ WEATHER_FAVORITE_DELETE_SUCCESS: Weather favorite deleted successfully")
                print("✅🗑️🌤️ WEATHER_FAVORITE_DELETE_SUCCESS: User = \(userId)")
                print("✅🗑️🌤️ WEATHER_FAVORITE_DELETE_SUCCESS: Location = \(latitude),\(longitude)")
            }
            
            endOperation(operationId, success: true)
            
        } catch {
            logQueue.async {
                print("❌🗑️🌤️ WEATHER_FAVORITE_DELETE_ERROR: Failed to delete weather favorite")
                print("❌🗑️🌤️ WEATHER_FAVORITE_DELETE_ERROR: User = \(userId)")
                print("❌🗑️🌤️ WEATHER_FAVORITE_DELETE_ERROR: Location = \(latitude),\(longitude)")
                print("❌🗑️🌤️ WEATHER_FAVORITE_DELETE_ERROR_DETAILS: \(error.localizedDescription)")
                print("❌🗑️🌤️ WEATHER_FAVORITE_DELETE_ERROR_TYPE: \(type(of: error))")
                
                // Log additional error context for debugging
                if let postgrestError = error as? PostgrestError {
                    print("❌🗑️🌤️ WEATHER_FAVORITE_DELETE_POSTGREST_ERROR: \(postgrestError)")
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
                print("🗑️🌤️ WEATHER_BULK_DELETE: Starting bulk weather favorites deletion")
                print("🗑️🌤️ WEATHER_BULK_DELETE: Table = user_weather_favorites")
                print("🗑️🌤️ WEATHER_BULK_DELETE: User ID = \(userId)")
                print("🗑️🌤️ WEATHER_BULK_DELETE: Delete Filter = user_id eq \(userId)")
                print("🗑️🌤️ WEATHER_BULK_DELETE: Operation = DELETE ALL for user")
                print("🗑️🌤️ WEATHER_BULK_DELETE: Timestamp = \(Date())")
            }
            
            // First, get the count before deletion for reporting
            let countResponse: PostgrestResponse<[RemoteWeatherFavorite]> = try await client
                .from("user_weather_favorites")
                .select("id")
                .eq("user_id", value: userId)
                .execute()
            
            let countBefore = countResponse.value.count
            
            logQueue.async {
                print("🗑️🌤️ WEATHER_BULK_DELETE: Found \(countBefore) weather favorites to delete")
            }
            
            // Perform the bulk deletion
            try await client
                .from("user_weather_favorites")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            
            logQueue.async {
                print("✅🗑️🌤️ WEATHER_BULK_DELETE_SUCCESS: All weather favorites deleted successfully")
                print("✅🗑️🌤️ WEATHER_BULK_DELETE_SUCCESS: User = \(userId)")
                print("✅🗑️🌤️ WEATHER_BULK_DELETE_SUCCESS: Deleted Count = \(countBefore)")
            }
            
            endOperation(operationId, success: true)
            return countBefore
            
        } catch {
            logQueue.async {
                print("❌🗑️🌤️ WEATHER_BULK_DELETE_ERROR: Failed to delete all weather favorites")
                print("❌🗑️🌤️ WEATHER_BULK_DELETE_ERROR: User = \(userId)")
                print("❌🗑️🌤️ WEATHER_BULK_DELETE_ERROR_DETAILS: \(error.localizedDescription)")
                print("❌🗑️🌤️ WEATHER_BULK_DELETE_ERROR_TYPE: \(type(of: error))")
                
                // Log additional error context for debugging
                if let postgrestError = error as? PostgrestError {
                    print("❌🗑️🌤️ WEATHER_BULK_DELETE_POSTGREST_ERROR: \(postgrestError)")
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
                print("🔍📊 TABLE_TEST: Testing embedded_routes table existence")
                print("🔍📊 TABLE_TEST: Attempting simple SELECT query")
            }
            
            // Try a simple query to see if the table exists at all
            let response: PostgrestResponse<[String]> = try await client
                .from("embedded_routes")
                .select("*")
                .limit(0)  // Don't actually return data, just test schema
                .execute()
            
            logQueue.async {
                print("✅🔍📊 TABLE_TEST_SUCCESS: embedded_routes table EXISTS")
                print("✅🔍📊 TABLE_TEST_SUCCESS: Table is accessible")
            }
            
            endOperation(operationId, success: true)
            return "Table exists and is accessible"
            
        } catch {
            logQueue.async {
                print("❌🔍📊 TABLE_TEST_ERROR: embedded_routes table issue")
                print("❌🔍📊 TABLE_TEST_ERROR_DETAILS: \(error.localizedDescription)")
                
                if let postgrestError = error as? PostgrestError {
                    print("❌🔍📊 TABLE_TEST_POSTGREST_ERROR: \(postgrestError)")
                    if let code = postgrestError.code {
                        print("❌🔍📊 TABLE_TEST_ERROR_CODE: \(code)")
                    }
                    print("❌🔍📊 TABLE_TEST_ERROR_MESSAGE: \(postgrestError.message)")
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
                print("📤🛣️ ROUTE_INSERT: Starting embedded route insert")
                print("📤🛣️ ROUTE_INSERT: Table = embedded_routes (RLS-protected table)")
                print("📤🛣️ ROUTE_INSERT: Authenticated User = \(session.user.id)")
                print("📤🛣️ ROUTE_INSERT: Route Name = \(route.name)")
                print("📤🛣️ ROUTE_INSERT: Category = \(route.category ?? "nil")")
                print("📤🛣️ ROUTE_INSERT: Waypoint Count = \(route.waypointCount)")
                print("📤🛣️ ROUTE_INSERT: Total Distance = \(route.totalDistance)")
                print("📤🛣️ ROUTE_INSERT: Is Active = \(route.isActive ?? false)")
                print("📤🛣️ ROUTE_INSERT: Timestamp = \(Date())")
            }
            
            // Use insert since there's no unique constraint on name
            // Each upload creates a new route entry
            try await client
                .from("embedded_routes")
                .insert(route)
                .execute()
            
            logQueue.async {
                print("✅📤🛣️ ROUTE_INSERT_SUCCESS: Embedded route inserted successfully")
                print("✅📤🛣️ ROUTE_INSERT_SUCCESS: Route '\(route.name)' added by user \(session.user.id)")
                print("✅📤🛣️ ROUTE_INSERT_SUCCESS: Waypoints: \(route.waypointCount), Distance: \(route.totalDistance)")
            }
            
            endOperation(operationId, success: true)
            
        } catch {
            logQueue.async {
                print("❌📤🛣️ ROUTE_INSERT_ERROR: Failed to insert embedded route")
                print("❌📤🛣️ ROUTE_INSERT_ERROR: Route = \(route.name)")
                print("❌📤🛣️ ROUTE_INSERT_ERROR_DETAILS: \(error.localizedDescription)")
                print("❌📤🛣️ ROUTE_INSERT_ERROR_TYPE: \(type(of: error))")
                
                // Log the route data that failed to insert for debugging
                print("❌📤🛣️ ROUTE_INSERT_FAILED_DATA:")
                print("   Route Name: \(route.name)")
                print("   Category: \(route.category ?? "nil")")
                print("   Waypoint Count: \(route.waypointCount)")
                print("   Total Distance: \(route.totalDistance)")
                print("   Is Active: \(route.isActive ?? false)")
                
                // Log additional error context for debugging
                if let postgrestError = error as? PostgrestError {
                    print("❌📤🛣️ ROUTE_INSERT_POSTGREST_ERROR: \(postgrestError)")
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
                print("📥🛣️ ROUTE_FETCH: Starting embedded routes fetch")
                print("📥🛣️ ROUTE_FETCH: Table = embedded_routes (public table)")
                print("📥🛣️ ROUTE_FETCH: Limit = \(limit?.description ?? "none")")
                print("📥🛣️ ROUTE_FETCH: Timestamp = \(Date())")
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
                print("✅📥🛣️ ROUTE_FETCH_SUCCESS: Embedded routes fetched successfully")
                print("✅📥🛣️ ROUTE_FETCH_SUCCESS: Routes found: \(response.value.count)")
                if !response.value.isEmpty {
                    print("✅📥🛣️ ROUTE_FETCH_SUCCESS: Route names: \(response.value.map { $0.name })")
                }
            }
            
            endOperation(operationId, success: true)
            return response.value
            
        } catch {
            logQueue.async {
                print("❌📥🛣️ ROUTE_FETCH_ERROR: Failed to fetch embedded routes")
                print("❌📥🛣️ ROUTE_FETCH_ERROR_DETAILS: \(error.localizedDescription)")
                print("❌📥🛣️ ROUTE_FETCH_ERROR_TYPE: \(type(of: error))")
                
                // Log additional error context for debugging
                if let postgrestError = error as? PostgrestError {
                    print("❌📥🛣️ ROUTE_FETCH_POSTGREST_ERROR: \(postgrestError)")
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
            print("🗄️ QUERY: SELECT \(columns) FROM \(self.table)")
        }
        return self
    }
    
    func eq(_ column: String, value: Any) -> DatabaseQueryBuilder {
        let filter = "\(column)=eq.\(value)"
        filters.append(filter)
        manager.logQueue.async {
            print("🗄️ FILTER: \(column) = \(value)")
        }
        return self
    }
    
    func limit(_ count: Int) -> DatabaseQueryBuilder {
        limitValue = count
        manager.logQueue.async {
            print("🗄️ LIMIT: \(count)")
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
                print("📊 QUERY RESULT:")
                print("   Table: \(self.table)")
                print("   Query: \(self.query)")
                print("   Filters: \(self.filters)")
                print("   Limit: \(self.limitValue?.description ?? "none")")
                print("   Status: Success")
            }
            
            manager.endOperation(operationId, success: true)
            return result
        } catch {
            manager.endOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    
}
