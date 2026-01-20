import Foundation
import AppKit
import SwiftUI
import Sparkle

/// AppDelegate for system-level integration
class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: NSWindow?
    var focusModeWindow: FocusModeWindow?
    var captionsWindowController: CaptionsWindowController?
    weak var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Log app info for debugging
        NSLog("[AppDelegate] App launched")
        NSLog("[AppDelegate] Bundle ID: %@", Bundle.main.bundleIdentifier ?? "unknown")
        NSLog("[AppDelegate] Bundle Path: %@", Bundle.main.bundlePath)
        NSLog("[AppDelegate] AXIsProcessTrusted: %@", AXIsProcessTrusted() ? "YES" : "NO")

        // Check if another instance is already running
        if isAnotherInstanceRunning() {
            NSLog("[AppDelegate] Another instance is already running. Terminating this instance.")
            // Activate the existing instance instead
            activateExistingInstance()
            NSApp.terminate(nil)
            return
        }

        // App runs as regular app with dock icon and main window
        // Menu bar extra provides quick access to recording features
        NSApp.setActivationPolicy(.regular)

        // Initialize captions window controller
        captionsWindowController = CaptionsWindowController()

        // Initialize Sparkle update service
        _ = UpdateService.shared
        NSLog("[AppDelegate] Sparkle update service initialized")

        // Initialize telemetry service and track app launch
        TelemetryService.shared.trackAppLaunch()
        NSLog("[AppDelegate] Telemetry service initialized")

        // Setup notification observers
        setupNotificationObservers()

        // Wait for SwiftUI to create the main window, then show it
        waitForMainWindowAndShow()
    }

    /// Check if another instance of the app is already running
    private func isAnotherInstanceRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        let myBundleId = Bundle.main.bundleIdentifier
        let myPID = ProcessInfo.processInfo.processIdentifier

        let otherInstances = runningApps.filter { app in
            app.bundleIdentifier == myBundleId && app.processIdentifier != myPID
        }

        return !otherInstances.isEmpty
    }

    /// Activate the existing instance of the app
    private func activateExistingInstance() {
        let runningApps = NSWorkspace.shared.runningApplications
        let myBundleId = Bundle.main.bundleIdentifier
        let myPID = ProcessInfo.processInfo.processIdentifier

        if let existingApp = runningApps.first(where: { $0.bundleIdentifier == myBundleId && $0.processIdentifier != myPID }) {
            existingApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }

    /// Wait for SwiftUI WindowGroup to create the main window, then show it
    private func waitForMainWindowAndShow(attempts: Int = 0) {
        let maxAttempts = 20  // Try for up to 2 seconds

        // Look for SwiftUI-created window (not status bar windows)
        let mainWindow = NSApp.windows.first { window in
            !(window is NonActivatingFloatingWindow) &&
            !(window is RealtimeCaptionsWindow) &&
            !window.className.contains("StatusBar") &&
            window.contentView != nil
        }

        if let window = mainWindow {
            NSLog("[AppDelegate] Found main window after %d attempts: %@", attempts, window)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else if attempts < maxAttempts {
            // Window not ready yet, try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.waitForMainWindowAndShow(attempts: attempts + 1)
            }
        } else {
            NSLog("[AppDelegate] Could not find main window after %d attempts", attempts)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        hideFloatingWindow()
        hideFocusModeWindow()
        hideCaptionsWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar when window is closed
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show main window when dock icon is clicked
        if !flag {
            showMainWindow()
        }
        return true
    }

    /// Show the main application window (used from menu bar)
    func showMainWindow() {
        // Temporarily become a regular app to show in dock and allow window focus
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        NSLog("[AppDelegate] showMainWindow called, windows count: %d", NSApp.windows.count)
        for (index, window) in NSApp.windows.enumerated() {
            NSLog("[AppDelegate] Window %d: %@, canBecomeMain: %d, isVisible: %d, title: '%@'", index, String(describing: type(of: window)), window.canBecomeMain ? 1 : 0, window.isVisible ? 1 : 0, window.title)
        }

        // Try to show ANY window first
        var foundWindow = false
        for window in NSApp.windows {
            if !(window is NonActivatingFloatingWindow) &&
               !(window is RealtimeCaptionsWindow) &&
               window.className.contains("SwiftUI") {
                NSLog("[AppDelegate] Making SwiftUI window key and front: %@", window)
                window.makeKeyAndOrderFront(nil)
                foundWindow = true
                break
            }
        }

        if !foundWindow {
            // Fallback: show first window that can become main
            for window in NSApp.windows {
                if window.canBecomeMain &&
                   !(window is NonActivatingFloatingWindow) &&
                   !(window is RealtimeCaptionsWindow) {
                    NSLog("[AppDelegate] Making window key and front (fallback): %@", window)
                    window.makeKeyAndOrderFront(nil)
                    break
                }
            }
        }
    }

    /// Hide main window (app stays in dock)
    func hideMainWindow() {
        for window in NSApp.windows {
            if window.canBecomeMain &&
               !(window is NonActivatingFloatingWindow) &&
               !(window is RealtimeCaptionsWindow) {
                window.orderOut(nil)
            }
        }
    }

    // MARK: - Floating Window Management

    func showFloatingWindow(with view: some View) {
        if floatingWindow == nil {
            createFloatingWindow()
        }

        floatingWindow?.contentView = NSHostingView(rootView: view)
        floatingWindow?.orderFrontRegardless()
    }

    func hideFloatingWindow() {
        floatingWindow?.orderOut(nil)
    }

    private func createFloatingWindow() {
        let window = NonActivatingFloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        window.isMovableByWindowBackground = true

        // Position in top-center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 150
            let y = screenFrame.maxY - 100
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        floatingWindow = window
    }

    // MARK: - Captions Window Management

    @MainActor
    func showCaptionsWindow() {
        guard let appState = appState else {
            NSLog("[AppDelegate] Cannot show captions window: appState is nil")
            return
        }

        // Only show if captions are enabled
        guard appState.settings.captionsSettings.enabled else { return }

        captionsWindowController?.setup(with: appState)
        captionsWindowController?.showCaptions()
    }

    @MainActor
    func hideCaptionsWindow() {
        captionsWindowController?.hideCaptions()
    }

    @MainActor
    func updateCaptionsPosition() {
        captionsWindowController?.updatePosition()
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowFloatingWindow),
            name: .showFloatingWindow,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHideFloatingWindow),
            name: .hideFloatingWindow,
            object: nil
        )

        // Focus Mode notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowFocusModeWindow),
            name: .showFocusModeWindow,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHideFocusModeWindow),
            name: .hideFocusModeWindow,
            object: nil
        )

        // Captions notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowCaptionsWindow),
            name: .showCaptionsWindow,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHideCaptionsWindow),
            name: .hideCaptionsWindow,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdateCaptionsPosition),
            name: .updateCaptionsPosition,
            object: nil
        )
    }

    @objc private func handleShowFloatingWindow(_ notification: Notification) {
        guard let appState = appState else {
            print("[AppDelegate] Cannot show floating window: appState is nil")
            return
        }

        let floatingView = FloatingRecordingWindow()
            .environmentObject(appState)

        showFloatingWindow(with: floatingView)
    }

    @objc private func handleHideFloatingWindow(_ notification: Notification) {
        hideFloatingWindow()
    }

    // MARK: - Focus Mode Window Management

    @objc private func handleShowFocusModeWindow(_ notification: Notification) {
        showFocusModeWindow()
    }

    @objc private func handleHideFocusModeWindow(_ notification: Notification) {
        hideFocusModeWindow()
    }

    func showFocusModeWindow() {
        guard let appState = appState else {
            print("[AppDelegate] Cannot show focus mode window: appState is nil")
            return
        }

        // Create window if needed
        if focusModeWindow == nil {
            focusModeWindow = FocusModeWindow.create()
        }

        // Set up the content view
        let focusModeView = FocusModeView()
            .environmentObject(appState)

        focusModeWindow?.setContent(focusModeView)

        // Show full screen
        focusModeWindow?.showFullScreen()
    }

    func hideFocusModeWindow() {
        focusModeWindow?.hideAndExitFullScreen {
            // Window is now hidden
        }
    }

    // MARK: - Captions Window Handlers

    @objc private func handleShowCaptionsWindow(_ notification: Notification) {
        Task { @MainActor in
            showCaptionsWindow()
        }
    }

    @objc private func handleHideCaptionsWindow(_ notification: Notification) {
        Task { @MainActor in
            hideCaptionsWindow()
        }
    }

    @objc private func handleUpdateCaptionsPosition(_ notification: Notification) {
        Task { @MainActor in
            updateCaptionsPosition()
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let showFloatingWindow = Notification.Name("showFloatingWindow")
    static let hideFloatingWindow = Notification.Name("hideFloatingWindow")
    static let recordingStarted = Notification.Name("recordingStarted")
    static let recordingStopped = Notification.Name("recordingStopped")
    static let transcriptionCompleted = Notification.Name("transcriptionCompleted")
}

// MARK: - Non-Activating Floating Window
/// Custom NSWindow subclass that cannot become key or main window
/// This prevents the floating window from stealing focus from the user's active app
class NonActivatingFloatingWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
