import SwiftUI

/// License activation and management view
struct LicenseSettingsSection: View {
    @StateObject private var licenseService = LicenseService.shared
    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var showDeactivateConfirm = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Current Status
            currentStatusSection

            // Activation or Management based on state
            if licenseService.licenseState.isPro {
                licenseManagementSection
            } else {
                activationSection
            }

            // Pro Features List
            proFeaturesSection
        }
        .alert("Deactivate License?", isPresented: $showDeactivateConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                deactivateLicense()
            }
        } message: {
            Text("You can reactivate this license on another device or re-enter it here.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }

    // MARK: - Status Section

    private var currentStatusSection: some View {
        SettingsSection(title: "License Status") {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        statusIcon
                        Text(statusTitle)
                            .font(.system(size: 15, weight: .semibold))
                    }

                    Text(licenseService.licenseState.displayStatus)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    if let maskedKey = licenseService.maskedLicenseKey, licenseService.licenseState.isPro {
                        Text(maskedKey)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                Spacer()

                if licenseService.isValidating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
    }

    private var statusIcon: some View {
        Group {
            switch licenseService.licenseState {
            case .valid, .offlineGrace:
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
            case .validating:
                ProgressView()
                    .scaleEffect(0.7)
            case .unlicensed, .unknown:
                Image(systemName: "star.circle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 20))
            case .invalid, .expired:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 20))
            }
        }
    }

    private var statusTitle: String {
        switch licenseService.licenseState {
        case .valid, .offlineGrace:
            return "Pro License Active"
        case .validating:
            return "Validating..."
        case .unlicensed, .unknown:
            return "Free Version"
        case .invalid:
            return "License Invalid"
        case .expired:
            return "License Expired"
        }
    }

    // MARK: - Activation Section

    private var activationSection: some View {
        SettingsSection(title: "Activate License", footer: "Enter your license key from Gumroad to unlock Pro features.") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("License Key", text: $licenseKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onSubmit {
                        activateLicense()
                    }

                HStack {
                    Button {
                        activateLicense()
                    } label: {
                        HStack(spacing: 6) {
                            if isActivating {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text(isActivating ? "Activating..." : "Activate")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActivating)

                    Button("Buy License") {
                        NSWorkspace.shared.open(Constants.URLs.gumroadURL)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - License Management Section

    private var licenseManagementSection: some View {
        SettingsSection(title: "Manage License", footer: "Deactivate to transfer your license to another device.") {
            VStack(alignment: .leading, spacing: 12) {
                // License info
                if case .valid(let info) = licenseService.licenseState {
                    if let email = info.email {
                        HStack {
                            Text("Email")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(email)
                                .font(.system(size: 13))
                        }
                        SettingsDivider()
                    }

                    HStack {
                        Text("Activated")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(info.activatedAt))
                            .font(.system(size: 13))
                    }
                    SettingsDivider()
                }

                HStack {
                    Button {
                        Task {
                            await licenseService.verify()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(role: .destructive) {
                        showDeactivateConfirm = true
                    } label: {
                        Label("Deactivate", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Pro Features Section

    private var proFeaturesSection: some View {
        SettingsSection(title: "Pro Features", footer: licenseService.licenseState.isPro ? "All features unlocked" : "Upgrade to Pro to unlock these features") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(ProFeature.allCases.enumerated()), id: \.element) { index, feature in
                    HStack {
                        Image(systemName: licenseService.licenseState.isPro ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundColor(licenseService.licenseState.isPro ? .green : .secondary)
                            .font(.system(size: 14))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.displayName)
                                .font(.system(size: 14))
                            Text(feature.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)

                    if index < ProFeature.allCases.count - 1 {
                        SettingsDivider()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func activateLicense() {
        let key = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        isActivating = true

        Task {
            do {
                try await licenseService.activate(licenseKey: key)
                await MainActor.run {
                    isActivating = false
                    showSuccess = true
                    licenseKey = ""
                }
            } catch let error as LicenseError {
                await MainActor.run {
                    isActivating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isActivating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func deactivateLicense() {
        Task {
            do {
                try await licenseService.deactivate()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Standalone License Entry View (for onboarding or prompts)

struct LicenseEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var licenseService = LicenseService.shared
    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?

    var onComplete: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DesignSystem.Colors.accentGradient)

                Text("Unlock EchoText Pro")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))

                Text("Enter your license key to access all Pro features")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // License Key Input
            VStack(alignment: .leading, spacing: 8) {
                TextField("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", text: $licenseKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(12)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit {
                        activate()
                    }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // Buttons
            VStack(spacing: 12) {
                Button {
                    activate()
                } label: {
                    HStack {
                        if isActivating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isActivating ? "Activating..." : "Activate License")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActivating)

                HStack(spacing: 16) {
                    Button("Buy License") {
                        NSWorkspace.shared.open(Constants.URLs.gumroadURL)
                    }
                    .buttonStyle(.bordered)

                    Button("Continue Free") {
                        dismiss()
                        onComplete?()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }

            // Feature highlights
            VStack(alignment: .leading, spacing: 8) {
                Text("Pro includes:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: 6) {
                    featureRow("Large Whisper models for best accuracy")
                    featureRow("Unlimited recording time")
                    featureRow("Auto-insert into any app")
                    featureRow("Speaker diarization")
                    featureRow("Batch transcription & watch folders")
                }
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(width: 400)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(DesignSystem.Colors.accent)
                .font(.system(size: 12))
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func activate() {
        let key = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        isActivating = true
        errorMessage = nil

        Task {
            do {
                try await licenseService.activate(licenseKey: key)
                await MainActor.run {
                    isActivating = false
                    dismiss()
                    onComplete?()
                }
            } catch {
                await MainActor.run {
                    isActivating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Pro Badge Component

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DesignSystem.Colors.accentGradient, in: Capsule())
    }
}

// MARK: - Feature Lock Overlay

struct FeatureLockOverlay: View {
    let feature: ProFeature
    @State private var showLicenseSheet = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text(feature.displayName)
                .font(.headline)

            Text("This feature requires EchoText Pro")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Upgrade to Pro") {
                showLicenseSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showLicenseSheet) {
            LicenseEntryView()
        }
    }
}

// MARK: - Preview

#Preview("License Settings") {
    LicenseSettingsSection()
        .padding()
        .frame(width: 600)
}

#Preview("License Entry") {
    LicenseEntryView()
}
