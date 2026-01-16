import Foundation
import SwiftUI
import Combine

/// ViewModel for the dictation functionality
@MainActor
final class DictationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var transcriptionText: String = ""
    @Published var isEditing: Bool = false
    @Published var showCopyConfirmation: Bool = false

    // MARK: - Dependencies
    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(appState: AppState) {
        self.appState = appState
        setupBindings()
    }

    // MARK: - Actions

    /// Toggle recording
    func toggleRecording() {
        appState?.handleAction(.toggle)
    }

    /// Cancel current recording
    func cancelRecording() {
        appState?.handleAction(.cancel)
    }

    /// Copy transcription to clipboard
    func copyToClipboard() {
        guard !transcriptionText.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcriptionText, forType: .string)

        showCopyConfirmation = true

        // Hide confirmation after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showCopyConfirmation = false
        }
    }

    /// Clear transcription history
    func clearHistory() {
        appState?.transcriptionHistory.removeAll()
        transcriptionText = ""
    }

    /// Insert text into active application
    func insertText() async {
        guard !transcriptionText.isEmpty else { return }

        do {
            try await appState?.textInsertionService.insertText(transcriptionText)
        } catch {
            print("Failed to insert text: \(error)")
        }
    }

    /// Export transcription
    func export(format: ExportFormat) async {
        guard let result = appState?.lastTranscription else { return }
        _ = await ExportService.exportToFile(result, format: format)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Sync transcription text with last transcription
        appState?.$lastTranscription
            .receive(on: DispatchQueue.main)
            .compactMap { $0?.text }
            .sink { [weak self] text in
                if !(self?.isEditing ?? false) {
                    self?.transcriptionText = text
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Computed Properties
extension DictationViewModel {
    var recordingState: RecordingState {
        appState?.recordingState ?? .idle
    }

    var audioLevel: Float {
        appState?.audioLevel ?? 0.0
    }

    var recordingDuration: TimeInterval {
        appState?.recordingDuration ?? 0.0
    }

    var formattedDuration: String {
        appState?.formattedDuration ?? "0:00"
    }

    var isRecording: Bool {
        appState?.isRecording ?? false
    }

    var isProcessing: Bool {
        appState?.isProcessing ?? false
    }

    var canRecord: Bool {
        appState?.isIdle ?? true
    }

    var hasTranscription: Bool {
        !transcriptionText.isEmpty
    }

    var wordCount: Int {
        transcriptionText.split(separator: " ").count
    }

    var characterCount: Int {
        transcriptionText.count
    }
}
