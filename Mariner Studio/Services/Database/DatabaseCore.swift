import Foundation
#if canImport(SQLite)
import SQLite
#endif

/// Core database management class responsible for connection lifecycle and common database operations.
/// Each database service should define its own tables and columns.
class DatabaseCore {
    // MARK: - Properties
    private var connection: Connection?
    private let dbFileName = "app.db"
    private let versionPreferenceKey = "DatabaseVersion"
    private let currentDatabaseVersion = 1
    
    // MARK: - Initialization
    init() {
        DebugLogger.shared.log("📊 DatabaseCore being initialized", category: "DATABASE_INIT")
    }
    
    // MARK: - Connection Management
    
    /// Ensures connection is valid before performing operations
    func ensureConnection() throws -> Connection {
        guard let db = connection else {
            DebugLogger.shared.log("❌ Database connection is nil, attempting to reinitialize", category: "DATABASE_CONNECTION")
            // Attempt to recover by initializing the database
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbPath = documentsDirectory.appendingPathComponent("SS1.db").path
            try openConnection(atPath: dbPath)
            
            // If still nil, throw error
            guard let recoveredConnection = connection else {
                throw NSError(domain: "DatabaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database connection could not be reinitialized"])
            }
            
            return recoveredConnection
        }
        
        return db
    }
    
    /// Method to check connection health and optionally reset it
    func checkConnectionHealth() -> Bool {
        guard let db = connection else {
            DebugLogger.shared.log("❌ No connection to check health for", category: "DATABASE_CONNECTION")
            return false
        }
        
        do {
            // Execute a simple query to test the connection
            let _ = try db.scalar("SELECT 1")
            return true
        } catch {
            DebugLogger.shared.log("❌ Connection health check failed: \(error.localizedDescription)", category: "DATABASE_CONNECTION")
            connection = nil
            return false
        }
    }
    
    // Method to explicitly flush database to disk
    func flushDatabaseAsync() async throws {
        do {
            let db = try ensureConnection()
            
            DebugLogger.shared.log("📊 Flushing database changes to disk", category: "DATABASE_FLUSH")
            try db.execute("PRAGMA wal_checkpoint(FULL)")
            DebugLogger.shared.log("📊 Database flush completed", category: "DATABASE_FLUSH")
        } catch {
            DebugLogger.shared.log("❌ Error flushing database: \(error.localizedDescription)", category: "DATABASE_FLUSH")
            throw error
        }
    }
    
    func initializeAsync() async throws {
        if connection != nil {
            DebugLogger.shared.log("📊 Database connection already initialized, reusing existing connection", category: "DATABASE_INIT")
            return
        }
        
        let fileManager = FileManager.default
        
        // Use Documents directory for persistent storage instead of app support
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsDirectory.appendingPathComponent("SS1.db").path
        
        DebugLogger.shared.log("📊 Database path: \(dbPath)", category: "DATABASE_INIT")
        
        if !fileManager.fileExists(atPath: dbPath) {
            DebugLogger.shared.log("📊 Database not found in documents directory. Attempting to copy from resources.", category: "DATABASE_INIT")
            try copyDatabaseFromBundle(to: dbPath)
            DebugLogger.shared.log("📊 Database successfully copied to documents directory.", category: "DATABASE_INIT")
        } else {
            DebugLogger.shared.log("📊 Database already exists in documents directory.", category: "DATABASE_INIT")
        }
        
        // Check if we have write permissions
        if fileManager.isWritableFile(atPath: dbPath) {
            DebugLogger.shared.log("📊 Database file is writable", category: "DATABASE_INIT")
        } else {
            DebugLogger.shared.log("❌ Database file is not writable", category: "DATABASE_INIT")
        }
        
        if fileManager.fileExists(atPath: dbPath) {
            if let attributes = try? fileManager.attributesOfItem(atPath: dbPath),
               let fileSize = attributes[.size] as? UInt64 {
                DebugLogger.shared.log("📊 Database file confirmed at: \(dbPath)", category: "DATABASE_INIT")
                DebugLogger.shared.log("📊 File size: \(fileSize) bytes", category: "DATABASE_INIT")
            }
        } else {
            throw NSError(domain: "DatabaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database file not found after copy attempt."])
        }
        
        try openConnection(atPath: dbPath)
        
        // Configure the connection for better performance and reliability
        if let db = connection {
            try db.execute("PRAGMA busy_timeout = 5000")
            try db.execute("PRAGMA journal_mode = WAL")
            try db.execute("PRAGMA synchronous = NORMAL")
        }
    }
    
    private func copyDatabaseFromBundle(to path: String) throws {
        guard let bundleDBPath = Bundle.main.path(forResource: "SS1", ofType: "db") else {
            throw NSError(domain: "DatabaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Database file not found in app bundle."])
        }
        
        try FileManager.default.copyItem(atPath: bundleDBPath, toPath: path)
    }
    
    private func openConnection(atPath path: String) throws {
        do {
            connection = try Connection(path)
            DebugLogger.shared.log("📊 Successfully opened database connection", category: "DATABASE_CONNECTION")
        } catch {
            DebugLogger.shared.log("❌ Error opening database connection: \(error.localizedDescription)", category: "DATABASE_CONNECTION")
            throw error
        }
    }
    
    // MARK: - Table Operations
    
    // Get all table names from the database
    func getTableNamesAsync() async throws -> [String] {
        do {
            let db = try ensureConnection()
            
            let query = "SELECT name FROM sqlite_master WHERE type='table'"
            
            var tableNames: [String] = []
            for row in try db.prepare(query) {
                if let tableName = row[0] as? String {
                    tableNames.append(tableName)
                }
            }
            DebugLogger.shared.log("📊 Found \(tableNames.count) tables in database", category: "DATABASE_TABLES")
            return tableNames
        } catch {
            DebugLogger.shared.log("❌ Error getting table names: \(error.localizedDescription)", category: "DATABASE_TABLES")
            throw error
        }
    }
    
    // Write permissions check function
    func checkDatabaseWritePermissions() {
        do {
            let db = try ensureConnection()
            
            let testTableName = "write_test_\(Int(Date().timeIntervalSince1970))"
            
            // Try to create a temporary test table
            try db.execute("CREATE TABLE \(testTableName) (id INTEGER PRIMARY KEY, value TEXT)")
            DebugLogger.shared.log("✅ Successfully created test table - write permissions OK", category: "DATABASE_PERMISSIONS")
            
            // Insert a test row
            try db.execute("INSERT INTO \(testTableName) (value) VALUES ('test_value')")
            DebugLogger.shared.log("✅ Successfully inserted test row - write permissions OK", category: "DATABASE_PERMISSIONS")
            
            // Clean up
            try db.execute("DROP TABLE \(testTableName)")
            DebugLogger.shared.log("✅ Successfully dropped test table - write permissions OK", category: "DATABASE_PERMISSIONS")
        } catch {
            DebugLogger.shared.log("❌ Write permissions check failed: \(error.localizedDescription)", category: "DATABASE_PERMISSIONS")
        }
    }
    
    // Check connection with a test query
    func checkConnectionWithTestQuery() async throws {
        do {
            let db = try ensureConnection()
            
            DebugLogger.shared.log("📊 Testing database connection...", category: "DATABASE_TEST")
            // Execute a simple test query
            let testQuery = "SELECT 1"
            let result = try db.scalar(testQuery)
            DebugLogger.shared.log("📊 Test query result: \(String(describing: result))", category: "DATABASE_TEST")
            DebugLogger.shared.log("📊 Database connection test successful", category: "DATABASE_TEST")
        } catch {
            DebugLogger.shared.log("❌ Test database operation failed: \(error.localizedDescription)", category: "DATABASE_TEST")
            throw error
        }
    }
}
