import SwiftUI
import LookupCore

struct HistoryWindow: View {
    @Bindable var history: LookupHistory
    let languageSettings: UILanguageSettings
    @State private var query = ""
    @State private var selectedID: UUID?
    @State private var confirmsClear = false

    private var strings: UIStrings { languageSettings.strings }
    private var selectedEntry: LookupHistoryEntry? {
        history.entries.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(history.search(query), selection: $selectedID) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.text).font(.headline)
                        Text(entry.meaning).lineLimit(2).foregroundStyle(.secondary)
                        Text(entry.createdAt, style: .date)
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .tag(entry.id)
                    .accessibilityElement(children: .combine)
                }
                if history.entries.isEmpty {
                    ContentUnavailableView(strings.emptyHistory,
                                           systemImage: "clock.arrow.circlepath")
                }
            }
            .navigationTitle(strings.history)
            .searchable(text: $query, prompt: strings.searchHistory)
            .toolbar {
                ToolbarItem {
                    Button(strings.clearHistory, systemImage: "trash") {
                        confirmsClear = true
                    }
                    .disabled(history.entries.isEmpty)
                }
            }
        } detail: {
            if let entry = selectedEntry {
                HistoryEntryDetail(entry: entry, strings: strings)
            } else {
                ContentUnavailableView(strings.selectHistoryEntry,
                                       systemImage: "text.book.closed")
            }
        }
        .frame(minWidth: 680, minHeight: 400)
        .confirmationDialog(strings.clearHistoryConfirmation, isPresented: $confirmsClear) {
            Button(strings.clearHistory, role: .destructive) {
                try? history.clear()
                selectedID = nil
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Toggle(strings.saveHistory, isOn: $history.isEnabled)
                Spacer()
                if let error = history.persistenceError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(10)
            .background(.regularMaterial)
        }
        .environment(\.locale, languageSettings.language.locale)
    }
}

private struct HistoryEntryDetail: View {
    let entry: LookupHistoryEntry
    let strings: UIStrings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(entry.text).font(.title)
                LabeledContent(strings.resultLanguage,
                               value: strings.targetLanguageName(code: entry.targetLanguageCode))
                LabeledContent(strings.professionalContext,
                               value: strings.contextName(id: entry.context.id,
                                                          customName: entry.context.name))
                Divider()
                Text(entry.meaning).font(.title3)
                Text(entry.example).foregroundStyle(.secondary)
                if !entry.detail.isEmpty {
                    Text(strings.resultDetail(entry.detail))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .navigationTitle(entry.text)
    }
}

extension UIStrings {
    private func historyText(_ vi: String, _ en: String) -> String {
        language == .vietnamese ? vi : en
    }

    var history: String { historyText("Lịch sử tra", "Lookup history") }
    var searchHistory: String { historyText("Tìm lượt tra", "Search history") }
    var emptyHistory: String { historyText("Chưa có lượt tra nào", "No lookups yet") }
    var selectHistoryEntry: String { historyText("Chọn một lượt tra để xem lại", "Select a lookup to review") }
    var saveHistory: String { historyText("Lưu lịch sử", "Save history") }
    var clearHistory: String { historyText("Xóa lịch sử", "Clear history") }
    var clearHistoryConfirmation: String { historyText("Xóa tất cả lịch sử tra?", "Clear all lookup history?") }
    var professionalContext: String { historyText("Ngữ cảnh chuyên môn", "Professional context") }
}
