# Lookup panel UI prototype

Question: which wider panel layout best prioritizes choosing a professional context and reading the lookup result?

Decision (2026-09-24): variant `A` was selected. Its wide single-column hierarchy is implemented in `Sources/InstaLingo/LookupPanel.swift`; result-language selection stays in the panel, while provider and interface-language controls move to Settings.

Run from the repository root:

```sh
./scripts/run-lookup-panel-prototype.sh
```

Open `http://127.0.0.1:4173/?variant=A`. Use the floating arrows or the left/right arrow keys to compare:

- `A` — wide single-column result focus
- `B` — persistent context sidebar and result workspace
- `C` — context-first hierarchy with an editorial result area

All variants keep the result-language control in the panel. Interface language, lookup provider, and provider credentials belong in Settings. Selected-text lookup, screen-region lookup, history, favorites, and quit are grouped under the `…` menu.

This is throwaway prototype code. After a direction is chosen, reimplement the winning hierarchy in SwiftUI rather than shipping this HTML.
