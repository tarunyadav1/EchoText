import Foundation
import Combine

/// Service for downloading audio from URLs using yt-dlp
@MainActor
final class URLDownloadService: ObservableObject {
    // MARK: - Singleton
    static let shared = URLDownloadService()

    // MARK: - Published Properties
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var currentDownloadProgress: Double = 0

    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var currentProcess: Process?
    private var downloadTasks: [UUID: Task<URL, Error>] = [:]

    // MARK: - Directory Management

    /// Downloads cache directory
    private var downloadsDirectory: URL {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = cacheDir.appendingPathComponent("EchoText/Downloads", isDirectory: true)

        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        return dir
    }

    /// Path to bundled yt-dlp binary
    private var ytdlpPath: String? {
        // First check bundle resources using path(forResource:)
        if let bundledPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) {
            return bundledPath
        }

        // Also check directly in the Resources folder
        if let resourcePath = Bundle.main.resourcePath {
            let directPath = (resourcePath as NSString).appendingPathComponent("yt-dlp")
            if fileManager.fileExists(atPath: directPath) {
                return directPath
            }
        }

        // Check in the bundle's MacOS folder (where executables sometimes go)
        if let executablePath = Bundle.main.executablePath {
            let bundlePath = (executablePath as NSString).deletingLastPathComponent
            let macOSPath = (bundlePath as NSString).appendingPathComponent("yt-dlp")
            if fileManager.fileExists(atPath: macOSPath) {
                return macOSPath
            }
        }

        // Fallback: Check if yt-dlp is installed via Homebrew or in PATH
        let homebrewPaths = [
            "/opt/homebrew/bin/yt-dlp",      // Apple Silicon Homebrew
            "/usr/local/bin/yt-dlp",          // Intel Homebrew
            "/usr/bin/yt-dlp"                 // System path
        ]

        for path in homebrewPaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }

    /// Check if yt-dlp is available
    var isYtdlpAvailable: Bool {
        ytdlpPath != nil
    }

    // MARK: - Initialization
    private init() {}

    // MARK: - Public Methods

    /// Validate a URL and fetch metadata
    /// - Parameter urlString: The URL string to validate
    /// - Returns: Video metadata if valid
    func validateURL(_ urlString: String) async throws -> URLVideoMetadata {
        NSLog("[URLDownloadService] validateURL called with URL: %@", urlString)
        guard let ytdlp = ytdlpPath else {
            NSLog("[URLDownloadService] yt-dlp not found!")
            throw URLDownloadError.bundledBinaryMissing
        }
        NSLog("[URLDownloadService] Using yt-dlp at: %@", ytdlp)

        // Check if yt-dlp is executable
        let isExecutable = fileManager.isExecutableFile(atPath: ytdlp)
        NSLog("[URLDownloadService] yt-dlp is executable: %@", isExecutable ? "YES" : "NO")

        // Basic URL validation
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            NSLog("[URLDownloadService] Invalid URL format")
            throw URLDownloadError.invalidURL
        }

        // Escape the URL for shell
        let escapedURL = urlString.replacingOccurrences(of: "'", with: "'\\''")

        // Build the shell command
        let shellCommand = "'\(ytdlp)' --simulate --dump-json --no-warnings --no-playlist --socket-timeout 30 --no-config --no-update '\(escapedURL)'"
        NSLog("[URLDownloadService] Shell command: %@", shellCommand)

        // Run using /bin/zsh for better compatibility
        do {
            let result = try await runShellCommand(shellCommand, timeout: 60)
            NSLog("[URLDownloadService] Command completed. Output length: %d, Error length: %d", result.output.count, result.error.count)

            // Check for errors
            if !result.error.isEmpty && result.output.isEmpty {
                let errorString = result.error
                NSLog("[URLDownloadService] Error output: %@", errorString.prefix(500).description)

                if errorString.contains("Unsupported URL") || errorString.contains("is not a valid URL") {
                    throw URLDownloadError.unsupportedPlatform
                } else if errorString.contains("Private video") || errorString.contains("Video unavailable") {
                    throw URLDownloadError.videoUnavailable(reason: "Video is private or unavailable")
                } else if errorString.contains("age") || errorString.contains("Sign in") {
                    throw URLDownloadError.videoUnavailable(reason: "Age-restricted or requires sign-in")
                } else if errorString.contains("geo") || errorString.contains("country") {
                    throw URLDownloadError.videoUnavailable(reason: "Not available in your region")
                } else if errorString.contains("truncated") || errorString.contains("Incomplete") {
                    throw URLDownloadError.invalidURL
                }

                throw URLDownloadError.downloadFailed(reason: errorString.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            // Parse JSON output
            guard let outputData = result.output.data(using: .utf8), !outputData.isEmpty else {
                NSLog("[URLDownloadService] Empty output, parsing failed")
                throw URLDownloadError.metadataParsingFailed
            }

            NSLog("[URLDownloadService] Parsing metadata...")
            return try parseMetadata(from: outputData, originalURL: url)
        } catch {
            NSLog("[URLDownloadService] Error: %@", error.localizedDescription)
            throw error
        }
    }

    /// Run a shell command with timeout - simplified synchronous approach
    private func runShellCommand(_ command: String, timeout: TimeInterval) async throws -> (output: String, error: String) {
        NSLog("[URLDownloadService] runShellCommand starting...")

        // Run process on a detached task
        let result: (output: String, error: String) = try await Task.detached(priority: .userInitiated) {
            NSLog("[URLDownloadService] Detached task started, creating process...")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]

            // Set up environment to include common paths
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (environment["PATH"] ?? "")
            process.environment = environment

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // CRITICAL: Start reading from pipes in the background to avoid deadlock.
            // When a process produces more than 64KB of output, it will block on write()
            // until the parent reads from the pipe. If the parent waits for the process
            // to terminate before reading, they will DEADLOCK.
            let outputTask = Task {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8) ?? ""
            }

            let errorTask = Task {
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8) ?? ""
            }

            // Use terminationHandler instead of waitUntilExit for better async handling
            let semaphore = DispatchSemaphore(value: 0)

            process.terminationHandler = { _ in
                NSLog("[URLDownloadService] Process terminated with status: %d", process.terminationStatus)
                semaphore.signal()
            }

            NSLog("[URLDownloadService] Running process...")
            do {
                try process.run()
                NSLog("[URLDownloadService] Process started, waiting for completion...")
            } catch {
                NSLog("[URLDownloadService] Failed to start process: %@", error.localizedDescription)
                outputTask.cancel()
                errorTask.cancel()
                throw error
            }

            // Wait with timeout
            let timeoutResult = semaphore.wait(timeout: .now() + timeout)

            if timeoutResult == .timedOut {
                NSLog("[URLDownloadService] Process timed out, terminating...")
                process.terminate()
                outputTask.cancel()
                errorTask.cancel()
                throw URLDownloadError.downloadFailed(reason: "Request timed out after \(Int(timeout)) seconds")
            }

            NSLog("[URLDownloadService] Process completed, awaiting output tasks...")

            // Await the output tasks which have been draining the pipes
            let output = await outputTask.value
            let errorOutput = await errorTask.value

            NSLog("[URLDownloadService] Output: %d bytes, Error: %d bytes", output.count, errorOutput.count)
            if !errorOutput.isEmpty {
                NSLog("[URLDownloadService] Error output: %@", errorOutput.prefix(500).description)
            }

            return (output, errorOutput)
        }.value

        NSLog("[URLDownloadService] runShellCommand completed")
        return result
    }

    /// Download audio from a URL
    /// - Parameters:
    ///   - metadata: Video metadata from validation
    ///   - progressHandler: Optional handler for download progress updates
    /// - Returns: Local URL to the downloaded audio file
    func downloadAudio(
        from metadata: URLVideoMetadata,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> URL {
        guard let ytdlp = ytdlpPath else {
            throw URLDownloadError.bundledBinaryMissing
        }

        let outputPath = downloadsDirectory
            .appendingPathComponent("\(UUID().uuidString).m4a")

        isDownloading = true
        currentDownloadProgress = 0

        defer {
            isDownloading = false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytdlp)
        process.arguments = [
            "-x",                           // Extract audio
            "--audio-format", "m4a",        // Convert to m4a
            "--audio-quality", "0",         // Best quality
            "-o", outputPath.path,          // Output path
            "--progress",                   // Show progress
            "--newline",                    // Progress on new lines
            "--no-playlist",                // Single video only
            "--no-warnings",
            metadata.originalURL.absoluteString
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        currentProcess = process

        // Read progress asynchronously
        let progressTask = Task.detached {
            let fileHandle = outputPipe.fileHandleForReading

            while let line = try? await fileHandle.asyncReadLine() {
                if Task.isCancelled { break }

                // Parse progress from yt-dlp output
                // Format: [download]  XX.X% of XXX at XXX/s ETA XX:XX
                if line.contains("[download]"), let percentRange = line.range(of: #"\d+\.?\d*%"#, options: .regularExpression) {
                    let percentString = line[percentRange].dropLast() // Remove %
                    if let percent = Double(percentString) {
                        let progress = percent / 100.0
                        await MainActor.run {
                            progressHandler?(progress)
                        }
                    }
                }
            }
        }

        do {
            try process.run()

            // Wait for process completion
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global().async {
                        process.waitUntilExit()

                        progressTask.cancel()

                        if process.terminationStatus == 0 {
                            // Verify file exists
                            if FileManager.default.fileExists(atPath: outputPath.path) {
                                continuation.resume(returning: outputPath)
                            } else {
                                continuation.resume(throwing: URLDownloadError.audioExtractionFailed(reason: "Output file not created"))
                            }
                        } else {
                            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                            continuation.resume(throwing: URLDownloadError.downloadFailed(reason: errorString.trimmingCharacters(in: .whitespacesAndNewlines)))
                        }
                    }
                }
            } onCancel: {
                process.terminate()
                try? FileManager.default.removeItem(at: outputPath)
            }
        } catch {
            throw URLDownloadError.networkError(error)
        }
    }

    /// Cancel current download
    func cancelDownload() {
        currentProcess?.terminate()
        currentProcess = nil
        isDownloading = false
        currentDownloadProgress = 0
    }

    /// Clean up a downloaded file
    func cleanupDownload(at url: URL) {
        try? fileManager.removeItem(at: url)
    }

    /// Clean up all downloaded files
    func cleanupAllDownloads() {
        try? fileManager.removeItem(at: downloadsDirectory)
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private Methods

    private func parseMetadata(from data: Data, originalURL: URL) throws -> URLVideoMetadata {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLDownloadError.metadataParsingFailed
        }

        // Extract required fields
        guard let id = json["id"] as? String,
              let title = json["title"] as? String else {
            throw URLDownloadError.metadataParsingFailed
        }

        // Extract optional fields
        let duration = json["duration"] as? Double ?? 0

        // Try different thumbnail fields
        var thumbnailURL: URL? = nil
        if let thumbnail = json["thumbnail"] as? String {
            thumbnailURL = URL(string: thumbnail)
        } else if let thumbnails = json["thumbnails"] as? [[String: Any]],
                  let lastThumbnail = thumbnails.last,
                  let thumbURL = lastThumbnail["url"] as? String {
            thumbnailURL = URL(string: thumbURL)
        }

        // Detect platform from extractor
        let extractor = json["extractor"] as? String
        let platform = normalizePlatformName(extractor)

        // Uploader info
        let uploader = json["uploader"] as? String ?? json["channel"] as? String

        // Upload date (format: YYYYMMDD)
        var uploadDate: Date? = nil
        if let dateString = json["upload_date"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            uploadDate = formatter.date(from: dateString)
        }

        return URLVideoMetadata(
            id: id,
            title: title,
            duration: duration,
            thumbnailURL: thumbnailURL,
            platform: platform,
            originalURL: originalURL,
            uploader: uploader,
            uploadDate: uploadDate
        )
    }

    private func normalizePlatformName(_ extractor: String?) -> String? {
        guard let extractor = extractor else { return nil }

        let lowercased = extractor.lowercased()

        if lowercased.contains("youtube") { return "YouTube" }
        if lowercased.contains("vimeo") { return "Vimeo" }
        if lowercased.contains("twitter") || lowercased.contains("x") { return "Twitter" }
        if lowercased.contains("tiktok") { return "TikTok" }
        if lowercased.contains("instagram") { return "Instagram" }
        if lowercased.contains("facebook") { return "Facebook" }
        if lowercased.contains("twitch") { return "Twitch" }
        if lowercased.contains("soundcloud") { return "SoundCloud" }
        if lowercased.contains("reddit") { return "Reddit" }

        // Capitalize first letter of extractor name
        return extractor.prefix(1).uppercased() + extractor.dropFirst()
    }
}

// MARK: - FileHandle Async Extension

extension FileHandle {
    /// Asynchronously read a line from the file handle
    func asyncReadLine() async throws -> String? {
        let fileDescriptor = self.fileDescriptor
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                var data = Data()
                var byte: UInt8 = 0

                while true {
                    var buffer = [UInt8](repeating: 0, count: 1)
                    let bytesRead = Darwin.read(fileDescriptor, &buffer, 1)
                    if bytesRead <= 0 {
                        // End of file or error
                        if data.isEmpty {
                            continuation.resume(returning: nil)
                        } else {
                            continuation.resume(returning: String(data: data, encoding: .utf8))
                        }
                        return
                    }

                    byte = buffer[0]
                    if byte == 0x0A { // newline
                        continuation.resume(returning: String(data: data, encoding: .utf8))
                        return
                    }

                    data.append(byte)
                }
            }
        }
    }
}
