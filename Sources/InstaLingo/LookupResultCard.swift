import AppKit
import SwiftUI
import LookupCore

/// The completed lookup: word, meaning, example and the collapsible
/// Vietnamese explanation and detail rows. The panel grows as rows open.
struct LookupResultView: View {
    let lookupText: String
    let metaLine: String
    let result: LookupResult
    /// Simple English results offer quick meanings and a Vietnamese explanation.
    let isEnglish: Bool
    let vietnameseResult: LookupResult?
    let vietnamesePhase: LookupPhase
    @Binding var isVietnameseExpanded: Bool
    @Binding var isDetailExpanded: Bool
    let loadVietnamese: () async -> Void
    let loadQuickMeaning: (String) async throws -> LookupResult
    let isFavorite: Bool
    let toggleFavorite: () -> Void
    let strings: UIStrings

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCopied = false
    @State private var quickWord: QuickMeaningWord?
    @State private var quickPhase: QuickMeaningPhase = .loading

    private var expandAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var hasRows: Bool { isEnglish || !result.detail.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            meaning

            if let quickWord {
                QuickMeaningCallout(word: quickWord.word, phase: quickPhase, strings: strings) {
                    withAnimation(expandAnimation) { self.quickWord = nil }
                }
                .transition(.opacity)
            }

            VStack(alignment: .leading, spacing: 3) {
                SectionLabel(title: strings.resultExample)
                example
            }

            if hasRows {
                disclosureRows
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, hasRows ? 2 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: quickWord?.id) { await loadQuickWord() }
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: .milliseconds(1_400))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { isCopied = false }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(lookupText)
                    .font(.system(size: 19, weight: .bold))
                    .tracking(-0.2)
                    .textSelection(.enabled)
                Text(metaLine)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)

            Button(action: toggleFavorite) {
                HStack(spacing: 4) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? Theme.star : Theme.textPrimary)
                        .contentTransition(.symbolEffect(.replace))
                    Text(isFavorite ? strings.savedShort : strings.saveShort)
                }
            }
            .buttonStyle(ActionButtonStyle())
            .keyboardShortcut("s", modifiers: .command)
            .help(isFavorite ? strings.removeFavorite : "\(strings.saveFavorite)  ⌘S")
            .accessibilityLabel(isFavorite ? strings.removeFavorite : strings.saveFavorite)

            Button(action: copyResult) {
                HStack(spacing: 4) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))
                    Text(isCopied ? strings.copiedResult : strings.copyResult)
                }
            }
            .buttonStyle(ActionButtonStyle())
        }
    }

    @ViewBuilder
    private var meaning: some View {
        if isEnglish {
            QuickMeaningText(
                text: result.meaning,
                font: .systemFont(ofSize: 15, weight: .medium),
                color: NSColor(Theme.textPrimary),
                isSelectionActive: quickWord != nil,
                lookup: { word, _ in beginQuickMeaning(word) }
            )
        } else {
            Text(result.meaning)
                .font(.system(size: 15, weight: .medium))
                .lineSpacing(2)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var example: some View {
        if isEnglish {
            QuickMeaningText(
                text: result.example,
                font: .systemFont(ofSize: 13),
                color: NSColor(Theme.textBody),
                emphasis: lookupText,
                emphasisColor: NSColor(Theme.textPrimary),
                isSelectionActive: quickWord != nil,
                lookup: { word, _ in beginQuickMeaning(word) }
            )
        } else {
            Text(Self.emphasized(result.example, term: lookupText, size: 13))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textBody)
                .lineSpacing(2)
                .textSelection(.enabled)
        }
    }

    private var disclosureRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            Theme.hairline.frame(height: 1)

            if isEnglish {
                DisclosureRow(
                    title: strings.vietnameseExplanationRow,
                    subtitle: strings.language == .english ? "Tiếng Việt" : nil,
                    isExpanded: $isVietnameseExpanded,
                    strings: strings
                )
                if isVietnameseExpanded {
                    VietnameseResultContent(
                        result: vietnameseResult,
                        phase: vietnamesePhase,
                        retry: loadVietnamese,
                        strings: strings
                    )
                    .padding(.leading, 18)
                    .padding(.bottom, 10)
                    .transition(.opacity)
                }
            }

            if !result.detail.isEmpty {
                if isEnglish {
                    Color.white.opacity(0.06).frame(height: 1)
                }
                DisclosureRow(
                    title: strings.moreDetail,
                    subtitle: strings.moreDetailSubtitle,
                    isExpanded: $isDetailExpanded,
                    strings: strings
                )
                if isDetailExpanded {
                    Text(strings.resultDetail(result.detail))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textBody)
                        .lineSpacing(2)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 18)
                        .padding(.bottom, 10)
                        .transition(.opacity)
                }
            }
        }
        .onChange(of: isVietnameseExpanded) { _, expanded in
            if expanded { Task { await loadVietnamese() } }
        }
    }

    private func beginQuickMeaning(_ word: String) {
        quickPhase = .loading
        withAnimation(expandAnimation) {
            quickWord = QuickMeaningWord(word: word)
        }
    }

    private func loadQuickWord() async {
        guard let quickWord else { return }
        do {
            let result = try await loadQuickMeaning(quickWord.word)
            guard self.quickWord?.id == quickWord.id else { return }
            quickPhase = .result(result)
        } catch is CancellationError {
            return
        } catch {
            guard self.quickWord?.id == quickWord.id else { return }
            quickPhase = .error(error.localizedDescription)
        }
    }

    private func copyResult() {
        let content = [result.meaning, result.example]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { isCopied = true }
    }

    /// Draws each occurrence of the looked-up term in a heavier, brighter style.
    static func emphasized(_ text: String, term: String, size: CGFloat = 15) -> AttributedString {
        var attributed = AttributedString(text)
        guard !term.isEmpty else { return attributed }
        var searchStart = attributed.startIndex
        while let range = attributed[searchStart...].range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[range].font = .system(size: size, weight: .semibold)
            attributed[range].foregroundColor = Theme.textPrimary
            searchStart = range.upperBound
        }
        return attributed
    }
}

private struct QuickMeaningWord: Identifiable, Equatable {
    let id = UUID()
    let word: String
}

private enum QuickMeaningPhase: Equatable {
    case loading
    case result(LookupResult)
    case error(String)
}

/// A temporary Vietnamese meaning for a word inside the result. The primary
/// result stays in place underneath it.
private struct QuickMeaningCallout: View {
    let word: String
    let phase: QuickMeaningPhase
    let strings: UIStrings
    let close: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(word) · \(strings.quickMeaning)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accentSoft)

                switch phase {
                case .loading:
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(strings.quickMeaningLoading)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .font(.system(size: 12))
                case .result(let result):
                    Text(result.meaning)
                        .font(.system(size: 13))
                        .lineSpacing(2)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                case .error(let message):
                    Text(strings.errorMessage(message))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(IconButtonStyle(size: 20))
            .accessibilityLabel(strings.closeQuickMeaning)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.accentBright.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.accentBright.opacity(0.18))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(strings.quickMeaning): \(word)")
    }
}

private struct DisclosureRow: View {
    let title: String
    let subtitle: String?
    @Binding var isExpanded: Bool
    let strings: UIStrings

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isHovered ? Theme.accentSoft : Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityValue(isExpanded ? strings.expanded : strings.collapsed)
    }
}

private struct VietnameseResultContent: View {
    let result: LookupResult?
    let phase: LookupPhase
    let retry: () async -> Void
    let strings: UIStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch phase {
            case .idle, .loading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(strings.loadingVietnamese)
                        .foregroundStyle(Theme.textSecondary)
                }
                .font(.system(size: 12))
            case .result:
                if let result {
                    Text(result.meaning)
                        .font(.system(size: 13))
                        .lineSpacing(2)
                        .textSelection(.enabled)
                    Text(result.example)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.iconDefault)
                        .lineSpacing(2)
                        .textSelection(.enabled)
                }
            case .error(let message):
                Text(strings.errorMessage(message))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.danger)
                Button(strings.retryVietnamese) {
                    Task { await retry() }
                }
                .buttonStyle(ActionButtonStyle())
                .padding(.top, 4)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension UIStrings {
    private func resultText(_ vi: String, _ en: String) -> String {
        language == .vietnamese ? vi : en
    }

    var saveShort: String { resultText("Lưu", "Save") }
    var savedShort: String { resultText("Đã lưu", "Saved") }
    var vietnameseExplanationRow: String { resultText("Giải nghĩa tiếng Việt", "Vietnamese explanation") }
    var expanded: String { resultText("Đang mở", "Expanded") }
    var collapsed: String { resultText("Đang thu gọn", "Collapsed") }
    var moreDetailSubtitle: String { resultText("cách dùng, sắc thái, từ liên quan", "usage, nuance, related terms") }
}
