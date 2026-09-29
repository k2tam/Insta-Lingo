import SwiftUI
import LookupCore
import Observation

enum LibraryTab: Hashable {
    case all
    case favorites
}

/// Which part of the library is showing. The windows controller owns it so the
/// panel's History and Favorites buttons can switch an already open window.
@MainActor @Observable
final class LibraryNavigation {
    var tab: LibraryTab = .all
    var isReviewing = false
}

/// One row in the library, from either lookup history or favorites.
struct LibraryItem: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let text: String
    let targetLanguageCode: String
    let context: ProfessionalContext
    let result: LookupResult

    init(_ entry: LookupHistoryEntry) {
        id = entry.id
        date = entry.createdAt
        text = entry.text
        targetLanguageCode = entry.targetLanguageCode
        context = entry.context
        result = entry.result
    }

    init(_ favorite: LookupFavorite) {
        id = favorite.id
        date = favorite.savedAt
        text = favorite.text
        targetLanguageCode = favorite.targetLanguageCode
        context = favorite.context
        result = favorite.result
    }

    var targetLanguage: TargetLanguage { TargetLanguage(code: targetLanguageCode) }
}

/// History and favorites in one window, with flashcard review of favorites.
struct LibraryWindow: View {
    @Bindable var history: LookupHistory
    @Bindable var favorites: LookupFavorites
    @Bindable var navigation: LibraryNavigation
    let languageSettings: UILanguageSettings
    let lookUpAgain: (String) -> Void

    @State private var query = ""
    @State private var selectedID: UUID?
    @State private var confirmsClear = false

    private var strings: UIStrings { languageSettings.strings }

    var body: some View {
        Group {
            if navigation.isReviewing {
                ReviewFavoritesView(
                    favorites: favorites.entries,
                    strings: strings,
                    close: { navigation.isReviewing = false }
                )
            } else {
                library
            }
        }
        .frame(minWidth: 680, minHeight: 440)
        .environment(\.locale, languageSettings.language.locale)
    }

    private var library: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } detail: {
            if let item = selectedItem {
                LibraryItemDetail(item: item, strings: strings)
            } else {
                ContentUnavailableView(
                    navigation.tab == .all ? strings.selectHistoryEntry : strings.selectFavorite,
                    systemImage: "text.book.closed"
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(strings.reviewFavorites, systemImage: "rectangle.on.rectangle.angled") {
                    navigation.isReviewing = true
                }
                .disabled(favorites.entries.isEmpty)
                .help(strings.reviewFavoritesHelp)
            }
            if let item = selectedItem {
                ToolbarItem(placement: .primaryAction) {
                    Button(strings.lookUpAgain, systemImage: "arrow.counterclockwise") {
                        lookUpAgain(item.text)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    let isFavorite = favoriteEntry(for: item) != nil
                    Button(isFavorite ? strings.removeFavorite : strings.saveFavorite,
                           systemImage: isFavorite ? "star.slash" : "star") {
                        toggleFavorite(item)
                    }
                }
            }
        }
        .confirmationDialog(strings.clearHistoryConfirmation, isPresented: $confirmsClear) {
            Button(strings.clearHistory, role: .destructive) {
                try? history.clear()
                selectedID = nil
            }
        }
        .onAppear { selectFirstIfNeeded() }
        .onChange(of: navigation.tab) { _, _ in
            selectedID = nil
            selectFirstIfNeeded()
        }
    }

    private var sidebar: some View {
        List(selection: $selectedID) {
            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        LibraryRow(item: item, isFavorite: favoriteEntry(for: item) != nil, strings: strings)
                            .tag(item.id)
                    }
                }
            }
        }
        .overlay {
            if items.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView(
                        navigation.tab == .all ? strings.emptyHistory : strings.emptyFavorites,
                        systemImage: navigation.tab == .all ? "clock.arrow.circlepath" : "star"
                    )
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker(strings.libraryShow, selection: $navigation.tab) {
                Text(strings.allLookups).tag(LibraryTab.all)
                Text(strings.favorites).tag(LibraryTab.favorites)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if navigation.tab == .all || storageError {
                VStack(alignment: .leading, spacing: 6) {
                    if storageError {
                        Text(strings.storageUnavailable)
                            .foregroundStyle(Theme.danger)
                    }
                    if navigation.tab == .all {
                        HStack {
                            Toggle(strings.saveHistory, isOn: $history.isEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            Spacer()
                            Button(strings.clearHistory) { confirmsClear = true }
                                .buttonStyle(.borderless)
                                .disabled(history.entries.isEmpty)
                        }
                    }
                }
                .font(.system(size: 12))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .searchable(text: $query, placement: .sidebar, prompt: strings.searchLibrary)
    }

    private var storageError: Bool {
        history.persistenceError != nil || favorites.persistenceError != nil
    }

    private var items: [LibraryItem] {
        switch navigation.tab {
        case .all: history.search(query).map(LibraryItem.init)
        case .favorites: favorites.search(query).map(LibraryItem.init)
        }
    }

    private var selectedItem: LibraryItem? {
        guard let selectedID else { return nil }
        return items.first { $0.id == selectedID }
    }

    private var sections: [(title: String, items: [LibraryItem])] {
        let items = items
        guard navigation.tab == .all else {
            return items.isEmpty ? [] : [(strings.savedSection, items)]
        }
        let calendar = Calendar.current
        let groups: [(String, (Date) -> Bool)] = [
            (strings.today, calendar.isDateInToday),
            (strings.yesterday, calendar.isDateInYesterday),
            (strings.earlier, { !calendar.isDateInToday($0) && !calendar.isDateInYesterday($0) }),
        ]
        return groups.compactMap { title, matches in
            let grouped = items.filter { matches($0.date) }
            return grouped.isEmpty ? nil : (title, grouped)
        }
    }

    private func favoriteEntry(for item: LibraryItem) -> LookupFavorite? {
        favorites.entry(text: item.text, targetLanguage: item.targetLanguage, context: item.context)
    }

    private func toggleFavorite(_ item: LibraryItem) {
        if let favorite = favoriteEntry(for: item) {
            try? favorites.remove(id: favorite.id)
            if navigation.tab == .favorites { selectedID = nil }
        } else {
            try? favorites.save(text: item.text, targetLanguage: item.targetLanguage,
                                context: item.context, result: item.result)
        }
    }

    private func selectFirstIfNeeded() {
        if selectedItem == nil { selectedID = items.first?.id }
    }
}

private struct LibraryRow: View {
    let item: LibraryItem
    let isFavorite: Bool
    let strings: UIStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(item.text)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.star)
                        .accessibilityLabel(strings.savedShort)
                }
            }
            Text(item.result.meaning)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

private struct LibraryItemDetail: View {
    let item: LibraryItem
    let strings: UIStrings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text)
                        .font(.system(size: 26, weight: .bold))
                        .tracking(-0.5)
                        .textSelection(.enabled)
                    HStack(spacing: 6) {
                        Pill(text: strings.targetLanguageName(code: item.targetLanguageCode),
                             foreground: Theme.textBody, background: Color.white.opacity(0.1))
                        Pill(text: strings.contextName(id: item.context.id, customName: item.context.name),
                             foreground: Theme.accentSoft, background: Theme.accentTint)
                        Text(item.date, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.leading, 4)
                    }
                }

                Text(item.result.meaning)
                    .font(.system(size: 16, weight: .medium))
                    .lineSpacing(3)
                    .textSelection(.enabled)

                if !item.result.example.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(title: strings.resultExample)
                        Text(LookupResultView.emphasized(item.result.example, term: item.text, size: 14))
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textBody)
                            .lineSpacing(3)
                            .textSelection(.enabled)
                    }
                }

                if !item.result.detail.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(title: strings.moreDetail)
                        Text(strings.resultDetail(item.result.detail))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textBody)
                            .lineSpacing(3)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(item.text)
    }
}

struct Pill: View {
    let text: String
    let foreground: Color
    let background: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(background, in: Capsule())
    }
}

extension UIStrings {
    private func libraryText(_ vi: String, _ en: String) -> String {
        language == .vietnamese ? vi : en
    }

    var library: String { libraryText("Thư viện", "Library") }
    var libraryShow: String { libraryText("Hiển thị", "Show") }
    var allLookups: String { libraryText("Tất cả lượt tra", "All lookups") }
    var favorites: String { libraryText("Mục yêu thích", "Favorites") }
    var searchLibrary: String { libraryText("Tìm từ và nghĩa", "Search words and meanings") }
    var today: String { libraryText("Hôm nay", "Today") }
    var yesterday: String { libraryText("Hôm qua", "Yesterday") }
    var earlier: String { libraryText("Trước đó", "Earlier") }
    var savedSection: String { libraryText("Đã lưu", "Saved") }
    var emptyHistory: String { libraryText("Chưa có lượt tra nào", "No lookups yet") }
    var emptyFavorites: String { libraryText("Chưa có mục yêu thích", "No favorites yet") }
    var selectHistoryEntry: String { libraryText("Chọn một lượt tra để xem lại", "Select a lookup to review") }
    var selectFavorite: String { libraryText("Chọn một mục để xem lại", "Select a favorite to review") }
    var saveHistory: String { libraryText("Lưu lịch sử", "Save history") }
    var clearHistory: String { libraryText("Xóa lịch sử", "Clear history") }
    var clearHistoryConfirmation: String { libraryText("Xóa tất cả lịch sử tra?", "Clear all lookup history?") }
    var saveFavorite: String { libraryText("Lưu vào yêu thích", "Save to favorites") }
    var removeFavorite: String { libraryText("Bỏ yêu thích", "Remove from favorites") }
    var lookUpAgain: String { libraryText("Tra lại", "Look up again") }
    var reviewFavorites: String { libraryText("Ôn tập", "Review favorites") }
    var reviewFavoritesHelp: String { libraryText("Ôn lại các mục yêu thích bằng thẻ ghi nhớ", "Practice your favorites with flashcards") }
}
