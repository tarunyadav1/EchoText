import Foundation
import AppKit
import SwiftUI

/// Custom NSWindow subclass for Focus Mode
/// This window can become key/main and handles full-screen appearance
class FocusModeWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private var localEventMonitor: Any?

    /// Create a new Focus Mode window
    static func create() -> FocusModeWindow {
        let window = FocusModeWindow(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure window
        window.level = .normal
        window.isOpaque = true
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false

        // Allow joining all spaces for multi-desktop support
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]

        // Enforce dark appearance
        window.appearance = NSAppearance(named: .darkAqua)

        // Make window the full size of the main screen
        if let screen = NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }

        return window
    }

    /// Set the content view with a SwiftUI view
    func setContent<V: View>(_ view: V) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    /// Show the window in fake full-screen mode (covers entire screen without native fullscreen)
    /// This gives us full control over the ESC key without macOS intercepting it
    func showFullScreen() {
        // Ensure window is sized to fill the screen (including menu bar area)
        if let screen = NSScreen.main {
            setFrame(screen.frame, display: true)
        }

        // Set window level to cover menu bar and dock
        level = .screenSaver

        // Make key, bring to front
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // NOTE: We intentionally do NOT use native fullscreen (toggleFullScreen)
        // because it intercepts ESC key before we can handle it.
        // The borderless window sized to fill the screen achieves the same visual effect.

        // Add local event monitor for ESC key to ensure it always works
        setupEscapeKeyMonitor()
    }

    /// Set up a local event monitor to catch ESC key press
    private func setupEscapeKeyMonitor() {
        // Remove existing monitor if any
        removeEscapeKeyMonitor()

        // Add local monitor for key events
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }

            // Check for Escape key (keyCode 53)
            if event.keyCode == 53 {
                NSLog("[FocusModeWindow] ESC key pressed - exiting focus mode")
                NotificationCenter.default.post(name: .exitFocusMode, object: nil)
                return nil // Consume the event
            }

            return event
        }
    }

    /// Remove the ESC key event monitor
    private func removeEscapeKeyMonitor() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    /// Hide the window (no longer uses native fullscreen, so simpler exit)
    func hideAndExitFullScreen(completion: (() -> Void)? = nil) {
        NSLog("[FocusModeWindow] hideAndExitFullScreen called")

        // Remove ESC key monitor
        removeEscapeKeyMonitor()

        // Reset window level to normal
        level = .normal

        // Hide window immediately (no native fullscreen animation needed)
        orderOut(nil)
        completion?()
    }

    deinit {
        removeEscapeKeyMonitor()
    }

    // MARK: - Keyboard Event Handling

    override func keyDown(with event: NSEvent) {
        // Check for Escape key
        if event.keyCode == 53 { // Escape key
            NotificationCenter.default.post(name: .exitFocusMode, object: nil)
            return
        }

        super.keyDown(with: event)
    }
}

// MARK: - Focus Mode Notifications

extension Notification.Name {
    static let showFocusModeWindow = Notification.Name("showFocusModeWindow")
    static let hideFocusModeWindow = Notification.Name("hideFocusModeWindow")
    static let exitFocusMode = Notification.Name("exitFocusMode")
}
