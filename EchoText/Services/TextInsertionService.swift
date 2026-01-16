import Foundation
import AppKit
import Carbon

/// Error types for text insertion operations
enum TextInsertionError: LocalizedError {
    case accessibilityNotEnabled
    case insertionFailed
    case pasteboardFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityNotEnabled:
            return "Accessibility access is not enabled. Please enable it in System Preferences."
        case .insertionFailed:
            return "Failed to insert text into the active application."
        case .pasteboardFailed:
            return "Failed to copy text to clipboard."
        }
    }
}

/// Service responsible for inserting transcribed text into active applications
@MainActor
final class TextInsertionService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isInserting = false

    // MARK: - Private Properties
    private var savedPasteboardContents: [NSPasteboard.PasteboardType: Data] = [:]
    private var previousActiveApp: NSRunningApplication?
    private var lastKnownExternalApp: NSRunningApplication?
    private var appObserver: NSObjectProtocol?

    // MARK: - Initialization
    init() {
        // Continuously track the frontmost app so we always know the last non-EchoText app
        startTrackingFrontmostApp()
    }

    deinit {
        if let observer = appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func startTrackingFrontmostApp() {
        let myBundleId = Bundle.main.bundleIdentifier

        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            // If it's not our app, remember it as the last external app
            if app.bundleIdentifier != myBundleId {
                Task { @MainActor in
                    self?.lastKnownExternalApp = app
                    NSLog("[TextInsertionService] Tracking external app: %@", app.localizedName ?? "unknown")
                }
            }
        }

        // Initialize with current frontmost app if it's not us
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != myBundleId {
            lastKnownExternalApp = frontApp
        }
    }

    // MARK: - Focus Management

    /// Save the currently active application (call when recording starts)
    /// Filters out our own app - if EchoText is frontmost, uses last known external app
    func saveActiveApp() {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let myBundleId = Bundle.main.bundleIdentifier

        NSLog("[TextInsertionService] saveActiveApp called")
        NSLog("[TextInsertionService] Front app: %@ (bundleID: %@)", frontApp?.localizedName ?? "none", frontApp?.bundleIdentifier ?? "none")
        NSLog("[TextInsertionService] Last known external app: %@", lastKnownExternalApp?.localizedName ?? "none")

        // If EchoText is currently frontmost, use the last known external app
        if frontApp?.bundleIdentifier == myBundleId {
            NSLog("[TextInsertionService] EchoText is frontmost, using last known external app")
            previousActiveApp = lastKnownExternalApp
        } else {
            previousActiveApp = frontApp
        }

        NSLog("[TextInsertionService] Will paste to: %@", previousActiveApp?.localizedName ?? "none")
    }

    /// Restore focus to the previously active application
    func restoreFocusToSavedApp() {
        let myBundleId = Bundle.main.bundleIdentifier

        NSLog("[TextInsertionService] restoreFocusToSavedApp called")
        NSLog("[TextInsertionService] Saved app: %@", previousActiveApp?.localizedName ?? "none")
        NSLog("[TextInsertionService] Last known external: %@", lastKnownExternalApp?.localizedName ?? "none")

        // Try saved app first
        if let app = previousActiveApp, app.bundleIdentifier != myBundleId, !app.isTerminated {
            NSLog("[TextInsertionService] Activating saved app: %@", app.localizedName ?? "unknown")
            app.activate()
            return
        }

        // Fallback to last known external app
        if let app = lastKnownExternalApp, app.bundleIdentifier != myBundleId, !app.isTerminated {
            NSLog("[TextInsertionService] Activating last known external app: %@", app.localizedName ?? "unknown")
            app.activate()
            return
        }

        // Last resort: Find any regular app
        NSLog("[TextInsertionService] No saved/tracked app, looking for any regular app...")
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if app.bundleIdentifier != myBundleId &&
               app.activationPolicy == .regular &&
               !app.isTerminated {
                NSLog("[TextInsertionService] Activating fallback app: %@", app.localizedName ?? "unknown")
                app.activate()
                return
            }
        }

        NSLog("[TextInsertionService] WARNING: No suitable app found to restore focus to")
    }

    // MARK: - Public Methods

    /// Insert text into the previously active application (the one saved when recording started)
    /// Uses the pasteboard + Cmd+V approach which is more reliable than CGEvents
    func insertText(_ text: String) async throws {
        guard !text.isEmpty else {
            NSLog("[TextInsertionService] insertText called with empty text, returning")
            return
        }

        NSLog("[TextInsertionService] insertText called with: '%@'", text)

        // Check accessibility FIRST - without it, nothing will work
        let hasAccess = AXIsProcessTrusted()
        WorkspaceLogger.log("[TextInsertionService] Accessibility access: \(hasAccess)")

        if !hasAccess {
            WorkspaceLogger.log("[TextInsertionService] ERROR: Accessibility not enabled - requesting permission")
            // Prompt user to enable accessibility
            requestAccessibilityAccess()
            throw TextInsertionError.accessibilityNotEnabled
        }

        isInserting = true
        defer { isInserting = false }

        // Save current pasteboard contents
        savePasteboardContents()

        // Set our text to pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            WorkspaceLogger.log("[TextInsertionService] Error: Failed to set pasteboard string")
            throw TextInsertionError.pasteboardFailed
        }

        WorkspaceLogger.log("[TextInsertionService] Text copied to clipboard")

        // Restore focus to the app that was active when recording started
        restoreFocusToSavedApp()

        // Wait for the app to become active and ready for input
        // Increased to 500ms for better reliability
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Try AppleScript paste first (works better in browsers)
        WorkspaceLogger.log("[TextInsertionService] Trying AppleScript paste...")
        let success = simulatePasteWithAppleScript()

        if !success {
            WorkspaceLogger.log("[TextInsertionService] AppleScript paste failed, trying CGEvent...")
            // Fallback to CGEvent
            simulatePaste()
        }

        // Delay before restoring - MUST be long enough for target app to process paste
        // Some apps (like Electron/Chrome) need more time
        WorkspaceLogger.log("[TextInsertionService] Waiting 500ms before restoring pasteboard...")
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Restore previous pasteboard contents
        restorePasteboardContents()
        WorkspaceLogger.log("[TextInsertionService] Pasteboard restored. Insertion flow complete.")
    }

    /// Insert text using CGEvents (alternative method, requires accessibility)
    func insertTextUsingKeyEvents(_ text: String) async throws {
        guard AXIsProcessTrusted() else {
            throw TextInsertionError.accessibilityNotEnabled
        }

        isInserting = true
        defer { isInserting = false }

        WorkspaceLogger.log("[TextInsertionService] Typing characters directly...")
        for character in text {
            typeCharacter(character)
            // Small delay between characters
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }

    /// Check if accessibility access is enabled
    func checkAccessibilityAccess() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Prompt user to enable accessibility access
    func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Private Methods

    private func savePasteboardContents() {
        savedPasteboardContents.removeAll()
        let pasteboard = NSPasteboard.general

        for type in pasteboard.types ?? [] {
            if let data = pasteboard.data(forType: type) {
                savedPasteboardContents[type] = data
            }
        }
        WorkspaceLogger.log("[TextInsertionService] Saved \(savedPasteboardContents.count) items from pasteboard")
    }

    private func restorePasteboardContents() {
        guard !savedPasteboardContents.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        for (type, data) in savedPasteboardContents {
            pasteboard.setData(data, forType: type)
        }

        WorkspaceLogger.log("[TextInsertionService] Restored \(savedPasteboardContents.count) items to pasteboard")
        savedPasteboardContents.removeAll()
    }

    private func simulatePasteWithAppleScript() -> Bool {
        let script = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            if let error = error {
                WorkspaceLogger.log("[TextInsertionService] AppleScript error detail: \(error)")
                return false
            }
            return true
        }
        return false
    }

    private func simulatePaste() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            WorkspaceLogger.log("[TextInsertionService] Error: Could not create CGEventSource")
            return
        }

        let vKeyCode = CGKeyCode(kVK_ANSI_V)
        let cmdKeyCode = CGKeyCode(kVK_Command)

        // Command + V key down
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        vDown?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)

        // Command + V key up
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        vUp?.flags = .maskCommand
        vUp?.post(tap: .cghidEventTap)
        
        WorkspaceLogger.log("[TextInsertionService] Posted CGEvent for Cmd+V")
    }

    private func typeCharacter(_ character: Character) {
        let source = CGEventSource(stateID: .hidSystemState)

        // Create a string from the character
        let string = String(character)

        // Create a key event
        if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            var unicodeChars = [UniChar](string.utf16)
            event.keyboardSetUnicodeString(stringLength: unicodeChars.count, unicodeString: &unicodeChars)
            event.post(tap: .cghidEventTap)

            // Key up
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }

    /// Deactivate the application to return focus to the previous one
    func yieldFocus() {
        if NSApp.isActive {
            WorkspaceLogger.log("[TextInsertionService] Yielding focus (app is active)")
            NSApp.hide(nil)
        } else {
            WorkspaceLogger.log("[TextInsertionService] App is not active, focus should already be elsewhere")
        }
    }
}

// MARK: - Virtual Key Codes
private let kVK_ANSI_V: UInt16 = 0x09
private let kVK_Command: UInt16 = 0x37
