import AppKit

/// Extensions for NSWindow to support floating window behavior
extension NSWindow {
    /// Configure window as a floating overlay
    func configureAsFloatingWindow() {
        // Window level
        level = .floating

        // Appearance
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Behavior
        collectionBehavior = [.canJoinAllSpaces, .transient]
        isMovableByWindowBackground = true

        // Don't show in Mission Control or dock
        styleMask = [.borderless]
    }

    /// Position window at top center of main screen
    func positionAtTopCenter(offset: CGFloat = 100) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowFrame = frame

        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.maxY - offset

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Position window at bottom right of main screen
    func positionAtBottomRight(padding: CGFloat = 20) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowFrame = frame

        let x = screenFrame.maxX - windowFrame.width - padding
        let y = screenFrame.minY + padding

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Animate window fade in
    func fadeIn(duration: TimeInterval = 0.2) {
        alphaValue = 0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            animator().alphaValue = 1
        }
    }

    /// Animate window fade out
    func fadeOut(duration: TimeInterval = 0.2, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            animator().alphaValue = 0
        } completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
            completion?()
        }
    }
}

// MARK: - Window Level Helpers
extension NSWindow.Level {
    /// Level for floating recording window
    static let recordingOverlay = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)

    /// Level for always-on-top windows
    static let alwaysOnTop = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)))
}
