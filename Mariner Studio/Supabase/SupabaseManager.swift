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
