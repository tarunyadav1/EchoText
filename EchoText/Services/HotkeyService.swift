import Foundation
import KeyboardShortcuts
import Combine

/// Define keyboard shortcut names
extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.r, modifiers: [.command, .shift]))
    static let cancelRecording = Self("cancelRecording", default: .init(.escape))
}

/// Service responsible for global keyboard shortcuts
@MainActor
final class HotkeyService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isHotkeyPressed = false

    // MARK: - Callbacks
    var onToggleRecording: (() -> Void)?
    var onStartHoldRecording: (() -> Void)?
    var onStopHoldRecording: (() -> Void)?
    var onCancelRecording: (() -> Void)?

    // MARK: - Private Properties
    private var recordingMode: RecordingMode = .pressToToggle
    private var keyDownTime: Date?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        setupHotkeys()
    }

    // MARK: - Public Methods

    /// Update the recording mode for hotkey behavior
    func setRecordingMode(_ mode: RecordingMode) {
        recordingMode = mode
        setupHotkeys()
    }

    /// Get the current shortcut for toggle recording
    func getCurrentShortcut() -> KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: .toggleRecording)
    }

    // MARK: - Private Methods

    private func setupHotkeys() {
        // Clear existing handlers for toggle recording
        KeyboardShortcuts.disable(.toggleRecording)

        switch recordingMode {
        case .pressToToggle, .voiceActivity:
            // Simple press to toggle
            KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
                Task { @MainActor in
                    self?.onToggleRecording?()
                }
            }

        case .holdToRecord:
            // Hold to record mode
            KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
                Task { @MainActor in
                    self?.isHotkeyPressed = true
                    self?.keyDownTime = Date()
                    self?.onStartHoldRecording?()
                }
            }

            KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
                Task { @MainActor in
                    self?.isHotkeyPressed = false
                    self?.onStopHoldRecording?()
                }
            }
        }

        // Note: Cancel shortcut (Escape) is only enabled during recording
        // to avoid capturing Escape globally. See enableCancelShortcut/disableCancelShortcut
    }

    /// Enable the cancel shortcut (call when recording starts)
    func enableCancelShortcut() {
        KeyboardShortcuts.onKeyDown(for: .cancelRecording) { [weak self] in
            Task { @MainActor in
                self?.onCancelRecording?()
            }
        }
    }

    /// Disable the cancel shortcut (call when recording stops)
    func disableCancelShortcut() {
        KeyboardShortcuts.disable(.cancelRecording)
    }
}

// MARK: - Shortcut Display Helpers
extension HotkeyService {
    /// Get human-readable shortcut string
    var toggleRecordingShortcutString: String {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording) else {
            return "Not set"
        }
        return shortcut.description
    }

    /// Get human-readable cancel shortcut string
    var cancelRecordingShortcutString: String {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .cancelRecording) else {
            return "Esc"
        }
        return shortcut.description
    }
}
