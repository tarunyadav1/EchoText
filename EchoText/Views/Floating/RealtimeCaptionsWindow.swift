import SwiftUI
import AppKit

/// Floating window for displaying realtime captions overlay
/// Stays on top of all apps and auto-hides when not recording
class RealtimeCaptionsWindow: NSWindow {
    private var appState: AppState?
    private var savedCustomPosition: NSPoint?

    // MARK: - Factory Method

    static func create() -> RealtimeCaptionsWindow {
        let window = RealtimeCaptionsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window properties
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.ignoresMouseEvents = false

        // Initial position
        window.positionAtDefaultLocation()

        return window
    }

    // MARK: - Window Behavior

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Content Management

    func setContent(_ view: some View) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    func updateContent(with appState: AppState) {
        self.appState = appState

        let captionsView = CompactCaptionsView()
            .environmentObject(appState)

        setContent(captionsView)
    }

    // MARK: - Positioning

    func positionAtDefaultLocation() {
        guard let screen = NSScreen.main else { return }
        positionForSettings(CaptionsSettings(), on: screen)
    }

    func positionForSettings(_ settings: CaptionsSettings, on screen: NSScreen? = nil) {
        guard let screen = screen ?? NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowWidth: CGFloat = 600
        let windowHeight: CGFloat = 120

        var x: CGFloat
        var y: CGFloat

        switch settings.position {
        case .bottomCenter:
            x = screenFrame.midX - windowWidth / 2
            y = screenFrame.minY + 60

        case .topCenter:
            x = screenFrame.midX - windowWidth / 2
            y = screenFrame.maxY - windowHeight - 60

        case .custom:
            // Use saved custom position or default to bottom center
            if let savedPosition = savedCustomPosition {
                x = savedPosition.x
                y = savedPosition.y
            } else {
                x = screenFrame.midX - windowWidth / 2 + settings.customOffsetX
                y = screenFrame.minY + settings.customOffsetY
            }
        }

        // Ensure window stays within screen bounds
        x = max(screenFrame.minX, min(x, screenFrame.maxX - windowWidth))
        y = max(screenFrame.minY, min(y, screenFrame.maxY - windowHeight))

        setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
    }

    func saveCustomPosition() {
        savedCustomPosition = frame.origin
    }

    // MARK: - Show/Hide

    func showCaptions() {
        // Apply current position settings
        if let appState = appState {
            positionForSettings(appState.settings.captionsSettings)
        } else {
            positionAtDefaultLocation()
        }

        // Fade in
        alphaValue = 0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
    }

    func hideCaptions(completion: (() -> Void)? = nil) {
        // Save position if custom
        if appState?.settings.captionsSettings.position == .custom {
            saveCustomPosition()
        }

        // Fade out
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.orderOut(nil)
            completion?()
        }
    }

    // MARK: - Mouse Handling for Dragging

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)

        // When dragged, switch to custom position mode
        if let appState = appState, appState.settings.captionsSettings.position != .custom {
            appState.settings.captionsSettings.position = .custom
        }

        // Save the custom position
        saveCustomPosition()
    }
}

// MARK: - Captions Window Controller

/// Controller for managing the captions window lifecycle
@MainActor
class CaptionsWindowController {
    private var captionsWindow: RealtimeCaptionsWindow?
    private weak var appState: AppState?

    init() {}

    func setup(with appState: AppState) {
        self.appState = appState
    }

    func showCaptions() {
        guard let appState = appState else {
            NSLog("[CaptionsWindowController] Cannot show captions: appState is nil")
            return
        }

        // Only show if captions are enabled
        guard appState.settings.captionsSettings.enabled else { return }

        // Create window if needed
        if captionsWindow == nil {
            captionsWindow = RealtimeCaptionsWindow.create()
        }

        // Update content and show
        captionsWindow?.updateContent(with: appState)
        captionsWindow?.showCaptions()

        NSLog("[CaptionsWindowController] Showing captions window")
    }

    func hideCaptions() {
        captionsWindow?.hideCaptions()
        NSLog("[CaptionsWindowController] Hiding captions window")
    }

    func updatePosition() {
        guard let appState = appState else { return }
        captionsWindow?.positionForSettings(appState.settings.captionsSettings)
    }

    var isVisible: Bool {
        captionsWindow?.isVisible ?? false
    }
}

// MARK: - Notification Names for Captions

extension Notification.Name {
    static let showCaptionsWindow = Notification.Name("showCaptionsWindow")
    static let hideCaptionsWindow = Notification.Name("hideCaptionsWindow")
    static let updateCaptionsPosition = Notification.Name("updateCaptionsPosition")
}
