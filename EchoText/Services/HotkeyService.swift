import Foundation
import KeyboardShortcuts
import Combine
import AppKit

/// Define keyboard shortcut names
extension KeyboardShortcuts.Name {
    // Default: Control + Space
    // Users can customize this in Settings
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: [.control]))
    static let cancelRecording = Self("cancelRecording", default: .init(.escape))
    // Focus Mode: Command + Shift + F
    static let toggleFocusMode = Self("toggleFocusMode", default: .init(.f, modifiers: [.command, .shift]))
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
    var onToggleFocusMode: (() -> Void)?

    // MARK: - Private Properties
    private var recordingMode: RecordingMode = .pressToToggle
    private var keyDownTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var globalKeyUpMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localKeyUpMonitor: Any?
    private var localFlagsMonitor: Any?
    private var isHoldRecording = false

    // MARK: - Initialization
    init() {
        setupHotkeys()
        setupFocusModeHotkey()
    }

    deinit {
        // Clean up event monitors
        if let monitor = globalKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalFlagsMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localFlagsMonitor {
            NSEvent.removeMonitor(monitor)
        }
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
        // Clear existing handlers and monitors
        KeyboardShortcuts.disable(.toggleRecording)
        removeHoldToRecordMonitors()

        switch recordingMode {
        case .pressToToggle, .voiceActivity:
            // Simple press to toggle
            KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
                Task { @MainActor in
                    self?.onToggleRecording?()
                }
            }

        case .holdToRecord:
            // Hold to record mode - use global event monitors for reliable key release detection
            KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
                Task { @MainActor in
                    guard let self = self, !self.isHoldRecording else { return }
                    self.isHotkeyPressed = true
                    self.isHoldRecording = true
                    self.keyDownTime = Date()
                    self.onStartHoldRecording?()
                    self.startHoldToRecordMonitors()
                }
            }
        }

        // Note: Cancel shortcut (Escape) is only enabled during recording
        // to avoid capturing Escape globally. See enableCancelShortcut/disableCancelShortcut
    }

    /// Start monitoring for key release in hold-to-record mode
    private func startHoldToRecordMonitors() {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording) else { return }

        let handleKeyUp: (NSEvent) -> Void = { [weak self] event in
            guard let self = self, self.isHoldRecording else { return }

            // Check if the released key matches our shortcut's key
            if event.keyCode == shortcut.carbonKeyCode {
                Task { @MainActor in
                    self.stopHoldRecording()
                }
            }
        }

        let handleFlagsChanged: (NSEvent) -> Void = { [weak self] event in
            guard let self = self, self.isHoldRecording else { return }

            // Check if the required modifiers are still being held
            let currentModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let requiredModifiers = shortcut.modifiers

            // If required modifiers are no longer held, stop recording
            if !currentModifiers.contains(requiredModifiers) {
                Task { @MainActor in
                    self.stopHoldRecording()
                }
            }
        }

        // Global monitors (when app is not focused)
        globalKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: handleKeyUp)
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handleFlagsChanged)

        // Local monitors (when app is focused)
        localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            handleKeyUp(event)
            return event
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handleFlagsChanged(event)
            return event
        }
    }

    /// Stop hold-to-record and clean up monitors
    private func stopHoldRecording() {
        guard isHoldRecording else { return }

        isHotkeyPressed = false
        isHoldRecording = false
        removeHoldToRecordMonitors()
        onStopHoldRecording?()
    }

    /// Remove all event monitors
    private func removeHoldToRecordMonitors() {
        if let monitor = globalKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyUpMonitor = nil
        }
        if let monitor = globalFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            globalFlagsMonitor = nil
        }
        if let monitor = localKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyUpMonitor = nil
        }
        if let monitor = localFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            localFlagsMonitor = nil
        }
    }

    private func setupFocusModeHotkey() {
        KeyboardShortcuts.onKeyDown(for: .toggleFocusMode) { [weak self] in
            Task { @MainActor in
                self?.onToggleFocusMode?()
            }
        }
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

    /// Get human-readable focus mode shortcut string
    var focusModeShortcutString: String {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .toggleFocusMode) else {
            return "\u{2318}\u{21E7}F"
        }
        return shortcut.description
    }
}
