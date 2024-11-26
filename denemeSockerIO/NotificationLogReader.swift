import Foundation

class NotificationLogReader {
    static let shared = NotificationLogReader()
    
    private let logFile = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.denemeSockerIO")?.appendingPathComponent("notification_logs.txt")
    
    func readLogs() -> String {
        guard let logFile = logFile,
              let content = try? String(contentsOf: logFile, encoding: .utf8) else {
            return "Logs not found"
        }
        return content
    }
    
    func clearLogs() {
        guard let logFile = logFile else { return }
        try? "".write(to: logFile, atomically: true, encoding: .utf8)
    }
}