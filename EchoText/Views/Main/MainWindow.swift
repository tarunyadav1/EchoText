import SwiftUI

/// Main window with proper Liquid Glass navigation (macOS 26+)
struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var licenseService = LicenseService.shared
    @State private var selectedTab: SidebarTab = .home
    @State private var selectedContentTab: ContentTab = .dictation
    @State private var emptyStateWaveAnimation = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var showClearHistoryConfirmation: Bool = false
    @StateObject private var fileTranscriptionVM: FileTranscriptionViewModel
    @StateObject private var batchTranscriptionVM: BatchTranscriptionViewModel

    init() {
        // Initialize with a temporary AppState - will be replaced by environment
        let tempAppState = AppState()
        _fileTranscriptionVM = StateObject(wrappedValue: FileTranscriptionViewModel(appState: tempAppState))
        _batchTranscriptionVM = StateObject(wrappedValue: BatchTranscriptionViewModel(appState: tempAppState))
    }

    enum SidebarTab: String, CaseIterable, Identifiable {
        case home = "Home"
        case history = "History"
        case feedback = "Feedback"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house"
            case .history: return "clock.arrow.circlepath"
            case .feedback: return "bubble.left"
            case .settings: return "gearshape"
            }
        }

        var selectedIcon: String {
            switch self {
            case .home: return "house.fill"
            case .history: return "clock.arrow.circlepath"
            case .feedback: return "bubble.left.fill"
            case .settings: return "gearshape.fill"
            }
        }

        static var mainTabs: [SidebarTab] { [.home, .history] }
        static var bottomTabs: [SidebarTab] { [.feedback, .settings] }
    }

    enum ContentTab: String, CaseIterable {
        case dictation = "Dictation"
        case links = "Links"
        case files = "Files"
        case batch = "Batch"
        case meetings = "Meetings"
    }

    var body: some View {
        Group {
            // Show license gate if not licensed
            if !licenseService.licenseState.isValid {
                LicenseGateView()
            } else {
                // Main app content (only shown when licensed)
                mainAppContent
            }
        }
    }

    // MARK: - Main App Content (Licensed Users Only)

    private var mainAppContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar with Liquid Glass navigation
            sidebarContent
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
                .background(.regularMaterial)
        } detail: {
            // Main content
            detailContent
        }
        .navigationSplitViewStyle(.prominentDetail)
        .frame(minWidth: 900, minHeight: 620)
        .sheet(isPresented: $appState.showOnboarding) {
            OnboardingView(viewModel: OnboardingViewModel(appState: appState))
                .frame(width: 600, height: 600)
        }
        .alert("Error", isPresented: $appState.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred")
        }
        .overlay(alignment: .top) {
            if appState.showSuccessToast {
                successToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(duration: 0.4), value: appState.showSuccessToast)
                    .padding(.top, 60)
            }
        }
    }

    // MARK: - Success Toast

    private var successToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.green)

            Text(appState.successToastMessage)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
    }

    // MARK: - Sidebar Content (Liquid Glass Navigation Layer)

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top spacing
            Spacer()
                .frame(height: 12)

            // Navigation items with glass effect
            GlassEffectContainer {
                VStack(spacing: 2) {
                    ForEach(SidebarTab.mainTabs) { tab in
                        sidebarButton(tab)
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Bottom section
            GlassEffectContainer {
                VStack(spacing: 2) {
                    sidebarButton(.feedback)

                    sidebarButton(.settings)

                    Link(destination: URL(string: "https://echotext.app/support")!) {
                        HStack(spacing: 10) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 15))
                                .frame(width: 20)
                            Text("Help & Support")
                                .font(.system(size: 13))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
    }

    private func sidebarButton(_ tab: SidebarTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 15, weight: selectedTab == tab ? .medium : .regular))
                    .frame(width: 20)
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: selectedTab == tab ? .medium : .regular))
                Spacer()
            }
            .foregroundColor(selectedTab == tab ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                selectedTab == tab
                    ? Color.primary.opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .shadow(
                color: selectedTab == tab ? Color.black.opacity(0.06) : Color.clear,
                radius: 3,
                y: 1
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .home:
            VStack(spacing: 0) {
                // Header toolbar with glass tabs
                headerToolbar

                // Content based on selected content tab
                if selectedContentTab == .dictation {
                    // Scrollable dictation content
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            headerSection
                            quickActionCard
                            focusModeCard

                            if appState.isRecording || appState.isProcessing {
                                recordingStatusCard
                            }

                            recentActivitySection
                        }
                        .padding(28)
                    }
                } else if selectedContentTab == .links {
                    // Links tab content
                    LinkTranscriptionTab(viewModel: fileTranscriptionVM)
                        .onAppear {
                            fileTranscriptionVM.appState = appState
                        }
                } else if selectedContentTab == .files {
                    // Files tab content
                    FileTranscriptionTab(viewModel: fileTranscriptionVM)
                        .onAppear {
                            fileTranscriptionVM.appState = appState
                        }
                } else if selectedContentTab == .batch {
                    // Batch transcription tab content
                    BatchTranscriptionView(viewModel: batchTranscriptionVM)
                        .onAppear {
                            batchTranscriptionVM.configure(appState: appState)
                        }
                } else if selectedContentTab == .meetings {
                    // Meetings tab content
                    MeetingTranscriptionView(
                        whisperService: appState.whisperService,
                        parakeetService: appState.parakeetService,
                        diarizationService: appState.diarizationService
                    )
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))

        case .history:
            HistoryView()

        case .feedback:
            EmbeddedFeedbackView()

        case .settings:
            SettingsView()
                .environmentObject(appState)
        }
    }

    // MARK: - Header Toolbar

    private var headerToolbar: some View {
        HStack(spacing: 16) {
            // Tab pills with glass effect
            HStack(spacing: 2) {
                ForEach(ContentTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedContentTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selectedContentTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedContentTab == tab ? .primary : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(
                        selectedContentTab == tab
                            ? Color.primary.opacity(0.08)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
            }
            .padding(4)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))

            Spacer()

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                if isSearching {
                    TextField("Search transcriptions...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .frame(width: 180)

                    Button {
                        searchText = ""
                        isSearching = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        isSearching = true
                    } label: {
                        Text("Search")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Content Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Welcome back")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("Ready to transcribe your voice")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    private var quickActionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "F9564F"), Color(hex: "B33F62")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Voice dictation in any app")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Speak naturally and watch your words appear")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("Press")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("⌃ Space")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))

                Text("to start")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Button {
                appState.handleAction(.toggle)
            } label: {
                Text("Try it now")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "F9564F"), Color(hex: "E84840")],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private var focusModeCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "7B1E7A"), Color(hex: "0C0A3E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Mode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Distraction-free full-screen transcription")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("Press")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("\u{2318}\u{21E7}F")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))

                Text("to start")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Button {
                appState.handleAction(.enterFocusMode)
            } label: {
                Text("Enter")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "7B1E7A"), Color(hex: "5A1259")],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private var recordingStatusCard: some View {
        HStack(spacing: 12) {
            ZStack {
                if appState.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 46, height: 46)
                        .scaleEffect(1.0 + CGFloat(appState.audioLevel) * 0.3)
                        .animation(.easeOut(duration: 0.1), value: appState.audioLevel)
                }

                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(appState.isProcessing ? Color.orange : Color.red, in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.isRecording ? "Recording..." : "Processing...")
                    .font(.system(size: 14, weight: .semibold))

                if appState.isRecording {
                    Text(appState.formattedDuration)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.red)
                } else {
                    Text("Transcribing...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if appState.isRecording {
                Button {
                    appState.handleAction(.stop)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.red, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent activity")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Spacer()

                if !appState.transcriptionHistory.isEmpty {
                    Button("Clear") {
                        showClearHistoryConfirmation = true
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .confirmationDialog(
                        "Clear Recent Activity",
                        isPresented: $showClearHistoryConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Clear All", role: .destructive) {
                            withAnimation {
                                appState.transcriptionHistory.removeAll()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will remove all recent transcription results. This action cannot be undone.")
                    }
                }
            }

            if appState.transcriptionHistory.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.transcriptionHistory.prefix(10)) { result in
                        TranscriptionRowView(result: result)
                        if result.id != appState.transcriptionHistory.prefix(10).last?.id {
                            Divider().padding(.horizontal, 14)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "F9564F"), Color(hex: "F3C677")],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 3, height: waveBarHeight(for: i))
                        .animation(
                            Animation.easeInOut(duration: 0.5 + Double(i) * 0.1)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.1),
                            value: emptyStateWaveAnimation
                        )
                }
            }
            .frame(width: 40, height: 32)
            .padding(16)
            .background(Color.primary.opacity(0.04), in: Circle())
            .onAppear { emptyStateWaveAnimation = true }

            VStack(spacing: 4) {
                Text("Your words will live here")
                    .font(.system(size: 14, weight: .semibold))

                HStack(spacing: 3) {
                    Text("Press")
                    Text("⌃ Space")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
                    Text("anywhere to start")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }

            Button {
                appState.handleAction(.toggle)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11))
                    Text("Say your first words")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(hex: "F9564F"), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private func waveBarHeight(for i: Int) -> CGFloat {
        let base: [CGFloat] = [12, 20, 28, 20, 12]
        let anim: [CGFloat] = [20, 28, 16, 32, 24]
        return emptyStateWaveAnimation ? anim[i] : base[i]
    }
}

// MARK: - Transcription Row

struct TranscriptionRowView: View {
    let result: TranscriptionResult
    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(formatTime(result.timestamp))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(result.text)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result.text, forType: .string)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopied = false }
            } label: {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: showCopied ? .bold : .regular))
                    .foregroundColor(showCopied ? .green : .secondary)
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.05), in: Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered || showCopied ? 1 : 0.3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isHovered ? Color.primary.opacity(0.02) : Color.clear)
        .onHover { isHovered = $0 }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f.string(from: date)
    }
}

#Preview {
    MainWindow()
        .environmentObject(AppState())
}
