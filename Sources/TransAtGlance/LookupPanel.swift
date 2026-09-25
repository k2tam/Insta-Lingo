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
    @Binding var inputFocusGeneration: Int
    let hidePanel: () -> Void
    let showPanel: () async -> Void
    let quitApp: () -> Void
    let openHistory: () -> Void
    let openFavorites: () -> Void
    let openSettings: () -> Void

    @State private var inputSelection: TextSelection?
    @State private var isVietnameseExpanded = false
    @State private var scrollContentHeight: CGFloat = 430

    private let maximumScrollHeight: CGFloat = 620
    private var strings: UIStrings { languageSettings.strings }

    var body: some View {
        VStack(spacing: 0) {
            LookupPanelHeader(
                selectedLanguage: $lookup.selectedLanguage,
                availableLanguages: lookup.availableLanguages,
                strings: strings,
                openHistory: openHistory,
                openFavorites: openFavorites,
                openSettings: openSettings,
                quitApp: quitApp
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LookupInputBar(
                        text: $lookup.text,
                        inputSelection: $inputSelection,
                        inputFocusGeneration: inputFocusGeneration,
                        strings: strings,
                        allowsProgrammaticFocus: selectionFlow.status != .reading
                            && selectionFlow.status != .reviewing
                            && !ocrFlow.isSelecting
                            && !ocrFlow.isRecognizing
                            && !ocrFlow.isReviewing
                            && lookup.phase != .loading,
                        selectionDisabled: selectionFlow.status == .reading || lookup.phase == .loading,
                        regionDisabled: ocrFlow.isSelecting || ocrFlow.isRecognizing || selectionFlow.status == .reading,
                        lookupDisabled: lookup.phase == .loading,
                        lookupSelection: startSelectionLookup,
                        selectRegion: startRegionSelection,
                        submit: submitInput
                    )

                    ProfessionalContextPicker(catalog: lookup.contextCatalog, strings: strings)

                    LookupStateRegion(
                        lookup: lookup,
                        ocrFlow: ocrFlow,
                        selectionFlow: selectionFlow,
                        favorites: favorites,
                        isDetailExpanded: $isDetailExpanded,
                        isVietnameseExpanded: $isVietnameseExpanded,
                        strings: strings,
                        retrySelection: startSelectionLookup,
                        selectRegion: startRegionSelection
                    )
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

    private func startSelectionLookup() {
        Task { await selectionFlow.start(lookup: lookup) }
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

private struct LookupPanelHeader: View {
    @Binding var selectedLanguage: TargetLanguage
    let availableLanguages: [TargetLanguage]
    let strings: UIStrings
    let openHistory: () -> Void
    let openFavorites: () -> Void
    let openSettings: () -> Void
    let quitApp: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("TransAtGlance")
                .font(.headline)

            Spacer()

            Picker(strings.resultLanguage, selection: $selectedLanguage) {
                ForEach(availableLanguages) { language in
                    Text(strings.targetLanguageName(code: language.code)).tag(language)
                }
            }
            .labelsHidden()
            .accessibilityLabel(strings.resultLanguage)
            .frame(width: 150)

            Button(action: openSettings) {
                Label(strings.settingsTitle, systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .help(strings.settingsTitle)
            .accessibilityLabel(strings.settingsTitle)

            Menu {
                Button(strings.historyTitle, systemImage: "clock", action: openHistory)
                Button(strings.favorites, systemImage: "star", action: openFavorites)
                Divider()
                Button(strings.quitApp, systemImage: "power", role: .destructive, action: quitApp)
                    .keyboardShortcut("q", modifiers: .command)
            } label: {
                Label(strings.moreActions, systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(strings.moreActions)
            .accessibilityLabel(strings.moreActions)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

private struct LookupInputBar: View {
    @Binding var text: String
    @Binding var inputSelection: TextSelection?
    let inputFocusGeneration: Int
    let strings: UIStrings
    let allowsProgrammaticFocus: Bool
    let selectionDisabled: Bool
    let regionDisabled: Bool
    let lookupDisabled: Bool
    let lookupSelection: () -> Void
    let selectRegion: () -> Void
    let submit: () -> Void

    @FocusState private var textFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField(strings.inputPlaceholder, text: $text, selection: $inputSelection, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($textFocused)
                .onSubmit(submit)
                .accessibilityLabel(strings.inputAccessibility)

            Button(action: lookupSelection) {
                Label(strings.lookupSelection, systemImage: "selection.pin.in.out")
                    .labelStyle(.iconOnly)
                    .frame(width: 18)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(selectionDisabled)
            .help(strings.lookupSelection)
            .accessibilityLabel(strings.lookupSelection)

            Button(action: selectRegion) {
                Label(strings.selectRegion, systemImage: "viewfinder")
                    .labelStyle(.iconOnly)
                    .frame(width: 18)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(regionDisabled)
            .help(strings.selectRegionAccessibility)
            .accessibilityLabel(strings.selectRegionAccessibility)

            Button(strings.lookup, action: submit)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(lookupDisabled)
                .keyboardShortcut(.return, modifiers: .command)
        }
        .onChange(of: inputFocusGeneration) {
            guard allowsProgrammaticFocus else { return }
            textFocused = false
            Task { @MainActor in
                await Task.yield()
                textFocused = true
            }
        }
    }
}

private struct LookupStateRegion: View {
    let lookup: LookupCoordinator
    let ocrFlow: OCRLookupFlow
    let selectionFlow: SelectionLookupFlow
    let favorites: LookupFavorites
    @Binding var isDetailExpanded: Bool
    @Binding var isVietnameseExpanded: Bool
    let strings: UIStrings
    let retrySelection: () -> Void
    let selectRegion: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stateIdentity: String {
        if selectionFlow.status == .reading { return "selection-reading" }
        if ocrFlow.isSelecting { return "region-selecting" }
        if ocrFlow.isRecognizing { return "region-recognizing" }
        if selectionFlow.status == .reviewing || ocrFlow.isReviewing { return "reviewing" }
        if let error = selectionFlow.errorMessage { return "selection-error-\(error)" }
        if let error = ocrFlow.errorMessage { return "ocr-error-\(error)" }
        if selectionFlow.status == .permissionRequired { return "permission" }
        if selectionFlow.status == .regionFallback { return "fallback" }
        switch lookup.phase {
        case .idle: return "idle"
        case .loading: return "lookup-loading"
        case .error(let message): return "lookup-error-\(message)"
        case .result: return "result"
        }
    }

    private var stateAnimation: Animation? {
        reduceMotion ? .easeOut(duration: 0.08) : .easeOut(duration: 0.2)
    }

    private var stateTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            stateContent
                .id(stateIdentity)
                .transition(stateTransition)
        }
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        .animation(stateAnimation, value: stateIdentity)
    }

    @ViewBuilder
    private var stateContent: some View {
        if selectionFlow.status == .reading {
            LookupMessageCard(
                icon: "text.magnifyingglass",
                message: strings.readingSelection,
                showsProgress: true
            )
        } else if ocrFlow.isSelecting {
            LookupMessageCard(icon: "viewfinder", message: strings.selectingRegionHint)
        } else if ocrFlow.isRecognizing {
            LookupMessageCard(
                icon: "text.viewfinder",
                message: strings.recognizingRegion,
                showsProgress: true
            )
        } else if selectionFlow.status == .reviewing || ocrFlow.isReviewing {
            LookupMessageCard(icon: "text.cursor", message: strings.reviewCapturedText)
        } else if let error = selectionFlow.errorMessage {
            LookupMessageCard(
                icon: "exclamationmark.triangle.fill",
                title: strings.lookupFailed,
                message: strings.errorMessage(error),
                tone: .error,
                actionTitle: strings.retrySelection,
                action: retrySelection
            )
        } else if let error = ocrFlow.errorMessage {
            LookupMessageCard(
                icon: "exclamationmark.triangle.fill",
                title: strings.lookupFailed,
                message: strings.errorMessage(error),
                tone: .error,
                actionTitle: strings.selectRegion,
                action: selectRegion
            )
        } else if selectionFlow.status == .permissionRequired {
            LookupMessageCard(
                icon: "lock.shield",
                message: strings.accessibilityPermissionNeeded,
                tone: .warning,
                actionTitle: strings.retrySelection,
                action: retrySelection
            )
        } else if selectionFlow.status == .regionFallback {
            LookupMessageCard(
                icon: "viewfinder",
                message: strings.selectionUnavailable,
                actionTitle: strings.selectRegionInstead,
                action: selectRegion
            )
        } else {
            lookupStateContent
        }
    }

    @ViewBuilder
    private var lookupStateContent: some View {
        switch lookup.phase {
        case .idle:
            LookupMessageCard(icon: "text.book.closed", message: strings.idle)
        case .loading:
            LookupMessageCard(
                icon: "sparkles",
                message: lookup.selectedSource == .groq ? strings.groqLoading : strings.loading,
                showsProgress: true
            )
        case .error(let message):
            LookupMessageCard(
                icon: "exclamationmark.triangle.fill",
                title: strings.lookupFailed,
                message: strings.errorMessage(message),
                tone: .error,
                actionTitle: strings.retryLookup,
                action: { Task { await lookup.submit() } }
            )
        case .result:
            resultContent
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if let result = lookup.result, let completed = lookup.completedLookup {
            let isFavorite = favorites.contains(
                text: completed.request.text,
                targetLanguage: completed.targetLanguage,
                context: completed.request.context
            )
            LookupResultView(
                lookupText: completed.request.text,
                source: lookup.selectedSource == .groq ? "Groq" : strings.local,
                result: result,
                showsVietnamese: completed.targetLanguage == .simpleEnglish,
                vietnameseResult: lookup.vietnameseResult,
                vietnamesePhase: lookup.vietnamesePhase,
                isVietnameseExpanded: $isVietnameseExpanded,
                loadVietnamese: { await lookup.loadVietnameseResult() },
                isExpanded: $isDetailExpanded,
                isFavorite: isFavorite,
                saveFavorite: {
                    try? favorites.save(
                        text: completed.request.text,
                        targetLanguage: completed.targetLanguage,
                        context: completed.request.context,
                        result: completed.result
                    )
                },
                strings: strings
            )

            if favorites.persistenceError != nil {
                Label(strings.storageUnavailable, systemImage: "externaldrive.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 10)
            }
        }
    }
}

private struct LookupMessageCard: View {
    enum Tone {
        case neutral
        case warning
        case error

        var color: Color {
            switch self {
            case .neutral: .accentColor
            case .warning: .orange
            case .error: .red
            }
        }
    }

    let icon: String
    var title: String?
    let message: String
    var tone: Tone = .neutral
    var showsProgress = false
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tone.color.opacity(0.12))
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tone.color)
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }
                    Text(message)
                        .foregroundStyle(title == nil ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                }
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct LookupResultView: View {
    let lookupText: String
    let source: String
    let result: LookupResult
    let showsVietnamese: Bool
    let vietnameseResult: LookupResult?
    let vietnamesePhase: LookupPhase
    @Binding var isVietnameseExpanded: Bool
    let loadVietnamese: () async -> Void
    @Binding var isExpanded: Bool
    let isFavorite: Bool
    let saveFavorite: () -> Void
    let strings: UIStrings

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCopied = false

    private var detailAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.18)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(lookupText)
                    .font(.headline)
                    .lineLimit(1)
                    .textSelection(.enabled)

                Spacer()

                Text(source)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            Text(result.meaning)
                .font(.title3.weight(.semibold))
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: 6) {
                Text(strings.resultExample)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(result.example)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor.opacity(0.65))
                    .frame(width: 2)
            }

            if showsVietnamese {
                DisclosureGroup(strings.vietnameseExplanation, isExpanded: $isVietnameseExpanded) {
                    VietnameseResultContent(
                        result: vietnameseResult,
                        phase: vietnamesePhase,
                        retry: loadVietnamese,
                        strings: strings
                    )
                    .padding(.top, 8)
                }
                .onChange(of: isVietnameseExpanded) { _, expanded in
                    if expanded { Task { await loadVietnamese() } }
                }
            }

            if isExpanded, !result.detail.isEmpty {
                Text(strings.resultDetail(result.detail))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }

            Divider()

            HStack(spacing: 8) {
                Button(isFavorite ? strings.savedFavorite : strings.saveFavorite,
                       systemImage: isFavorite ? "star.fill" : "star",
                       action: saveFavorite)
                    .disabled(isFavorite)
                    .contentTransition(.symbolEffect(.replace))

                Button(isCopied ? strings.copiedResult : strings.copyResult,
                       systemImage: isCopied ? "checkmark" : "doc.on.doc",
                       action: copyResult)
                    .contentTransition(.symbolEffect(.replace))

                Spacer()

                if !result.detail.isEmpty {
                    Button(isExpanded ? strings.showLess : strings.moreDetail,
                           systemImage: isExpanded ? "chevron.up" : "chevron.down") {
                        if reduceMotion {
                            isExpanded.toggle()
                        } else {
                            withAnimation(detailAnimation) { isExpanded.toggle() }
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        }
        .animation(detailAnimation, value: isExpanded)
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: .milliseconds(1_200))
            guard !Task.isCancelled else { return }
            if reduceMotion {
                isCopied = false
            } else {
                withAnimation(.easeOut(duration: 0.15)) { isCopied = false }
            }
        }
    }

    private func copyResult() {
        let content = [result.meaning, result.example]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        if reduceMotion {
            isCopied = true
        } else {
            withAnimation(.easeOut(duration: 0.15)) { isCopied = true }
        }
    }
}

private struct VietnameseResultContent: View {
    let result: LookupResult?
    let phase: LookupPhase
    let retry: () async -> Void
    let strings: UIStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch phase {
            case .idle, .loading:
                ProgressView(strings.loadingVietnamese)
            case .result:
                if let result {
                    Text(result.meaning)
                        .textSelection(.enabled)
                    Text(result.example)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            case .error(let message):
                Text(strings.errorMessage(message))
                    .foregroundStyle(.red)
                Button(strings.retryVietnamese) {
                    Task { await retry() }
                }
            }
        }
    }
}

private struct ScrollContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
