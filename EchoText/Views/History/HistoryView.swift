import SwiftUI

/// Main history view showing all past transcriptions
struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showDeleteConfirmation = false
    @State private var showClearAllConfirmation = false
    @State private var itemToDelete: TranscriptionHistoryItem?

    var body: some View {
        Group {
            if let selectedItem = viewModel.selectedItem {
                // Full-screen detail view (replaces list)
                HistoryDetailView(
                    item: selectedItem,
                    onSave: { updatedItem in
                        viewModel.updateItem(updatedItem)
                    },
                    onDelete: {
                        viewModel.delete(selectedItem)
                        viewModel.selectedItem = nil
                    },
                    onDismiss: {
                        viewModel.selectedItem = nil
                    },
                    onSaveSpeakerMapping: { newMapping in
                        viewModel.updateSpeakerMapping(selectedItem, newMapping: newMapping)
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                // History list view
                listContent
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedItem != nil)
        .alert("Delete Transcription?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    viewModel.delete(item)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Clear All History?", isPresented: $showClearAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                viewModel.clearAll()
            }
        } message: {
            Text("This will permanently delete all \(viewModel.historyItems.count) transcriptions. This action cannot be undone.")
        }
    }

    // MARK: - List Content

    private var listContent: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            historyHeader

            // Content
            if viewModel.isEmpty {
                emptyState
            } else if viewModel.filteredItems.isEmpty && viewModel.isFiltered {
                noResultsState
            } else {
                historyList
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var historyHeader: some View {
        VStack(spacing: 12) {
            HStack {
                // Title and stats
                VStack(alignment: .leading, spacing: 2) {
                    Text("History")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    if let stats = viewModel.statistics {
                        Text("\(stats.totalTranscriptions) transcriptions \u{2022} \(stats.totalWords) words")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Action buttons
                if viewModel.isSelectionMode {
                    selectionActions
                } else {
                    regularActions
                }
            }

            HStack(spacing: 12) {
                // Search field
                searchField

                // Advanced search toggle
                advancedSearchToggle

                // Filter pills
                filterPills
            }

            // Advanced search panel (collapsible)
            if viewModel.showAdvancedSearch {
                advancedSearchPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showAdvancedSearch)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            TextField("Search transcriptions...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: 300)
    }

    private var filterPills: some View {
        HStack(spacing: 4) {
            ForEach(HistoryViewModel.HistoryFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedFilter = filter
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 10))
                        Text(filter.rawValue)
                            .font(.system(size: 11, weight: viewModel.selectedFilter == filter ? .semibold : .regular))
                    }
                    .foregroundColor(viewModel.selectedFilter == filter ? .primary : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        viewModel.selectedFilter == filter
                            ? Color.primary.opacity(0.08)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(4)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private var advancedSearchToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.showAdvancedSearch.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12))
                if viewModel.activeFilterCount > 0 {
                    Text("\(viewModel.activeFilterCount)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.accent, in: Capsule())
                }
            }
            .foregroundColor(viewModel.showAdvancedSearch ? DesignSystem.Colors.accent : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                viewModel.showAdvancedSearch
                    ? DesignSystem.Colors.accent.opacity(0.1)
                    : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help("Advanced Search Options")
    }

    private var advancedSearchPanel: some View {
        VStack(spacing: 12) {
            // Date range presets
            HStack(spacing: 8) {
                Text("Date:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                ForEach(HistoryViewModel.DateRangePreset.allCases, id: \.self) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.dateRangePreset = preset
                        }
                    } label: {
                        Text(preset.rawValue)
                            .font(.system(size: 11, weight: viewModel.dateRangePreset == preset ? .semibold : .regular))
                            .foregroundColor(viewModel.dateRangePreset == preset ? .primary : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                viewModel.dateRangePreset == preset
                                    ? DesignSystem.Colors.accent.opacity(0.15)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()
            }

            // Custom date pickers (show when custom is selected)
            if viewModel.dateRangePreset == .custom {
                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Text("From:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { viewModel.startDate ?? Date() },
                                set: { viewModel.startDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    }

                    HStack(spacing: 8) {
                        Text("To:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { viewModel.endDate ?? Date() },
                                set: { viewModel.endDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    }

                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Sort options
            HStack(spacing: 8) {
                Text("Sort:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Menu {
                    ForEach(HistoryViewModel.SortOption.allCases, id: \.self) { option in
                        Button {
                            viewModel.sortOption = option
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                Text(option.rawValue)
                                if viewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.sortOption.icon)
                            .font(.system(size: 10))
                        Text(viewModel.sortOption.rawValue)
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)

                Spacer()

                // Clear all filters button
                if viewModel.isFiltered {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.clearFilters()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Clear All")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var regularActions: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.isSelectionMode = true
            } label: {
                Label("Select", systemImage: "checkmark.circle")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            if !viewModel.isEmpty {
                Button {
                    showClearAllConfirmation = true
                } label: {
                    Label("Clear All", systemImage: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
    }

    private var selectionActions: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.selectionCount) selected")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Button {
                viewModel.selectAll()
            } label: {
                Text("Select All")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            if viewModel.hasSelection {
                Button {
                    viewModel.deleteSelected()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }

            Button {
                viewModel.clearSelection()
            } label: {
                Text("Done")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
    }

    // MARK: - History List

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(viewModel.groupedHistory, id: \.date) { group in
                    Section {
                        ForEach(group.items) { item in
                            HistoryItemRow(
                                item: item,
                                searchQuery: viewModel.searchText,
                                matchRanges: viewModel.getMatchRanges(for: item),
                                isSelectionMode: viewModel.isSelectionMode,
                                isSelected: viewModel.selectedItems.contains(item.id),
                                onSelect: { viewModel.toggleSelection(item) },
                                onFavorite: { viewModel.toggleFavorite(item) },
                                onCopy: { viewModel.copyToClipboard(item) },
                                onDelete: {
                                    itemToDelete = item
                                    showDeleteConfirmation = true
                                },
                                onTap: {
                                    viewModel.selectedItem = item
                                }
                            )

                            if item.id != group.items.last?.id {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    } header: {
                        dateHeader(for: group.date)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func dateHeader(for date: Date) -> some View {
        HStack {
            Text(formatDateHeader(date))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: 4) {
                Text("No transcriptions yet")
                    .font(.system(size: 16, weight: .semibold))

                Text("Your voice transcriptions will appear here")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: 4) {
                Text("No results found")
                    .font(.system(size: 16, weight: .semibold))

                Text("Try adjusting your search or filters")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.clearFilters()
                }
            } label: {
                Text("Clear filters")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    let item: TranscriptionHistoryItem
    let searchQuery: String
    let matchRanges: [Range<String.Index>]
    let isSelectionMode: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onFavorite: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Selection checkbox
            if isSelectionMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }

            // Source icon
            Image(systemName: item.source.icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.relativeTimestamp)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                    }

                    Text("\u{2022} \(item.wordCount) words")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text("\u{2022} \(item.formattedDuration)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // Preview text with highlighting
                Text(highlightedPreview)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions
            if !isSelectionMode {
                HStack(spacing: 4) {
                    Button(action: onFavorite) {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundColor(item.isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered || item.isFavorite ? 1 : 0)

                    Button {
                        onCopy()
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    } label: {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(showCopied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered || showCopied ? 1 : 0.3)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered ? 1 : 0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onSelect()
            } else {
                onTap()
            }
        }
        .onHover { isHovered = $0 }
    }

    /// Creates an AttributedString with highlighted search matches
    private var highlightedPreview: AttributedString {
        let previewText = item.preview

        // If no search query, return plain text
        guard !searchQuery.isEmpty else {
            return AttributedString(previewText)
        }

        var attributedString = AttributedString(previewText)

        // Find all occurrences of search terms and highlight them
        let searchTerms = searchQuery.lowercased().split(separator: " ").map(String.init)

        for term in searchTerms {
            var searchStartIndex = previewText.startIndex

            while let range = previewText.range(
                of: term,
                options: .caseInsensitive,
                range: searchStartIndex..<previewText.endIndex
            ) {
                // Convert String.Index range to AttributedString range
                if let attrRange = Range(NSRange(range, in: previewText), in: attributedString) {
                    attributedString[attrRange].backgroundColor = DesignSystem.Colors.accent.opacity(0.3)
                    attributedString[attrRange].foregroundColor = DesignSystem.Colors.accent
                }

                // Move past this match
                searchStartIndex = range.upperBound
            }
        }

        return attributedString
    }
}

#Preview {
    HistoryView()
        .frame(width: 700, height: 600)
}
