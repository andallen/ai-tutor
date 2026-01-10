// File-based logger for UI test debugging.
// Writes logs to a file that can be retrieved after tests complete.
// Usage: FileLogger.shared.log("message") or FileLogger.log("message")

import Foundation

final class FileLogger {
    static let shared = FileLogger()

    private let fileHandle: FileHandle?
    private let logFileURL: URL?
    private let queue = DispatchQueue(label: "com.inkos.filelogger", qos: .utility)
    private let dateFormatter: DateFormatter

    // Whether to also print to console.
    var printToConsole = true

    // Log level for filtering.
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"
    }

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        // Create log file in Documents directory.
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logFileName = "inkos_debug.log"
        logFileURL = documentsPath.appendingPathComponent(logFileName)

        // Clear existing log file and create new one.
        if let url = logFileURL {
            try? FileManager.default.removeItem(at: url)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            fileHandle = try? FileHandle(forWritingTo: url)

            // Write header.
            let header = """
                =====================================
                InkOS Debug Log
                Started: \(Date())
                =====================================

                """
            if let data = header.data(using: .utf8) {
                fileHandle?.write(data)
            }
        } else {
            fileHandle = nil
        }
    }

    deinit {
        try? fileHandle?.close()
    }

    // Main logging function.
    func log(_ message: String, level: Level = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(message)\n"

        queue.async { [weak self] in
            guard let self else { return }

            // Write to file.
            if let data = formattedMessage.data(using: .utf8) {
                self.fileHandle?.write(data)
            }

            // Optionally print to console.
            if self.printToConsole {
                print(formattedMessage, terminator: "")
            }
        }
    }

    // Convenience static methods.
    static func log(_ message: String, level: Level = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: level, file: file, function: function, line: line)
    }

    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .debug, file: file, function: function, line: line)
    }

    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .info, file: file, function: function, line: line)
    }

    static func warn(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .warn, file: file, function: function, line: line)
    }

    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .error, file: file, function: function, line: line)
    }

    // Flush any buffered data.
    func flush() {
        queue.sync {
            try? fileHandle?.synchronize()
        }
    }

    // Get the log file URL for retrieval.
    var logURL: URL? {
        logFileURL
    }

    // Read the current log contents.
    func readLog() -> String? {
        guard let url = logFileURL else { return nil }
        flush()
        return try? String(contentsOf: url, encoding: .utf8)
    }

    // Clear the log file.
    func clear() {
        queue.sync {
            try? fileHandle?.truncate(atOffset: 0)
            try? fileHandle?.seek(toOffset: 0)
        }
    }
}

// MARK: - Global Convenience Function

// Drop-in replacement for print() that also writes to file.
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, function: String = #function, line: Int = #line) {
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    FileLogger.shared.log(message, file: file, function: function, line: line)
}
