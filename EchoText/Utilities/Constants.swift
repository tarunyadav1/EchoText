import Foundation

/// Application-wide constants
enum Constants {
    // MARK: - App Info
    static let appName = "Echo-text"
    static let appBundleId = "com.echotext.app"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    // MARK: - Storage Paths
    enum Paths {
        static var applicationSupport: URL {
            let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            return paths.first!.appendingPathComponent(Constants.appName, isDirectory: true)
        }

        static var modelsDirectory: URL {
            applicationSupport.appendingPathComponent("Models", isDirectory: true)
        }

        static var logsDirectory: URL {
            applicationSupport.appendingPathComponent("Logs", isDirectory: true)
        }

        static var tempDirectory: URL {
            FileManager.default.temporaryDirectory.appendingPathComponent(Constants.appName, isDirectory: true)
        }
    }

    // MARK: - Audio Settings
    enum Audio {
        static let sampleRate: Double = 16000.0
        static let channelCount: UInt32 = 1
        static let bitDepth: UInt32 = 32
        static let bufferSize: UInt32 = 1024
    }

    // MARK: - UI Settings
    enum UI {
        static let floatingWindowWidth: CGFloat = 300
        static let floatingWindowHeight: CGFloat = 80
        static let floatingWindowCornerRadius: CGFloat = 16

        static let minMainWindowWidth: CGFloat = 700
        static let minMainWindowHeight: CGFloat = 500

        static let animationDuration: Double = 0.25
    }

    // MARK: - Default Values
    enum Defaults {
        static let vadSilenceThreshold: TimeInterval = 1.5
        static let vadEnergyThreshold: Float = 0.01
        static let floatingWindowOpacity: Double = 0.95
    }

    // MARK: - URLs
    enum URLs {
        static let helpURL = URL(string: "https://echotext.app/help")!
        static let privacyURL = URL(string: "https://echotext.app/privacy")!
        static let termsURL = URL(string: "https://echotext.app/terms")!
        static let githubURL = URL(string: "https://github.com/echotext/echotext")!
    }

    // MARK: - Notification Names
    enum Notifications {
        static let recordingStarted = Notification.Name("com.echotext.recordingStarted")
        static let recordingStopped = Notification.Name("com.echotext.recordingStopped")
        static let transcriptionCompleted = Notification.Name("com.echotext.transcriptionCompleted")
        static let modelDownloaded = Notification.Name("com.echotext.modelDownloaded")
        static let settingsChanged = Notification.Name("com.echotext.settingsChanged")
    }
}

/// Simple file-based logger for debugging in the workspace
struct WorkspaceLogger {
    static let logFileURL: URL = {
        // Use a fixed location in /tmp that we know will be writable
        let logsDir = URL(fileURLWithPath: "/tmp/echotext_logs")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        return logsDir.appendingPathComponent("app.log")
    }()

    static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"

        NSLog("EchoText: %@", message) // Use NSLog which always works

        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }
}

// MARK: - Directory Creation
extension Constants.Paths {
    /// Ensure all required directories exist
    static func createRequiredDirectories() throws {
        let directories = [applicationSupport, modelsDirectory, logsDirectory, tempDirectory]

        for directory in directories {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}
