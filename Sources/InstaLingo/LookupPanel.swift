import AppKit
import SwiftUI
import LookupCore

struct LookupPanel: View {
    @Bindable var lookup: LookupCoordinator
    @Bindable var ocrFlow: OCRLookupFlow
    @Bindable var selectionFlow: SelectionLookupFlow
    @Bindable var languageSettings: UILanguageSettings
    @Bindable var favorites: LookupFavorites
    let history: LookupHistory
    let hotkeys: GlobalHotkeyManager
    let groqConfiguration: GroqConfiguration
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
    @State private var contentHeight: CGFloat = 300

    /// The body grows with its content up to this height, then scrolls.
    private let maximumBodyHeight: CGFloat = 440
    private var strings: UIStrings { languageSettings.strings }

    var body: some View {
        VStack(spacing: 0) {
            LookupPanelHeader(
                strings: strings,
                openHistory: openHistory,
                openFavorites: openFavorites,
                openSettings: openSettings,
                quitApp: quitApp
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    LookupInputBar(
                        text: $lookup.text,
                        inputSelection: $inputSelection,
                        inputFocusGeneration: inputFocusGeneration,
                        strings: strings,
                        selectionShortcut: hotkeys.assignments[.selectedText].displayName,
                        regionShortcut: hotkeys.assignments[.screenRegion].displayName,
                        allowsProgrammaticFocus: selectionFlow.status != .reading
                            && selectionFlow.status != .reviewing
                            && !ocrFlow.isSelecting
                            && !ocrFlow.isRecognizing
                            && !ocrFlow.isReviewing
                            && lookup.phase != .loading,
                        selectionDisabled: selectionFlow.status == .reading || lookup.phase == .loading,
                        regionDisabled: ocrFlow.isSelecting || ocrFlow.isRecognizing || selectionFlow.status == .reading,
                        lookupDisabled: lookup.phase == .loading,
                        clear: clearInput,
                        lookupSelection: startSelectionLookup,
                        selectRegion: startRegionSelection,
                        submit: submitInput
                    )

                    HStack(spacing: 8) {
                        ProfessionalContextPicker(catalog: lookup.contextCatalog, strings: strings)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        GlassMenuPicker(
                            label: strings.resultLanguage,
                            selection: $lookup.selectedLanguage,
                            options: resultLanguageOptions
                        )
                        .fixedSize()
                    }

                    LookupStateRegion(
                        lookup: lookup,
                        ocrFlow: ocrFlow,
                        selectionFlow: selectionFlow,
                        favorites: favorites,
                        history: history,
                        isDetailExpanded: $isDetailExpanded,
                        isVietnameseExpanded: $isVietnameseExpanded,
                        strings: strings,
                        selectionShortcut: hotkeys.assignments[.selectedText].displayName,
                        regionShortcut: hotkeys.assignments[.screenRegion].displayName,
                        retrySelection: startSelectionLookup,
                        selectRegion: startRegionSelection,
                        submitPhrase: submitPhrase,
                        lookUp: lookUp
                    )
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    if height > 0 { contentHeight = height }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(contentHeight, maximumBodyHeight))

            LookupPanelFooter(
                source: lookup.selectedSource,
                groqModel: groqConfiguration.model,
                hasGroqKey: groqConfiguration.hasAPIKey,
                showsQuickMeaningHint: lookup.phase == .result
                    && lookup.completedLookup?.targetLanguage == .simpleEnglish,
                strings: strings
            )
        }
        .background(Theme.panelFill)
        .foregroundStyle(Theme.textPrimary)
        .onExitCommand(perform: hidePanel)
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
        .onChange(of: lookup.selectedLanguage) { _, _ in
            // Show the current word in the newly chosen language.
            Task { await lookup.refreshForSelectedContext() }
        }
        .onChange(of: lookup.text) { _, _ in inputSelection = nil }
        .environment(\.locale, languageSettings.language.locale)
    }

    private var resultLanguageOptions: [(value: TargetLanguage, title: String)] {
        lookup.availableLanguages
            .sorted { $0.isSimpleEnglish && !$1.isSimpleEnglish }
            .map { ($0, strings.targetLanguageName(code: $0.code)) }
    }

    private var selectedInputText: String? {
        guard let inputSelection,
              case .selection(let range) = inputSelection.indices,
              !range.isEmpty else { return nil }
        return String(lookup.text[range])
    }

    private func clearInput() {
        selectionFlow.reset()
        ocrFlow.cancelReview()
        lookup.text = ""
        inputFocusGeneration += 1
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

    private func submitPhrase(_ phrase: String) {
        selectionFlow.reset()
        ocrFlow.cancelReview()
        Task { await lookup.submit(selectedPhrase: phrase) }
    }

    private func lookUp(_ text: String) {
        selectionFlow.reset()
        ocrFlow.cancelReview()
        lookup.text = text
        Task { await lookup.submit() }
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

// MARK: - Header and footer

private struct LookupPanelHeader: View {
    let strings: UIStrings
    let openHistory: () -> Void
    let openFavorites: () -> Void
    let openSettings: () -> Void
    let quitApp: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accentBright)
                .accessibilityHidden(true)

            Text("Insta Lingo")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button(action: openHistory) {
                Image(systemName: "clock")
            }
            .buttonStyle(IconButtonStyle())
            .keyboardShortcut("y", modifiers: .command)
            .help("\(strings.historyTitle)  ⌘Y")
            .accessibilityLabel(strings.historyTitle)

            Button(action: openFavorites) {
                Image(systemName: "star")
            }
            .buttonStyle(IconButtonStyle())
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .help("\(strings.favorites)  ⇧⌘S")
            .accessibilityLabel(strings.favorites)

            Menu {
                Button(strings.settingsTitle, systemImage: "gearshape", action: openSettings)
                    .keyboardShortcut(",", modifiers: .command)
                Divider()
                Button(strings.quitApp, systemImage: "power", role: .destructive, action: quitApp)
                    .keyboardShortcut("q", modifiers: .command)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.iconDefault)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(strings.moreActions)
            .accessibilityLabel(strings.moreActions)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(height: 36)
        .overlay(alignment: .bottom) {
            Theme.hairline.frame(height: 1)
        }
    }
}

private struct LookupPanelFooter: View {
    let source: LookupSource
    let groqModel: GroqModel
    let hasGroqKey: Bool
    let showsQuickMeaningHint: Bool
    let strings: UIStrings

    private var isReady: Bool { source == .local || hasGroqKey }

    private var sourceLabel: String {
        switch source {
        case .groq: hasGroqKey ? "Groq · \(groqModel.rawValue)" : strings.groqNeedsKey
        case .local: strings.onThisMac
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isReady ? Theme.success : Theme.warning)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(sourceLabel)
                    .truncationMode(.middle)
            }
            .layoutPriority(1)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            if showsQuickMeaningHint {
                Text(strings.quickMeaningFooterHint)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(spacing: 4) {
                KeyCap(keys: "⌘S")
                Text(strings.footerSave)
            }
        }
        .font(.system(size: 10.5))
        .foregroundStyle(Theme.textSecondary)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .frame(height: 26)
        .overlay(alignment: .top) {
            Theme.hairline.frame(height: 1)
        }
    }
}

// MARK: - Input

private struct LookupInputBar: View {
    @Binding var text: String
    @Binding var inputSelection: TextSelection?
    let inputFocusGeneration: Int
    let strings: UIStrings
    let selectionShortcut: String
    let regionShortcut: String
    let allowsProgrammaticFocus: Bool
    let selectionDisabled: Bool
    let regionDisabled: Bool
    let lookupDisabled: Bool
    let clear: () -> Void
    let lookupSelection: () -> Void
    let selectRegion: () -> Void
    let submit: () -> Void

    @FocusState private var textFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .accessibilityHidden(true)

            TextField(strings.inputPlaceholder, text: $text, selection: $inputSelection, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...4)
                .padding(.leading, 2)
                .focused($textFocused)
                .onSubmit(submit)
                .accessibilityLabel(strings.inputAccessibility)

            if !text.isEmpty {
                Button(action: clear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(hex: 0x6E6E73))
                }
                .buttonStyle(IconButtonStyle(size: 22))
                .help(strings.clearInput)
                .accessibilityLabel(strings.clearInput)
            }

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 18)
                .padding(.horizontal, 2)
                .accessibilityHidden(true)

            Button(action: lookupSelection) {
                Image(systemName: "text.viewfinder")
            }
            .buttonStyle(IconButtonStyle())
            .disabled(selectionDisabled)
            .help("\(strings.lookupSelection)  \(selectionShortcut)")
            .accessibilityLabel(strings.lookupSelection)

            Button(action: selectRegion) {
                Image(systemName: "viewfinder")
            }
            .buttonStyle(IconButtonStyle())
            .disabled(regionDisabled)
            .help("\(strings.selectRegion)  \(regionShortcut)")
            .accessibilityLabel(strings.selectRegionAccessibility)

            Button(strings.lookup, action: submit)
            .buttonStyle(PrimaryButtonStyle(height: 26))
            .padding(.leading, 2)
            .help("\(strings.lookup)  ⌘↩")
            .disabled(lookupDisabled)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .padding(.vertical, 5)
        .frame(minHeight: 36)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.fieldStroke)
        }
        .background {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.accentBright.opacity(textFocused ? 0.16 : 0), lineWidth: 3)
                .padding(-3)
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

// MARK: - State region

private struct LookupStateRegion: View {
    let lookup: LookupCoordinator
    let ocrFlow: OCRLookupFlow
    let selectionFlow: SelectionLookupFlow
    let favorites: LookupFavorites
    let history: LookupHistory
    @Binding var isDetailExpanded: Bool
    @Binding var isVietnameseExpanded: Bool
    let strings: UIStrings
    let selectionShortcut: String
    let regionShortcut: String
    let retrySelection: () -> Void
    let selectRegion: () -> Void
    let submitPhrase: (String) -> Void
    let lookUp: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

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

    var body: some View {
        ZStack(alignment: .topLeading) {
            stateContent
                .id(stateIdentity)
                // Scaling a native ProgressView during preferred-content sizing
                // can produce inconsistent AppKit minimum and maximum dimensions.
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassCard(cornerRadius: 12)
        .animation(stateAnimation, value: stateIdentity)
    }

    @ViewBuilder
    private var stateContent: some View {
        if selectionFlow.status == .reading {
            LookupMessageView(icon: "text.magnifyingglass", message: strings.readingSelection, showsProgress: true)
        } else if ocrFlow.isSelecting {
            LookupMessageView(icon: "viewfinder", message: strings.selectingRegionHint)
        } else if ocrFlow.isRecognizing {
            LookupMessageView(icon: "text.viewfinder", message: strings.recognizingRegion, showsProgress: true)
        } else if selectionFlow.status == .reviewing || ocrFlow.isReviewing {
            CapturedTextPicker(
                text: lookup.text,
                intro: ocrFlow.isReviewing ? strings.reviewRegionIntro : strings.reviewSelectionIntro,
                strings: strings,
                submit: submitPhrase
            )
            .id(lookup.text)
        } else if let error = selectionFlow.errorMessage {
            LookupMessageView(
                icon: "exclamationmark.triangle",
                title: strings.lookupFailed,
                message: strings.errorMessage(error),
                tone: .error,
                primary: MessageAction(title: strings.retrySelection, action: retrySelection)
            )
        } else if let error = ocrFlow.errorMessage {
            LookupMessageView(
                icon: "exclamationmark.triangle",
                title: strings.lookupFailed,
                message: strings.errorMessage(error),
                tone: .error,
                primary: MessageAction(title: strings.selectRegion, action: selectRegion)
            )
        } else if selectionFlow.status == .permissionRequired {
            LookupMessageView(
                icon: "lock.shield",
                title: strings.permissionTitle,
                message: strings.permissionMessage,
                tone: .warning,
                primary: MessageAction(title: strings.openSystemSettings) {
                    openURL(SystemSettingsLink.accessibility)
                },
                secondary: MessageAction(title: strings.retrySelection, action: retrySelection),
                tertiary: MessageAction(title: strings.useRegionInstead, action: selectRegion)
            )
        } else if selectionFlow.status == .regionFallback {
            LookupMessageView(
                icon: "viewfinder",
                title: strings.selectionUnavailableTitle,
                message: strings.selectionUnavailableMessage,
                primary: MessageAction(title: strings.selectRegion, action: selectRegion),
                note: strings.orPressNextTime(regionShortcut)
            )
        } else {
            lookupStateContent
        }
    }

    @ViewBuilder
    private var lookupStateContent: some View {
        switch lookup.phase {
        case .idle:
            LookupIdleView(
                recent: recentEntries,
                strings: strings,
                selectionShortcut: selectionShortcut,
                regionShortcut: regionShortcut,
                lookUp: lookUp
            )
        case .loading:
            LookupLoadingView(
                word: lookup.text.trimmingCharacters(in: .whitespacesAndNewlines),
                status: lookup.selectedSource == .groq ? strings.groqLoading : strings.loading
            )
        case .error(let message):
            errorContent(message)
        case .result:
            resultContent
        }
    }

    @ViewBuilder
    private func errorContent(_ message: String) -> some View {
        if LookupCoordinator.isShortPhrase(lookup.text) {
            LookupMessageView(
                icon: "exclamationmark.triangle",
                title: strings.lookupFailed,
                message: strings.errorMessage(message),
                tone: .error,
                primary: MessageAction(title: strings.retryLookup) {
                    Task { await lookup.submit() }
                },
                secondary: lookup.selectedSource == .groq
                    ? MessageAction(title: strings.lookUpOnThisMac, action: lookUpOnThisMac)
                    : nil
            )
        } else {
            // Input problems need a different word, not a retry.
            LookupMessageView(icon: "character.cursor.ibeam", message: strings.errorMessage(message), tone: .warning)
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if let result = lookup.result, let completed = lookup.completedLookup {
            let favorite = favorites.entry(
                text: completed.request.text,
                targetLanguage: completed.targetLanguage,
                context: completed.request.context
            )
            VStack(alignment: .leading, spacing: 0) {
                LookupResultView(
                    lookupText: completed.request.text,
                    metaLine: strings.resultMeta(
                        language: strings.targetLanguageName(code: completed.targetLanguage.code),
                        context: strings.contextName(id: completed.request.context.id,
                                                     customName: completed.request.context.name)
                    ),
                    result: result,
                    isEnglish: completed.targetLanguage == .simpleEnglish,
                    vietnameseResult: lookup.vietnameseResult,
                    vietnamesePhase: lookup.vietnamesePhase,
                    isVietnameseExpanded: $isVietnameseExpanded,
                    isDetailExpanded: $isDetailExpanded,
                    loadVietnamese: { await lookup.loadVietnameseResult() },
                    loadQuickMeaning: { try await lookup.quickMeaning(for: $0) },
                    isFavorite: favorite != nil,
                    toggleFavorite: {
                        if let favorite {
                            try? favorites.remove(id: favorite.id)
                        } else {
                            try? favorites.save(
                                text: completed.request.text,
                                targetLanguage: completed.targetLanguage,
                                context: completed.request.context,
                                result: completed.result
                            )
                        }
                    },
                    strings: strings
                )

                if favorites.persistenceError != nil {
                    Label(strings.storageUnavailable, systemImage: "externaldrive.badge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                }
            }
        }
    }

    /// The most recent distinct words, newest first.
    private var recentEntries: [LookupHistoryEntry] {
        guard history.isEnabled else { return [] }
        var seen = Set<String>()
        var recent: [LookupHistoryEntry] = []
        for entry in history.entries where seen.insert(entry.text.lowercased()).inserted {
            recent.append(entry)
            if recent.count == 3 { break }
        }
        return recent
    }

    /// Runs this lookup on the Mac once, then returns to Groq for later lookups.
    private func lookUpOnThisMac() {
        let previous = lookup.selectedSource
        lookup.selectedSource = .local
        Task {
            await lookup.submit()
            lookup.selectedSource = previous
        }
    }
}

struct MessageAction {
    let title: String
    let action: () -> Void
}

private struct LookupMessageView: View {
    enum Tone {
        case neutral
        case warning
        case error

        var color: Color {
            switch self {
            case .neutral: Theme.accentBright
            case .warning: Theme.warning
            case .error: Theme.danger
            }
        }

        var tint: Color {
            switch self {
            case .neutral: Theme.accentTint
            case .warning: Theme.warningTint
            case .error: Theme.dangerTint
            }
        }
    }

    let icon: String
    var title: String?
    let message: String
    var tone: Tone = .neutral
    var showsProgress = false
    var primary: MessageAction?
    var secondary: MessageAction?
    var tertiary: MessageAction?
    var note: String?

    private var hasActions: Bool { primary != nil || secondary != nil || tertiary != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                TintedIcon(systemName: icon, color: tone.color, tint: tone.tint)

                VStack(alignment: .leading, spacing: 3) {
                    if let title {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(title == nil ? Theme.textPrimary : Theme.iconDefault)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, title == nil ? 6 : 0)

                Spacer(minLength: 8)

                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 6)
                        .accessibilityHidden(true)
                }
            }

            if hasActions {
                FlowLayout(spacing: 6) {
                    if let primary {
                        Button(primary.title, action: primary.action)
                            .buttonStyle(PrimaryButtonStyle(height: 26))
                    }
                    if let secondary {
                        Button(secondary.title, action: secondary.action)
                            .buttonStyle(ActionButtonStyle(height: 26))
                    }
                    if let tertiary {
                        Button(tertiary.title, action: tertiary.action)
                            .buttonStyle(ActionButtonStyle(height: 26))
                    }
                    if let note {
                        Text(note)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(height: 26)
                    }
                }
                .padding(.leading, 38)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

private struct LookupIdleView: View {
    let recent: [LookupHistoryEntry]
    let strings: UIStrings
    let selectionShortcut: String
    let regionShortcut: String
    let lookUp: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                TintedIcon(systemName: "text.viewfinder", color: Theme.accentBright, tint: Theme.accentTint)

                VStack(alignment: .leading, spacing: 3) {
                    Text(Self.withKey(strings.idleTitle, key: selectionShortcut))
                        .font(.system(size: 13, weight: .semibold))
                    Text(Self.withKey(strings.idleMessage, key: regionShortcut))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(title: strings.recentLookups)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 2)

                    ForEach(recent) { entry in
                        Button {
                            lookUp(entry.text)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(entry.text)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.textPrimary)
                                Text(entry.meaning)
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(entry.createdAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .font(.system(size: 12))
                        }
                        .buttonStyle(HoverRowButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Replaces the `%@` placeholder with the shortcut drawn as a key cap.
    private static func withKey(_ template: String, key: String) -> AttributedString {
        let parts = template.components(separatedBy: "%@")
        var result = AttributedString(parts.first ?? template)
        guard parts.count > 1 else { return result }
        var cap = AttributedString("\u{2009}\(key)\u{2009}")
        cap.font = .system(size: 10.5, weight: .medium)
        cap.foregroundColor = Theme.iconDefault
        cap.backgroundColor = Color.white.opacity(0.1)
        result += cap
        result += AttributedString(parts.dropFirst().joined(separator: "%@"))
        return result
    }
}

private struct LookupLoadingView: View {
    let word: String
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            SkeletonBar(widthFraction: 0.92, height: 14)
            SkeletonBar(widthFraction: 0.70, height: 14)
            SkeletonBar(widthFraction: 0.40, height: 10)
                .padding(.top, 6)
            SkeletonBar(widthFraction: 0.84, height: 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Lets the user pick one word, or shift-click a phrase, from captured text
/// that is too long to look up as a whole.
private struct CapturedTextPicker: View {
    private struct Token: Identifiable {
        /// Position in the captured text. The picker is rebuilt whenever the
        /// text changes, so a position always names the same word.
        let id: Int
        let range: Range<String.Index>
    }

    let text: String
    let intro: String
    let strings: UIStrings
    let submit: (String) -> Void

    @State private var selection: ClosedRange<Int>?

    private static let maximumTokens = 80

    private var tokens: [Token] {
        text.split(whereSeparator: \.isWhitespace)
            .prefix(Self.maximumTokens)
            .enumerated()
            .map { Token(id: $0.offset, range: $0.element.startIndex..<$0.element.endIndex) }
    }

    private var phrase: String? {
        let tokens = tokens
        guard let selection, selection.upperBound < tokens.count else { return nil }
        let range = tokens[selection.lowerBound].range.lowerBound..<tokens[selection.upperBound].range.upperBound
        let phrase = String(text[range]).trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        return phrase.isEmpty ? nil : phrase
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(intro)
                .font(.system(size: 12))
                .foregroundStyle(Theme.iconDefault)

            FlowLayout(spacing: 6) {
                ForEach(tokens) { token in
                    Button(String(text[token.range])) { toggle(token.id) }
                        .buttonStyle(ChipButtonStyle(isOn: selection?.contains(token.id) == true))
                }
            }

            HStack(spacing: 8) {
                Button(phrase.map(strings.lookUpPhrase) ?? strings.lookup) {
                    if let phrase { submit(phrase) }
                }
                .buttonStyle(PrimaryButtonStyle(height: 26))
                .disabled(phrase == nil)

                Text(strings.shiftClickHint)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ index: Int) {
        if NSEvent.modifierFlags.contains(.shift), let selection {
            self.selection = min(selection.lowerBound, index)...max(selection.upperBound, index)
        } else {
            selection = selection == index...index ? nil : index...index
        }
    }
}

extension UIStrings {
    private func panelText(_ vi: String, _ en: String) -> String {
        language == .vietnamese ? vi : en
    }

    var clearInput: String { panelText("Xóa chữ đã nhập", "Clear") }
    var recentLookups: String { panelText("Gần đây", "Recent") }
    var idleTitle: String { panelText("Bôi đen một từ ở bất kỳ đâu, rồi nhấn %@", "Select a word anywhere, then press %@") }
    var idleMessage: String {
        panelText(
            "Nghĩa sẽ hiện ở đây. Bạn cũng có thể gõ từ ở ô trên, hoặc nhấn %@ để đọc chữ trong một vùng màn hình.",
            "The meaning appears here. You can also type a word above, or press %@ to read text from a screen region."
        )
    }
    var onThisMac: String { panelText("Trên máy Mac này", "On this Mac") }
    var groqNeedsKey: String { panelText("Groq · thêm khóa API trong Cài đặt", "Groq · add an API key in Settings") }
    var quickMeaningFooterHint: String { panelText("Double-click một từ để xem nghĩa nhanh", "Double-click a word for a quick meaning") }
    var footerSave: String { panelText("lưu", "save") }
    var permissionTitle: String { panelText("Cho phép Insta Lingo đọc chữ đã bôi đen", "Allow Insta Lingo to read selected text") }
    var permissionMessage: String {
        panelText(
            "Chỉ cần làm một lần. Bật Insta Lingo trong Quyền riêng tư & Bảo mật → Trợ năng, rồi thử đọc lại.",
            "One-time step. Turn on Insta Lingo in Privacy & Security → Accessibility, then retry."
        )
    }
    var openSystemSettings: String { panelText("Mở Cài đặt hệ thống", "Open System Settings") }
    var useRegionInstead: String { panelText("Dùng vùng màn hình", "Use screen region instead") }
    var selectionUnavailableTitle: String { panelText("Ứng dụng này không chia sẻ chữ đã bôi đen", "This app didn't share the selected text") }
    var selectionUnavailableMessage: String {
        panelText("Kéo khoanh quanh từ trên màn hình, Insta Lingo sẽ đọc giúp bạn.", "Drag around the word on screen and Insta Lingo will read it for you.")
    }
    func orPressNextTime(_ shortcut: String) -> String {
        panelText("hoặc nhấn \(shortcut) lần sau", "or press \(shortcut) next time")
    }
    var reviewRegionIntro: String { panelText("Đã đọc từ màn hình. Chọn từ hoặc cụm cần tra:", "Captured from screen. Pick a word or phrase to look up:") }
    var reviewSelectionIntro: String { panelText("Đoạn bôi đen khá dài. Chọn từ hoặc cụm cần tra:", "Your selection is long. Pick a word or phrase to look up:") }
    func lookUpPhrase(_ phrase: String) -> String { panelText("Tra “\(phrase)”", "Look up “\(phrase)”") }
    var shiftClickHint: String { panelText("Shift-click để chọn cả cụm", "Shift-click to select a phrase") }
    var lookUpOnThisMac: String { panelText("Tra trên máy Mac này", "Look up on this Mac") }
    func resultMeta(language: String, context: String) -> String {
        panelText("\(language) · ngữ cảnh \(context)", "\(language) · \(context) context")
    }
}
