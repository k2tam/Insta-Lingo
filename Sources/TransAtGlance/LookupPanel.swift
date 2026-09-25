import AppKit
import SwiftUI
import LookupCore

struct LookupPanel: View {
    @Bindable var lookup: LookupCoordinator
    @Bindable var ocrFlow: OCRLookupFlow
    @Bindable var selectionFlow: SelectionLookupFlow
    @Bindable var languageSettings: UILanguageSettings
    @Bindable var favorites: LookupFavorites
    @Binding var isDetailExpanded: Bool
    let hidePanel: () -> Void
    let showPanel: () async -> Void
    let quitApp: () -> Void
    let openHistory: () -> Void
    let openFavorites: () -> Void
    let openSettings: () -> Void
    @FocusState private var textFocused: Bool
    @State private var inputSelection: TextSelection?
    @State private var isVietnameseExpanded = false
    @State private var scrollContentHeight: CGFloat = 360

    private let maximumScrollHeight: CGFloat = 620

    private var strings: UIStrings { languageSettings.strings }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("TransAtGlance")
                    .font(.headline)
                Spacer()
                Picker(strings.resultLanguage, selection: $lookup.selectedLanguage) {
                    ForEach(lookup.availableLanguages) { language in
                        Text(strings.targetLanguageName(code: language.code)).tag(language)
                    }
                }
                .labelsHidden()
                .accessibilityLabel(strings.resultLanguage)
                .frame(width: 150)
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(strings.settingsTitle)
                Menu {
                    Button(strings.lookupSelection, systemImage: "selection.pin.in.out") {
                        Task { await selectionFlow.start(lookup: lookup) }
                    }
                    .disabled(selectionFlow.status == .reading || lookup.phase == .loading)
                    Button(strings.selectRegion, systemImage: "viewfinder") { startRegionSelection() }
                        .disabled(ocrFlow.isSelecting || selectionFlow.status == .reading)
                    Divider()
                    Button(strings.historyTitle, systemImage: "clock", action: openHistory)
                    Button(strings.favorites, systemImage: "star", action: openFavorites)
                    Divider()
                    Button(strings.quitApp, systemImage: "power", role: .destructive, action: quitApp)
                        .keyboardShortcut("q", modifiers: .command)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel(strings.moreActions)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    inputRow
                    reviewStatus
                    ProfessionalContextPicker(catalog: lookup.contextCatalog, strings: strings)
                    captureStatus
                    lookupOutput
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: ScrollContentHeightKey.self, value: geometry.size.height)
                    }
                }
            }
            .frame(height: min(scrollContentHeight, maximumScrollHeight))
            .onPreferenceChange(ScrollContentHeightKey.self) { height in
                if height > 0 { scrollContentHeight = height }
            }
        }
        .task { await lookup.loadAvailableLanguages() }
        .onChange(of: lookup.result) { _, result in
            if result != nil {
                isDetailExpanded = false
                isVietnameseExpanded = false
            }
        }
        .onChange(of: lookup.contextCatalog.selectedContext) { _, _ in
            Task { await lookup.refreshForSelectedContext() }
        }
        .onChange(of: lookup.text) { _, _ in inputSelection = nil }
        .environment(\.locale, languageSettings.language.locale)
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            TextField(strings.inputPlaceholder, text: $lookup.text, selection: $inputSelection, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($textFocused)
                .onSubmit { submitInput() }
                .accessibilityLabel(strings.inputAccessibility)

            Button(strings.lookup) { submitInput() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(lookup.phase == .loading)
                .keyboardShortcut(.return, modifiers: .command)
        }
    }

    @ViewBuilder
    private var reviewStatus: some View {
        if selectionFlow.status == .reviewing || ocrFlow.isReviewing {
            Text(strings.reviewCapturedText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var captureStatus: some View {
        if selectionFlow.status == .reading {
            Text(strings.readingSelection).foregroundStyle(.secondary)
        } else if selectionFlow.status == .permissionRequired {
            Text(strings.accessibilityPermissionNeeded).foregroundStyle(.secondary)
        } else if selectionFlow.status == .regionFallback {
            Text(strings.selectionUnavailable).foregroundStyle(.secondary)
        }

        if let error = selectionFlow.errorMessage {
            Label(strings.errorMessage(error), systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }

        if ocrFlow.isSelecting {
            Text(strings.selectingRegionHint).foregroundStyle(.secondary)
        }

        if let error = ocrFlow.errorMessage {
            Label(strings.errorMessage(error), systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var lookupOutput: some View {
        if ocrFlow.isRecognizing {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(strings.recognizingRegion)
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .accessibilityElement(children: .combine)
        } else {
            lookupPhaseContent
        }

        if favorites.persistenceError != nil {
            Text(strings.storageUnavailable).font(.caption).foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var lookupPhaseContent: some View {
        switch lookup.phase {
        case .idle:
            if selectionFlow.status == .reviewing || ocrFlow.isReviewing {
                Color.clear.frame(minHeight: 180)
            } else {
                Text(strings.idle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            }
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(lookup.selectedSource == .groq ? strings.groqLoading : strings.loading)
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .accessibilityElement(children: .combine)
        case .error(let message):
            Label(strings.errorMessage(message), systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        case .result:
            resultContent
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if let result = lookup.result {
            LookupResultView(
                source: lookup.selectedSource == .groq ? "Groq" : strings.local,
                result: result,
                showsVietnamese: lookup.completedLookup?.targetLanguage == .simpleEnglish,
                vietnameseResult: lookup.vietnameseResult,
                vietnamesePhase: lookup.vietnamesePhase,
                isVietnameseExpanded: $isVietnameseExpanded,
                loadVietnamese: { await lookup.loadVietnameseResult() },
                isExpanded: $isDetailExpanded,
                strings: strings
            )
            if let completed = lookup.completedLookup {
                favoriteButton(for: completed)
            }
        }
    }

    private func favoriteButton(for completed: CompletedLookup) -> some View {
        let isFavorite = favorites.contains(text: completed.request.text,
                                            targetLanguage: completed.targetLanguage,
                                            context: completed.request.context)
        return Button(isFavorite ? strings.savedFavorite : strings.saveFavorite,
                      systemImage: isFavorite ? "star.fill" : "star") {
            try? favorites.save(text: completed.request.text,
                                targetLanguage: completed.targetLanguage,
                                context: completed.request.context,
                                result: completed.result)
        }
        .disabled(isFavorite)
    }

    private var selectedInputText: String? {
        guard let inputSelection,
              case .selection(let range) = inputSelection.indices,
              !range.isEmpty else { return nil }
        return String(lookup.text[range])
    }

    private func submitInput() {
        let selected = selectedInputText
        selectionFlow.reset()
        ocrFlow.cancelReview()
        Task {
            if let selected {
                await lookup.submit(selectedPhrase: selected)
            } else {
                await lookup.submit()
            }
        }
    }

    private func startRegionSelection() {
        selectionFlow.reset()
        Task {
            await ocrFlow.start(
                lookup: lookup,
                hidePanel: hidePanel,
                showPanel: showPanel
            )
        }
    }
}

private struct ScrollContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct LookupResultView: View {
    let source: String
    let result: LookupResult
    let showsVietnamese: Bool
    let vietnameseResult: LookupResult?
    let vietnamesePhase: LookupPhase
    @Binding var isVietnameseExpanded: Bool
    let loadVietnamese: () async -> Void
    @Binding var isExpanded: Bool
    let strings: UIStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                Text(source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            Text(result.meaning)
                .font(.title3)
                .textSelection(.enabled)
            Text(result.example)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if showsVietnamese {
                DisclosureGroup(strings.vietnameseExplanation, isExpanded: $isVietnameseExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        switch vietnamesePhase {
                        case .idle, .loading:
                            ProgressView(strings.loadingVietnamese)
                        case .result:
                            if let vietnameseResult {
                                Text(vietnameseResult.meaning)
                                    .textSelection(.enabled)
                                Text(vietnameseResult.example)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        case .error(let message):
                            Text(strings.errorMessage(message))
                                .foregroundStyle(.red)
                            Button(strings.retryVietnamese) {
                                Task { await loadVietnamese() }
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                .onChange(of: isVietnameseExpanded) { _, expanded in
                    if expanded { Task { await loadVietnamese() } }
                }
            }
            if !result.detail.isEmpty {
                DisclosureGroup(strings.moreDetail, isExpanded: $isExpanded) {
                    Text(strings.resultDetail(result.detail))
                        .textSelection(.enabled)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        }
    }
}
