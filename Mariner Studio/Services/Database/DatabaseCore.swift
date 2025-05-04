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
        print("📊 DatabaseCore being initialized")
    }
    
    // MARK: - Connection Management
    
    /// Ensures connection is valid before performing operations
    func ensureConnection() throws -> Connection {
        guard let db = connection else {
            print("❌ Database connection is nil, attempting to reinitialize")
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
            print("❌ No connection to check health for")
            return false
        }
        
        do {
            // Execute a simple query to test the connection
            let _ = try db.scalar("SELECT 1")
            return true
        } catch {
            print("❌ Connection health check failed: \(error.localizedDescription)")
            connection = nil
            return false
        }
    }
    
    // Method to explicitly flush database to disk
    func flushDatabaseAsync() async throws {
        do {
            let db = try ensureConnection()
            
            print("📊 Flushing database changes to disk")
            try db.execute("PRAGMA wal_checkpoint(FULL)")
            print("📊 Database flush completed")
        } catch {
            print("❌ Error flushing database: \(error.localizedDescription)")
            throw error
        }
    }
    
    func initializeAsync() async throws {
        if connection != nil {
            print("📊 Database connection already initialized, reusing existing connection")
            return
        }
        
        let fileManager = FileManager.default
        
        // Use Documents directory for persistent storage instead of app support
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsDirectory.appendingPathComponent("SS1.db").path
        
        print("📊 Database path: \(dbPath)")
        
        if !fileManager.fileExists(atPath: dbPath) {
            print("📊 Database not found in documents directory. Attempting to copy from resources.")
            try copyDatabaseFromBundle(to: dbPath)
            print("📊 Database successfully copied to documents directory.")
        } else {
            print("📊 Database already exists in documents directory.")
        }
        
        // Check if we have write permissions
        if fileManager.isWritableFile(atPath: dbPath) {
            print("📊 Database file is writable")
        } else {
            print("❌ Database file is not writable")
        }
        
        if fileManager.fileExists(atPath: dbPath) {
            if let attributes = try? fileManager.attributesOfItem(atPath: dbPath),
               let fileSize = attributes[.size] as? UInt64 {
                print("📊 Database file confirmed at: \(dbPath)")
                print("📊 File size: \(fileSize) bytes")
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
            print("📊 Successfully opened database connection")
        } catch {
            print("❌ Error opening database connection: \(error.localizedDescription)")
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
            print("📊 Found \(tableNames.count) tables in database")
            return tableNames
        } catch {
            print("❌ Error getting table names: \(error.localizedDescription)")
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
            print("✅ Successfully created test table - write permissions OK")
            
            // Insert a test row
            try db.execute("INSERT INTO \(testTableName) (value) VALUES ('test_value')")
            print("✅ Successfully inserted test row - write permissions OK")
            
            // Clean up
            try db.execute("DROP TABLE \(testTableName)")
            print("✅ Successfully dropped test table - write permissions OK")
        } catch {
            print("❌ Write permissions check failed: \(error.localizedDescription)")
        }
    }
    
    // Check connection with a test query
    func checkConnectionWithTestQuery() async throws {
        do {
            let db = try ensureConnection()
            
            print("📊 Testing database connection...")
            // Execute a simple test query
            let testQuery = "SELECT 1"
            let result = try db.scalar(testQuery)
            print("📊 Test query result: \(String(describing: result))")
            print("📊 Database connection test successful")
        } catch {
            print("❌ Test database operation failed: \(error.localizedDescription)")
            throw error
        }
    }
}
