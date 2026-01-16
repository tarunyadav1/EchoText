import Foundation
import AppKit
import SwiftUI

/// AppDelegate for system-level integration
class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: NSWindow?
    weak var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app as accessory - runs in menu bar only, doesn't show in dock
        // This prevents the main window from appearing during recording flow
        NSApp.setActivationPolicy(.accessory)

        // Setup notification observers
        setupNotificationObservers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        hideFloatingWindow()
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

        for window in NSApp.windows {
            if window.canBecomeMain && !(window is NonActivatingFloatingWindow) {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
    }

    /// Hide main window and return to accessory mode
    func hideMainWindow() {
        for window in NSApp.windows {
            if window.canBecomeMain && !(window is NonActivatingFloatingWindow) {
                window.orderOut(nil)
            }
        }
        // Return to accessory mode (menu bar only)
        NSApp.setActivationPolicy(.accessory)
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
