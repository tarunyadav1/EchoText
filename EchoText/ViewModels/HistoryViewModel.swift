import Foundation
import SwiftUI
import Combine

/// ViewModel for the transcription history view
@MainActor
final class HistoryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var historyItems: [TranscriptionHistoryItem] = []
    @Published var filteredItems: [TranscriptionHistoryItem] = []
    @Published var searchText: String = ""
    @Published var selectedFilter: HistoryFilter = .all
    @Published var selectedItem: TranscriptionHistoryItem?
    @Published var isLoading: Bool = false
    @Published var statistics: HistoryStatistics?
    @Published var groupedHistory: [(date: Date, items: [TranscriptionHistoryItem])] = []

    // Selection for bulk operations
    @Published var selectedItems: Set<UUID> = []
    @Published var isSelectionMode: Bool = false

    // Advanced search properties
    @Published var sortOption: SortOption = .newestFirst
    @Published var startDate: Date? = nil
    @Published var endDate: Date? = nil
    @Published var showAdvancedSearch: Bool = false
    @Published var dateRangePreset: DateRangePreset = .allTime
    @Published var searchResultRanges: [UUID: [Range<String.Index>]] = [:]

    // MARK: - Dependencies
    private let historyService = TranscriptionHistoryService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Sort Options
    enum SortOption: String, CaseIterable {
        case newestFirst = "Newest First"
        case oldestFirst = "Oldest First"
        case longestFirst = "Longest First"
        case mostWords = "Most Words"

        var icon: String {
            switch self {
            case .newestFirst: return "arrow.down"
            case .oldestFirst: return "arrow.up"
            case .longestFirst: return "clock"
            case .mostWords: return "text.alignleft"
            }
        }
    }

    // MARK: - Date Range Presets
    enum DateRangePreset: String, CaseIterable {
        case allTime = "All Time"
        case today = "Today"
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case custom = "Custom"

        var icon: String {
            switch self {
            case .allTime: return "infinity"
            case .today: return "sun.max"
            case .last7Days: return "calendar.badge.clock"
            case .last30Days: return "calendar"
            case .custom: return "calendar.badge.plus"
            }
        }
    }

    // MARK: - Filter Options
    enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case dictation = "Dictation"
        case files = "Files"
        case meetings = "Meetings"
        case favorites = "Favorites"

        var icon: String {
            switch self {
            case .all: return "clock"
            case .dictation: return "mic.fill"
            case .files: return "doc.fill"
            case .meetings: return "person.2.fill"
            case .favorites: return "star.fill"
            }
        }
    }

    // MARK: - Initialization
    init() {
        setupBindings()
        loadHistory()
    }

    // MARK: - Public Methods

    /// Refresh history from disk
    func loadHistory() {
        isLoading = true

        historyItems = historyService.loadHistory()
        groupedHistory = historyService.getHistoryGroupedByDate()
        statistics = historyService.getStatistics()
        applyFilters()

        isLoading = false
    }

    /// Delete a single item
    func delete(_ item: TranscriptionHistoryItem) {
        historyService.delete(item)
        loadHistory()
    }

    /// Delete selected items
    func deleteSelected() {
        let itemsToDelete = historyItems.filter { selectedItems.contains($0.id) }
        historyService.delete(itemsToDelete)
        selectedItems.removeAll()
        isSelectionMode = false
        loadHistory()
    }

    /// Clear all history
    func clearAll() {
        historyService.clearAll()
        loadHistory()
    }

    /// Toggle favorite status
    func toggleFavorite(_ item: TranscriptionHistoryItem) {
        historyService.toggleFavorite(item)
        loadHistory()
    }

    /// Export a single item
    func export(_ item: TranscriptionHistoryItem, format: ExportFormat) async -> URL? {
        let result = item.toTranscriptionResult()
        return await ExportService.exportToFile(result, format: format)
    }

    /// Export multiple items
    func exportSelected(format: ExportFormat) async -> URL? {
        let results = historyItems
            .filter { selectedItems.contains($0.id) }
            .map { $0.toTranscriptionResult() }

        return await ExportService.exportBatch(results, format: format)
    }

    /// Copy text to clipboard
    func copyToClipboard(_ item: TranscriptionHistoryItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
    }

    /// Toggle selection for an item
    func toggleSelection(_ item: TranscriptionHistoryItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    /// Select all visible items
    func selectAll() {
        selectedItems = Set(filteredItems.map { $0.id })
    }

    /// Clear selection
    func clearSelection() {
        selectedItems.removeAll()
        isSelectionMode = false
    }

    /// Update text of an item (for editing)
    func updateText(_ item: TranscriptionHistoryItem, newText: String) {
        var updatedItem = item
        updatedItem.text = newText
        historyService.update(updatedItem)
        loadHistory()
    }

    /// Update an entire item (for segment editing)
    func updateItem(_ item: TranscriptionHistoryItem) {
        historyService.update(item)
        loadHistory()
    }

    /// Update speaker mapping of an item
    func updateSpeakerMapping(_ item: TranscriptionHistoryItem, newMapping: SpeakerMapping) {
        historyService.updateSpeakerMapping(newMapping, for: item.id)
        loadHistory()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // React to search text changes
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)

        // React to filter changes
        $selectedFilter
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)

        // React to sort option changes
        $sortOption
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)

        // React to date range changes
        $startDate
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)

        $endDate
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)

        // React to date range preset changes
        $dateRangePreset
            .sink { [weak self] preset in
                self?.applyDateRangePreset(preset)
            }
            .store(in: &cancellables)
    }

    private func applyDateRangePreset(_ preset: DateRangePreset) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch preset {
        case .allTime:
            startDate = nil
            endDate = nil
        case .today:
            startDate = today
            endDate = today
        case .last7Days:
            startDate = calendar.date(byAdding: .day, value: -6, to: today)
            endDate = today
        case .last30Days:
            startDate = calendar.date(byAdding: .day, value: -29, to: today)
            endDate = today
        case .custom:
            // Keep current dates for custom
            break
        }
    }

    private func applyFilters() {
        // Clear previous search result ranges
        searchResultRanges = [:]

        // Use advanced search if we have a search query or date filters
        if !searchText.isEmpty || startDate != nil || endDate != nil {
            let searchResults = historyService.advancedSearch(
                query: searchText,
                startDate: startDate,
                endDate: endDate
            )

            // Store match ranges for highlighting
            for result in searchResults {
                if !result.matchRanges.isEmpty {
                    searchResultRanges[result.item.id] = result.matchRanges
                }
            }

            // Extract items from search results
            var result = searchResults.map { $0.item }

            // Apply source filter
            result = applySourceFilter(to: result)

            // Apply sorting
            result = applySorting(to: result)

            filteredItems = result
        } else {
            // No search query or date filters - use all items
            var result = historyItems

            // Apply source filter
            result = applySourceFilter(to: result)

            // Apply sorting
            result = applySorting(to: result)

            filteredItems = result
        }

        // Update grouped history for display
        updateGroupedHistory()
    }

    private func applySourceFilter(to items: [TranscriptionHistoryItem]) -> [TranscriptionHistoryItem] {
        switch selectedFilter {
        case .all:
            return items
        case .dictation:
            return items.filter {
                if case .dictation = $0.source { return true }
                return false
            }
        case .files:
            return items.filter {
                if case .file = $0.source { return true }
                if case .url = $0.source { return true }
                return false
            }
        case .meetings:
            return items.filter {
                if case .meeting = $0.source { return true }
                return false
            }
        case .favorites:
            return items.filter { $0.isFavorite }
        }
    }

    private func applySorting(to items: [TranscriptionHistoryItem]) -> [TranscriptionHistoryItem] {
        switch sortOption {
        case .newestFirst:
            return items.sorted { $0.timestamp > $1.timestamp }
        case .oldestFirst:
            return items.sorted { $0.timestamp < $1.timestamp }
        case .longestFirst:
            return items.sorted { $0.duration > $1.duration }
        case .mostWords:
            return items.sorted { $0.wordCount > $1.wordCount }
        }
    }

    private func updateGroupedHistory() {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: filteredItems) { item in
            calendar.startOfDay(for: item.timestamp)
        }

        groupedHistory = grouped
            .map { (date: $0.key, items: $0.value) }
            .sorted { $0.date > $1.date }
    }

    /// Clear all filters and search
    func clearFilters() {
        searchText = ""
        selectedFilter = .all
        sortOption = .newestFirst
        dateRangePreset = .allTime
        startDate = nil
        endDate = nil
        showAdvancedSearch = false
    }

    /// Get match ranges for a specific item (for highlighting)
    func getMatchRanges(for item: TranscriptionHistoryItem) -> [Range<String.Index>] {
        return searchResultRanges[item.id] ?? []
    }
}


// MARK: - Computed Properties
extension HistoryViewModel {
    var hasSelection: Bool {
        !selectedItems.isEmpty
    }

    var selectionCount: Int {
        selectedItems.count
    }

    var isEmpty: Bool {
        historyItems.isEmpty
    }

    var isFiltered: Bool {
        !searchText.isEmpty || selectedFilter != .all || hasDateFilter || sortOption != .newestFirst
    }

    var hasDateFilter: Bool {
        startDate != nil || endDate != nil
    }

    var hasActiveSearch: Bool {
        !searchText.isEmpty
    }

    var activeFilterCount: Int {
        var count = 0
        if !searchText.isEmpty { count += 1 }
        if selectedFilter != .all { count += 1 }
        if hasDateFilter { count += 1 }
        if sortOption != .newestFirst { count += 1 }
        return count
    }
}
