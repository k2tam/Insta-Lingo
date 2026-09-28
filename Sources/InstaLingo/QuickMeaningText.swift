import AppKit
import SwiftUI
import LookupCore

/// Selectable result text that reports the word and source rectangle produced
/// by AppKit's native double-click word selection.
struct QuickMeaningText: NSViewRepresentable {
    let text: String
    let font: NSFont
    let color: NSColor
    let isSelectionActive: Bool
    let lookup: (String, CGRect) -> Void

    func makeNSView(context: Context) -> QuickMeaningTextView {
        let textView = QuickMeaningTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return textView
    }

    func updateNSView(_ nsView: QuickMeaningTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
        }
        nsView.font = font
        nsView.textColor = color
        nsView.onWordLookup = lookup
        if !isSelectionActive, nsView.selectedRange().length > 0 {
            nsView.setSelectedRange(NSRange(location: 0, length: 0))
        }
        nsView.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: QuickMeaningTextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width > 0,
              let textContainer = nsView.textContainer,
              let layoutManager = nsView.layoutManager else { return nil }
        textContainer.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let height = ceil(layoutManager.usedRect(for: textContainer).height)
        return CGSize(width: width, height: max(height, font.ascender - font.descender))
    }
}

final class QuickMeaningTextView: NSTextView {
    var onWordLookup: ((String, CGRect) -> Void)?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        guard event.clickCount == 2 else { return }

        let range = selectedRange()
        guard range.location != NSNotFound, range.length > 0,
              let textContainer,
              let layoutManager else { return }

        let rawWord = (string as NSString).substring(with: range)
        let word = rawWord.trimmingCharacters(in: CharacterSet.letters.inverted)
        guard !word.isEmpty, LookupCoordinator.isClearShortPhrase(word) else { return }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        onWordLookup?(word, rect)
    }
}
