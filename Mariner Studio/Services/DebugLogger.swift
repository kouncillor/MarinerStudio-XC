import Foundation
import UIKit

class DebugLogger {
    static let shared = DebugLogger()

    private let logDirectory: URL
    private let logFileURL: URL
    private let fileManager = FileManager.default

    private init() {
        // Try to write to project directory for easy access
        if let projectPath = Self.getProjectPath() {
            logDirectory = projectPath.appendingPathComponent("LOGS").appendingPathComponent("DEBUG")
        } else {
            // Fallback to Documents directory
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            logDirectory = documentsDirectory.appendingPathComponent("LOGS").appendingPathComponent("DEBUG")
        }

        logFileURL = logDirectory.appendingPathComponent("DebugConsole.log")

        // Create directories if they don't exist
        createLogsDirectory()
    }

    private static func getProjectPath() -> URL? {
        // Try to find the project directory by looking for the .xcodeproj file
        let fileManager = FileManager.default
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        var searchDir = currentDir

        // Search up the directory tree for the project root
        for _ in 0..<10 { // Limit search to prevent infinite loop
            let contents = try? fileManager.contentsOfDirectory(at: searchDir, includingPropertiesForKeys: nil)
            if let contents = contents {
                for url in contents {
                    if url.pathExtension == "xcodeproj" {
                        return searchDir // Found project root
                    }
                }
            }

            let parentDir = searchDir.deletingLastPathComponent()
            if parentDir == searchDir {
                break // Reached root directory
            }
            searchDir = parentDir
        }

        return nil
    }

    private func createLogsDirectory() {
        do {
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create logs directory: \(error)")
        }
    }

    func log(_ message: String, category: String = "DEBUG") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "\(timestamp) [\(category)] \(message)\n"

        // Also print to console for immediate debugging
        print(message)

        // Write to file
        writeToFile(logEntry)
    }

    private func writeToFile(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }

        if fileManager.fileExists(atPath: logFileURL.path) {
            // Append to existing file
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            // Create new file
            do {
                try data.write(to: logFileURL)
            } catch {
                print("Failed to write to log file: \(error)")
            }
        }
    }

    func clearLogs() {
        do {
            try fileManager.removeItem(at: logFileURL)
        } catch {
            print("Failed to clear log file: \(error)")
        }
    }

    func getLogFileURL() -> URL {
        return logFileURL
    }

    func printLogLocation() {
        print("🗂️ DEBUG LOGGER: Writing logs to: \(logFileURL.path)")
        print("🗂️ DEBUG LOGGER: Directory exists: \(fileManager.fileExists(atPath: logDirectory.path))")
    }

}