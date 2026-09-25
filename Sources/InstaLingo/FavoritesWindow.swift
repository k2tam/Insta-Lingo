import SwiftUI
import LookupCore

struct FavoritesWindow: View {
    @Bindable var favorites: LookupFavorites
    let languageSettings: UILanguageSettings
    @State private var query = ""
    @State private var selectedID: UUID?

    private var strings: UIStrings { languageSettings.strings }
    private var selectedEntry: LookupFavorite? {
        favorites.entries.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(favorites.search(query), selection: $selectedID) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.text).font(.headline)
                        Text(entry.meaning).lineLimit(2).foregroundStyle(.secondary)
                        Text(strings.targetLanguageName(code: entry.targetLanguageCode))
                            .font(.caption).foregroundStyle(.tertiary)
                        Text(strings.contextName(id: entry.context.id, customName: entry.context.name))
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .tag(entry.id)
                    .accessibilityElement(children: .combine)
                }
                if favorites.entries.isEmpty {
                    ContentUnavailableView(strings.emptyFavorites, systemImage: "star")
                }
            }
            .navigationTitle(strings.favorites)
            .searchable(text: $query, prompt: strings.searchFavorites)
        } detail: {
            if let entry = selectedEntry {
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
                .toolbar {
                    ToolbarItem {
                        Button(strings.removeFavorite, systemImage: "star.slash") {
                            try? favorites.remove(id: entry.id)
                            selectedID = nil
                        }
                    }
                }
            } else {
                ContentUnavailableView(strings.selectFavorite, systemImage: "star")
            }
        }
        .frame(minWidth: 680, minHeight: 400)
        .safeAreaInset(edge: .bottom) {
            if favorites.persistenceError != nil {
                Text(strings.storageUnavailable)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.regularMaterial)
            }
        }
        .environment(\.locale, languageSettings.language.locale)
    }
}

extension UIStrings {
    private func favoritesText(_ vi: String, _ en: String) -> String {
        language == .vietnamese ? vi : en
    }

    var favorites: String { favoritesText("Mục yêu thích", "Favorites") }
    var saveFavorite: String { favoritesText("Đánh dấu yêu thích", "Save to favorites") }
    var savedFavorite: String { favoritesText("Đã đánh dấu yêu thích", "Saved to favorites") }
    var removeFavorite: String { favoritesText("Bỏ yêu thích", "Remove favorite") }
    var searchFavorites: String { favoritesText("Tìm mục yêu thích", "Search favorites") }
    var emptyFavorites: String { favoritesText("Chưa có mục yêu thích", "No favorites yet") }
    var selectFavorite: String { favoritesText("Chọn một mục để xem lại", "Select a favorite to review") }
}
