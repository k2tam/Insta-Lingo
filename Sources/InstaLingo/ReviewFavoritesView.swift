import SwiftUI
import LookupCore

/// Flashcard practice over saved favorites: recall the meaning, reveal it,
/// then mark whether you knew it.
struct ReviewFavoritesView: View {
    let favorites: [LookupFavorite]
    let strings: UIStrings
    let close: () -> Void

    /// One-time snapshot of `favorites` taken when the session starts, so
    /// saving or removing favorites elsewhere does not reshuffle the deck.
    @State private var deck: [LookupFavorite]?
    @State private var index = 0
    @State private var isRevealed = false
    @State private var knownCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var cards: [LookupFavorite] { deck ?? favorites }
    private var isDone: Bool { index >= cards.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if cards.isEmpty {
                    ContentUnavailableView(strings.emptyFavorites, systemImage: "star")
                } else if isDone {
                    summary
                } else {
                    card(cards[index])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
        }
        .onAppear { if deck == nil { deck = favorites } }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(strings.reviewFavorites)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if !cards.isEmpty {
                Text(strings.reviewProgress(current: min(index + 1, cards.count), total: cards.count))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
                ProgressView(value: Double(index), total: Double(cards.count))
                    .progressViewStyle(.linear)
                    .frame(width: 110)
                    .accessibilityHidden(true)
            }
            Button(strings.backToLibrary, systemImage: "chevron.left", action: close)
                .buttonStyle(ActionButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private func card(_ favorite: LookupFavorite) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Pill(text: strings.contextName(id: favorite.context.id, customName: favorite.context.name),
                     foreground: Theme.accentSoft, background: Theme.accentTint)
                Text(favorite.text)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)

                if isRevealed {
                    VStack(spacing: 8) {
                        Text(favorite.meaning)
                            .font(.system(size: 16, weight: .medium))
                            .lineSpacing(3)
                        Text(favorite.example)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.iconDefault)
                            .lineSpacing(3)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .transition(.opacity)
                } else {
                    Text(strings.reviewRecallHint)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 26)
            .frame(width: 480)
            .frame(minHeight: 250, alignment: .top)
            .glassCard(cornerRadius: 14)
            .id(favorite.id)

            HStack(spacing: 10) {
                if isRevealed {
                    Button { next(knewIt: false) } label: {
                        HStack(spacing: 8) { Text(strings.reviewAgain); KeyCap(keys: "1") }
                    }
                    .buttonStyle(ActionButtonStyle(height: 32))
                    .keyboardShortcut("1", modifiers: [])

                    Button { next(knewIt: true) } label: {
                        HStack(spacing: 8) { Text(strings.reviewKnewIt); KeyCap(keys: "2") }
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 32))
                    .keyboardShortcut("2", modifiers: [])
                } else {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { isRevealed = true }
                    } label: {
                        HStack(spacing: 8) { Text(strings.reviewShowMeaning); KeyCap(keys: "space") }
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 32))
                    .keyboardShortcut(.space, modifiers: [])
                }
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 10) {
            Text(strings.reviewComplete)
                .font(.system(size: 20, weight: .bold))
            Text(strings.reviewSummary(known: knownCount, total: cards.count))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Button(strings.reviewRestart) {
                deck = favorites
                index = 0
                knownCount = 0
                isRevealed = false
            }
            .buttonStyle(PrimaryButtonStyle(height: 32))
            .padding(.top, 10)
        }
        .multilineTextAlignment(.center)
    }

    private func next(knewIt: Bool) {
        if knewIt { knownCount += 1 }
        isRevealed = false
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { index += 1 }
    }
}

extension UIStrings {
    private func reviewText(_ vi: String, _ en: String) -> String {
        language == .vietnamese ? vi : en
    }

    var backToLibrary: String { reviewText("Về thư viện", "Back to Library") }
    var reviewRecallHint: String { reviewText("Thử nhớ lại nghĩa, rồi mở xem.", "Try to recall the meaning, then reveal it.") }
    var reviewShowMeaning: String { reviewText("Xem nghĩa", "Show meaning") }
    var reviewAgain: String { reviewText("Ôn lại sau", "Review again") }
    var reviewKnewIt: String { reviewText("Mình đã nhớ", "I knew it") }
    var reviewComplete: String { reviewText("Hoàn tất lượt ôn", "Session complete") }
    var reviewRestart: String { reviewText("Ôn lại từ đầu", "Review again") }
    func reviewProgress(current: Int, total: Int) -> String {
        reviewText("\(current) / \(total)", "\(current) of \(total)")
    }
    func reviewSummary(known: Int, total: Int) -> String {
        reviewText("Bạn nhớ \(known) trên \(total) từ.", "You knew \(known) of \(total).")
    }
}
