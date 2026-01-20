import Foundation
import Sparkle

/// Service for managing application updates using Sparkle
@MainActor
final class UpdateService: NSObject, ObservableObject, SPUUpdaterDelegate {
    /// Shared instance
    static let shared = UpdateService()

    /// The Sparkle updater controller
    private var updaterController: SPUStandardUpdaterController!

    /// Whether an update is currently being checked
    @Published var isCheckingForUpdates = false

    /// Whether an update is available
    @Published var updateAvailable = false

    /// The last check date
    @Published var lastCheckDate: Date?

    /// Whether automatic update checks are enabled
    var automaticUpdateChecks: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    /// Whether automatic downloads are enabled
    var automaticDownloads: Bool {
        get { updaterController.updater.automaticallyDownloadsUpdates }
        set { updaterController.updater.automaticallyDownloadsUpdates = newValue }
    }

    /// Update check interval in seconds (default: 1 day)
    var updateCheckInterval: TimeInterval {
        get { updaterController.updater.updateCheckInterval }
        set { updaterController.updater.updateCheckInterval = newValue }
    }

    /// Whether the updater can check for updates
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    private override init() {
        super.init()

        // Create the updater controller with self as delegate
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        // Set default update check interval to 1 day
        if updaterController.updater.updateCheckInterval == 0 {
            updaterController.updater.updateCheckInterval = 86400 // 24 hours
        }

        // Load last check date
        lastCheckDate = updaterController.updater.lastUpdateCheckDate
    }

    /// Check for updates interactively (shows UI)
    func checkForUpdates() {
        guard canCheckForUpdates else {
            NSLog("[UpdateService] Cannot check for updates right now")
            return
        }

        isCheckingForUpdates = true
        updaterController.checkForUpdates(nil)
    }

    /// Check for updates in the background (no UI unless update found)
    func checkForUpdatesInBackground() {
        guard canCheckForUpdates else { return }
        updaterController.updater.checkForUpdatesInBackground()
    }

    /// Get the current app version string
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// Get the current build number
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    /// Format the last check date for display
    var lastCheckDateFormatted: String {
        guard let date = lastCheckDate else {
            return "Never"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - SPUUpdaterDelegate

    nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        Task { @MainActor in
            self.isCheckingForUpdates = false
            self.lastCheckDate = updater.lastUpdateCheckDate

            if let error = error {
                NSLog("[UpdateService] Update check failed: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in
            self.updateAvailable = true
            NSLog("[UpdateService] Update available: \(item.displayVersionString)")
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: (any Error)?) {
        Task { @MainActor in
            self.updateAvailable = false
            self.isCheckingForUpdates = false
            self.lastCheckDate = updater.lastUpdateCheckDate
        }
    }
}
