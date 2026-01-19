import Foundation
import AVFoundation

/// Benchmark results for comparing transcription engines
struct BenchmarkResult: Identifiable {
    let id = UUID()
    let engineName: String
    let audioDuration: TimeInterval
    let processingTime: TimeInterval
    let text: String
    let wordCount: Int

    var realtimeFactor: Double {
        audioDuration / processingTime
    }

    var formattedRTF: String {
        String(format: "%.1fx realtime", realtimeFactor)
    }

    var formattedProcessingTime: String {
        String(format: "%.2fs", processingTime)
    }
}

/// Service for benchmarking transcription engines
@MainActor
final class TranscriptionBenchmark: ObservableObject {
    @Published var isRunning = false
    @Published var currentEngine: String = ""
    @Published var whisperResult: BenchmarkResult?
    @Published var parakeetResult: BenchmarkResult?
    @Published var errorMessage: String?

    private let whisperService: WhisperService
    private let parakeetService: ParakeetService

    // Test audio file bundled with WhisperKit
    private var testAudioURL: URL? {
        let possiblePaths = [
            "build-output/SourcePackages/checkouts/WhisperKit/Tests/WhisperKitTests/Resources/ted_60.m4a",
            "build-output/SourcePackages/checkouts/WhisperKit/Tests/WhisperKitTests/Resources/jfk.wav"
        ]

        let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for path in possiblePaths {
            let url = baseURL.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Try from app bundle location
        if let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() as URL? {
            for path in possiblePaths {
                let url = appURL.appendingPathComponent(path)
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
        }

        return nil
    }

    init(whisperService: WhisperService, parakeetService: ParakeetService) {
        self.whisperService = whisperService
        self.parakeetService = parakeetService
    }

    /// Run benchmark comparing both engines
    func runBenchmark() async {
        guard !isRunning else { return }

        isRunning = true
        errorMessage = nil
        whisperResult = nil
        parakeetResult = nil

        defer { isRunning = false }

        // Find test audio
        guard let audioURL = findTestAudio() else {
            errorMessage = "No test audio file found. Please ensure WhisperKit package is downloaded."
            return
        }

        // Get audio duration
        let audioDuration = await getAudioDuration(url: audioURL)
        guard audioDuration > 0 else {
            errorMessage = "Could not determine audio duration"
            return
        }

        print("🎯 Starting benchmark with \(String(format: "%.1f", audioDuration))s audio file")

        // Test Whisper
        currentEngine = "Whisper"
        if whisperService.isModelLoaded {
            print("⏱️ Testing Whisper...")
            let startTime = Date()
            do {
                let result = try await whisperService.transcribe(audioURL: audioURL)
                let processingTime = Date().timeIntervalSince(startTime)
                whisperResult = BenchmarkResult(
                    engineName: "Whisper (\(whisperService.loadedModelId ?? "unknown"))",
                    audioDuration: audioDuration,
                    processingTime: processingTime,
                    text: result.text,
                    wordCount: result.text.split(separator: " ").count
                )
                print("✅ Whisper: \(whisperResult!.formattedRTF)")
            } catch {
                print("❌ Whisper failed: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ Whisper model not loaded, skipping")
        }

        // Test Parakeet
        currentEngine = "Parakeet"
        if parakeetService.isModelLoaded {
            print("⏱️ Testing Parakeet...")
            let startTime = Date()
            do {
                let result = try await parakeetService.transcribe(audioURL: audioURL)
                let processingTime = Date().timeIntervalSince(startTime)
                parakeetResult = BenchmarkResult(
                    engineName: "Parakeet (\(parakeetService.loadedModelId ?? "unknown"))",
                    audioDuration: audioDuration,
                    processingTime: processingTime,
                    text: result.text,
                    wordCount: result.text.split(separator: " ").count
                )
                print("✅ Parakeet: \(parakeetResult!.formattedRTF)")
            } catch {
                print("❌ Parakeet failed: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ Parakeet model not loaded, skipping")
        }

        currentEngine = ""

        // Print comparison
        if let w = whisperResult, let p = parakeetResult {
            let speedup = p.realtimeFactor / w.realtimeFactor
            print("📊 Parakeet is \(String(format: "%.1fx", speedup)) faster than Whisper")
        }
    }

    private func findTestAudio() -> URL? {
        // Try multiple possible locations
        let paths = [
            "/Users/mac/work/saas-project-rocket/Echo-text/build-output/SourcePackages/checkouts/WhisperKit/Tests/WhisperKitTests/Resources/ted_60.m4a",
            "/Users/mac/work/saas-project-rocket/Echo-text/build-output/SourcePackages/checkouts/WhisperKit/Tests/WhisperKitTests/Resources/jfk.wav"
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }

    private func getAudioDuration(url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            return 0
        }
    }
}
