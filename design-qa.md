# Design QA — Lookup panel refresh

- Source visual truth: `Prototypes/lookup-panel/index.html?variant=A`
- Implementation: `Sources/TransAtGlance/LookupPanel.swift`
- Intended viewport: 680 pt wide macOS popover, system display density
- State: idle, loading, review, error, and result states
- Source pixels: unavailable; the integrated browser is not available in this session
- Implementation pixels: unavailable; the app cannot be built with the active Command Line Tools-only toolchain
- Density normalization: not performed because neither side could be captured

## Full-view comparison evidence

Blocked. The selected prototype and the native SwiftUI implementation could not be rendered and captured in the same session.

## Focused region comparison evidence

Blocked for the same reason. Input controls, context chips, state card, result hierarchy, and action row were reviewed from source only; source review is not accepted as visual comparison evidence.

## Findings

- No visual severity can be assigned without rendered evidence.
- Static verification confirms the implementation keeps the 680 pt panel width, uses native system typography and colors, supplies localized copy, and gates motion with Reduce Motion.
- `swift build --target LookupCore` passes.
- Full app build is blocked because the active developer directory is `/Library/Developer/CommandLineTools` and the toolchain cannot load `SwiftUIMacros`.
- Tests are blocked by the same installation issue for `TestingMacros`.

## Comparison history

- No visual iteration was possible because the initial capture was blocked.

## Implementation checklist

- Select a full Xcode installation with `xcode-select`.
- Build and launch the menu-bar app.
- Capture prototype variant A and the result state at the same 680 pt width.
- Verify idle, loading, review, error, result, expanded detail, light/dark mode, and Reduce Motion.
- Fix any P0/P1/P2 differences and repeat the comparison before release.

final result: blocked
