import SwiftUI

/// Bottom customization panel for Focus Mode
struct FocusModeCustomizationPanel: View {
    @Binding var settings: FocusModeSettings
    @Binding var isVisible: Bool

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Toggle button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isVisible.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isVisible ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Customize")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isVisible {
                panelContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var panelContent: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 24) {
                // Theme section
                themeSection

                Divider()
                    .frame(height: 60)
                    .background(Color.white.opacity(0.1))

                // Font section
                fontSection

                Divider()
                    .frame(height: 60)
                    .background(Color.white.opacity(0.1))

                // Size section
                sizeSection

                Divider()
                    .frame(height: 60)
                    .background(Color.white.opacity(0.1))

                // Display options
                displaySection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THEME")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.5)

            HStack(spacing: 8) {
                ForEach(FocusModeTheme.allCases) { theme in
                    ThemePickerItem(
                        theme: theme,
                        isSelected: settings.theme == theme
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            settings.theme = theme
                        }
                    }
                }
            }
        }
    }

    // MARK: - Font Section

    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FONT")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.5)

            HStack(spacing: 6) {
                ForEach(FocusModeFont.allCases) { font in
                    FontPickerItem(
                        font: font,
                        isSelected: settings.font == font
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            settings.font = font
                        }
                    }
                }
            }
        }
    }

    // MARK: - Size Section

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SIZE")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.5)

            HStack(spacing: 12) {
                FocusModeSlider(
                    label: "Font",
                    value: $settings.fontSize,
                    range: FocusModeSettings.minFontSize...FocusModeSettings.maxFontSize,
                    step: 2,
                    format: "%.0fpx"
                )

                FocusModeSlider(
                    label: "Line Height",
                    value: $settings.lineHeight,
                    range: FocusModeSettings.minLineHeight...FocusModeSettings.maxLineHeight,
                    step: 0.1,
                    format: "%.1f"
                )
            }
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DISPLAY")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.5)

            HStack(spacing: 12) {
                Toggle(isOn: $settings.showWordCount) {
                    Label("Words", systemImage: "textformat.123")
                }
                .toggleStyle(FocusModeToggleStyle())

                Toggle(isOn: $settings.showDuration) {
                    Label("Time", systemImage: "clock")
                }
                .toggleStyle(FocusModeToggleStyle())

                Toggle(isOn: $settings.showHints) {
                    Label("Hints", systemImage: "questionmark.circle")
                }
                .toggleStyle(FocusModeToggleStyle())
            }
        }
    }
}

// MARK: - Custom Toggle Style

struct FocusModeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                configuration.label
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(configuration.isOn ? .white : .white.opacity(0.5))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isOn ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(hex: "0C0A3E")
            .ignoresSafeArea()

        VStack {
            Spacer()
            FocusModeCustomizationPanel(
                settings: .constant(FocusModeSettings()),
                isVisible: .constant(true)
            )
            .padding()
        }
    }
}
