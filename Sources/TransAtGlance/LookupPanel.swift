import AppKit
import SwiftUI
import LookupCore

struct LookupPanel: View {
    @Bindable var lookup: LookupCoordinator
    @Bindable var ocrFlow: OCRLookupFlow
    @Bindable var selectionFlow: SelectionLookupFlow
    @Bindable var languageSettings: UILanguageSettings
    @Bindable var geminiConfiguration: GeminiConfiguration
    @Bindable var favorites: LookupFavorites
    @Binding var isDetailExpanded: Bool
    let hidePanel: () -> Void
    let showPanel: () -> Void
    let openHistory: () -> Void
    let openFavorites: () -> Void
    let openSettings: () -> Void
    @FocusState private var textFocused: Bool
    @State private var ocrSelection: TextSelection?
    @State private var ocrPhrase = ""
    @State private var ocrSentence = ""
    @State private var accessibilityPhrase = ""
    @State private var accessibilitySentence = ""

    private var strings: UIStrings { languageSettings.strings }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TransAtGlance")
                .font(.headline)

            TextField(strings.inputPlaceholder, text: $lookup.text)
                .textFieldStyle(.roundedBorder)
                .focused($textFocused)
                .onSubmit { Task { await lookup.submit() } }
                .accessibilityLabel(strings.inputAccessibility)

            HStack {
                Picker(strings.resultLanguage, selection: $lookup.selectedLanguage) {
                    ForEach(lookup.availableLanguages) { language in
                        Text(strings.targetLanguageName(code: language.code)).tag(language)
                    }
                }
                .labelsHidden()
                .accessibilityLabel(strings.resultLanguage)
                Spacer()
                Button(strings.lookup) { Task { await lookup.submit() } }
                    .disabled(lookup.phase == .loading)
                    .keyboardShortcut(.return, modifiers: .command)
            }

            ProfessionalContextPicker(catalog: lookup.contextCatalog, strings: strings)

            HStack {
                Picker(strings.lookupSource, selection: $lookup.selectedSource) {
                    Text(strings.local).tag(LookupSource.local)
                    if geminiConfiguration.isEnabled {
                        Text(strings.gemini).tag(LookupSource.gemini)
                    }
                }
                .disabled(lookup.phase == .loading)
                .accessibilityLabel(strings.lookupSource)
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(strings.settingsTitle)
            }

            if lookup.selectedSource == .gemini {
                Text(strings.geminiDisclosure)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker(strings.interfaceLanguage, selection: $languageSettings.language) {
                Text(strings.vietnamese).tag(UILanguage.vietnamese)
                Text(strings.english).tag(UILanguage.english)
            }
            .accessibilityLabel(strings.interfaceLanguage)

            HStack {
                Button(strings.historyTitle, action: openHistory)
                Button(strings.favorites, action: openFavorites)
            }

            Button(strings.lookupSelection) {
                Task { await selectionFlow.start(lookup: lookup, reviewSelection: true) }
            }
            .disabled(selectionFlow.status == .reading || lookup.phase == .loading)
            .accessibilityLabel(strings.lookupSelection)

            if selectionFlow.status == .reading {
                Text(strings.readingSelection)
                    .foregroundStyle(.secondary)
            } else if selectionFlow.status == .permissionRequired {
                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.accessibilityPermissionNeeded)
                        .foregroundStyle(.secondary)
                    Button(strings.retrySelection) {
                        Task { await selectionFlow.start(lookup: lookup, reviewSelection: true) }
                    }
                }
            } else if selectionFlow.status == .regionFallback {
                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.selectionUnavailable)
                        .foregroundStyle(.secondary)
                    Button(strings.selectRegionInstead) { startRegionSelection() }
                }
            } else if selectionFlow.status == .reviewing {
                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.reviewingSelection).font(.subheadline.weight(.semibold))
                    Text(selectionFlow.selectedText)
                        .textSelection(.enabled)
                    TextField(strings.lookupPhrase, text: $accessibilityPhrase)
                        .accessibilityLabel(strings.lookupPhrase)
                    TextField(strings.optionalSelectedSentence, text: $accessibilitySentence)
                        .accessibilityLabel(strings.optionalSelectedSentence)
                    Text(strings.selectedSentenceHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button(strings.lookup) {
                            Task {
                                await selectionFlow.confirm(lookup: lookup, phrase: accessibilityPhrase, sentence: accessibilitySentence)
                            }
                        }
                        Button(strings.cancel, role: .cancel) { selectionFlow.reset() }
                    }
                }
            }

            if let error = selectionFlow.errorMessage {
                Label(strings.errorMessage(error), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            Button(strings.selectRegion) { startRegionSelection() }
            .disabled(ocrFlow.isSelecting || selectionFlow.status == .reading)
            .accessibilityLabel(strings.selectRegionAccessibility)

            if ocrFlow.isSelecting {
                Text(strings.selectingRegionHint)
                    .foregroundStyle(.secondary)
            }

            if ocrFlow.isReviewing {
                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.reviewingOCR)
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: $ocrFlow.recognizedText, selection: $ocrSelection)
                        .frame(height: 90)
                        .border(.separator)
                        .accessibilityLabel(strings.recognizedTextAccessibility)
                    TextField(strings.lookupPhrase, text: $ocrPhrase)
                        .accessibilityLabel(strings.lookupPhrase)
                    TextField(strings.optionalSelectedSentence, text: $ocrSentence)
                        .accessibilityLabel(strings.optionalSelectedSentence)
                    Text(strings.selectedSentenceHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        if let selectedOCRText {
                            Button(strings.useSelectedText) { ocrPhrase = selectedOCRText }
                            Button(strings.useSelectionAsSentence) { ocrSentence = selectedOCRText }
                        }
                        Button(strings.lookup) {
                            Task {
                                await ocrFlow.confirm(lookup: lookup, selectedText: ocrPhrase.isEmpty ? ocrFlow.recognizedText : ocrPhrase, selectedSentence: ocrSentence)
                                ocrSelection = nil
                            }
                        }
                        Button(strings.cancel, role: .cancel) { ocrFlow.cancelReview() }
                    }
                }
            }

            if let error = ocrFlow.errorMessage {
                Label(strings.errorMessage(error), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            switch lookup.phase {
            case .idle:
                Text(strings.idle)
                    .foregroundStyle(.secondary)
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(lookup.selectedSource == .gemini ? strings.geminiLoading : strings.loading)
                }
                .accessibilityElement(children: .combine)
            case .fallbackPrompt(let reason):
                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.localFallbackTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(strings.errorMessage(reason))
                        .foregroundStyle(.secondary)
                    Text(strings.localFallbackExplanation)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button(strings.useGeminiFallback) {
                            Task { await lookup.resolveFallback(.allow) }
                        }
                        Button(strings.declineGeminiFallback) {
                            Task { await lookup.resolveFallback(.decline) }
                        }
                    }
                }
            case .error(let message):
                Label(strings.errorMessage(message), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            case .result:
                if let result = lookup.result {
                    LookupResultView(result: result, isExpanded: $isDetailExpanded, strings: strings)
                    if let completed = lookup.completedLookup {
                        let isFavorite = favorites.contains(text: completed.request.text,
                                                            targetLanguage: completed.targetLanguage,
                                                            context: completed.request.context)
                        Button(isFavorite ? strings.savedFavorite : strings.saveFavorite,
                               systemImage: isFavorite ? "star.fill" : "star") {
                            try? favorites.save(text: completed.request.text,
                                                targetLanguage: completed.targetLanguage,
                                                context: completed.request.context,
                                                result: completed.result)
                        }
                        .disabled(isFavorite)
                    }
                }
            }
            if favorites.persistenceError != nil {
                Text(strings.storageUnavailable).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(16)
        .task { await lookup.loadAvailableLanguages() }
        .onChange(of: lookup.result) { _, result in
            if result != nil { isDetailExpanded = false }
        }
        .onChange(of: selectionFlow.selectedText) { _, text in
            accessibilityPhrase = text
            accessibilitySentence = ""
        }
        .onChange(of: ocrFlow.recognizedText) { old, new in
            if new.isEmpty {
                ocrPhrase = ""
                ocrSentence = ""
            } else if old.isEmpty || ocrPhrase == old {
                ocrPhrase = new
            }
            let sentence = ocrSentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty && !new.contains(sentence) {
                ocrSentence = ""
            }
        }
        .environment(\.locale, languageSettings.language.locale)
    }

    private var selectedOCRText: String? {
        guard let ocrSelection,
              case .selection(let range) = ocrSelection.indices,
              !range.isEmpty else { return nil }
        return String(ocrFlow.recognizedText[range])
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

private struct LookupResultView: View {
    let result: LookupResult
    @Binding var isExpanded: Bool
    let strings: UIStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.meaning)
                .font(.body)
                .textSelection(.enabled)
            Text(result.example)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if !result.detail.isEmpty {
                DisclosureGroup(strings.moreDetail, isExpanded: $isExpanded) {
                    Text(strings.resultDetail(result.detail))
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
