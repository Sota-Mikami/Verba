import Foundation

/// Simple file-based debug logger that writes to /tmp/verba-debug.log
/// Use `tail -f /tmp/verba-debug.log` to monitor in real-time
enum DebugLog {
    private static let logURL = URL(fileURLWithPath: "/tmp/verba-debug.log")
    private static let lock = NSLock()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func log(_ message: String, file: String = #file, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let entry = "[\(timestamp)] [\(fileName):\(line)] \(message)\n"

        lock.lock()
        defer { lock.unlock() }

        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }

    /// Clear the log file
    static func clear() {
        try? "".write(to: logURL, atomically: true, encoding: .utf8)
    }
}
