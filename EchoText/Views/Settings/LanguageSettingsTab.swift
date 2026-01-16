import SwiftUI

/// Language settings tab
struct LanguageSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Transcription Language")
                    .font(.headline)

                Spacer()

                if appState.settings.selectedLanguage != "auto" {
                    Button("Reset to Auto-detect") {
                        appState.settings.selectedLanguage = "auto"
                    }
                    .buttonStyle(.link)
                }
            }
            .padding()

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search languages...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)

            // Language list
            List(selection: Binding(
                get: { appState.settings.selectedLanguage },
                set: { appState.settings.selectedLanguage = $0 }
            )) {
                ForEach(filteredLanguages) { language in
                    LanguageRow(
                        language: language,
                        isSelected: language.code == appState.settings.selectedLanguage
                    )
                    .tag(language.code)
                }
            }
            .listStyle(.inset)
        }
    }

    private var filteredLanguages: [SupportedLanguage] {
        if searchText.isEmpty {
            return SupportedLanguage.allLanguages
        }

        let query = searchText.lowercased()
        return SupportedLanguage.allLanguages.filter { language in
            language.name.lowercased().contains(query) ||
            language.nativeName.lowercased().contains(query) ||
            language.code.lowercased().contains(query)
        }
    }
}

// MARK: - Language Row

struct LanguageRow: View {
    let language: SupportedLanguage
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(language.name)
                    .font(.body)

                if language.nativeName != language.name && language.code != "auto" {
                    Text(language.nativeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if language.code == "auto" {
                Text("Recommended")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Preview
#Preview {
    LanguageSettingsTab()
        .environmentObject(AppState())
        .frame(width: 500, height: 400)
}
