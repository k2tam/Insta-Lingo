# Design QA — Nested meaning prototype A

- Source visual truth: `http://127.0.0.1:4174/?variant=A`
- Source capture: `/tmp/prototype-a-source.png`
- Implementation capture: `/tmp/insta-lingo-prototype-a-implementation.png`
- Combined comparison evidence: `/tmp/prototype-a-comparison.png`
- Viewport: 680 pt native macOS menu-bar popover on a 2× Retina display
- Source pixels: 1320 × 1900 crop from the browser reference
- Implementation pixels: 1400 × 1060 crop from the native app
- Combined comparison pixels: 3360 × 2100
- Density normalization: both captures came from the same 2× Retina display; the comparison judged the anchored word/popover region rather than browser chrome or surrounding canvas
- State: Simple English result for `scalable`, nested Vietnamese meaning open from an English word

## Full-view comparison evidence

The native result keeps the existing Insta Lingo panel hierarchy and design system while reproducing the selected interaction: an English word remains visibly selected, a compact popover is anchored to that word, and the primary `scalable` result stays visible behind it. The implementation uses the app's existing system typography, semantic colors, card radius, and spacing rather than copying the throwaway browser shell.

## Focused region comparison evidence

The focused word/popover region was checked in both the primary meaning and example sentence. The native popover contains the selected word, a secondary “Nghĩa nhanh” label, Vietnamese meaning, close control, and the note that the primary result remains unchanged. Its arrow is anchored to the selected glyph range and moves correctly between the two text blocks. A follow-up regression check used `cat` and the word `as` near the end of its primary meaning.

## Findings

- No actionable P0, P1, or P2 differences remain.
- Fonts and typography: native SF system styles preserve the reference hierarchy and remain consistent with the production panel.
- Spacing and layout rhythm: the popover is compact, does not reflow the result card, and remains visually attached to the selected word.
- Colors and visual tokens: semantic macOS materials, accent color, secondary text, selection highlight, and error/loading states match the app's existing tokens and the dark reference intent.
- Image quality and asset fidelity: the target contains no raster imagery; implementation uses native SF Symbols for the close and hint affordances rather than approximate custom artwork.
- Copy and content: localized hint, loading, close, error, and “primary result stays” copy are present in Vietnamese and English. The quick result intentionally omits the prototype's hard-coded part of speech because providers do not return a reliable POS field.
- Accessibility: the close control has a localized label, the popover exposes a meaningful group label, result text remains selectable, and double-click uses native AppKit word selection.

## Primary interactions tested

- Submitted `scalable` and observed the loading-to-result transition.
- Double-clicked `expanded` in the primary meaning and received a Vietnamese quick meaning.
- Closed the popover and confirmed the primary result remained unchanged.
- Double-clicked `demand` in the example and received a second anchored quick meaning.

## Comparison history

- Initial comparison: the quick-meaning interaction and content matched the chosen direction.
- Follow-up: a user capture revealed that an anchor positioned with SwiftUI `offset` kept its pre-transform attachment geometry, placing the arrow left of the selected word.
- Fix verification: replaced the transformed anchor with real spacer-based layout and re-tested `cat` → `as`; the popover arrow now points directly at the selected glyph range.

## Implementation checklist

- [x] Keep the original lookup visible and unchanged.
- [x] Resolve nested meanings with the completed lookup's provider and current professional context.
- [x] Return the nested meaning in Vietnamese without recording another history entry.
- [x] Anchor a native popover to the double-clicked glyph range.
- [x] Support meaning and example text, loading, success, error, and close states.
- [x] Preserve localized copy and accessibility labels.

## Follow-up polish

- P3: if providers later expose a trustworthy part-of-speech field, add it beside the selected word to match the throwaway mock more literally.

final result: passed
