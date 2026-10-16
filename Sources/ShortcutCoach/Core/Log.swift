import Foundation

/// Tiny append-only log at ~/Library/Logs/ShortcutCoach.log. Never records typed text.
enum Log {
    static let url: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ShortcutCoach.log")
    }()

    private static let queue = DispatchQueue(label: "ShortcutCoach.log", qos: .background)
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    static func info(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        queue.async {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int, size > 2_000_000 {
                try? FileManager.default.removeItem(at: url)
            }
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? Data(line.utf8).write(to: url)
            }
        }
    }

    /// Verbose click diagnostics, only when "Debug logging" is enabled in Settings.
    static func debug(_ message: @autoclosure () -> String) {
        if Prefs.debugLogging { info("[debug] " + message()) }
    }
}
