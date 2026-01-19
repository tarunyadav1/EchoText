import Foundation
import AVFoundation
import AppKit

/// Permission states
enum PermissionStatus {
    case notDetermined
    case granted
    case denied

    var isGranted: Bool {
        self == .granted
    }

    var displayText: String {
        switch self {
        case .notDetermined:
            return "Not Requested"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        }
    }

    var systemImageName: String {
        switch self {
        case .notDetermined:
            return "questionmark.circle"
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        }
    }
}

/// Service responsible for managing system permissions
@MainActor
final class PermissionService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var microphoneStatus: PermissionStatus = .notDetermined
    @Published private(set) var accessibilityStatus: PermissionStatus = .notDetermined

    // MARK: - Private Properties
    private var accessibilityCheckTimer: Timer?

    // MARK: - Computed Properties
    var allPermissionsGranted: Bool {
        microphoneStatus.isGranted && accessibilityStatus.isGranted
    }

    var requiredPermissionsGranted: Bool {
        microphoneStatus.isGranted // Accessibility is optional but recommended
    }

    // MARK: - Initialization
    init() {
        checkAllPermissions()
        startAccessibilityMonitoring()
    }

    deinit {
        accessibilityCheckTimer?.invalidate()
    }

    // MARK: - Accessibility Monitoring

    /// Start periodic monitoring for accessibility permission changes
    /// This is needed because macOS doesn't notify apps when permission is granted
    private func startAccessibilityMonitoring() {
        // Check every 2 seconds if accessibility status has changed
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAccessibilityPermission()
            }
        }
    }

    // MARK: - Public Methods

    /// Check all permission statuses
    func checkAllPermissions() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
    }

    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    self.microphoneStatus = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// Request accessibility permission (opens System Preferences)
    func requestAccessibilityPermission() {
        // Use takeUnretainedValue to avoid memory issues
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        accessibilityStatus = trusted ? .granted : .denied

        // If not trusted, open accessibility settings
        if !trusted {
            openAccessibilitySettings()
        }
    }

    /// Open System Preferences to Microphone settings
    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open System Preferences to Accessibility settings
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private Methods

    private func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            microphoneStatus = .notDetermined
        case .authorized:
            microphoneStatus = .granted
        case .denied, .restricted:
            microphoneStatus = .denied
        @unknown default:
            microphoneStatus = .notDetermined
        }
    }

    private func checkAccessibilityPermission() {
        let isTrusted = AXIsProcessTrusted()
        NSLog("[PermissionService] AXIsProcessTrusted() = %@", isTrusted ? "true" : "false")
        accessibilityStatus = isTrusted ? .granted : .denied
    }
}

// MARK: - Permission Request Flow
extension PermissionService {
    /// Sequentially request all required permissions
    func requestAllPermissions() async {
        // Request microphone first
        _ = await requestMicrophonePermission()

        // Then prompt for accessibility
        requestAccessibilityPermission()

        // Wait a moment and recheck
        try? await Task.sleep(nanoseconds: 500_000_000)
        checkAllPermissions()
    }
}
